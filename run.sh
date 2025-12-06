#!/bin/bash

# Mojo PDF Search Engine - Helper Script
# Makes testing and running easier

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Print header
print_header() {
    echo ""
    print_color "$BLUE" "================================"
    print_color "$BLUE" "$1"
    print_color "$BLUE" "================================"
    echo ""
}

# Check if Mojo is installed
check_mojo() {
    if ! command -v mojo &> /dev/null; then
        print_color "$RED" "Error: Mojo is not installed or not in PATH"
        exit 1
    fi
    print_color "$GREEN" "✓ Mojo found: $(mojo --version 2>&1 | head -n1)"
}

# Check if Python dependencies are installed
check_python_deps() {
    python3 -c "import PyPDF2" 2>/dev/null
    if [ $? -ne 0 ]; then
        print_color "$YELLOW" "⚠ PyPDF2 not found. Installing..."
        pip install PyPDF2
        if [ $? -eq 0 ]; then
            print_color "$GREEN" "✓ PyPDF2 installed successfully"
        else
            print_color "$RED" "✗ Failed to install PyPDF2"
            exit 1
        fi
    else
        print_color "$GREEN" "✓ PyPDF2 installed"
    fi
}

# Run the search engine
run_search() {
    local pdf_file=$1
    local query=$2
    local num_results=${3:-5}
    
    if [ ! -f "$pdf_file" ]; then
        print_color "$RED" "Error: PDF file '$pdf_file' not found"
        exit 1
    fi
    
    print_header "Running Search"
    print_color "$BLUE" "PDF: $pdf_file"
    print_color "$BLUE" "Query: \"$query\""
    print_color "$BLUE" "Results: $num_results"
    echo ""
    
    mojo pdfsearch_final.mojo "$pdf_file" "$query" "$num_results"
}

# Run test suite
run_tests() {
    local pdf_file=$1
    
    if [ ! -f "$pdf_file" ]; then
        print_color "$RED" "Error: PDF file '$pdf_file' not found"
        exit 1
    fi
    
    print_header "Running Test Suite"
    python3 test_search.py "$pdf_file"
}

# Quick demo with example queries
run_demo() {
    local pdf_file=$1
    
    if [ ! -f "$pdf_file" ]; then
        print_color "$RED" "Error: PDF file '$pdf_file' not found"
        exit 1
    fi
    
    print_header "Running Demo Searches"
    
    queries=(
        "strategic planning:3"
        "student success:5"
        "academic excellence:3"
        "research innovation:5"
    )
    
    for query_config in "${queries[@]}"; do
        IFS=':' read -r query num <<< "$query_config"
        echo ""
        print_color "$YELLOW" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_color "$YELLOW" "Query: \"$query\" (top $num)"
        print_color "$YELLOW" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        mojo pdfsearch_final.mojo "$pdf_file" "$query" "$num"
        sleep 1
    done
}

# Benchmark performance
run_benchmark() {
    local pdf_file=$1
    
    if [ ! -f "$pdf_file" ]; then
        print_color "$RED" "Error: PDF file '$pdf_file' not found"
        exit 1
    fi
    
    print_header "Performance Benchmark"
    
    query="machine learning optimization"
    runs=3
    
    print_color "$BLUE" "Running $runs searches with query: \"$query\""
    echo ""
    
    total_time=0
    
    for i in $(seq 1 $runs); do
        print_color "$YELLOW" "Run $i/$runs..."
        start=$(date +%s.%N)
        mojo pdfsearch_final.mojo "$pdf_file" "$query" 5 > /dev/null 2>&1
        end=$(date +%s.%N)
        runtime=$(echo "$end - $start" | bc)
        echo "  Time: ${runtime}s"
        total_time=$(echo "$total_time + $runtime" | bc)
    done
    
    avg_time=$(echo "scale=3; $total_time / $runs" | bc)
    echo ""
    print_color "$GREEN" "Average time: ${avg_time}s"
}

# Show usage
show_usage() {
    cat << EOF
Mojo PDF Search Engine - Helper Script

Usage: $0 <command> [options]

Commands:
  check              Check if dependencies are installed
  search <pdf> <query> [n]   Run a single search
  test <pdf>        Run test suite on PDF
  demo <pdf>        Run demo with example queries
  benchmark <pdf>   Benchmark performance
  help              Show this help message

Examples:
  $0 check
  $0 search Morgan_2030.pdf "strategic planning" 5
  $0 test Morgan_2030.pdf
  $0 demo Morgan_2030.pdf
  $0 benchmark Morgan_2030.pdf

EOF
}

# Main script logic
main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 0
    fi
    
    command=$1
    shift
    
    case $command in
        check)
            print_header "Checking Dependencies"
            check_mojo
            check_python_deps
            print_color "$GREEN" ""
            print_color "$GREEN" "All dependencies are installed!"
            ;;
        search)
            if [ $# -lt 2 ]; then
                print_color "$RED" "Error: search requires <pdf> <query> [n]"
                exit 1
            fi
            check_mojo
            check_python_deps
            run_search "$@"
            ;;
        test)
            if [ $# -lt 1 ]; then
                print_color "$RED" "Error: test requires <pdf>"
                exit 1
            fi
            check_mojo
            check_python_deps
            run_tests "$@"
            ;;
        demo)
            if [ $# -lt 1 ]; then
                print_color "$RED" "Error: demo requires <pdf>"
                exit 1
            fi
            check_mojo
            check_python_deps
            run_demo "$@"
            ;;
        benchmark)
            if [ $# -lt 1 ]; then
                print_color "$RED" "Error: benchmark requires <pdf>"
                exit 1
            fi
            check_mojo
            check_python_deps
            run_benchmark "$@"
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            print_color "$RED" "Error: Unknown command '$command'"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
