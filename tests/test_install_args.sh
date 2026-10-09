#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../install.sh"

echo "Testing install.sh arguments and privilege checks..."

# Test 1: Running without arguments
echo "Test 1: No arguments"
OUTPUT=$("$INSTALL_SCRIPT" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 1 ]; then
    echo "FAIL: Expected exit code 1 without arguments, got $EXIT_CODE"
    exit 1
fi

if ! echo "$OUTPUT" | grep -qi "usage"; then
    echo "FAIL: Expected 'usage' in output without arguments. Output:"
    echo "$OUTPUT"
    exit 1
fi
echo "PASS: Test 1"

# Test 2: Running with an argument as non-root user
# Note: The test runner is assumed to be a non-root user.
echo "Test 2: With argument as non-root"
OUTPUT=$("$INSTALL_SCRIPT" dummy_arg 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 1 ]; then
    echo "FAIL: Expected exit code 1 when running as non-root, got $EXIT_CODE"
    exit 1
fi

if ! echo "$OUTPUT" | grep -qi "root"; then
    echo "FAIL: Expected 'root' error in output when running as non-root. Output:"
    echo "$OUTPUT"
    exit 1
fi
echo "PASS: Test 2"

echo "All tests passed successfully."
exit 0
