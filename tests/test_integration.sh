#!/usr/bin/env bash
##############################################################################
#
#  SPAN-MRI Integration Tests
#
#  Runs the full pipeline on case AM4607 and verifies that all stages
#  produce output, key files are present, and results match the expected
#  reference data in tests/expected/AM4607/.
#
#  Usage:
#    bash tests/test_integration.sh [mouse|rat]
#
#  These tests will be skipped gracefully if dependencies are missing.
#
##############################################################################

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"
TMP_DIR="${SCRIPT_DIR}/tmp"
EXPECTED_DIR="${SCRIPT_DIR}/expected"

source "${SCRIPT_DIR}/helpers.sh"

SPECIES="${1:-mouse}"
CASE_NAME="AM4607"

echo "============================================================"
echo "  SPAN-MRI Integration Tests (${CASE_NAME})"
echo "============================================================"
echo ""

##############################################################################
# Check dependencies
##############################################################################

echo "--- Dependency Checks ---"

HAS_QIT=true
HAS_ANTS=true
HAS_DCM2NIIX=true

if ! skip_if_missing qit "QIT"; then HAS_QIT=false; fi
if ! skip_if_missing N4BiasFieldCorrection "ANTs (N4BiasFieldCorrection)"; then HAS_ANTS=false; fi
if ! skip_if_missing dcm2niix "dcm2niix"; then HAS_DCM2NIIX=false; fi

echo ""

##############################################################################
# Check for test data
##############################################################################

echo "--- Test Data ---"

CASE_ZIP="${DATA_DIR}/${CASE_NAME}.zip"

if [ ! -f "${CASE_ZIP}" ]; then
    fail_test "Test data available" "Not found: ${CASE_ZIP}"
    test_summary
    exit $?
fi

pass_test "Test data available: ${CASE_ZIP}"

mkdir -p "${TMP_DIR}"

if [ ! -d "${TMP_DIR}/${CASE_NAME}" ]; then
    echo "  Extracting ${CASE_NAME}..."
    unzip -q -o "${CASE_ZIP}" -d "${TMP_DIR}" -x '__MACOSX/*'
fi

DICOM_DIR="${TMP_DIR}/${CASE_NAME}"

if [ -d "${DICOM_DIR}" ]; then
    pass_test "Test case extracted: ${CASE_NAME}"
else
    fail_test "Test case extracted: ${CASE_NAME}" "Directory not found after extraction"
    test_summary
    exit $?
fi

# Count DICOM files
DCM_COUNT=$(find "${DICOM_DIR}" -name "*.dcm" 2>/dev/null | wc -l | tr -d ' ')
pass_test "DICOM files found: ${DCM_COUNT} in ${CASE_NAME}"

echo ""

##############################################################################
# Full pipeline test
##############################################################################

