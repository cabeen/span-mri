#!/usr/bin/env bash
##############################################################################
#
#  SPAN-MRI Test Helpers
#
#  Shared utility functions for test scripts. Source this file at the top
#  of each test script:
#    source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
#
##############################################################################

# Test counters
_TEST_PASS=0
_TEST_FAIL=0
_TEST_SKIP=0
_TEST_TOTAL=0

# Colors (if terminal supports them)
if [ -t 1 ]; then
    _GREEN='\033[0;32m'
    _RED='\033[0;31m'
    _YELLOW='\033[0;33m'
    _RESET='\033[0m'
else
    _GREEN=''
    _RED=''
    _YELLOW=''
    _RESET=''
fi

# Report a passing test
pass_test() {
    _TEST_PASS=$((_TEST_PASS + 1))
    _TEST_TOTAL=$((_TEST_TOTAL + 1))
    echo -e "  ${_GREEN}PASS${_RESET}  $1"
}

# Report a failing test
fail_test() {
    _TEST_FAIL=$((_TEST_FAIL + 1))
    _TEST_TOTAL=$((_TEST_TOTAL + 1))
    echo -e "  ${_RED}FAIL${_RESET}  $1"
    if [ -n "$2" ]; then
        echo "        $2"
    fi
}

# Report a skipped test
skip_test() {
    _TEST_SKIP=$((_TEST_SKIP + 1))
    _TEST_TOTAL=$((_TEST_TOTAL + 1))
    echo -e "  ${_YELLOW}SKIP${_RESET}  $1"
    if [ -n "$2" ]; then
        echo "        $2"
    fi
}

# Assert that a file exists
assert_file_exists() {
    local file="$1"
    local label="${2:-File exists: $(basename $file)}"
    if [ -e "$file" ]; then
        pass_test "$label"
    else
        fail_test "$label" "File not found: $file"
    fi
}

# Assert that a file exists and is non-empty
assert_file_nonempty() {
    local file="$1"
    local label="${2:-File non-empty: $(basename $file)}"
    if [ -e "$file" ] && [ -s "$file" ]; then
        pass_test "$label"
    elif [ ! -e "$file" ]; then
        fail_test "$label" "File not found: $file"
    else
        fail_test "$label" "File is empty: $file"
    fi
}

# Assert that a CSV file has at least N data rows (excluding header)
assert_csv_has_rows() {
    local file="$1"
    local min_rows="${2:-1}"
    local label="${3:-CSV has >= $min_rows rows: $(basename $file)}"
    if [ ! -e "$file" ]; then
        fail_test "$label" "File not found: $file"
        return
    fi
    local row_count
    row_count=$(tail -n +2 "$file" | wc -l | tr -d ' ')
    if [ "$row_count" -ge "$min_rows" ]; then
        pass_test "$label"
    else
        fail_test "$label" "Expected >= $min_rows rows, got $row_count"
    fi
}

# Assert that a command succeeds (exit code 0)
assert_command_succeeds() {
    local label="$1"
    shift
    if "$@" > /dev/null 2>&1; then
        pass_test "$label"
    else
        fail_test "$label" "Command failed: $*"
    fi
}

# Assert that a command produces output containing a string
assert_output_contains() {
    local label="$1"
    local expected="$2"
    shift 2
    local output
    output=$("$@" 2>&1)
    if echo "$output" | grep -q "$expected"; then
        pass_test "$label"
    else
        fail_test "$label" "Expected output to contain: $expected"
    fi
}

# Skip a test if a command is not available
skip_if_missing() {
    local cmd="$1"
    local label="${2:-$cmd}"
    if ! command -v "$cmd" > /dev/null 2>&1; then
        skip_test "Dependency not available: $label" "Install $cmd to run these tests"
        return 1
    fi
    return 0
}

# Assert that two files are identical
assert_files_match() {
    local actual="$1"
    local expected="$2"
    local label="${3:-Files match: $(basename $actual)}"
    if [ ! -e "$actual" ]; then
        fail_test "$label" "Actual file not found: $actual"
        return
    fi
    if [ ! -e "$expected" ]; then
        fail_test "$label" "Expected file not found: $expected"
        return
    fi
    if diff -q "$actual" "$expected" > /dev/null 2>&1; then
        pass_test "$label"
    else
        fail_test "$label" "Files differ: $actual vs $expected"
    fi
}

# Assert that two name,value CSV files match within a relative tolerance.
# Compares row count and each numeric value with a default 5% tolerance.
# Non-numeric values (NA, headers) are compared exactly.
assert_csv_approx() {
    local actual="$1"
    local expected="$2"
    local tol="${3:-0.05}"
    local label="${4:-CSV approx matches: $(basename $actual)}"
    if [ ! -e "$actual" ]; then
        fail_test "$label" "Actual file not found: $actual"
        return
    fi
    if [ ! -e "$expected" ]; then
        fail_test "$label" "Expected file not found: $expected"
        return
    fi
    local result
    result=$(python3 -c "
import sys, csv
tol = float('$tol')
with open('$actual') as f: actual = list(csv.reader(f))
with open('$expected') as f: expected = list(csv.reader(f))
if len(actual) != len(expected):
    print('Row count differs: %d vs %d' % (len(actual), len(expected)))
    sys.exit(1)
for i, (a, e) in enumerate(zip(actual, expected)):
    if a[0] != e[0]:
        print('Row %d name differs: %s vs %s' % (i, a[0], e[0]))
        sys.exit(1)
    if len(a) < 2 or len(e) < 2:
        continue
    if a[1] == e[1]:
        continue
    try:
        av, ev = float(a[1]), float(e[1])
        denom = max(abs(ev), 1e-12)
        if abs(av - ev) / denom > tol:
            print('Row %d (%s) exceeds tolerance: %s vs %s (%.2f%%)' % (i, a[0], a[1], e[1], 100*abs(av-ev)/denom))
            sys.exit(1)
    except ValueError:
        if a[1] != e[1]:
            print('Row %d (%s) non-numeric mismatch: %s vs %s' % (i, a[0], a[1], e[1]))
            sys.exit(1)
print('OK')
" 2>&1)
    if [ "$result" = "OK" ]; then
        pass_test "$label"
    else
        fail_test "$label" "$result"
    fi
}

# Print test summary and return appropriate exit code
test_summary() {
    echo ""
    echo "============================================================"
    echo "  Test Summary"
    echo "============================================================"
    echo -e "  ${_GREEN}Passed:  ${_TEST_PASS}${_RESET}"
    if [ $_TEST_FAIL -gt 0 ]; then
        echo -e "  ${_RED}Failed:  ${_TEST_FAIL}${_RESET}"
    else
        echo "  Failed:  ${_TEST_FAIL}"
    fi
    if [ $_TEST_SKIP -gt 0 ]; then
        echo -e "  ${_YELLOW}Skipped: ${_TEST_SKIP}${_RESET}"
    else
        echo "  Skipped: ${_TEST_SKIP}"
    fi
    echo "  Total:   ${_TEST_TOTAL}"
    echo "============================================================"

    if [ $_TEST_FAIL -gt 0 ]; then
        return 1
    fi
    return 0
}
