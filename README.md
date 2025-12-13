# Weekly REDCap Email Report

Automated weekly email report that pulls evaluation and attendance data from REDCap and sends summaries to faculty and residents every Monday morning.

## Overview

This project:
- Pulls data from two REDCap databases (faculty and resident/rdm)
- Generates HTML summary tables and visualizations
- Sends weekly emails via Posit Connect Cloud scheduler
- Automatically emails all faculty (using `fac_email` field) and residents (using `email` field)
- Scheduled to run every Monday morning at 8:00 AM

## Quick Start

**📧 Want to deploy to Posit Connect and set up weekly emails?**
👉 See **[DEPLOYMENT.md](DEPLOYMENT.md)** for complete step-by-step instructions.

## Project Structure

```
imslu.email/
├── weekly_report.qmd         # Main Quarto report (email template)
├── R/
│   ├── fetch_redcap_data.R   # REDCap API functions
│   ├── utils.R               # Summary/counting functions
│   └── get_email_list.R      # Email distribution list generator
├── test_email_list.R         # Test script to preview email recipients
├── deploy_to_connect.R       # Automated deployment script
├── .Renviron.example         # Environment variable template
├── manifest.json             # R package dependencies (for Posit Connect)
├── _quarto.yml               # Quarto configuration
├── DEPLOYMENT.md             # 📧 Detailed deployment and email setup guide
└── README.md                 # This file
```

## Local Development Setup

### 1. Clone and Setup Environment

```bash
git clone <your-repo-url>
cd imslu.email
```

### 2. Configure API Tokens

Copy the example environment file and add your REDCap tokens:

```bash
cp .Renviron.example .Renviron
```

Edit `.Renviron` with your actual tokens:

```
REDCAP_URL=https://redcapsurvey.slu.edu/api/
REDCAP_FAC_TOKEN=your_actual_faculty_token
REDCAP_RDM_TOKEN=your_actual_rdm_token
```

**Important:** `.Renviron` is gitignored and will NOT be committed.

### 3. Install Dependencies

Install required R packages:

```r
install.packages(c("httr", "dplyr", "ggplot2", "knitr", "quarto", "rsconnect"))
```

### 4. Test Locally

Render the report to verify it works:

```r
quarto::quarto_render("weekly_report.qmd")
```

This will create `weekly_report.html` for preview.

### 5. Customize the Report (if needed)

The report is already configured for your REDCap data structure. Customization is optional.

## Posit Connect Cloud Deployment

**For complete deployment instructions including email setup, see [DEPLOYMENT.md](DEPLOYMENT.md)**

### Quick Overview

1. **Deploy** to Posit Connect Cloud (via RStudio or git-backed)
   ```r
   library(rsconnect)
   rsconnect::deployDoc("weekly_report.qmd")
   ```

2. **Configure** environment variables in Posit Connect:
   - `REDCAP_URL`
   - `REDCAP_FAC_TOKEN`
   - `REDCAP_RDM_TOKEN`

3. **Set Schedule** for Monday mornings:
   - Frequency: Weekly
   - Day: Monday
   - Time: 08:00
   - Or use cron: `0 8 * * 1`

4. **Email Distribution** - automatically configured via `R/get_email_list.R`
   - Pulls from faculty database (`fac_email` field)
   - Pulls from resident database (`email` field)
   - Automatically updates each run

The `manifest.json` file is already configured with all necessary dependencies.

## Updating the Report

To make changes:

1. Edit files locally
2. Test with `quarto::quarto_render("weekly_report.qmd")`
3. Regenerate manifest: `rsconnect::writeManifest()`
4. Commit and push to GitHub
5. Posit Connect will auto-update (if git-backed) or manually redeploy

## Dependencies

Key R packages (tracked in manifest.json):
- httr (REDCap API calls)
- dplyr (data manipulation)
- ggplot2 (visualizations)
- knitr (table formatting)
- quarto (document rendering)

## Troubleshooting

**API connection fails:**
- Verify tokens are correct in Posit Connect environment variables
- Check REDCap API is accessible from Posit Connect servers

**Archived records showing up:**
- Ensure `archive` field exists in your REDCap data
- Update filter logic in `fetch_redcap_data.R` if needed

**Email not sending:**
- Verify email settings in Posit Connect
- Check that document renders successfully first

## Next Steps

1. Review actual REDCap data structure
2. Customize counting/summary functions in `R/utils.R`
3. Update visualizations and tables in `weekly_report.qmd`
4. Add your actual REDCap links to Quick Links section
5. Test locally, then deploy to Posit Connect Cloud
