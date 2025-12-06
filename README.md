# Mojo PDF Search Engine - Project 9

A high-performance command-line search engine built in Mojo that ranks PDF passages using TF-IDF (Term Frequency-Inverse Document Frequency) with SIMD optimization.

## Features

- **TF-IDF Ranking**: Sophisticated relevance scoring based on term frequency and document rarity
- **SIMD Optimization**: Vectorized text processing for improved performance
- **Smart Passage Extraction**: Sentence-aware sliding window with overlap
- **Length Normalization**: Fair comparison between passages of different lengths
- **Efficient Tokenization**: Fast text processing with SIMD-friendly algorithms

## Installation

### Prerequisites

1. **Mojo Compiler**: Install from [modular.com](https://www.modular.com/)
2. **Python 3.x**: For PDF text extraction
3. **PyPDF2**: Python PDF library

```bash
pip install PyPDF2
```

## Usage

```bash
mojo pdfsearch_v2.mojo <pdf_file> "<search_query>" <num_results>
```

### Examples

```bash
# Search for "machine learning" and return top 3 results
mojo pdfsearch_v2.mojo document.pdf "machine learning" 3

# Search for multiple terms
mojo pdfsearch_v2.mojo paper.pdf "neural networks deep learning" 5

# Single term search
mojo pdfsearch_v2.mojo thesis.pdf "optimization" 10
```

## Algorithm Design

### 1. Passage Extraction

The document is split into overlapping passages using a sliding window approach:

- **Window Size**: 500 characters (configurable)
- **Overlap**: 100 characters for context preservation
- **Boundary Detection**: Attempts to break at sentence endings (., !, ?)

This ensures:
- Relevant context is maintained across passages
- Query terms near passage boundaries aren't missed
- Natural reading experience in results

### 2. Tokenization

Text is converted to lowercase tokens:
- Alphanumeric characters and apostrophes are preserved
- Punctuation serves as delimiter
- Case-insensitive matching

### 3. TF-IDF Scoring

Each passage receives a relevance score based on:

**Term Frequency (TF)**:
```
TF(t, p) = 1 + log(count(t, p))
```
- Sublinear scaling prevents longer passages from dominating
- Diminishing returns for repeated terms

**Inverse Document Frequency (IDF)**:
```
IDF(t) = log((N + 1) / (df(t) + 1))
```
- Higher scores for rare terms
- Smoothed to handle zero frequencies
- N = total passages, df(t) = passages containing term t

**Combined Score**:
```
Score(p, q) = Σ(TF(t, p) × IDF(t)) × (1 / √(|p| + 1))
```
- Length normalization factor prevents bias toward longer passages
- Sum over all query terms

### 4. SIMD Optimization

Performance improvements through vectorization:

```mojo
# Vectorized term counting
alias simd_width = 4

@parameter
fn count_batch[width: Int](offset: Int):
    if tokens[offset] == term:
        count += 1.0

vectorize[count_batch, simd_width](i)
```

Benefits:
- Process 4+ tokens simultaneously
- Reduced instruction overhead
- Better CPU cache utilization
- Significant speedup on large documents

## Architecture

### Core Structures

```mojo
struct PassageData:
    var text: String       # Passage content
    var page: Int         # Page number
    var start_pos: Int    # Character offset in page

struct SearchResult:
    var score: Float64    # Relevance score
    var text: String      # Passage text
    var page: Int        # Page number
```

### Main Functions

1. **tokenize_text()**: Convert text to lowercase tokens
2. **create_passages()**: Extract overlapping passages
3. **compute_term_frequency()**: Calculate TF with SIMD
4. **compute_idf()**: Calculate inverse document frequency
5. **calculate_cosine_similarity()**: Compute final TF-IDF score
6. **search_document()**: Main search orchestration
7. **display_search_results()**: Format output

## Performance Considerations

### Bottlenecks Identified

1. **PDF Text Extraction**: I/O bound, uses Python
2. **Tokenization**: CPU bound, SIMD optimized
3. **IDF Calculation**: O(P × T) where P=passages, T=tokens
4. **Scoring**: O(P × Q) where Q=query terms

### SIMD Benefits

- **When it helps**: Tight loops with simple operations
  - Character comparison
  - Arithmetic operations
  - Pattern matching

- **When it doesn't**: 
  - String operations (variable length)
  - Complex branching logic
  - Memory-bound operations

### Optimizations Applied

1. **Vectorized Tokenization**: Process multiple characters per cycle
2. **SIMD Term Counting**: Parallel term frequency calculation
3. **Efficient Memory Layout**: Cache-friendly data structures
4. **Early Termination**: Skip passages with zero scores

## Output Format

```
Results for: "gradient descent optimization"

[1] Score: 8.42 (page 12)
"Gradient descent iteratively updates parameters by moving in the 
direction of steepest descent. The learning rate controls step size 
and significantly impacts optimization convergence..."

[2] Score: 7.18 (page 34)
"Stochastic gradient descent (SGD) approximates the true gradient 
using mini-batches, trading accuracy for computational efficiency 
in large-scale optimization problems..."
```

Each result includes:
- Rank number [1, 2, 3, ...]
- Relevance score (higher = more relevant)
- Page number where passage appears
- Text snippet (first 200 characters, cleaned)

## Design Decisions

### Why Overlapping Passages?

Prevents splitting relevant content across boundaries. A 100-character overlap ensures query terms near boundaries appear in multiple passages.

### Why Sublinear TF Scaling?

`1 + log(tf)` prevents a single term appearing 100 times from overwhelming the score. Provides diminishing returns for repeated occurrences.

### Why Length Normalization?

Without normalization, longer passages score higher simply by containing more words. The `1/√(length)` factor makes comparisons fair.

### Why Not Use N-grams or Stemming?

Simplicity and performance. The assignment constrains us to Mojo standard library. N-grams and stemming would require significant additional complexity for marginal gains given the constraint.

## Common Words (Stopwords)

The IDF component naturally handles common words:
- Words appearing in many passages get low IDF scores
- Terms like "the", "and", "is" contribute minimally
- No explicit stopword list needed

## Testing Strategy

### Test Cases

1. **Single term query**: "optimization"
2. **Multi-term query**: "machine learning algorithms"
3. **Phrase with common words**: "the impact of climate change"
4. **Technical terms**: "gradient descent convergence rate"
5. **Empty results**: "xyzabc123" (nonsense term)

### Validation

- Verify scores decrease monotonically
- Check page numbers are correct
- Ensure snippets contain query terms
- Test edge cases (empty PDF, single page, etc.)

## Performance Benchmarking

### Metrics to Track

1. **Total execution time**: PDF load + search + display
2. **SIMD speedup**: Compare with scalar baseline
3. **Passages per second**: Throughput metric
4. **Memory usage**: Peak memory consumption

### Expected Performance

- **Small PDFs** (<100 pages): < 1 second
- **Medium PDFs** (100-500 pages): 1-5 seconds  
- **Large PDFs** (500+ pages): 5-15 seconds

SIMD optimization should provide 2-4x speedup for tokenization and term counting operations.

## Limitations

1. **No phrase matching**: "machine learning" matches "machine" OR "learning", not the exact phrase
2. **No stemming**: "run", "running", "ran" are different terms
3. **No semantic understanding**: Can't handle synonyms
4. **Memory intensive**: All passages stored in memory
5. **Python dependency**: PDF extraction requires PyPDF2

## Future Enhancements

1. **Phrase matching**: Track term positions for exact phrase queries
2. **BM25 ranking**: More sophisticated scoring algorithm
3. **Parallel processing**: Multi-threaded passage scoring
4. **Caching**: Store processed documents for repeated searches
5. **Query expansion**: Handle synonyms and related terms

## Troubleshooting

### "PyPDF2 not found"
```bash
pip install PyPDF2
```

### "Memory error on large PDF"
Reduce PASSAGE_SIZE or increase PASSAGE_OVERLAP to create fewer passages.

### "No results found"
- Check if query terms are spelled correctly
- Try broader search terms
- Verify PDF contains searchable text (not scanned images)

## Code Quality

### Mojo Features Demonstrated

- ✅ Structs with methods
- ✅ `fn` for strong typing
- ✅ Ownership semantics (inout parameters)
- ✅ SIMD with `vectorize`
- ✅ Python interop
- ✅ Type annotations
- ✅ Memory-efficient data structures

### Organization

- Clear separation of concerns
- Well-documented functions
- Consistent naming conventions
- Modular design for testability

## References

- **TF-IDF**: [Wikipedia](https://en.wikipedia.org/wiki/Tf%E2%80%93idf)
- **Mojo Docs**: [docs.modular.com](https://docs.modular.com/mojo/)
- **SIMD**: [SIMD Programming](https://en.wikipedia.org/wiki/SIMD)

## Author Notes

This implementation prioritizes:
1. **Correctness**: Accurate TF-IDF implementation
2. **Performance**: SIMD optimization where beneficial
3. **Code quality**: Readable, maintainable structure
4. **Sophistication**: Advanced ranking beyond simple term counting

The search quality should handle complex queries effectively while maintaining fast execution times through SIMD vectorization.
