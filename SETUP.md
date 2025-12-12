# Setup Instructions

## Local Testing

### 1. Install Required R Packages

```r
install.packages(c(
  "httr",      # REDCap API calls
  "dplyr",     # Data manipulation
  "ggplot2",   # Visualizations
  "knitr",     # Tables
  "quarto"     # Document rendering
))
```

### 2. Setup Environment Variables

```bash
cp .Renviron.example .Renviron
```

Edit `.Renviron` with your actual REDCap tokens:

```
REDCAP_URL=https://redcapsurvey.slu.edu/api/
REDCAP_FAC_TOKEN=your_actual_faculty_token
REDCAP_RDM_TOKEN=your_actual_rdm_token
```

**Restart your R session** to load the environment variables.

### 3. Test Locally

```r
quarto::quarto_render("weekly_report.qmd")
```

This will create `weekly_report.html` for preview.

## Deploy to Posit Connect Cloud

### Generate Manifest

Before deploying, generate a `manifest.json` to track dependencies:

```r
library(rsconnect)
rsconnect::writeManifest()
```

This creates `manifest.json` which Posit Connect uses to install the correct package versions.

### Deploy Options

**Option A: Direct Publish from RStudio**

```r
library(rsconnect)
rsconnect::deployDoc("weekly_report.qmd")
```

**Option B: Git-backed Deployment**

1. Commit `manifest.json` to your repo
2. Push to GitHub
3. In Posit Connect → Import from Git
4. Select `weekly_report.qmd`

### Configure in Posit Connect

1. **Environment Variables**: Add your tokens in the "Vars" tab
2. **Schedule**: Set to weekly (e.g., `0 8 * * 1` for Mondays at 8am)
3. **Email**: Configure recipients in the email settings

## Updating

When you update the report:

1. Make changes locally
2. Test with `quarto::quarto_render("weekly_report.qmd")`
3. Regenerate manifest: `rsconnect::writeManifest()`
4. Commit and push (if git-backed) or redeploy

## Troubleshooting

**Missing packages on Connect**: Regenerate manifest.json locally after installing any new packages

**Environment variables not loading**: Verify they're set in Posit Connect UI, not just locally
