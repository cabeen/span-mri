#! /usr/bin/env bash
##############################################################################
#
#  SPAN Rodent MRI Analytics — Volume Normalization
#
#  Purpose:
#    Post-processes a group metrics table to normalize tissue, CSF, and
#    lesion volumes across sites and species. Computes:
#    1. Total intracranial volume (tissue + CSF + lesion)
#    2. Volume fractions (each compartment / total)
#    3. Global normalization factor (mean total volume per species)
#    4. Site-specific normalization factor (mean total volume per species+site)
#    5. Normalized volumes adjusted for inter-site brain size differences
#
#  Inputs:
#    $1 — Input CSV table (group metrics from SpanMainGroup.sh)
#    $2 — Output CSV table (can be same as input for in-place update)
#
#  Outputs:
#    Updated CSV with additional columns:
#      volume_total, volumetrics_by_classes_fraction_{tissue,csf,lesion},
#      normalization_factor, volumetrics_by_classes_normalized_volume_{tissue,csf,lesion},
#      normalized_volume_total
#
#  Dependencies: QIT (TableSelect, TableMath, TableStats, TableMerge)
#
#  Author: Ryan Cabeen
#
##############################################################################

name=$(basename $0)

usage()
{
    echo "
Name: ${name}

Description:

  Normalize tissue, CSF, and lesion volumes across sites and species.
  Computes total intracranial volume, volume fractions, and site-specific
  normalization factors.

Usage:

  ${name} <input.csv> <output.csv>

Inputs:

  input.csv   — Group metrics table (from SpanMainGroup.sh)
  output.csv  — Output table with normalized volumes (can be same as input)

Author: Ryan Cabeen
"
    exit 1
}

if [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then usage; fi
if [ $# -ne 2 ]; then usage; fi

input=$1
output=$2

echo "started"

qit TableSelect \
  --input ${input} \
  --sort site,subject,timepoint \
  --output ${output}

qit TableMath \
  --input ${output} \
  --expression "volumetrics_by_classes_volume_tissue + volumetrics_by_classes_volume_csf + volumetrics_by_classes_volume_lesion" \
  --result "volume_total" \
  --output ${output}

for x in csf tissue lesion; do
  qit TableMath \
    --input ${output} \
    --expression "volumetrics_by_classes_volume_${x} / volume_total" \
    --result "volumetrics_by_classes_fraction_${x}" \
    --output ${output}
done

qit TableStats \
  --input ${output} \
  --value volume_total \
  --which mean \
  --group species \
  --output ${output}.tmp.csv

qit TableSelect \
  --input ${output}.tmp.csv \
  --rename global_volume_total=mean \
  --output ${output}.tmp.csv

qit TableMerge \
  --left ${output} \
  --right ${output}.tmp.csv \
  --field species \
  --output ${output}

rm ${output}.tmp.csv

qit TableSelect \
  --input ${output} \
  --cat species_site=%{species}_%{site} \
  --output ${output}

qit TableStats \
  --input ${output} \
  --value volume_total \
  --group species_site \
  --which mean \
  --output ${output}.tmp.csv

qit TableSelect \
  --rename grouped_volume_total=mean \
  --input ${output}.tmp.csv \
  --output ${output}.tmp.csv

qit TableMerge \
  --field species_site \
  --left ${output} \
  --right ${output}.tmp.csv \
  --output ${output}

rm ${output}.tmp.csv

qit TableMath \
	--input ${output} \
	--expression "global_volume_total / grouped_volume_total" \
	--result normalization_factor \
	--output ${output}

for x in lesion csf tissue; do
  qit TableMath \
    --input ${output} \
    --expression "normalization_factor * volumetrics_by_classes_volume_${x}" \
    --result volumetrics_by_classes_normalized_volume_${x} \
    --output ${output}
done

qit TableMath \
	--input ${output} \
	--expression "normalization_factor * volume_total" \
	--result normalized_volume_total \
	--output ${output}

qit TableSelect \
  --input ${output} \
  --remove global_volume_total,grouped_volume_total,species_site \
  --output ${output}

echo "finished"

################################################################################
# END
################################################################################
