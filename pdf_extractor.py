#!/usr/bin/env python3
"""
PDF text extraction helper for Mojo search engine.
This script extracts text from PDFs and passes it to the Mojo search implementation.
"""

import sys
import json
from pathlib import Path

try:
    import PyPDF2
except ImportError:
    print("Error: PyPDF2 not installed. Install with: pip install PyPDF2")
    sys.exit(1)


def extract_pdf_text(pdf_path):
    """
    Extract text from PDF file, maintaining page information.
    
    Returns:
        List of tuples: (page_number, text_content)
    """
    pages = []
    
    try:
        with open(pdf_path, 'rb') as file:
            pdf_reader = PyPDF2.PdfReader(file)
            
            for page_num in range(len(pdf_reader.pages)):
                page = pdf_reader.pages[page_num]
                text = page.extract_text()
                
                if text.strip():  # Only include non-empty pages
                    pages.append({
                        'page': page_num + 1,
                        'text': text
                    })
    
    except Exception as e:
        print(f"Error reading PDF: {e}", file=sys.stderr)
        sys.exit(1)
    
    return pages


def save_extracted_text(pages, output_path):
    """Save extracted text to JSON file for Mojo to read."""
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(pages, f, ensure_ascii=False, indent=2)


def main():
    if len(sys.argv) < 2:
        print("Usage: python pdf_extractor.py <pdf_file>")
        sys.exit(1)
    
    pdf_path = sys.argv[1]
    
    if not Path(pdf_path).exists():
        print(f"Error: File '{pdf_path}' not found")
        sys.exit(1)
    
    print(f"Extracting text from {pdf_path}...", file=sys.stderr)
    pages = extract_pdf_text(pdf_path)
    
    # Output to stdout for piping to Mojo
    print(json.dumps(pages))
    
    print(f"Extracted {len(pages)} pages", file=sys.stderr)


if __name__ == "__main__":
    main()
