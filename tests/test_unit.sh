#!/usr/bin/env bash
##############################################################################
#
#  SPAN-MRI Unit Tests
#
#  Tests that verify data integrity and basic functionality without
#  requiring external tools (QIT, ANTs). These tests check that atlas data,
#  site parameters, model files, and scripts are properly set up.
#
#  Usage: bash tests/test_unit.sh
#
##############################################################################

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/helpers.sh"

echo "============================================================"
echo "  SPAN-MRI Unit Tests"
echo "============================================================"
echo ""

##############################################################################
# Mouse atlas data integrity
##############################################################################

echo "--- Mouse Atlas Data ---"

for f in brain.nii.gz brain.mask.nii.gz restrict.mask.nii.gz middle.mask.nii.gz \
         lesion.mask.nii.gz regions.nii.gz hemis.nii.gz lm.txt; do
    assert_file_nonempty "${ROOT_DIR}/data/mouse/${f}" "Mouse atlas: ${f}"
done

for f in regions.csv hemis.csv lesion.mask.csv restrict.mask.csv; do
    assert_file_nonempty "${ROOT_DIR}/data/mouse/${f}" "Mouse lookup: ${f}"
    assert_csv_has_rows "${ROOT_DIR}/data/mouse/${f}" 1 "Mouse lookup has rows: ${f}"
done

echo ""

##############################################################################
# Rat atlas data integrity
##############################################################################

echo "--- Rat Atlas Data ---"

for f in brain.nii.gz brain.mask.nii.gz restrict.mask.nii.gz middle.mask.nii.gz \
         lesion.mask.nii.gz regions.nii.gz lm.txt; do
    assert_file_nonempty "${ROOT_DIR}/data/rat/${f}" "Rat atlas: ${f}"
done

for f in regions.csv hemis.csv lesion.mask.csv restrict.mask.csv; do
    assert_file_nonempty "${ROOT_DIR}/data/rat/${f}" "Rat lookup: ${f}"
    assert_csv_has_rows "${ROOT_DIR}/data/rat/${f}" 1 "Rat lookup has rows: ${f}"
done

echo ""

##############################################################################
# Site parameter integrity
##############################################################################

echo "--- Site Parameters ---"

for site in Augusta_University DII_UT_Health Kennedy_Krieger_Institute MGH \
            University_of_Iowa USC Yale_University; do
    site_dir="${ROOT_DIR}/params/${site}"
    assert_file_exists "${site_dir}" "Site directory: ${site}"
    assert_file_nonempty "${site_dir}/orient.json" "Site orient.json: ${site}"
    assert_file_nonempty "${site_dir}/site.txt" "Site site.txt: ${site}"
done

assert_file_nonempty "${ROOT_DIR}/params/Common/adc.txt" "Common params: adc.txt"
assert_file_nonempty "${ROOT_DIR}/params/Common/site.csv" "Common params: site.csv"
assert_file_nonempty "${ROOT_DIR}/params/Common/resample.json" "Common params: resample.json"
assert_file_nonempty "${ROOT_DIR}/params/Common/transform.json" "Common params: transform.json"

echo ""

##############################################################################
# Brain model files
##############################################################################

echo "--- Brain Model ---"

for f in brain-model-split-aa brain-model-split-ab brain-model-split-ac \
         brain-model-split-ad brain-model-split-ae; do
    assert_file_nonempty "${ROOT_DIR}/lib/${f}" "Brain model split: ${f}"
done

echo ""

##############################################################################
# Script availability
##############################################################################

echo "--- Script Files ---"

for script in SpanMainRun.sh SpanMainRunAll.sh SpanMainGroup.sh \
              SpanAuxConvert.sh SpanAuxImport.sh SpanAuxDenoise.sh \
              SpanAuxSegmentBrainLearn.sh SpanAuxSegmentBrainRule.sh \
              SpanAuxSegmentLesion.sh SpanAuxMidline.py; do
    assert_file_nonempty "${ROOT_DIR}/bin/${script}" "Script exists: ${script}"
done

echo ""

##############################################################################
# Script help messages
##############################################################################

echo "--- Script Help Messages ---"

for script in SpanMainRun.sh SpanAuxSegmentLesion.sh SpanMainEvaluateLesion.sh; do
    output=$(bash "${ROOT_DIR}/bin/${script}" --help 2>&1 || true)
    if echo "$output" | grep -qi "usage\|description\|author"; then
        pass_test "Help message works: ${script}"
    else
        fail_test "Help message works: ${script}" "No usage info in output"
    fi
done

echo ""

##############################################################################
# Python dependency availability
##############################################################################

echo "--- Python Dependencies ---"

for pkg in nibabel numpy scipy; do
    if python3 -c "import ${pkg}" 2>/dev/null; then
        pass_test "Python package available: ${pkg}"
    else
        skip_test "Python package available: ${pkg}" "Install with: pip install ${pkg}"
    fi
done

if python3 -c "import torch" 2>/dev/null; then
    pass_test "Python package available: torch"
else
    skip_test "Python package available: torch" "Install with: pip install torch"
fi

echo ""

##############################################################################
# U-Net module
##############################################################################

echo "--- U-Net Module ---"

assert_file_nonempty "${ROOT_DIR}/lib/unetseg/unetseg.py" "U-Net module: unetseg.py"
assert_file_nonempty "${ROOT_DIR}/lib/unetseg/predict.py" "U-Net module: predict.py"
assert_file_nonempty "${ROOT_DIR}/lib/unetseg/setup.sh" "U-Net module: setup.sh"

if python3 -c "import sys; sys.path.insert(0, '${ROOT_DIR}/lib/unetseg'); import unetseg" 2>/dev/null; then
    pass_test "U-Net module imports successfully"
else
    skip_test "U-Net module imports successfully" "PyTorch may not be installed"
fi

echo ""

##############################################################################
# Summary
##############################################################################

test_summary
exit $?
