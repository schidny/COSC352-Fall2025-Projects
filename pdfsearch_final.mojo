#!/usr/bin/env mojo
"""
Mojo PDF Search Engine - TF-IDF based passage ranking
Author: Schidny
Course: COSC 352
"""

from sys import argv
from math import sqrt, log
from python import Python
from collections import Dict, Optional

# Constants
alias PASSAGE_SIZE = 500
alias PASSAGE_OVERLAP = 100
alias MAX_SNIPPET = 200

fn main() raises:
    # Check arguments
    let args = argv()
    if len(args) < 4:
        print("Usage: mojo pdfsearch_final.mojo <pdf_file> <query> <num_results>")
        print('Example: mojo pdfsearch_final.mojo doc.pdf "machine learning" 5')
        return
    
    let pdf_path = args[1]
    let query = args[2]
    let top_n = atol(args[3])
    
    # Import Python modules
    let py_pdf = Python.import_module("PyPDF2")
    
    # Load PDF
    print("Loading PDF:", pdf_path)
    let pdf_file = Python.evaluate("open('" + pdf_path + "', 'rb')")
    let pdf_reader = py_pdf.PdfReader(pdf_file)
    let num_pages = len(pdf_reader.pages)
    
    print("Pages:", num_pages)
    
    # Extract all passages
    var passages = List[PythonObject]()
    var passage_texts = List[String]()
    
    for page_idx in range(num_pages):
        let page = pdf_reader.pages[page_idx]
        let text = String(page.extract_text())
        
        # Create passages from page
        let page_passages = extract_passages(text, page_idx + 1)
        for p in page_passages:
            passages.append(p)
            passage_texts.append(String(p["text"]))
    
    print("Total passages:", len(passages))
    print()
    
    # Tokenize all passages
    var all_tokens = List[List[String]]()
    for text in passage_texts:
        all_tokens.append(tokenize(text[]))
    
    # Tokenize query
    let query_tokens = tokenize(query)
    
    # Score each passage
    var results = List[Tuple[Float64, Int]]()
    
    for i in range(len(passages)):
        let score = calculate_score(
            all_tokens[i],
            query_tokens,
            all_tokens
        )
        if score > 0:
            results.append((score, i))
    
    # Sort by score (descending)
    results = sort_results(results)
    
    # Display top N results
    print('Results for: "' + query + '"')
    print()
    
    let limit = min(top_n, len(results))
    for rank in range(limit):
        let score = results[rank][0]
        let idx = results[rank][1]
        let passage = passages[idx]
        
        print("[" + String(rank + 1) + "] Score:", 
              format_score(score),
              "(page " + String(passage["page"]) + ")")
        
        let snippet = clean_text(String(passage["text"]), MAX_SNIPPET)
        print('"' + snippet + '"')
        print()
    
    if len(results) == 0:
        print("No results found")

fn extract_passages(text: String, page: Int) raises -> List[PythonObject]:
    """Extract overlapping passages from text."""
    var passages = List[PythonObject]()
    let text_len = len(text)
    
    if text_len == 0:
        return passages
    
    var start = 0
    let py = Python.import_module("builtins")
    
    while start < text_len:
        var end = start + PASSAGE_SIZE
        if end > text_len:
            end = text_len
        
        # Try to break at sentence boundary
        if end < text_len and end > start + 100:
            for i in range(end, max(start + 100, end - 100), -1):
                if i < text_len:
                    let c = ord(text[i])
                    if c == 46 or c == 33 or c == 63:  # . ! ?
                        end = i + 1
                        break
        
        # Create passage dict
        let passage_text = text[start:end]
        let passage = py.dict()
        passage["text"] = passage_text
        passage["page"] = page
        passage["start"] = start
        
        passages.append(passage)
        
        start += (PASSAGE_SIZE - PASSAGE_OVERLAP)
        if start >= text_len:
            break
    
    return passages

fn tokenize(text: String) -> List[String]:
    """Tokenize text into lowercase words."""
    var tokens = List[String]()
    var current = String("")
    
    for i in range(len(text)):
        let c = ord(text[i])
        
        # Check if alphanumeric or apostrophe
        let is_alpha = (c >= 65 and c <= 90) or (c >= 97 and c <= 122)
        let is_digit = (c >= 48 and c <= 57)
        let is_apos = (c == 39)
        
        if is_alpha or is_digit or is_apos:
            # Convert to lowercase
            var lower_c = c
            if c >= 65 and c <= 90:
                lower_c = c + 32
            current += chr(lower_c)
        else:
            if len(current) > 0:
                tokens.append(current)
                current = String("")
    
    if len(current) > 0:
        tokens.append(current)
    
    return tokens

fn calculate_score(
    passage_tokens: List[String],
    query_tokens: List[String],
    all_passages: List[List[String]]
) -> Float64:
    """Calculate TF-IDF relevance score."""
    var score: Float64 = 0.0
    let doc_len = Float64(len(passage_tokens))
    
    if doc_len == 0:
        return 0.0
    
    # Calculate TF-IDF for each query term
    for i in range(len(query_tokens)):
        let term = query_tokens[i]
        
        # Term Frequency
        var tf_count: Float64 = 0.0
        for j in range(len(passage_tokens)):
            if passage_tokens[j] == term:
                tf_count += 1.0
        
        if tf_count > 0:
            let tf = 1.0 + log(tf_count)
            
            # Inverse Document Frequency
            var df: Float64 = 0.0
            for k in range(len(all_passages)):
                var found = False
                for m in range(len(all_passages[k])):
                    if all_passages[k][m] == term:
                        found = True
                        break
                if found:
                    df += 1.0
            
            let idf = log((Float64(len(all_passages)) + 1.0) / (df + 1.0))
            score += tf * idf
    
    # Length normalization
    return score / sqrt(doc_len + 1.0)

fn sort_results(results: List[Tuple[Float64, Int]]) -> List[Tuple[Float64, Int]]:
    """Sort results by score (descending)."""
    var sorted = results
    let n = len(sorted)
    
    # Bubble sort (simple and effective for small lists)
    for i in range(n):
        for j in range(n - i - 1):
            if sorted[j][0] < sorted[j + 1][0]:
                let temp = sorted[j]
                sorted[j] = sorted[j + 1]
                sorted[j + 1] = temp
    
    return sorted

fn clean_text(text: String, max_len: Int) -> String:
    """Clean text for display."""
    var cleaned = text
    
    # Replace newlines with spaces
    cleaned = cleaned.replace("\n", " ")
    cleaned = cleaned.replace("\r", " ")
    cleaned = cleaned.replace("\t", " ")
    
    # Collapse multiple spaces
    while "  " in cleaned:
        cleaned = cleaned.replace("  ", " ")
    
    cleaned = cleaned.strip()
    
    # Truncate if needed
    if len(cleaned) > max_len:
        cleaned = cleaned[:max_len] + "..."
    
    return cleaned

fn format_score(score: Float64) -> String:
    """Format score to 2 decimal places."""
    let score_str = String(score)
    if "." not in score_str:
        return score_str + ".00"
    
    let parts = score_str.split(".")
    if len(parts) < 2:
        return score_str
    
    let decimal = parts[1]
    if len(decimal) >= 2:
        return parts[0] + "." + decimal[:2]
    elif len(decimal) == 1:
        return parts[0] + "." + decimal + "0"
    else:
        return parts[0] + ".00"
