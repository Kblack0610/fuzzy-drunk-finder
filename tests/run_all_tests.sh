#!/bin/bash

# Comprehensive test script for fuzzy-drunk-finder
# Runs all individual tests in sequence

# Ensure script is executable
chmod +x "$(dirname "$0")/../fuzzy-drunk-finder.sh"
chmod +x "$(dirname "$0")"/*.sh

# Directory where test scripts are located
TEST_DIR="$(dirname "$0")"

# Source the fuzzy-drunk-finder script
source "$(dirname "$0")/../fuzzy-drunk-finder.sh"

# Clear cache before testing
fdf_clear_cache

# Function to run a test with a header
run_test() {
    local test_script="$1"
    local test_name=$(basename "$test_script" .sh | sed 's/test_//')
    
    echo "========================================================"
    echo "  RUNNING TEST: $test_name"
    echo "========================================================"
    
    # Run the test
    bash "$test_script"
    
    echo ""
    echo "Test $test_name completed."
    echo "--------------------------------------------------------"
    echo ""
    
    # Small pause between tests for readability
    sleep 1
}

# Main test execution

echo "Starting comprehensive tests for fuzzy-drunk-finder"
echo "=================================================="
echo ""

# Run basic test
run_test "$TEST_DIR/test_basic.sh"

# Run hidden test
run_test "$TEST_DIR/test_hidden.sh"

# Run unlimited depth test
run_test "$TEST_DIR/test_unlimited.sh"

# Run hidden and unlimited combined test
run_test "$TEST_DIR/test_hidden_unlimited.sh"

# Run search test
run_test "$TEST_DIR/test_search.sh"

# Run specific dog search test
run_test "$TEST_DIR/test_search_dog.sh"

# Run cache test
run_test "$TEST_DIR/test_cache.sh"

echo ""
echo "=================================================="
echo "All tests completed."
echo "=================================================="
