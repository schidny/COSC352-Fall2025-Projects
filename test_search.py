#!/usr/bin/env python3
"""
Test script for Mojo PDF Search Engine
Validates functionality and measures performance
"""

import subprocess
import time
import sys
from pathlib import Path

def run_search(pdf_file, query, num_results):
    """Run the search engine and return output."""
    cmd = ["mojo", "pdfsearch_final.mojo", pdf_file, query, str(num_results)]
    
    start_time = time.time()
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30
        )
        elapsed = time.time() - start_time
        
        return {
            'success': result.returncode == 0,
            'stdout': result.stdout,
            'stderr': result.stderr,
            'elapsed': elapsed
        }
    except subprocess.TimeoutExpired:
        return {
            'success': False,
            'stdout': '',
            'stderr': 'Timeout after 30 seconds',
            'elapsed': 30.0
        }
    except Exception as e:
        return {
            'success': False,
            'stdout': '',
            'stderr': str(e),
            'elapsed': 0.0
        }

def test_search_quality(pdf_file):
    """Test search result quality."""
    print("=" * 70)
    print("SEARCH QUALITY TESTS")
    print("=" * 70)
    print()
    
    test_queries = [
        ("machine learning", 3),
        ("data analysis", 5),
        ("optimization", 3),
        ("neural networks deep learning", 5),
    ]
    
    for query, n in test_queries:
        print(f"Testing: '{query}' (top {n})")
        print("-" * 70)
        
        result = run_search(pdf_file, query, n)
        
        if result['success']:
            print(f"✓ Success ({result['elapsed']:.2f}s)")
            
            # Check if results are present
            if "Results for:" in result['stdout']:
                lines = result['stdout'].split('\n')
                result_count = sum(1 for line in lines if line.startswith('['))
                print(f"  Found {result_count} results")
                
                # Check for scores
                has_scores = any('Score:' in line for line in lines)
                has_pages = any('page' in line for line in lines)
                
                if has_scores:
                    print("  ✓ Scores present")
                if has_pages:
                    print("  ✓ Page numbers present")
            else:
                print("  ⚠ No results found")
        else:
            print(f"✗ Failed: {result['stderr']}")
        
        print()

def test_performance(pdf_file):
    """Benchmark search performance."""
    print("=" * 70)
    print("PERFORMANCE BENCHMARKS")
    print("=" * 70)
    print()
    
    queries = [
        "optimization",
        "machine learning algorithms",
        "deep neural networks training",
    ]
    
    times = []
    
    for query in queries:
        print(f"Benchmarking: '{query}'")
        
        # Run 3 times and average
        run_times = []
        for i in range(3):
            result = run_search(pdf_file, query, 5)
            if result['success']:
                run_times.append(result['elapsed'])
        
        if run_times:
            avg_time = sum(run_times) / len(run_times)
            min_time = min(run_times)
            max_time = max(run_times)
            
            times.append(avg_time)
            
            print(f"  Average: {avg_time:.3f}s")
            print(f"  Min: {min_time:.3f}s, Max: {max_time:.3f}s")
        else:
            print("  ✗ Failed to run")
        print()
    
    if times:
        print(f"Overall average: {sum(times)/len(times):.3f}s")
        print()

def test_edge_cases(pdf_file):
    """Test edge cases and error handling."""
    print("=" * 70)
    print("EDGE CASE TESTS")
    print("=" * 70)
    print()
    
    tests = [
        ("Empty query", "", 5),
        ("Single character", "a", 3),
        ("Very long query", " ".join(["word"] * 50), 5),
        ("Special characters", "!@#$%^&*()", 3),
        ("Numbers", "12345", 3),
        ("Common words", "the and of", 5),
    ]
    
    for name, query, n in tests:
        print(f"{name}: '{query[:50]}'")
        result = run_search(pdf_file, query, n)
        
        if result['success']:
            if "Results for:" in result['stdout']:
                print(f"  ✓ Handled successfully")
            else:
                print(f"  ⚠ No results (expected for some cases)")
        else:
            print(f"  ✗ Error: {result['stderr'][:100]}")
        print()

def test_result_format(pdf_file):
    """Validate output format."""
    print("=" * 70)
    print("OUTPUT FORMAT VALIDATION")
    print("=" * 70)
    print()
    
    result = run_search(pdf_file, "optimization", 3)
    
    if not result['success']:
        print("✗ Search failed")
        return
    
    output = result['stdout']
    lines = output.split('\n')
    
    # Check for required elements
    checks = {
        'Query display': 'Results for:' in output,
        'Rank numbers': any('[1]' in line for line in lines),
        'Scores': any('Score:' in line for line in lines),
        'Page numbers': any('page' in line for line in lines),
        'Text snippets': any('"' in line for line in lines),
    }
    
    for check_name, passed in checks.items():
        status = "✓" if passed else "✗"
        print(f"{status} {check_name}")
    
    print()

def main():
    if len(sys.argv) < 2:
        print("Usage: python test_search.py <pdf_file>")
        print()
        print("Example: python test_search.py Morgan_2030.pdf")
        sys.exit(1)
    
    pdf_file = sys.argv[1]
    
    if not Path(pdf_file).exists():
        print(f"Error: File '{pdf_file}' not found")
        sys.exit(1)
    
    print("\n" + "=" * 70)
    print(f"TESTING MOJO PDF SEARCH ENGINE")
    print(f"PDF: {pdf_file}")
    print("=" * 70)
    print()
    
    # Run all tests
    test_search_quality(pdf_file)
    test_performance(pdf_file)
    test_edge_cases(pdf_file)
    test_result_format(pdf_file)
    
    print("=" * 70)
    print("TESTING COMPLETE")
    print("=" * 70)

if __name__ == "__main__":
    main()
