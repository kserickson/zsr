# R Visualization Setup Guide

This guide will help you set up the R/ggplot2 visualization system for ZSR.

## Quick Start

```bash
# 1. Install R (see below)
# 2. Run setup script
Rscript scripts/setup.R

# 3. Generate visualizations
Rscript scripts/zsr_plots.R
```

## Installing R

### macOS

**Option 1: Homebrew (Recommended)**
```bash
brew install r
```

**Option 2: Official Installer**
1. Download from https://cran.r-project.org/bin/macosx/
2. Install the `.pkg` file
3. Verify: `R --version`

### Verify Installation

```bash
R --version
# Should show R version 4.1.0 or higher
```

## Package Installation

The `setup.R` script will automatically install all required packages:

```bash
Rscript scripts/setup.R
```

**Packages installed:**
- **Core**: tidyverse, yaml, jsonlite, lubridate, here, glue
- **Visualization**: scales, viridis, RColorBrewer, ggtext, patchwork

## Usage

### Generate All Plots for All Years

```bash
Rscript scripts/zsr_plots.R
```

### Generate Plots for Specific Year

```bash
Rscript scripts/zsr_plots.R 2024
```

### Get Help

```bash
Rscript scripts/zsr_plots.R --help
```

## Configuration

Edit `config/viz_config.yaml` to customize:

- **Colors**: Change palettes (viridis, Set2, custom)
- **Fonts**: Adjust sizes and families
- **Dimensions**: Modify plot sizes
- **Thresholds**: Tweak annotation limits, quantiles

Example customizations:

```yaml
# Use faceted view instead of overlay
overlay:
  facet_alternative: true

# Adjust heatmap sensitivity
heatmap:
  vmax_quantile: 0.90  # Show more intensity variation
  annotation_size_threshold: 30  # Annotate more cells
```

## What Gets Generated

For each year in your dataset, the script creates:

1. **daily-pages-YYYY.png** - Calendar heatmap of reading activity
2. **overlay-chart-YYYY.png** - Dual-axis chart (bars + lines)

All plots saved to `figures/` directory at 300 DPI.

## Troubleshooting

### "command not found: R"

R is not installed or not in PATH. Install R using instructions above.

### "package 'X' is not available"

Run the setup script again:
```bash
Rscript scripts/setup.R
```

### "No data found for year"

Make sure you've run the Python data processing script first:
```bash
python scripts/zsr.py
```

This generates the required CSV files (`library.csv`, `dailies.csv`).

### Font warnings

If Arial is not available, the theme will fall back to system default. To use a specific font:

1. Install the font on your system
2. Edit `config/viz_config.yaml`:
   ```yaml
   fonts:
     base_family: "Helvetica"  # or another installed font
   ```

## Comparison with Python Version

| Feature | Python (old) | R (new) |
|---------|-------------|---------|
| Legend on overlay chart | ✗ Disabled | ✓ Enabled |
| Color palette | gist_stern_r (not CB-friendly) | Set2 (colorblind-safe) |
| Heatmap vmax | Hardcoded 75 | Dynamic (95th percentile) |
| Annotations | All cells | Smart (only high values) |
| Theme | Basic matplotlib | Custom (Healy-inspired) |
| Config system | JSON | YAML (more flexible) |

## File Structure

```
scripts/
├── zsr_plots.R          # Main script (run this)
├── setup.R              # Package installation
├── theme_zsr.R          # Custom ggplot2 theme
├── color_palettes.R     # Colorblind-friendly palettes
├── utils.R              # Data loading helpers
└── plot_functions.R     # Plotting functions

config/
└── viz_config.yaml      # Visualization configuration
```

## Next Steps

Once R visualization is working:

1. **Add books table** (Week 3) - Using gt package
2. **Add new plot types** (Week 4):
   - Year-over-year comparisons
   - Distribution plots
   - Completion pace charts
3. **Testing & documentation** (Week 5)

## Philosophy

This R implementation follows Kieran Healy's data visualization principles from [*Data Visualization: A Practical Introduction*](https://socviz.co/):

- **Grammar of graphics**: Layered, declarative approach
- **Perception-based**: Colors and layouts based on human vision
- **Honest representation**: No misleading scales or distortions
- **Accessibility**: Colorblind-friendly palettes throughout

## Resources

- [Kieran Healy's book (free online)](https://socviz.co/)
- [ggplot2 documentation](https://ggplot2.tidyverse.org/)
- [R for Data Science](https://r4ds.had.co.nz/)
- [ColorBrewer palettes](https://colorbrewer2.org/)

## Support

If you encounter issues:
1. Check this guide's Troubleshooting section
2. Verify R and package versions with `setup.R`
3. Check the plan file at `.claude/plans/velvety-forging-nygaard.md`
