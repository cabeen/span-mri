# SPAN-MRI Demo

This demo processes a single rodent brain MRI case through the full SPAN
pipeline, from raw DICOM data to quantitative stroke metrics and
visualizations.

## Running the Demo

The demo uses bundled test data from `tests/data/` by default. Just run:

```bash
bash demo/run_demo.sh
```

Or specify your own DICOM directory and species:

```bash
bash demo/run_demo.sh /path/to/dicom_dir [mouse|rat]
```

### With Docker

```bash
docker run --rm \
  -v $PWD/demo/output:/data/output \
  span-mri:latest bash /opt/span-mri/demo/run_demo.sh
```

Or with your own data:

```bash
docker run --rm \
  -v /path/to/dicom_dir:/data/input:ro \
  -v $PWD/demo/output:/data/output \
  span-mri:latest bash /opt/span-mri/demo/run_demo.sh /data/input mouse
```

## Output

The demo creates `demo/output/case/` containing all pipeline stage outputs:

- `standard.seg/` — Lesion, CSF, and tissue segmentation masks
- `standard.midline/map.csv` — Midline shift metrics
- `standard.map/` — Quantitative metric tables (volumes, intensities)
- `standard.vis/` — Mosaic visualization PNGs

## What It Demonstrates

1. DICOM conversion and metadata extraction
2. Multi-echo exponential decay fitting
3. Brain extraction (U-Net for mice, rule-based for rats)
4. Atlas registration
5. Multi-modal lesion segmentation
6. Midline shift analysis
7. Regional anatomical labeling
8. Visualization generation
