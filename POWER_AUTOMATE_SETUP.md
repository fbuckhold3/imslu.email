# Power Automate Setup for Weekly Email Delivery

This guide explains how to set up a Microsoft Power Automate flow to automatically email the IMSLU Weekly Assessment Report every Monday morning.

## Prerequisites

- Microsoft 365 account with Power Automate access
- Posit Connect Cloud report URL (the public link to your deployed weekly_report)
- Access to REDCap APIs for fetching recipient emails (or manual recipient list)

## Overview

The Power Automate flow will:
1. Run every Monday at 8:00 AM
2. Fetch the latest rendered report from Posit Connect Cloud
3. Get the recipient list (faculty and residents)
4. Send the email via Outlook with the report attached or embedded

## Step-by-Step Setup

### Step 1: Create a New Scheduled Flow

1. Go to [Power Automate](https://make.powerautomate.com)
2. Click **+ Create** in the left menu
3. Select **Scheduled cloud flow**
4. Name it: "IMSLU Weekly Assessment Report Email"
5. Set the schedule:
   - **Starting**: Select next Monday
   - **Repeat every**: 1 Week
   - **On these days**: Monday
   - **At these hours**: 8
   - **At these minutes**: 0
6. Click **Create**

### Step 2: Add HTTP Action to Fetch Report

1. Click **+ New step**
2. Search for and select **HTTP** action
3. Configure:
   - **Method**: GET
   - **URI**: `https://019b1858-834c-987a-ee25-a5e13dabef9b.share.connect.posit.cloud/weekly_report.html`
   - **Authentication**: None (since it's publicly accessible)

   **Your specific report URL:**
   - Base URL: `https://019b1858-834c-987a-ee25-a5e13dabef9b.share.connect.posit.cloud`
   - Full report: `https://019b1858-834c-987a-ee25-a5e13dabef9b.share.connect.posit.cloud/weekly_report.html`

4. **Note**: If the report is not public and requires login, click **Show advanced options** and add:
   - **Authentication**: Basic
   - **Username**: Your Connect Cloud username
   - **Password**: Your Connect Cloud API key

### Step 3: Option A - Get Recipients from REDCap API

**If you want dynamic recipient lists from REDCap:**

1. Click **+ New step**
2. Add **HTTP** action for faculty emails:
   - **Method**: POST
   - **URI**: `https://redcap.wustl.edu/redcap/srvrs/prod_v3_1_0_001/redcap/api/`
   - **Headers**:
     - Content-Type: `application/x-www-form-urlencoded`
   - **Body**:
     ```
     token=YOUR_FACULTY_API_TOKEN&content=record&format=json&type=flat&fields[]=fac_email
     ```
3. Click **+ New step**
4. Add **Parse JSON** action:
   - **Content**: Body (from previous HTTP action)
   - **Schema**: Click "Use sample payload" and paste:
     ```json
     [{"fac_email": "example@example.com"}]
     ```
5. Repeat for residents (using resident API token and `email` field)

6. Click **+ New step**
7. Add **Compose** action to combine emails:
   - **Inputs**: Use expressions to extract and combine email arrays

### Step 3: Option B - Use Static Recipient List

**If you want a simple static list:**

1. Click **+ New step**
2. Add **Initialize variable** action:
   - **Name**: `EmailRecipients`
   - **Type**: String
   - **Value**: `Fred.buckhold@slucare.ssmhealth.com; faculty2@example.com; resident1@example.com`

   (Separate multiple emails with semicolons)

### Step 4: Send Email via Outlook

1. Click **+ New step**
2. Search for and select **Send an email (V2)** (Office 365 Outlook)
3. Configure:
   - **To**:
     - For Option A: Use the composed/parsed email list
     - For Option B: Use the `EmailRecipients` variable
   - **Subject**: `IMSLU Weekly Assessment Report - @{formatDateTime(utcNow(), 'MMMM dd, yyyy')}`
   - **Body**:
     ```html
     <h2>IMSLU Weekly Assessment Report</h2>

     <p>Your weekly residency program assessment report for <strong>@{formatDateTime(utcNow(), 'MMMM dd, yyyy')}</strong> is ready.</p>

     <p><strong>Quick Links:</strong></p>
     <ul>
       <li><a href="https://fbuckhold3-imslu-resident-assessment.share.connect.posit.cloud">Submit Resident Assessment</a></li>
       <li><a href="https://fbuckhold3-imslu-facultyeval.share.connect.posit.cloud">Submit Faculty Evaluation</a></li>
       <li><a href="https://fbuckhold3-imslu-at-noon.share.connect.posit.cloud">Submit Attendance at Noon Conference</a></li>
     </ul>

     <p>See the attached report for full details including charts and tables.</p>

     <hr>
     <p><em>This is an automated email from the IMSLU Residency Program reporting system.</em></p>
     ```
   - **Importance**: Normal
   - Click **Show advanced options**
   - **Attachments**:
     - **Name**: `IMSLU_Weekly_Report_@{formatDateTime(utcNow(), 'yyyy-MM-dd')}.html`
     - **Content**: `@{body('HTTP')}` (the report content from Step 2)

4. Click **Save**

## Testing the Flow

1. Click **Test** in the top right
2. Select **Manually**
3. Click **Test** button
4. Check your email to verify it works
5. Check that the report attachment opens correctly

## Troubleshooting

### Report doesn't load
- Verify the Connect Cloud URL is correct and publicly accessible
- Check if authentication is required
- Try opening the URL in an incognito browser window

### Recipients not receiving
- Check spam/junk folders
- Verify email addresses are correct
- Check Power Automate run history for errors

### Report is outdated
- Make sure the schedule in Posit Connect Cloud is set to re-render before the email sends
- Or have Power Automate trigger a re-render first (add HTTP POST to trigger render endpoint)

## Alternative: Embed Report Instead of Attach

Instead of attaching the HTML file, you can embed it directly in the email body:

In the Send Email action, use:
- **Body**: `@{body('HTTP')}`
- **Is HTML**: Yes
- Remove the attachment

This sends the full report as the email body rather than as an attachment.

## Production Configuration

Once tested, update for production:

1. Change recipients from test email to full list
2. Consider using a distribution list/group email for easier management
3. Set up error notifications if the flow fails
4. Document the flow for other team members

## Getting Recipient List from R/REDCap

If you want to continue using your `get_email_list()` R function, you could:

1. Modify `weekly_report.qmd` to export the email list to a JSON file
2. Deploy that JSON file alongside the report
3. Have Power Automate fetch and parse the JSON for recipients

Let me know if you need help with this approach!

## Contact

Questions about this setup? Contact your program administrator or the person who set up the Posit Connect Cloud deployment.