if [ "${HAS_QIT}" = true ] && [ "${HAS_ANTS}" = true ] && [ "${HAS_DCM2NIIX}" = true ]; then

    echo "--- Full Pipeline Test (${CASE_NAME}) ---"

    CASE_DIR="${TMP_DIR}/pipeline_${CASE_NAME}"
    rm -rf "${CASE_DIR}"

    echo "  Running pipeline (this may take several minutes)..."
    if bash "${ROOT_DIR}/bin/SpanMainRun.sh" \
        --source "${DICOM_DIR}" \
        --species "${SPECIES}" \
        --case "${CASE_DIR}" > "${TMP_DIR}/pipeline_${CASE_NAME}.log" 2>&1; then
        pass_test "Pipeline completes successfully"
    else
        fail_test "Pipeline completes successfully" "See ${TMP_DIR}/pipeline_${CASE_NAME}.log"
    fi

    echo ""
    echo "--- Pipeline Output Verification ---"

    # Verify each pipeline stage produced output
    for stage in native.dicom native.convert native.import native.denoise \
                 native.fit native.mask native.harm native.reg \
                 standard.fit standard.harm standard.mask standard.seg \
                 standard.midline standard.label standard.map standard.vis; do
        assert_file_exists "${CASE_DIR}/${stage}" "Stage output: ${stage}"
    done

    echo ""
    echo "--- Key File Verification ---"

    # Verify key output files
    assert_file_nonempty "${CASE_DIR}/native.import/adc.nii.gz" "ADC volume imported"
    assert_file_nonempty "${CASE_DIR}/native.import/t2.nii.gz" "T2 volume imported"
    assert_file_nonempty "${CASE_DIR}/native.mask/brain.mask.nii.gz" "Brain mask produced"
    assert_file_nonempty "${CASE_DIR}/native.reg/xfm.txt" "Registration transform produced"
    assert_file_nonempty "${CASE_DIR}/standard.seg/lesion.mask.nii.gz" "Lesion mask produced"
    assert_file_nonempty "${CASE_DIR}/standard.seg/csf.mask.nii.gz" "CSF mask produced"
    assert_file_nonempty "${CASE_DIR}/standard.seg/tissue.mask.nii.gz" "Tissue mask produced"
    assert_file_nonempty "${CASE_DIR}/standard.seg/rois.nii.gz" "ROI labels produced"

    echo ""
    echo "--- Metric Verification ---"

    # Verify metric CSV files
    assert_file_nonempty "${CASE_DIR}/standard.midline/map.csv" "Midline metrics produced"
    assert_csv_has_rows "${CASE_DIR}/standard.midline/map.csv" 5 "Midline CSV has metrics"
    assert_csv_has_rows "${CASE_DIR}/standard.seg/rois.csv" 3 "ROI CSV has 3 labels"

    # Verify QA reports
    assert_file_nonempty "${CASE_DIR}/standard.map/midline.csv" "Midline metrics in standard.map"
    assert_file_nonempty "${CASE_DIR}/standard.map/adc_qa.csv" "ADC QA report"
    assert_file_nonempty "${CASE_DIR}/standard.map/t2_qa.csv" "T2 QA report"

    echo ""
    echo "--- Visualization Verification ---"

    # Verify visualization PNGs were generated
    png_count=$(find "${CASE_DIR}/standard.vis" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$png_count" -gt 0 ]; then
        pass_test "Visualizations generated: ${png_count} PNGs"
    else
        fail_test "Visualizations generated" "No PNG files found in standard.vis"
    fi

    echo ""
    echo "--- Idempotency Test ---"

    # Verify re-running the pipeline completes quickly (all stages skipped)
    start_time=$(date +%s)
    bash "${ROOT_DIR}/bin/SpanMainRun.sh" \
        --species "${SPECIES}" \
        --case "${CASE_DIR}" > /dev/null 2>&1
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    if [ "$elapsed" -lt 10 ]; then
        pass_test "Re-run is idempotent (completed in ${elapsed}s)"
    else
        fail_test "Re-run is idempotent" "Took ${elapsed}s (expected < 10s for skipped stages)"
    fi

    echo ""

    ##########################################################################
    # Expected output comparison
    ##########################################################################

    CASE_EXPECTED_DIR="${EXPECTED_DIR}/${CASE_NAME}"

    if [ -d "${CASE_EXPECTED_DIR}" ]; then
        echo "--- Expected Output Comparison (${CASE_NAME}) ---"

        # Compare CSV outputs (exact match for QA, approximate for metrics
        # that vary slightly due to non-determinism in registration)
        for csv in adc_qa.csv t2_qa.csv; do
            assert_files_match \
                "${CASE_DIR}/standard.map/${csv}" \
                "${CASE_EXPECTED_DIR}/${csv}" \
                "CSV matches expected: ${csv}"
        done

        for csv in midline.csv volumetrics_by_classes.csv \
                   volumetrics_by_hemis_classes.csv; do
            assert_csv_approx \
                "${CASE_DIR}/standard.map/${csv}" \
                "${CASE_EXPECTED_DIR}/${csv}" \
                0.05 \
                "CSV approx matches expected: ${csv}"
        done

        # Verify PNG outputs exist and are non-empty (exact byte comparison
        # is not reliable due to non-determinism in rendering)
        for png in t2_rate_rois.png adc_rate_rois.png; do
            assert_file_nonempty \
                "${CASE_DIR}/standard.vis/${png}" \
                "PNG produced: ${png}"
        done
    else
        skip_test "Expected output comparison" "No expected data in ${CASE_EXPECTED_DIR}"
    fi

else
    echo ""
    skip_test "Full pipeline test" "Missing required dependencies (QIT, ANTs, dcm2niix)"
fi

echo ""

##############################################################################
# Summary
##############################################################################

test_summary
exit $?
