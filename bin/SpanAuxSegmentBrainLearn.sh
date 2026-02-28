#! /usr/bin/env bash
##############################################################################
#
#  SPAN Rodent MRI Analytics — Deep Learning Brain Extraction (Mice)
#
#  Purpose:
#    Extracts the brain from mouse MRI using a pre-trained tri-planar
#    2D U-Net model. This approach is used for mice where the U-Net has
#    been trained; rats use the rule-based pipeline instead.
#
#  Algorithm:
#    1. Fuse four parameter maps (t2_base, t2_rate, adc_base, adc_rate)
#       into a single 4-channel NIfTI volume
#    2. Run the U-Net prediction, which:
#       a. Normalizes each channel (zero mean, unit variance, clip outliers)
#       b. Rescales to 256x256 for each 2D slice
#       c. Predicts segmentation along all three axes (axial, coronal, sagittal)
#       d. Averages the three predictions for a robust consensus mask
#       e. Thresholds at 0.5 and extracts the largest connected component
#    3. Output the binary brain mask
#
#  Inputs:
#    $1 — Directory containing fitted parameter maps
#         ({t2,adc}_{base,rate}.nii.gz from native.fit)
#    $2 — Output brain mask path (brain.mask.nii.gz)
#
#  Outputs:
#    Brain mask NIfTI file at the specified output path
#
#  Dependencies: QIT, Python 3, PyTorch, nibabel, scipy
#
#  Author: Ryan Cabeen
#
##############################################################################

usage()
{
    echo "
Name: $(basename ${0})

Description:

  Extract the brain from mouse MRI using a pre-trained tri-planar 2D U-Net.
  Fuses four parameter maps (t2_base, t2_rate, adc_base, adc_rate) into a
  4-channel volume and runs the U-Net for robust brain segmentation.

Usage:

  $(basename ${0}) <input_dir> <output.nii.gz>

Inputs:

  input_dir       — Directory containing fitted parameter maps
                    ({t2,adc}_{base,rate}.nii.gz from native.fit)
  output.nii.gz   — Output brain mask path

Author: Ryan Cabeen
"
    exit 1
}

if [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then usage; fi
if [ $# -lt "2" ]; then usage; fi

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )"

echo "started"

input=$1
output=$2

if [ ! -e ${input} ]; then
    echo "Error: input file not found: ${input}"
    exit
fi

if [ ! -e ${input}/adc_base.nii.gz ]; then
    echo "Error: input file not found: ${input}/adc_base.nii.gz"
    exit
fi

# Activate a Python environment with PyTorch available.
# Strategy: first check if torch is already importable (e.g. in Docker or
# an already-activated environment). If not, try the project's local venv
# setup script. This avoids hardcoding any specific conda path.
if ! python3 -c "import torch" 2>/dev/null; then
    if [ -f "${ROOT}/lib/unetseg/setup.sh" ]; then
        echo "  activating Python environment via setup.sh"
        source ${ROOT}/lib/unetseg/setup.sh
    else
        echo "Error: PyTorch is not available and no setup.sh found"
        exit 1
    fi
fi

# Fuse the four parameter maps into a single 4-channel volume for the U-Net
qit VolumeFuse \
    --input ${input}/{t2,adc}_{base,rate}.nii.gz \
    --output-cat ${output}.fuse.nii.gz \

# Run the U-Net prediction using the pre-trained brain model
python3 ${ROOT}/lib/unetseg/predict.py \
  --model ${ROOT}/lib/brain-model \
  --image ${output}.fuse.nii.gz \
  --output ${output}

rm ${output}.fuse.nii.gz

echo "finished"

##############################################################################
# End
##############################################################################
