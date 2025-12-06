# System Architecture - Mojo PDF Search Engine

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     USER INPUT                              │
│  ./pdfsearch document.pdf "search query" N                  │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│                  ARGUMENT PARSING                           │
│  • Extract PDF path                                         │
│  • Extract search query                                     │
│  • Extract result count N                                   │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│              PDF TEXT EXTRACTION                            │
│  (Python PyPDF2 via Mojo interop)                          │
│  • Open PDF file                                           │
│  • Extract text from each page                             │
│  • Maintain page number metadata                           │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│              PASSAGE CREATION                               │
│  • Sliding window (500 chars)                              │
│  • Overlap (100 chars)                                     │
│  • Sentence-aware boundaries                               │
│  • Store page + position metadata                          │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│                 TOKENIZATION                                │
│  (SIMD Optimized)                                          │
│  • Convert to lowercase                                    │
│  • Split on punctuation/whitespace                         │
│  • Parallel character processing                           │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ├──────────────┬────────────────┐
                    ▼              ▼                ▼
        ┌─────────────────┐  ┌──────────┐  ┌──────────┐
        │ Query Tokens    │  │Passage 1 │  │Passage N │
        │ ["machine",     │  │ Tokens   │  │ Tokens   │
        │  "learning"]    │  │          │  │          │
        └─────────────────┘  └──────────┘  └──────────┘
                    │              │                │
                    └──────────────┴────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────┐
│                TF-IDF SCORING ENGINE                        │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  FOR EACH PASSAGE:                                    │ │
│  │                                                       │ │
│  │  1. Calculate Term Frequency (TF)                    │ │
│  │     • Count term occurrences (SIMD)                  │ │
│  │     • Apply sublinear scaling: 1 + log(count)        │ │
│  │                                                       │ │
│  │  2. Calculate Inverse Document Frequency (IDF)       │ │
│  │     • Count passages containing term                 │ │
│  │     • Apply formula: log((N+1)/(df+1))              │ │
│  │                                                       │ │
│  │  3. Compute Combined Score                           │ │
│  │     • score = Σ(TF × IDF) for all query terms       │ │
│  │     • Apply length normalization: / sqrt(len + 1)    │ │
│  └───────────────────────────────────────────────────────┘ │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│              RESULT RANKING                                 │
│  • Sort by score (descending)                              │
│  • Select top N results                                    │
│  • Preserve passage metadata                               │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│              OUTPUT FORMATTING                              │
│  • Format scores (2 decimal places)                        │
│  • Clean text snippets (200 chars)                         │
│  • Display with page numbers                               │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│                     USER OUTPUT                             │
│  Results for: "machine learning"                            │
│  [1] Score: 8.42 (page 12)                                 │
│  "Passage text here..."                                    │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

```
PDF File                     Query String
    │                            │
    ├──► Text Extraction         │
    │         │                  │
    │         ▼                  │
    │    Page Texts ─────► Passages
    │                       │
    │                       ▼
    │                  Tokenization (SIMD)
    │                       │
    │         ┌─────────────┴─────────────┐
    │         ▼                           ▼
    │    Query Tokens              Passage Tokens
    │         │                           │
    │         └──────────┬────────────────┘
    │                    ▼
    │            TF-IDF Calculator
    │                    │
    │         ┌──────────┴──────────┐
    │         ▼                     ▼
    │        TF                    IDF
    │    (per passage)        (corpus-wide)
    │         │                     │
    │         └──────────┬──────────┘
    │                    ▼
    │             Combined Score
    │         (with length norm)
    │                    │
    │                    ▼
    │            Ranked Results
    │                    │
    │                    ▼
    └──────────►  Formatted Output
```

## SIMD Optimization Points

```
┌─────────────────────────────────────────────────────────────┐
│                   SIMD PIPELINE                             │
│                                                             │
│  Input: [token₀, token₁, token₂, token₃, ...]             │
│         [  "the",  "cat",  "sat",  "on", ...]              │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  SIMD UNIT (Width = 4)                                │ │
│  │                                                       │ │
│  │  Compare 4 tokens simultaneously:                    │ │
│  │  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐               │ │
│  │  │ t₀  │  │ t₁  │  │ t₂  │  │ t₃  │               │ │
│  │  │ ==  │  │ ==  │  │ ==  │  │ ==  │               │ │
│  │  │"cat"│  │"cat"│  │"cat"│  │"cat"│               │ │
│  │  └──┬──┘  └──┬──┘  └──┬──┘  └──┬──┘               │ │
│  │     │        │        │        │                   │ │
│  │     ▼        ▼        ▼        ▼                   │ │
│  │  [ 0 ]    [ 1 ]    [ 0 ]    [ 0 ]                 │ │
│  │     └────────┴────────┴────────┘                   │ │
│  │              Sum = 1                                │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  Result: count += 1 (in single cycle)                      │
│                                                             │
│  Traditional approach: 4 cycles for 4 comparisons          │
│  SIMD approach:        1 cycle for 4 comparisons           │
│  Speedup:              4x theoretical, 2-3x practical      │
└─────────────────────────────────────────────────────────────┘
```

