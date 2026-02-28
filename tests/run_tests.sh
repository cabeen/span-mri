#!/usr/bin/env bash
##############################################################################
#
#  SPAN-MRI Test Runner
#
#  Usage:
#    bash tests/run_tests.sh [all|unit|integration|python]
#
#  Arguments:
#    all         — Run unit, python, and integration tests (default)
#    unit        — Run bash unit tests only
#    integration — Run integration tests (requires QIT, ANTs, test data)
#    python      — Run Python unit tests only
#
#  For integration tests (uses bundled test data from tests/data/):
#    bash tests/run_tests.sh integration [mouse|rat]
#
#  Exit code: 0 if all tests pass, 1 if any test fails
#
##############################################################################

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

MODE="${1:-all}"
shift 2>/dev/null || true

EXIT_CODE=0

run_unit() {
    echo ""
    echo "============================================================"
    echo "  Running Unit Tests"
    echo "============================================================"
    echo ""
    bash "${SCRIPT_DIR}/test_unit.sh"
    if [ $? -ne 0 ]; then EXIT_CODE=1; fi
}

run_python() {
    echo ""
    echo "============================================================"
    echo "  Running Python Tests"
    echo "============================================================"
    echo ""
    if command -v python3 > /dev/null 2>&1; then
        if python3 -c "import pytest" 2>/dev/null; then
            python3 -m pytest "${SCRIPT_DIR}/test_python.py" -v
            if [ $? -ne 0 ]; then EXIT_CODE=1; fi
        else
            python3 -m unittest discover -s "${SCRIPT_DIR}" -p "test_python.py" -v
            if [ $? -ne 0 ]; then EXIT_CODE=1; fi
        fi
    else
        echo "  Python 3 not available, skipping Python tests"
    fi
}

run_integration() {
    echo ""
    echo "============================================================"
    echo "  Running Integration Tests"
    echo "============================================================"
    echo ""
    bash "${SCRIPT_DIR}/test_integration.sh" "$@"
    if [ $? -ne 0 ]; then EXIT_CODE=1; fi
}

case "${MODE}" in
    unit)
        run_unit
        ;;
    python)
        run_python
        ;;
    integration)
        run_integration "$@"
        ;;
    all)
        run_unit
        run_python
        run_integration "$@"
        ;;
    *)
        echo "Usage: bash tests/run_tests.sh [all|unit|integration|python]"
        exit 1
        ;;
esac

echo ""
if [ ${EXIT_CODE} -eq 0 ]; then
    echo "All test suites passed."
else
    echo "Some tests failed."
fi

exit ${EXIT_CODE}
