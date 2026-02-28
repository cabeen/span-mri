# SPAN-MRI: Stroke Preclinical Assessment Network MRI Toolkit

[![License: Non-Commercial](https://img.shields.io/badge/License-Non--Commercial-blue.svg)](LICENSE)

## Overview

**SPAN-MRI** is an automated image analysis toolkit for rodent brain stroke
MRI, developed for the [Stroke Preclinical Assessment Network
(SPAN)](https://spannetwork.org/). It provides a complete pipeline from raw
DICOM data to quantitative stroke metrics, including lesion volumes, midline
shift, and regional anatomical measurements.

The toolkit is built on the [Quantitative Imaging Toolkit
(QIT)](http://cabeen.io/qitwiki) and supports multi-site, multi-species
(mouse and rat) analysis with automated brain extraction, atlas registration,
and tissue segmentation. It has been used to process stroke MRI data from
multiple research sites across the SPAN consortium.

## Pipeline Architecture

```
Raw DICOM
    |
    v
[1. Convert] ----> NIfTI volumes + metadata
    |
    v
[2. Import] -----> Organized modalities (ADC, T2, RARE) with site-specific orientation
    |
    v
[3. Denoise] ----> Non-local means filtered volumes
    |
    v
[4. Fit] --------> Exponential decay parameters (base, rate, SNR, RMSE)
    |
    v
[5. Brain Mask] -> Brain extraction (U-Net for mice, rule-based for rats)
    |
    v
[6. Harmonize] --> Statistically harmonized parameter maps
    |
    v
[7. Register] ---> Rigid alignment to species-specific atlas (ANTs)
    |
    v
[8. Standard] ---> Parameter maps + brain mask in atlas space
    |
    v
[9. Segment] ----> Lesion, CSF, and tissue masks (multi-modal thresholding)
    |
    v
[10. Midline] ---> Midline shift metrics (mm, percent, laterality)
    |
    v
[11. Label] -----> Anatomical labels (hemispheres x regions x tissue classes)
    |
    v
[12. Metrics] ---> Quantitative tables (volumes, intensities by region)
    |
    v
[13. Visualize] -> Mosaic overlay PNGs for quality control
```

## Pipeline Stages

1. **Convert** — Convert DICOM files to NIfTI format using dcm2niix; extract
   site metadata and build an image index
2. **Import** — Identify ADC, T2, and RARE modalities; apply site-specific
   orientation and resample to common geometry
3. **Denoise** — Otsu-masked non-local means filtering to reduce noise while
   preserving edges
4. **Fit** — Fit exponential decay model S(TE) = α·exp(-β·TE) to multi-echo
   data, producing baseline amplitude, decay rate, SNR, and RMSE maps
5. **Brain Mask** — Brain extraction using a tri-planar 2D U-Net (mice) or a
   multi-step morphological pipeline (rats)
6. **Harmonize** — Normalize parameter maps with mode-scaling 
   within the brain mask to reduce inter-site variability
7. **Register** — Rigid registration to species-specific brain atlas using ANTs
8. **Standard Space** — Transform parameter maps and brain mask to atlas
   coordinates
9. **Segment** — Multi-modal sigmoid thresholding with a two-threshold
   seed-and-grow strategy for lesion delineation; separate CSF segmentation
10. **Midline** — Measure midline shift from CSF centroid displacement;
    compute laterality indices for tissue and brain volumes
11. **Label** — Combine tissue classes, hemispheres, and anatomical regions
    into combinatorial label volumes
12. **Metrics** — Compute regional statistics (mean intensities, volumes) for
    each label combination
13. **Visualize** — Generate coronal mosaic PNGs with label overlays on
    parameter maps

## Directory Structure

### Repository Layout

```
span-mri/
├── bin/                    # Pipeline scripts (bash + python)
│   ├── SpanMainRun.sh      #   Single-case processing pipeline
│   ├── SpanMainRunAll.sh   #   Batch processing for all cases
│   ├── SpanMainGroup.sh    #   Group-level metric aggregation
│   ├── SpanAuxConvert.sh   #   DICOM to NIfTI conversion
│   ├── SpanAuxImport.sh    #   Modality identification and orientation
│   ├── SpanAuxDenoise.sh   #   Non-local means denoising
│   ├── SpanAuxSegmentBrainLearn.sh  # U-Net brain extraction (mice)
│   ├── SpanAuxSegmentBrainRule.sh   # Rule-based brain extraction (rats)
│   ├── SpanAuxSegmentLesion.sh      # Lesion and CSF segmentation
│   ├── SpanAuxMidline.py   #   Midline shift analysis
│   └── ...                 #   Additional utility scripts
├── lib/
│   ├── unetseg/            # U-Net segmentation library
│   │   ├── unetseg.py      #   Model definition and inference code
│   │   ├── predict.py      #   Command-line prediction entry point
│   │   └── setup.sh        #   Python environment setup
│   └── brain-model-split-* # Pre-trained brain model (split for git)
├── data/
│   ├── mouse/              # Mouse brain atlas (templates, masks, labels)
│   └── rat/                # Rat brain atlas (templates, masks, labels)
├── params/
│   ├── Common/             # Shared parameters (echo times, resampling)
│   └── <Site>/             # Site-specific orientation and metadata
├── demo/                   # Demo script and sample data
├── tests/                  # Unit and integration tests
├── Makefile                # Build targets (brain model, docker, tests)
├── Dockerfile              # Container definition
└── docker-compose.yml      # Container orchestration
```

### Per-Case Output Layout

```
<case_dir>/
├── native.dicom/           # Original DICOM files (copied from source)
├── native.convert/         # NIfTI conversion output
│   ├── nifti/              #   Converted .nii.gz files
│   ├── site.txt            #   Acquisition site name
│   └── images.csv          #   DICOM metadata index
├── native.import/          # Organized modalities
│   ├── adc.nii.gz          #   Multi-echo ADC volume
│   ├── t2.nii.gz           #   Multi-echo T2 volume
│   ├── rare.nii.gz         #   T2-weighted anatomical (if available)
│   ├── adc.txt             #   ADC echo/b-value parameters
│   └── t2.txt              #   T2 echo time parameters
├── native.denoise/         # Denoised volumes
├── native.fit/             # Exponential decay fit results
│   ├── {adc,t2}_base.nii.gz   # Baseline amplitude (alpha)
│   ├── {adc,t2}_rate.nii.gz   # Decay rate (beta)
│   ├── {adc,t2}_snr.nii.gz    # Signal-to-noise ratio
│   ├── {adc,t2}_rmse.nii.gz   # Root mean square error
│   └── {adc,t2}_mean.nii.gz   # Mean across echoes (bias corrected)
├── native.mask/            # Brain extraction result
│   └── brain.mask.nii.gz
├── native.harm/            # Harmonized parameter maps
├── native.reg/             # Registration output
│   └── xfm.txt             #   Affine transform to atlas space
├── standard.fit/           # Fitted maps in atlas space
├── standard.harm/          # Harmonized maps in atlas space
├── standard.mask/          # Brain mask in atlas space
├── standard.seg/           # Segmentation results
│   ├── lesion.mask.nii.gz  #   Binary lesion mask
│   ├── csf.mask.nii.gz     #   Binary CSF mask
│   ├── tissue.mask.nii.gz  #   Binary healthy tissue mask
│   └── rois.nii.gz         #   Combined ROI labels (1=tissue, 2=CSF, 3=lesion)
├── standard.midline/       # Midline shift analysis
│   └── map.csv             #   Shift metrics (mm, percent, laterality)
├── standard.label/         # Anatomical labels
│   ├── classes.nii.gz      #   Tissue class labels
│   ├── hemis.nii.gz        #   Hemisphere labels
│   └── hemis_classes_regions.nii.gz  # Full combinatorial labels
├── standard.map/           # Quantitative metric tables
│   ├── midline.csv         #   Midline shift metrics
│   ├── volumetrics_by_*.csv    # Volumes by label combination
│   └── hemis_classes_*_mean.csv  # Regional intensity statistics
└── standard.vis/           # Visualization PNGs
    └── {adc,t2}_rate_{anatomy,brain,lesion,csf,rois,hemis}.png
```

## Quick Start

### Prerequisites

The pipeline requires the following external tools:

- [dcm2niix](https://github.com/rordenlab/dcm2niix) — DICOM to NIfTI conversion
- [ANTs](https://stnava.github.io/ANTs/) — Image registration (N4BiasFieldCorrection, antsRegistration)
- [QIT](http://cabeen.io/qitwiki) — Quantitative image analysis framework (requires Java 11+)
- [DCMTK](https://dicom.offis.de/dcmtk.php.en) — DICOM toolkit (dcmdump, dcmodify)
- Python 3 with PyTorch, nibabel, scipy, numpy (required for mouse brain extraction)
- GNU Parallel, bc, gawk

### Local Environment Setup

#### macOS (Homebrew)

```bash
# Install system dependencies
brew install dcm2niix dcmtk parallel bc gawk

# Install ANTs (pre-built binaries)
curl -fsSL https://github.com/ANTsX/ANTs/releases/download/v2.5.3/ants-2.5.3-macos-14-ARM64-clang.zip \
  -o /tmp/ants.zip
unzip /tmp/ants.zip -d /opt && rm /tmp/ants.zip
export PATH="/opt/ants-2.5.3/bin:$PATH"

# Install QIT (requires Java 11+)
brew install openjdk@11
mkdir -p /opt/qit
curl -fsSL 'http://cabeen.io/qitwiki/lib/exe/fetch.php?media=qit-latest.tar.gz' \
  -o /tmp/qit.tar.gz
tar -xzf /tmp/qit.tar.gz -C /opt/qit --strip-components=1 && rm /tmp/qit.tar.gz
export PATH="/opt/qit/bin:$PATH"

# Install Python dependencies (CPU-only PyTorch)
pip3 install torch --index-url https://download.pytorch.org/whl/cpu
pip3 install nibabel scipy numpy
```

#### Ubuntu/Debian

```bash
# Install system dependencies
sudo apt-get update && sudo apt-get install -y \
  bash bc curl gawk openjdk-11-jre-headless parallel \
  python3 python3-pip unzip wget dcmtk

# Install dcm2niix
curl -fsSL https://github.com/rordenlab/dcm2niix/releases/download/v1.0.20240202/dcm2niix_lnx.zip \
  -o /tmp/dcm2niix.zip
sudo unzip /tmp/dcm2niix.zip -d /usr/local/bin && rm /tmp/dcm2niix.zip

# Install ANTs (pre-built binaries)
curl -fsSL https://github.com/ANTsX/ANTs/releases/download/v2.5.3/ants-2.5.3-ubuntu-22.04-X64-gcc.zip \
  -o /tmp/ants.zip
sudo unzip /tmp/ants.zip -d /opt && rm /tmp/ants.zip
export PATH="/opt/ants-2.5.3/bin:$PATH"

# Install QIT
sudo mkdir -p /opt/qit
curl -fsSL 'http://cabeen.io/qitwiki/lib/exe/fetch.php?media=qit-latest.tar.gz' \
  -o /tmp/qit.tar.gz
sudo tar -xzf /tmp/qit.tar.gz -C /opt/qit --strip-components=1 && rm /tmp/qit.tar.gz
export PATH="/opt/qit/bin:$PATH"

# Install Python dependencies (CPU-only PyTorch)
pip3 install torch --index-url https://download.pytorch.org/whl/cpu
pip3 install nibabel scipy numpy
```

### Installation

```bash
# Clone the repository
git clone https://github.com/cabeen/span-mri.git
cd span-mri

# Build the brain model from split files
make

# Add bin/ to your PATH
export PATH=$PWD/bin:$PATH
```

### Docker Quick Start (Recommended)

```bash
# Build the Docker image
docker compose build

# Run the pipeline on your data
docker compose run --rm span-mri SpanMainRun.sh --source /data/input --case /data/output/mycase
```

### Running a Single Case

```bash
SpanMainRun.sh --source /path/to/dicom --case /path/to/output/case_dir
```

The pipeline will auto-detect the species from the directory path (looks for
"mouse" or "rat" in the path; defaults to mouse). You can also specify it
explicitly:

```bash
SpanMainRun.sh --source /path/to/dicom --case /path/to/output/case_dir --species rat
```

### Running the Demo

```bash
bash demo/run_demo.sh
```

## Detailed Usage

### Single-Subject Processing

```bash
# First run: provide DICOM source
SpanMainRun.sh --source /path/to/dicom --case process/mouse/early/subject001

# Re-run (skips completed stages automatically)
SpanMainRun.sh --case process/mouse/early/subject001
```

### Batch Processing

```bash
# Organize source data in the expected layout:
#   source/{mouse,rat}/{early,late}/<subject_id>/

# Run all cases (submits grid jobs via qsubcmd)
SpanMainRunAll.sh
```

### Group Analysis

```bash
# After all subjects are processed, aggregate metrics:
SpanMainGroup.sh

# Collect visualization PNGs:
SpanMainGroupVis.sh

# Fuse parameter maps into group averages:
SpanMainFuse.sh
```

## Site Configuration

Each acquisition site has a configuration directory under `params/` containing:

| File | Description |
|------|-------------|
| `orient.json` | QIT orientation parameters to standardize image axes |
| `site.txt` | Short site identifier used in output tables |
| `t2.txt` | T2 sequence echo time configuration |
| `t2star.txt` | T2* sequence configuration |

**Adding a new site:**

1. Create a directory under `params/` with the site's `InstitutionName` from DICOM
2. Add `orient.json` with the appropriate axis reorientation for the scanner
3. Add `site.txt` with a short identifier (e.g., "MY_SITE")
4. Copy and adjust `t2.txt` and `t2star.txt` from an existing site

The site name is automatically detected from the DICOM `InstitutionName` field
during conversion.

## Key Metrics

### Midline Shift

| Metric | Description |
|--------|-------------|
| `shift_mm` | Displacement of CSF centroid from anatomical center (mm) |
| `shift_percent` | Shift as percentage of brain width: 200 × shift_mm / width |
| `shift_ratio` | min(left_dist, right_dist) / max(left_dist, right_dist) |
| `shift_index` | Laterality index: 2 × (right − left) / (right + left) |
| `tissue_volume_index` | Tissue volume laterality between hemispheres |
| `brain_volume_index` | Brain volume laterality between hemispheres |

### Lesion Segmentation Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `t2RateThreshLesion` | 0.80 | Sigmoid center for T2 rate lesion detection |
| `adcRateThreshLesion` | 1.5 | Sigmoid center for ADC rate lesion detection |
| `adcBaseThreshLesion` | 0.25 | Sigmoid center for ADC baseline detection |
| `sigmoidHighThreshLesion` | 0.5 | High threshold for lesion seed detection |
| `sigmoidLowThreshLesion` | 0.45 | Low threshold for seed-and-grow expansion |
| `t2RateThreshCsf` | 0.75 | Sigmoid center for T2 rate CSF detection |
| `adcRateThreshCsf` | 1.25 | Sigmoid center for ADC rate CSF detection |

## Species Support

| Feature | Mouse | Rat |
|---------|-------|-----|
| Brain extraction | U-Net (deep learning) | Rule-based morphology |
| Atlas template | Yes | Yes |
| Hemispheric regions | Cortex, striatum, hippocampus, thalamus | Cortex, striatum, hippocampus, thalamus |
| Lesion prior mask | Yes | Yes |
| Midline analysis | Yes | Yes |

The species is auto-detected from the case directory path. If the path
contains "rat", rat-specific processing is used; otherwise, mouse is assumed.

## Testing

```bash
# Run all tests
bash tests/run_tests.sh all

# Run only unit tests (no external dependencies required)
bash tests/run_tests.sh unit

# Run only Python tests
python3 -m pytest tests/test_python.py -v

# Run integration tests (requires QIT, ANTs, and sample data)
bash tests/run_tests.sh integration
```

## Data Availability

The MRI dataset used in this study is publicly available:

> **TODO**: Add Dryad/Zenodo DOI link upon data deposit

## Citation

If you use SPAN-MRI in your research, please cite:

> Publication under review. Citation details will be provided upon acceptance.

Source code repository: https://github.com/cabeen/span-mri

## License

This software is released under a non-commercial research license. See
[LICENSE](LICENSE) for details.

## Contact

Author: Ryan Cabeen, cabeen@gmail.com
