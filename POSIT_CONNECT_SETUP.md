# Posit Connect Cloud Email Setup

This guide explains how to set up the weekly resident evaluation report to be emailed every Monday morning via Posit Connect Cloud.

## Prerequisites

1. **Posit Connect Cloud Account**: You need access to Posit Connect Cloud
2. **Environment Variables**: Ensure your `.Renviron` file contains:
   ```
   REDCAP_URL=your_redcap_api_url
   REDCAP_FAC_TOKEN=your_faculty_database_token
   REDCAP_RDM_TOKEN=your_rdm_database_token
   ```

## Deployment Steps

### Step 1: Deploy to Posit Connect Cloud

There are two ways to deploy:

#### Option A: Using RStudio IDE (Recommended)

1. Open `weekly_report.qmd` in RStudio
2. Click the **Publish** button (blue icon in top right)
3. Select **Posit Connect Cloud**
4. Sign in to your account if prompted
5. Choose a title (e.g., "Weekly Resident Evaluation Report")
6. Click **Publish**

#### Option B: Using Command Line with `rsconnect` package

```r
library(rsconnect)

# First time: Set up your Posit Connect Cloud account
rsconnect::connectApiUser(
  account = "your-account-name",
  server = "connect.posit.cloud",
  apiKey = "your-api-key"
)

# Deploy the report
rsconnect::deployDoc(
  doc = "weekly_report.qmd",
  appTitle = "Weekly Resident Evaluation Report",
  server = "connect.posit.cloud"
)
```

### Step 2: Configure Environment Variables in Posit Connect

After deployment, you need to add your REDCap credentials:

1. Go to your deployed content on Posit Connect Cloud
2. Click on **Settings** (gear icon)
3. Navigate to **Vars** tab
4. Add the following environment variables:
   - `REDCAP_URL`
   - `REDCAP_FAC_TOKEN`
   - `REDCAP_RDM_TOKEN`
5. Click **Save**

### Step 3: Set Up Weekly Schedule

Configure the report to run every Monday at 8:00 AM:

1. In your content settings, go to the **Schedule** tab
2. Enable **Schedule this report**
3. Set the schedule to:
   - **Frequency**: Weekly
   - **Day**: Monday
   - **Time**: 08:00 (8:00 AM in your timezone)
4. Click **Save**

### Step 4: Configure Email Delivery

You have two options for email delivery:

#### Option A: Use Posit Connect's Email Customization (Simpler)

1. In your content settings, go to the **Email** tab
2. Enable **Email output to custom addresses**
3. Generate the email list by running locally:
   ```r
   Rscript get_email_list.R
   ```
4. Copy the comma-separated email list from the output
5. Paste it into the **Email addresses** field in Posit Connect
6. Configure email settings:
   - **Subject**: `Weekly Resident Evaluation Report - {Date}`
   - **Attach output**: Checked (to include HTML report)
7. Click **Save**

#### Option B: Dynamic Email List (Advanced)

For a dynamic email list that updates automatically:

1. The report already includes `get_email_recipients()` function
2. In Posit Connect, you may need to set up a custom email integration
3. Contact your Posit Connect administrator for assistance

### Step 5: Test the Setup

1. Click **Render** or **Run** to manually trigger the report
2. Verify that:
   - The report renders successfully
   - REDCap data is fetched correctly
   - (Optional) Test email delivery by using a single test email first

## Email Recipients

The email will be sent to:
- **Faculty**: All active (non-archived) faculty from the faculty database (`fac_email` field)
- **Residents**: All active (non-archived) residents from the RDM database (`email` field)

To view the current email list at any time, run:
```r
Rscript get_email_list.R
```

## Schedule Summary

- **Frequency**: Weekly
- **Day**: Monday
- **Time**: 8:00 AM (your timezone)
- **Recipients**: Faculty + Residents (dynamic from REDCap databases)

## Troubleshooting

### Report fails to render
- Check that environment variables are set correctly in Posit Connect
- Verify REDCap API tokens have correct permissions
- Check the error logs in Posit Connect

### Emails not being sent
- Verify email delivery is enabled in the Email tab
- Check that email addresses are valid
- Confirm your Posit Connect account has email sending permissions
- Check spam/junk folders

### Email list is empty
- Run `get_email_list.R` locally to verify data is being fetched
- Ensure the `fac_email` and `email` fields exist in your REDCap databases
- Check that there are active (non-archived) records

### Wrong timezone
- Schedule times are based on your Posit Connect server's timezone
- Adjust the time in the Schedule tab as needed

## Updating Email Recipients

The email list is automatically updated each time the report runs IF you use the dynamic approach. For the manual approach (Option A above):

1. Run `get_email_list.R` to get the updated list
2. Go to Posit Connect → Settings → Email
3. Update the email addresses
4. Click Save

## Files Created

- `weekly_report.qmd` - Main report (modified for email support)
- `manifest.json` - Posit Connect deployment configuration
- `setup_connect_email.R` - Automated setup script (advanced)
- `get_email_list.R` - Helper script to generate email list
- `POSIT_CONNECT_SETUP.md` - This documentation

## Additional Resources

- [Posit Connect User Guide](https://docs.posit.co/connect/user/)
- [Scheduling Reports in Posit Connect](https://docs.posit.co/connect/user/scheduling/)
- [Email Delivery in Posit Connect](https://docs.posit.co/connect/user/content-settings/#email-settings)

## Support

If you encounter issues:
1. Check the Posit Connect error logs
2. Verify your REDCap API access
3. Contact your Posit Connect administrator
4. Refer to the troubleshooting section above
