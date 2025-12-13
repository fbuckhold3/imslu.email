# Deploying Weekly Report to Posit Connect Cloud

This guide walks you through deploying the weekly assessment report to Posit Connect Cloud with automatic Monday morning emails.

## Prerequisites

1. Posit Connect Cloud account
2. `rsconnect` package installed: `install.packages("rsconnect")`
3. API tokens stored in `.Renviron` (already configured)

## Step 1: Install Required Packages

```r
install.packages(c("rsconnect", "quarto"))
```

## Step 2: Configure Posit Connect Cloud

### First-time setup:

```r
library(rsconnect)

# Connect to your Posit Cloud account
# You'll need your account name and API key from Connect Cloud
connectApiUser(
  account = "your-account-name",
  server = "connect.posit.cloud",
  apiKey = "your-api-key"
)
```

To get your API key:
1. Log into https://connect.posit.cloud
2. Click your name (top right) → API Keys
3. Create a new API key

## Step 3: Deploy the Report

```r
library(rsconnect)

# Deploy the Quarto document
deployDoc(
  doc = "weekly_report.qmd",
  appTitle = "IMSLU Weekly Assessment Report",
  server = "connect.posit.cloud",
  account = "your-account-name",
  forceUpdate = TRUE
)
```

## Step 4: Configure Email Distribution on Connect Cloud

After deployment, configure the email settings in the Connect Cloud web interface:

### 4.1 Access the Content Settings

1. Go to https://connect.posit.cloud
2. Find your deployed report
3. Click on it → **Settings** tab

### 4.2 Configure Schedule

1. Go to **Schedule** section
2. Click **Add Schedule**
3. Configure:
   - **Type**: Standard schedule
   - **Frequency**: Weekly
   - **Day**: Monday
   - **Time**: 08:00 (your timezone)
   - **Timezone**: Select your timezone

### 4.3 Configure Email Distribution

#### Option A: Static Email List (Simplest)

1. In **Schedule** settings, enable **Send email**
2. Enter email addresses manually in the **To:** field
3. Add subject: "IMSLU Weekly Assessment Report"

**Pros**: Simple, works immediately
**Cons**: Must manually update when faculty/residents change

#### Option B: Dynamic Email List (Recommended)

Posit Connect Cloud supports custom email lists through R code.

1. Add this code chunk to your `weekly_report.qmd` after the fetch-data chunk:

```r
# Set email distribution list for Connect Cloud
if (Sys.getenv("RSTUDIO_PRODUCT") == "CONNECT") {
  source("R/get_email_list.R")
  email_list <- get_email_list()

  # Configure Connect email metadata
  rmarkdown::output_metadata$set(
    rsc_email_subject = "IMSLU Weekly Assessment Report",
    rsc_email_body_text = "Please find attached the weekly assessment report.",
    rsc_email_attachments = list(),
    rsc_email_suppress_report_attachment = FALSE,
    connect_email_to = email_list
  )
}
```

2. Re-deploy the report
3. In Connect Cloud, enable email in Schedule settings (it will use the dynamic list)

**Pros**: Automatically updates when faculty/residents change
**Cons**: Requires re-deploy to set up

### 4.4 Email Server Configuration

Posit Connect Cloud provides email service by default. However, if your organization restricts external emails:

#### Workaround Options:

1. **Use personal email for notifications**: Configure Connect to send from a personal Gmail/Outlook account
   - Settings → Email Provider → Configure custom SMTP
   - Use Gmail App Password or Outlook SMTP settings

2. **Request IT to allowlist**: Ask IT to allowlist `*.posit.cloud` email addresses

3. **Use Connect's default**: Emails will come from `noreply@posit.cloud`

## Step 5: Test the Setup

1. After configuration, click **Run Report** in Connect Cloud
2. Check if emails are received
3. Verify the report renders correctly
4. Confirm email list is complete

## Step 6: Monitor

- Connect Cloud will email you if the scheduled report fails
- Check the **Logs** tab for any errors
- Review the **Usage** tab to see email delivery status

## Environment Variables

Make sure your `.Renviron` is deployed with the report:

```bash
# Check .Renviron contains:
REDCAP_URL=your_redcap_url
REDCAP_RDM_TOKEN=your_rdm_token
REDCAP_FAC_TOKEN=your_fac_token
```

**Important**: When deploying, `rsconnect` should automatically include `.Renviron`, but verify in Connect Cloud Settings → Vars that the tokens are set.

## Troubleshooting

### Report fails to render
- Check **Logs** tab for error messages
- Verify API tokens are set correctly in Environment Variables
- Ensure all required packages are installed on Connect

### Emails not sending
- Verify schedule is enabled
- Check email addresses are valid
- Review email logs in Settings → Logs

### Missing recipients
- Test `get_email_list()` function locally
- Verify `fac_email` and `email` fields exist in datasets
- Check for typos in email addresses in REDCap

## Alternative: Manual Deployment via Web Interface

If command-line deployment doesn't work:

1. Export report as static HTML locally
2. Upload to Connect Cloud via web interface
3. Configure schedule and emails through UI

## Next Steps

Once deployed and tested:
- Document the process for your team
- Set up alerts for delivery failures
- Consider adding more recipients (administrators, etc.)
- Monitor email delivery rates

## Support

- Posit Connect Cloud docs: https://docs.posit.co/connect/
- Contact Posit support if email issues persist
