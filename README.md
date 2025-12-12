# Weekly REDCap Email Report

Automated weekly email report that pulls evaluation and attendance data from REDCap and sends summaries to faculty.

## Overview

This project:
- Pulls data from two REDCap databases (faculty and resident/rdm)
- Generates HTML summary tables and visualizations
- Sends weekly emails via Posit Connect Cloud scheduler

## Project Structure

```
imslu.email/
├── weekly_report.qmd        # Main Quarto report (email template)
├── R/
│   ├── fetch_redcap_data.R  # REDCap API functions
│   └── utils.R              # Summary/counting functions
├── .Renviron.example        # Environment variable template
├── renv.lock                # R package dependencies
└── README.md
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

Open R/RStudio and restore packages:

```r
# Install renv if needed
install.packages("renv")

# Restore project dependencies
renv::restore()
```

### 4. Customize the Report

Edit `weekly_report.qmd` and `R/utils.R` to match your actual data structure:

1. Review column names in your REDCap data
2. Update the counting functions in `R/utils.R`
3. Modify tables/visualizations in `weekly_report.qmd`

### 5. Test Locally

Render the report to verify it works:

```r
quarto::quarto_render("weekly_report.qmd")
```

This will create `weekly_report.html` for preview.

## Posit Connect Cloud Deployment

### 1. Prepare for Deployment

Ensure all changes are committed and pushed to GitHub:

```bash
git add .
git commit -m "Setup weekly email report"
git push origin main
```

### 2. Deploy to Posit Connect

**Option A: Git-backed deployment (recommended)**

1. Log into Posit Connect Cloud
2. Click "Publish" → "Import from Git"
3. Connect your GitHub repository
4. Select `weekly_report.qmd` as the content
5. Connect will automatically detect dependencies from `renv.lock`

**Option B: Direct publish from RStudio**

```r
library(rsconnect)
rsconnect::deployDoc("weekly_report.qmd")
```

### 3. Configure Environment Variables in Connect

In the Posit Connect UI for your deployed content:

1. Go to "Vars" tab
2. Add three environment variables:
   - `REDCAP_URL` = `https://redcapsurvey.slu.edu/api/`
   - `REDCAP_FAC_TOKEN` = your faculty token
   - `REDCAP_RDM_TOKEN` = your rdm token

### 4. Set Schedule

1. Go to "Schedule" tab
2. Set schedule type: "Cron"
3. For weekly Monday 8am: `0 8 * * 1`
4. Set timezone appropriately

### 5. Configure Email Distribution

1. Go to "Access" or "Email" settings
2. Enable "Send email when content is updated"
3. Add recipient email addresses
4. Customize email subject line (optional)

The rendered HTML report will be sent as the email body automatically.

## Updating the Report

To make changes:

1. Edit files locally
2. Test with `quarto::quarto_render("weekly_report.qmd")`
3. Commit and push to GitHub
4. Posit Connect will auto-update (if git-backed) or manually redeploy

## Dependencies

Key R packages (managed by renv):
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
