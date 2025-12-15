# Power Automate - Email Recipients Setup

## Option 1: Outlook Groups (RECOMMENDED - Simplest!)

If you already have Outlook distribution groups set up, this is by far the easiest approach:

### Setup Steps:

1. **Create/Use Outlook Groups:**
   - Faculty group: e.g., `residency-faculty@yourdomain.com`
   - Active residents group: e.g., `residency-residents-active@yourdomain.com`

2. **In Power Automate Email Step:**
   - **To**: `residency-faculty@yourdomain.com; residency-residents-active@yourdomain.com`

**Benefits:**
- ✅ No API calls needed
- ✅ No filtering logic required
- ✅ Easy to manage recipients (just update the group)
- ✅ Works instantly
- ✅ Non-technical users can manage membership

**Drawbacks:**
- Requires maintaining Outlook groups separately
- Need admin access or permission to create/manage groups

---

## Option 2: REDCap API (Dynamic, but more complex)

Fetches email lists directly from REDCap, filtering out archived residents automatically.

### Prerequisites:
- Faculty REDCap API token
- Resident REDCap API token
- Know the field name that indicates archived status (e.g., `active`, `status`, `archived`)

### Setup Steps:

#### Step 1: Fetch Faculty Emails

1. Click **+ New step**
2. Search for **HTTP** and select it
3. Configure:
   - **Method**: POST
   - **URI**: `https://redcap.wustl.edu/redcap/srvrs/prod_v3_1_0_001/redcap/api/`
   - **Headers**:
     - Click **+ Add new item**
     - Key: `Content-Type`
     - Value: `application/x-www-form-urlencoded`
   - **Body**:
     ```
     token=YOUR_FACULTY_API_TOKEN&content=record&format=json&type=flat&fields[]=fac_email
     ```
     (Replace `YOUR_FACULTY_API_TOKEN` with your actual token)

4. **Rename this action**: Click the **...** menu → **Rename** → "Get Faculty Emails"

#### Step 2: Parse Faculty Emails

1. Click **+ New step**
2. Search for **Parse JSON** and select it
3. Configure:
   - **Content**: Click in the box → Select **Body** from "Get Faculty Emails"
   - **Schema**: Click "Use sample payload to generate schema" and paste:
     ```json
     [
       {"fac_email": "faculty1@example.com"},
       {"fac_email": "faculty2@example.com"}
     ]
     ```
4. Click **Done**

#### Step 3: Fetch Resident Emails (with filtering)

**Method A: Filter in REDCap API (Recommended)**

1. Click **+ New step**
2. Search for **HTTP** and select it
3. Configure:
   - **Method**: POST
   - **URI**: `https://redcap.wustl.edu/redcap/srvrs/prod_v3_1_0_001/redcap/api/`
   - **Headers**:
     - Key: `Content-Type`
     - Value: `application/x-www-form-urlencoded`
   - **Body** (update `FIELD_NAME` based on your database):
     ```
     token=YOUR_RESIDENT_API_TOKEN&content=record&format=json&type=flat&fields[]=email&filterLogic=[archived]="0"
     ```

     **Replace `[archived]="0"` with your actual filter logic. Common examples:**
     - If you have an `archived` field: `[archived]="0"` or `[archived]=""`
     - If you have a `status` field: `[status]="active"`
     - If you have an `active` field: `[active]="1"`
     - For multiple conditions: `[archived]="" AND [status]="active"`

4. **Rename this action**: "Get Active Resident Emails"

**Method B: Filter in Power Automate**

If filterLogic doesn't work or you need complex filtering:

1. Click **+ New step**
2. Add **HTTP** action to get ALL residents:
   - **Method**: POST
   - **URI**: `https://redcap.wustl.edu/redcap/srvrs/prod_v3_1_0_001/redcap/api/`
   - **Headers**: Same as above
   - **Body**:
     ```
     token=YOUR_RESIDENT_API_TOKEN&content=record&format=json&type=flat&fields[]=email&fields[]=archived
     ```
     (Include the archived/status field)

3. Click **+ New step**
4. Search for **Parse JSON** and add it
5. Click **+ New step**
6. Search for **Filter array** and select it
7. Configure:
   - **From**: Select the parsed JSON array
   - **Condition**: `archived` is equal to `0` (or whatever indicates active)

#### Step 4: Extract Email Addresses

1. Click **+ New step**
2. Search for **Select** and add it
3. Configure:
   - **From**: Body from "Parse JSON" (faculty)
   - **Map**:
     - Left side: `email`
     - Right side: Click and select `fac_email` from dynamic content

4. Repeat for residents

#### Step 5: Combine Email Lists

1. Click **+ New step**
2. Search for **Compose** and add it
3. Configure:
   - **Inputs**:
     ```
     @{join(body('Select_Faculty'), ';')}; @{join(body('Select_Residents'), ';')}
     ```

#### Step 6: Use Combined List in Email

In your "Send an email" action:
- **To**: Select the **Outputs** from the "Compose" action

---

## Recommendation

**Start with Outlook Groups** if you have them or can create them. It's:
- Much simpler to set up and maintain
- Less prone to errors
- Easier for non-technical staff to manage
- No API token management needed

**Use REDCap API** only if:
- You don't have Outlook groups
- You need real-time updates based on REDCap data
- You have complex filtering requirements

---

## What field indicates archived residents?

Please provide:
1. The field name in REDCap that indicates if a resident is archived
2. What value that field has for:
   - Active residents: (e.g., `0`, `""`, `"active"`)
   - Archived residents: (e.g., `1`, `"archived"`)

This will help me provide the exact filterLogic string for your setup.

Alternatively, if you have Outlook groups already set up, just let me know the group email addresses and we can skip the REDCap complexity!
