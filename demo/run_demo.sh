#!/usr/bin/env bash
##############################################################################
#
#  SPAN-MRI Demo Script
#
#  Purpose:
#    Demonstrates the SPAN pipeline by processing a single rodent brain MRI
#    case from raw DICOM data through to quantitative stroke metrics and
#    visualizations.
#
#  Usage:
#    bash demo/run_demo.sh [/path/to/dicom_dir] [mouse|rat]
#
#    If no DICOM directory is provided, the first test case from tests/data/
#    will be extracted and used automatically.
#
#    # Or with Docker:
#    docker run --rm \
#      -v /path/to/dicom_dir:/data/input:ro \
#      -v $PWD/demo/output:/data/output \
#      span-mri:latest bash demo/run_demo.sh /data/input mouse
#
#  Arguments:
#    $1 — Path to a DICOM directory (optional; defaults to bundled test data)
#    $2 — Species: "mouse" or "rat" (default: mouse)
#
#  Outputs:
#    demo/output/case/ — Full pipeline output for the demo case
#
##############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Parse arguments
DICOM_DIR="${1:-}"
SPECIES="${2:-mouse}"
OUTPUT_DIR="${SCRIPT_DIR}/output"
CASE_DIR="${OUTPUT_DIR}/case"

# If no DICOM directory provided, use bundled test data
if [ -z "${DICOM_DIR}" ]; then
    TEST_DATA_DIR="${ROOT_DIR}/tests/data"
    FIRST_ZIP=$(find "${TEST_DATA_DIR}" -name "*.zip" 2>/dev/null | sort | head -1)

    if [ -z "${FIRST_ZIP}" ]; then
        echo "Error: No DICOM directory provided and no test data found in tests/data/"
        echo ""
        echo "Usage: bash demo/run_demo.sh [/path/to/dicom_dir] [mouse|rat]"
        exit 1
    fi

    CASE_NAME=$(basename "${FIRST_ZIP}" .zip)
    EXTRACT_DIR="${OUTPUT_DIR}/extracted"

    if [ ! -d "${EXTRACT_DIR}/${CASE_NAME}" ]; then
        echo "Extracting test case ${CASE_NAME} from tests/data/..."
        mkdir -p "${EXTRACT_DIR}"
        unzip -q -o "${FIRST_ZIP}" -d "${EXTRACT_DIR}" -x '__MACOSX/*'
    fi

    DICOM_DIR="${EXTRACT_DIR}/${CASE_NAME}"
    echo "Using bundled test case: ${CASE_NAME}"
fi

if [ ! -d "${DICOM_DIR}" ]; then
    echo "Error: DICOM directory not found: ${DICOM_DIR}"
    exit 1
fi

echo "============================================================"
echo "  SPAN-MRI Demo"
echo "============================================================"
echo ""
echo "  DICOM source: ${DICOM_DIR}"
echo "  Species:      ${SPECIES}"
echo "  Output:       ${CASE_DIR}"
echo ""

# Ensure the brain model is built
if [ ! -e "${ROOT_DIR}/lib/brain-model" ]; then
    echo "Building brain model from split files..."
    make -C "${ROOT_DIR}" lib/brain-model
fi

# Run the pipeline
echo "------------------------------------------------------------"
echo "  Running SPAN pipeline..."
echo "------------------------------------------------------------"
echo ""

bash "${ROOT_DIR}/bin/SpanMainRun.sh" \
    --source "${DICOM_DIR}" \
    --species "${SPECIES}" \
    --case "${CASE_DIR}"

echo ""
echo "============================================================"
echo "  Demo Complete"
echo "============================================================"
echo ""

# Print summary of results
echo "Output directory: ${CASE_DIR}"
echo ""

if [ -d "${CASE_DIR}/standard.seg" ]; then
    echo "Segmentation results:"
    for mask in brain lesion csf tissue; do
        f="${CASE_DIR}/standard.seg/${mask}.mask.nii.gz"
        if [ ! -e "$f" ]; then
            f="${CASE_DIR}/standard.mask/${mask}.mask.nii.gz"
        fi
        if [ -e "$f" ]; then
            echo "  - ${mask} mask: $(basename $f)"
        fi
    done
    echo ""
fi

if [ -e "${CASE_DIR}/standard.midline/map.csv" ]; then
    echo "Midline shift metrics:"
    while IFS=, read -r name value; do
        if [ "${name}" != "name" ]; then
            printf "  %-30s %s\n" "${name}" "${value}"
        fi
    done < "${CASE_DIR}/standard.midline/map.csv"
    echo ""
fi

if [ -d "${CASE_DIR}/standard.vis" ]; then
    echo "Visualizations:"
    for png in "${CASE_DIR}"/standard.vis/*.png; do
        echo "  - $(basename ${png})"
    done
    echo ""
fi

echo "To view results, open the PNG files in standard.vis/"
echo "Metric tables are in standard.map/"
