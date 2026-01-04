# GitHub Actions + Fastlane Setup for TestFlight

**Problem:** Your macOS is too old to run the required Xcode version for TestFlight uploads.

**Solution:** Use GitHub Actions (cloud macOS with latest Xcode) + Fastlane to automate uploads.

---

## What I've Created For You

✅ `Gemfile` - Tells Ruby to install Fastlane
✅ `fastlane/Fastfile` - Fastlane configuration for building and uploading
✅ `.github/workflows/testflight.yml` - GitHub Actions workflow that runs on push
✅ Updated `.gitignore` - Prevents committing secrets

---

## Step 1: Create App Store Connect API Key

This lets GitHub authenticate with Apple on your behalf.

### Instructions:

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **Users and Access** in the top navigation
3. Click **Keys** tab (or **Integrations** → **App Store Connect API**)
4. Click **+ Generate API Key** or **+ Request Access** (if first time)
5. Fill in:
   - **Name:** "GitHub Actions" (or "Fastlane CI")
   - **Access:** Select **App Manager** (gives build upload permissions)
6. Click **Generate**
7. **IMPORTANT - Do this NOW (you can only download once):**
   - Click **Download API Key** button
   - Save the `.p8` file somewhere safe (like your Downloads folder)
   - **Copy the Key ID** (shows as "Key ID: ABC123XYZ")
   - **Copy the Issuer ID** (shows at top: "Issuer ID: xxxx-xxxx-xxxx-xxxx")

### Save These Values:

```
Key ID: __________ (e.g., "ABC123XYZ")
Issuer ID: __________ (e.g., "12345678-1234-1234-1234-123456789012")
.p8 file location: __________ (e.g., "/Users/asad/Downloads/AuthKey_ABC123XYZ.p8")
```

---

## Step 2: Get Your Team ID

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Click **Membership** in the sidebar
3. Find **Team ID** (10-character alphanumeric like "ABC123XYZ0")
4. Copy it

```
Team ID: __________ (e.g., "ABC123XYZ0")
```

---

## Step 3: Prepare the API Key for GitHub

You need to convert the `.p8` file to base64 so it can be stored as a GitHub Secret.

### On your Mac terminal:

```bash
cd ~/Downloads  # or wherever you saved the .p8 file
base64 -i AuthKey_ABC123XYZ.p8 | pbcopy
```

(Replace `ABC123XYZ` with your actual Key ID)

This copies the base64-encoded key to your clipboard.

---

## Step 4: Set Up GitHub Secrets

GitHub Secrets are encrypted environment variables that your workflow can access.

### Instructions:

1. Go to your GitHub repository: `https://github.com/<your-username>/Momento`
2. Click **Settings** tab (at the top)
3. In left sidebar: **Secrets and variables** → **Actions**
4. Click **New repository secret** button

### Add these secrets ONE BY ONE:

| Secret Name | Value | Where to Get It |
|-------------|-------|----------------|
| `APP_STORE_CONNECT_KEY_ID` | Your Key ID from Step 1 | e.g., "ABC123XYZ" |
| `APP_STORE_CONNECT_ISSUER_ID` | Your Issuer ID from Step 1 | e.g., "12345678-1234-..." |
| `APP_STORE_CONNECT_API_KEY` | Paste from clipboard (Step 3) | The base64 string you copied |

For each secret:
1. Click **New repository secret**
2. Enter the **Name** (exactly as shown in table)
3. Paste the **Value**
4. Click **Add secret**
5. Repeat for next secret

---

## Step 5: Update Fastfile with Your Team ID

We need to tell Fastlane your Team ID.

Open `fastlane/Fastfile` and update this line:

```ruby
# Find this section and add your Team ID
build_app(
  scheme: "Momento",
  export_method: "app-store",
  export_options: {
    teamID: "YOUR_TEAM_ID_HERE",  # ← Add this line
    provisioningProfiles: {
      "com.asad.Momento" => "match AppStore com.asad.Momento"
    }
  }
)
```

---

## Step 6: Commit and Push to GitHub

Now let's commit the new files and push to trigger the workflow!

```bash
cd /Users/asad/Documents/Momento

# Add the new files
git add Gemfile fastlane/ .github/ .gitignore

# Commit
git commit -m "Add GitHub Actions for automated TestFlight uploads"

# Push to GitHub (this will trigger the workflow!)
git push origin main
```

---

## Step 7: Watch the Workflow Run

1. Go to your GitHub repository
2. Click **Actions** tab
3. You should see a workflow running called "Deploy to TestFlight"
4. Click on it to see real-time logs
5. Wait 10-15 minutes for the build to complete
6. Check your email for TestFlight processing notification

---

## How It Works Going Forward

**Every time you push to `main` branch:**
1. GitHub Actions automatically triggers
2. Builds your app with latest Xcode (on GitHub's macOS runners)
3. Auto-increments build number
4. Uploads to TestFlight
5. You get an email when ready (~30 mins total)

**Manual trigger:**
1. Go to GitHub → Actions tab
2. Click "Deploy to TestFlight" workflow
3. Click "Run workflow" button
4. Select branch → Run workflow

---

## Troubleshooting

### Workflow fails with "No signing identity"

**Solution:** We need to set up code signing certificates. Let me know if this happens and I'll help you set up Fastlane Match (automated certificate management).

### Workflow fails with "Invalid API key"

**Solution:** Double-check your GitHub Secrets:
- Make sure Key ID is exactly correct (no spaces)
- Make sure Issuer ID is the full UUID
- Make sure the base64 .p8 key was copied completely

### Build succeeds but never appears in TestFlight

**Solution:** Check App Store Connect → Your App → TestFlight. Build might be "Processing" (takes 10-30 mins).

---

## Next Steps

Once this is working:
1. **Day 5 upload:** Just push code to `main` → automatic upload!
2. **Day 10 upload:** Same - push code → automatic upload!
3. No need to use Xcode for uploads ever again

---

## Cost

- **GitHub Actions:** Free for private repos (2,000 minutes/month)
- Each build takes ~10-15 minutes
- You have room for ~130 builds/month for free
- More than enough for your needs!

---

## Summary

✅ GitHub Actions workflow created
✅ Fastlane configured
✅ Will auto-upload on push to `main`
✅ No local Xcode upload needed
✅ Works with your outdated macOS

Let's get started with Step 1! 🚀
