# Power Automate Quick Start - IMSLU Weekly Report

**Your Report URL**: `https://019b1858-834c-987a-ee25-a5e13dabef9b.share.connect.posit.cloud/weekly_report.html`

## Quick Setup (15 minutes)

### 1. Create the Flow

1. Go to https://make.powerautomate.com
2. Click **+ Create** → **Scheduled cloud flow**
3. Name: "IMSLU Weekly Assessment Report"
4. Schedule:
   - Repeat every: **1 Week**
   - On these days: **Monday**
   - At these hours: **8**
   - At these minutes: **0**
5. Click **Create**

### 2. Fetch the Report

1. Click **+ New step**
2. Search for **HTTP** and select it
3. Set:
   - Method: **GET**
   - URI: `https://019b1858-834c-987a-ee25-a5e13dabef9b.share.connect.posit.cloud/weekly_report.html`
4. Leave Authentication as **None**

### 3. Send the Email

1. Click **+ New step**
2. Search for **Send an email** and select **Send an email (V2)** (Office 365 Outlook)
3. Fill in:

   **To**: `Fred.buckhold@slucare.ssmhealth.com`

   **Subject**: `IMSLU Weekly Assessment Report - @{formatDateTime(utcNow(), 'MMMM dd, yyyy')}`

   **Body** (click the **<>** code view button and paste):
   ```html
   <h2>IMSLU Weekly Assessment Report</h2>
   <p>Your weekly residency program assessment report is ready for <strong>@{formatDateTime(utcNow(), 'MMMM dd, yyyy')}</strong>.</p>
   <p><strong>Quick Links:</strong></p>
   <ul>
     <li><a href="https://fbuckhold3-imslu-resident-assessment.share.connect.posit.cloud">Submit Resident Assessment</a></li>
     <li><a href="https://fbuckhold3-imslu-facultyeval.share.connect.posit.cloud">Submit Faculty Evaluation</a></li>
     <li><a href="https://fbuckhold3-imslu-at-noon.share.connect.posit.cloud">Submit Attendance at Noon Conference</a></li>
   </ul>
   <p>See the attached report for full details including charts and tables.</p>
   <hr>
   <p><em>This is an automated email from the IMSLU Residency Program.</em></p>
   ```

4. Click **Show advanced options**
5. Under **Attachments - 1**, set:
   - **Name**: `IMSLU_Weekly_Report.html`
   - **Content**: Click in the box, then select **Body** from the Dynamic content (from the HTTP step)

6. Click **Save** (top right)

### 4. Test It

1. Click **Test** (top right)
2. Select **Manually**
3. Click **Test**
4. Click **Run flow**
5. Check your email (Fred.buckhold@slucare.ssmhealth.com)

### 5. Add More Recipients (Production)

Once testing works, update the **To** field:

**Option A - Manual List:**
Change the **To** field to:
```
Fred.buckhold@slucare.ssmhealth.com; faculty1@example.com; resident1@example.com
```
(Separate emails with semicolons)

**Option B - Distribution List:**
If your organization has an email distribution list, just use that:
```
residency-program@yourdomain.com
```

## Troubleshooting

**Email doesn't arrive:**
- Check spam/junk folder
- Verify the email address is correct
- Check Power Automate run history (left menu → **My flows** → click your flow → **Run history**)

**Report doesn't attach:**
- Verify the URL works by opening it in your browser
- Check if the report requires authentication (if yes, see full guide)
- Look at the HTTP action output in the run history

**Report is outdated:**
- Make sure Posit Connect Cloud schedule runs BEFORE the email (e.g., 7:30 AM render, 8:00 AM email)
- Or remove the schedule from Posit and rely only on Power Automate

## Next Steps

Once this is working:
1. Keep the Posit Connect Cloud schedule to re-render data Monday mornings at 7:30 AM
2. Power Automate fetches and emails it at 8:00 AM
3. Add all faculty and resident emails to the recipient list
4. Consider using REDCap API to dynamically fetch recipients (see full guide)

## Support

Questions? See the full `POWER_AUTOMATE_SETUP.md` guide for advanced options including:
- Dynamic recipient lists from REDCap
- Error notifications
- Embedding the report instead of attaching
- Customizing the email template
