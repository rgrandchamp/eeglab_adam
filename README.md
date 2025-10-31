# EEGLAB–ADAM Plugin

> **Version 0.1** – October 2025  
> An EEGLAB plugin to run the [ADAM toolbox](https://github.com/fahrenfort/ADAM) (Amsterdam Decoding and Modeling Toolbox) directly from an EEGLAB STUDY.

---

## Overview

This plugin integrates the **ADAM (Amsterdam Decoding and Modeling)** toolbox into **EEGLAB**, providing graphical interfaces to configure, run, and visualize MVPA analyses on EEG data (.set files) or STUDY structures.

It simplifies the entire decoding workflow — from defining contrasts to visualizing group and single-subject results — without requiring direct MATLAB scripting.

---

## Main Features

### 1. **First-Level MVPA Analysis**
- GUI for defining class specifications (`cond_string`), model type (`BDM` only), classification method, resampling rate, etc.
- Custom **output folder** support (`cfg.outputdir`).
- Automatically creates a subfolder for each contrast in the format:  
  `RESULTS/CLASS1LABEL_VS_CLASS2LABEL`

### 2. **Group ERP Viewer**
- Compute and plot **group-level ERPs** on a chosen electrode.
- Automatically computes the **difference** between the two classes and plots both ERPs and their difference in one figure.
- Contrast folders (e.g., `EEG_FAMOUS_VS_SCRAMBLED`) are selected directly from the RESULTS directory.

### 3. **Diagonal Decoding Viewer**
- Compute and plot **diagonal decoding (same train/test time)** results for one or multiple contrasts.
- Combine multiple EEG contrasts into a single plot.

### 4. **Single-Subject Decoding Viewer**
- Plot **individual subject decoding results** for one or more contrasts.
- Optional temporal smoothing via `cfg.splinefreq` (default: 11 Hz).

### 5. **Temporal Generalization Viewer**
- Compute and plot **temporal generalization matrices (TGMs)** for one or multiple contrasts.
- Supports:
  - `cfg.iterations` — number of iterations (default: 250)
  - `cfg.mpcompcor_method` — multiple-comparison correction (e.g., `cluster_based`)
  - `cfg.trainlim` — optional training time window (ms)
  - `cfg.reduce_dims` — `none`, `avtrain` (average over training window), or `diag` (diagonal decoding)

---

## Installation

1. **Download** or **clone** this repository into your EEGLAB plugins folder:
   ```bash
   git clone https://github.com/<yourusername>/eeglab-adam-plugin.git
   ```
   or manually copy the folder to:
   ```
   eeglab/plugins/
   ```

2. **Launch EEGLAB** — the **“ADAM”** menu will appear automatically under *Tools*.

3. Open **ADAM Preferences** (`Tools → ADAM → Preferences…`) to verify the paths to ADAM, FieldTrip, and EEGLAB.

---

## Available Menus

| Menu | Description |
|------|--------------|
| **First-level (MVPA)…** | Define and run first-level ADAM decoding analyses |
| **Group analysis…** | Placeholder for future group-level tools |
| **Visualize → Group ERP…** | Compute and plot group ERPs for a selected contrast |
| **Visualize → Diagonal decoding…** | Compute and plot diagonal decoding for one or multiple contrasts |
| **Visualize → Single-subject decoding…** | Plot individual subject decoding results |
| **Visualize → Temporal generalization…** | Compute and plot temporal generalization matrices (optionally within a time window) |
| **Preferences…** | Set or test ADAM / FieldTrip / EEGLAB root paths |

---

## Example Workflows

### First-Level Analysis
```matlab
cfg = [];
cfg.class_spec = {'cond_string([13 14 15],[5 13 17])', 'cond_string([17 18 19],[5 13 17])'};
cfg.model = 'BDM';
cfg.raw_or_tfr = 'raw';
cfg.nfolds = 5;
adam_run_firstlevel_from_eeglab(cfg);
```

### Temporal Generalization (250–400 ms training window)
```matlab
cfg = [];
cfg.startdir = 'C:\ADAM\RESULTS';
cfg.mpcompcor_method = 'cluster_based';
cfg.trainlim = [250 400];   % 250–400 ms training interval
cfg.reduce_dims = 'avtrain'; % average over training window
mvpa_stats = adam_compute_group_MVPA(cfg);
adam_plot_MVPA([], mvpa_stats);
```

---

## Requirements

| Component | Supported Version(s) | Notes |
|------------|----------------------|-------|
| **EEGLAB** | ≥ 2023.1 | Required base environment |
| **FieldTrip** | Between **2015** and **2022-12-23 (excluded)** | ⚠️ Newer FieldTrip versions (≥ 2022-12-23) are **not compatible** (dimord curse...)|
| **ADAM Toolbox** | **1.13-beta** *(embedded in the plugin)* | Automatically configured by the plugin |
| **MATLAB** | R2020b – R2024b recommended | Not tested on earlier releases |

> ⚠️ **Important:**  
> The plugin includes an embedded version of **ADAM 1.13-beta**, which should be used as-is.  
> Using latest ADAM versions or recent FieldTrip releases may cause path or data structure errors.

---

## 🆕 What’s New in v0.2
- ✅ Added BDM activation patterns plot  


---

## 🛠️ Current Limitations

- Requires manually specifying FieldTrip version ≤ 2022-12-23.  
- Class definition only supports event types as integers.  
- GUI windows may appear wider than necessary on small screens.
- No decoding based on TFR (time-frequency decomposition).
- No FEM (Forward Encoding Models) support.

---

## 🧭 Roadmap

Planned features for upcoming releases:

- **Make GUI more compact** — optimize window geometry and scaling for typical laptop displays.  
- **Add support for TFR (time-frequency decomposition)** — enable MVPA on induced or total power using ADAM’s `raw_or_tfr = 'tfr'` mode.  
- **Add FEM (Forward Encoding Models)** — allow direct computation of encoding models alongside backward decoding models.  
- **Allow text-based trigger values** — support non-numeric event codes for class definitions in study designs.  
- **Ensure compatibility with latest FieldTrip** — remove dependency on a fixed legacy version by adapting function calls dynamically.

---


## Reference

Fahrenfort, J. J., Van Driel, J., Van Gaal, S., & Olivers, C. N. L. (2018).  
*From ERPs to MVPA using the Amsterdam Decoding and Modeling Toolbox (ADAM).*  
Frontiers in Neuroscience, 12, 368.  
[https://doi.org/10.3389/fnins.2018.00368](https://doi.org/10.3389/fnins.2018.00368)

---

## License

Released under the **GNU GPL v3**.  
© 2025 – Development: romain.grandchamp@univ-grenoble-alpes.fr