## TF-IDF Calculation Flow

```
Query: "machine learning"

Step 1: Calculate TF for each term
┌─────────────────────────────────────────────┐
│  Passage 1 (200 tokens):                    │
│  "machine" appears 5 times                  │
│  TF = 1 + log(5) = 1 + 1.61 = 2.61        │
│                                             │
│  "learning" appears 3 times                 │
│  TF = 1 + log(3) = 1 + 1.10 = 2.10        │
└─────────────────────────────────────────────┘

Step 2: Calculate IDF for each term
┌─────────────────────────────────────────────┐
│  "machine" in 50 of 500 passages            │
│  IDF = log((500+1)/(50+1)) = 2.29          │
│                                             │
│  "learning" in 30 of 500 passages           │
│  IDF = log((500+1)/(30+1)) = 2.77          │
└─────────────────────────────────────────────┘

Step 3: Combine scores
┌─────────────────────────────────────────────┐
│  Raw score = (2.61 × 2.29) + (2.10 × 2.77) │
│            = 5.98 + 5.82                    │
│            = 11.80                          │
│                                             │
│  Passage length = 200 tokens                │
│  Normalized = 11.80 / sqrt(200 + 1)        │
│             = 11.80 / 14.18                 │
│             = 0.83                          │
└─────────────────────────────────────────────┘

Final Score: 0.83
```

## Memory Layout

```
┌─────────────────────────────────────────────────────────────┐
│                    MEMORY STRUCTURE                         │
│                                                             │
│  PassageData (per passage):                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  text: String         ─► "The quick brown fox..."  │   │
│  │  page: Int            ─► 42                        │   │
│  │  start_pos: Int       ─► 1500                      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  SearchResult (per result):                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  score: Float64       ─► 8.42                      │   │
│  │  text: String         ─► "Passage snippet..."     │   │
│  │  page: Int            ─► 42                        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Token Lists (for IDF calculation):                        │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Passage 1: ["the", "cat", "sat", "on", ...]      │   │
│  │  Passage 2: ["machine", "learning", "is", ...]     │   │
│  │  ...                                                │   │
│  │  Passage N: ["data", "science", "requires", ...]   │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Performance Characteristics

```
Time Complexity Analysis:

P = number of passages
T = average tokens per passage
Q = query terms
N = results to return

┌────────────────────────┬──────────────┬──────────────┐
│ Operation              │ Complexity   │ SIMD Impact  │
├────────────────────────┼──────────────┼──────────────┤
│ PDF Extraction         │ O(pages)     │ None (I/O)   │
│ Passage Creation       │ O(chars)     │ None         │
│ Tokenization           │ O(chars)     │ 2-3x faster  │
│ TF Calculation         │ O(P × T × Q) │ 3-4x faster  │
│ IDF Calculation        │ O(P × T)     │ 1.5-2x faster│
│ Sorting                │ O(P log P)   │ None         │
│ Output                 │ O(N)         │ None         │
├────────────────────────┼──────────────┼──────────────┤
│ Total                  │ O(P × T × Q) │ ~2x faster   │
└────────────────────────┴──────────────┴──────────────┘

Space Complexity: O(P × T)
- Store all passages: O(P)
- Store all tokens: O(P × T)
- Results: O(N)
```

## Comparison: Simple vs. TF-IDF Ranking

```
Query: "machine learning"

Document: 100 pages, 2000 passages

┌─────────────────────────────────────────────────────────────┐
│ SIMPLE TERM COUNTING:                                       │
│                                                             │
│ Passage A (long):                                          │
│ "machine" appears 10 times                                 │
│ "learning" appears 8 times                                 │
│ Length: 1000 tokens                                        │
│ Score: 10 + 8 = 18                                        │
│                                                             │
│ Passage B (short, focused):                                │
│ "machine" appears 5 times                                  │
│ "learning" appears 5 times                                 │
│ Length: 100 tokens                                         │
│ Score: 5 + 5 = 10                                         │
│                                                             │
│ Ranking: A > B (unfair - A is just longer!)               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ TF-IDF WITH LENGTH NORMALIZATION:                          │
│                                                             │
│ Passage A:                                                  │
│ TF("machine") = 1 + log(10) = 2.30                        │
│ TF("learning") = 1 + log(8) = 1.90                        │
│ Raw score = (2.30 + 1.90) × IDF                           │
│ Normalized = score / sqrt(1000) = score / 31.6           │
│ Final score: 0.42                                          │
│                                                             │
│ Passage B:                                                  │
│ TF("machine") = 1 + log(5) = 1.70                        │
│ TF("learning") = 1 + log(5) = 1.70                        │
│ Raw score = (1.70 + 1.70) × IDF                           │
│ Normalized = score / sqrt(100) = score / 10              │
│ Final score: 0.85                                          │
│                                                             │
│ Ranking: B > A (fair - B is more focused!)                │
└─────────────────────────────────────────────────────────────┘
```

This architecture delivers:
✓ Sophisticated ranking algorithm
✓ SIMD performance optimization
✓ Fair passage comparison
✓ Scalable design
✓ Clean separation of concerns
