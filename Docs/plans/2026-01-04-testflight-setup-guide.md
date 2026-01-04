# TestFlight Setup Guide - Momento Beta Launch

**Goal:** Set up TestFlight for Momento app beta testing leading to Jan 10th party launch.

**Timeline:**
- **Day 1 (Today):** Solo testing - just you
- **Day 5:** Small group - 2 people
- **Day 10:** Party launch - ~20 people

**Approach:** Manual builds, internal testing only (no Apple review delays), iterative development

---

## Section 1: App Store Connect Initial Setup

### Creating Your App Record

You need to create your app in App Store Connect before you can upload any builds. This is a one-time setup that establishes your app's identity in the Apple ecosystem.

### Bundle ID Registration (Do This First)

Before you can create the app in App Store Connect, register the Bundle ID:

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to "Certificates, Identifiers & Profiles" → "Identifiers"
3. Click "+" to create a new identifier
4. Select "App IDs" → "Continue"
5. Fill in:
   - **Description:** "Momento"
   - **Bundle ID:** `com.asad.Momento` (explicit, not wildcard)
6. **Capabilities:** Enable "Sign in with Apple" (matches your Xcode setup)
7. Click "Continue" → "Register"

### Create App in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click "My Apps" → "+" → "New App"
3. Fill in required fields:
   - **Platform:** iOS
   - **Name:** "Momento" (user-facing name, can change later)
   - **Primary Language:** English
   - **Bundle ID:** Select `com.asad.Momento` (the one you just created)
   - **SKU:** Internal reference (e.g., "momento-2026" - not visible to users)
   - **User Access:** Full Access

### Important Notes
- Bundle ID must exactly match what's in your Xcode project
- Once created, Bundle ID cannot be changed
- App name can be changed anytime before public launch

---

## Section 2: Xcode Project Configuration

### Automatic Signing Setup

**Note:** "Automatic Signing" in Xcode is about code signing certificates - it has NOTHING to do with user authentication in your app. Your Google/Apple/Email sign-in remains unchanged.

**Steps:**
1. Open `Momento.xcodeproj` in Xcode
2. Select the "Momento" target → "Signing & Capabilities" tab
3. Check "Automatically manage signing"
4. Select your Team (your Apple Developer account)
5. Verify Bundle Identifier shows `com.asad.Momento`
6. Xcode will automatically create provisioning profiles

### Version & Build Numbers

Configure proper versioning for TestFlight:

1. Select "Momento" target → "General" tab
2. **Version:** User-facing version (e.g., "1.0.0")
3. **Build:** Internal build number (must increment with each upload)

**Versioning Strategy for Beta:**
- **Version:** Keep at "1.0.0" throughout beta
- **Build:** Simple counter - "1", "2", "3", etc.
- For your timeline:
  - Build 1: Today (current features)
  - Build 2: Day 5 (new screens added)
  - Build 3: Day 10 (party-ready polish)

### App Icon Requirement

TestFlight requires an app icon in all sizes.

**Options:**
- Create a proper icon (recommended)
- Use a placeholder (solid color with "M" text) to get started
- Generate quickly with [AppIcon.co](https://www.appicon.co/)
- Icon must be in `Assets.xcassets` in all required sizes

**Action:** Create or generate an icon before your first upload.

---

## Section 3: Creating and Uploading Your First Build

### Archive Process in Xcode

An "archive" is a special build package that can be uploaded to TestFlight.

**Steps:**
1. **Select target device:** In Xcode toolbar, change from simulator to **"Any iOS Device (arm64)"**
2. **Clean build:** Product → Clean Build Folder (⇧⌘K)
3. **Create archive:** Product → Archive
4. **Wait:** Takes 2-5 minutes depending on your Mac

**Troubleshooting:**
- If "Archive" is grayed out, make sure you selected "Any iOS Device" not a simulator
- If build fails, check for errors in the Issue Navigator

### Upload to App Store Connect

After archiving, the Organizer window opens automatically:

1. **Select your archive** from the list (should be at the top)
2. **Click "Distribute App"**
3. **Select "App Store Connect"** → Next
4. **Select "Upload"** (not "Export") → Next
5. **Signing:** Choose "Automatically manage signing" → Next
6. **Review:** Check the summary shows correct version/build → Upload
7. **Wait:** Upload takes 5-15 minutes depending on internet speed

### Processing & Availability

After upload completes in Xcode:

1. **Processing:** App Store Connect processes the build (10-30 minutes)
2. **Email notification:** You'll receive an email when processing completes
3. **Check status:** Go to App Store Connect → Your App → TestFlight → iOS Builds
4. **Status progression:** "Processing" → "Ready to Submit" → "Ready to Test"

**Note:** Don't worry if processing takes up to 30 minutes - this is normal for first builds.

### First Build Checklist

Before uploading Build 1, verify:
- ✅ Version: 1.0.0
- ✅ Build: 1
- ✅ App icon present in all required sizes
- ✅ Target device: "Any iOS Device (arm64)"
- ✅ No build errors or serious warnings
- ✅ Bundle ID matches: com.asad.Momento

---

## Section 4: TestFlight Configuration and Adding Testers

### Internal vs External Testing

TestFlight offers two testing modes:

| Type | Limit | Review Required | Best For |
|------|-------|-----------------|----------|
| **Internal** | 100 testers | No | Fast iteration, trusted testers |
| **External** | 10,000 testers | Yes (24-48h first build) | Public beta, large groups |

**For Your Timeline: Use Internal Testing**
- No Apple review delays
- Builds available instantly
- Perfect for your rapid timeline (today → 4 days → 10 days)

### Adding Testers in App Store Connect

1. Go to App Store Connect → Your App → TestFlight
2. Click **"Internal Testing"** tab
3. Click "+" to create a new tester group
4. Name it: "Beta Testers" (or "Party Beta")
5. Click "Add Testers"
6. Enter email addresses (they need Apple IDs)

**For Your Timeline:**
- **Today:** Add just your email address
- **Day 5:** Add 2 more email addresses
- **Day 10 prep (Day 8-9):** Add remaining ~18 email addresses

### How Testers Install Your App

1. Tester receives email invitation to TestFlight
2. They download "TestFlight" app from App Store (if not installed)
3. Open invitation email → Click "View in TestFlight"
4. Accept invitation in TestFlight app
5. Tap "Install" to download your app
6. When you upload new builds, they get push notifications to update

### Important Tester Notes

- Testers need an Apple ID (any email with Apple account works)
- They must install TestFlight app first (free from App Store)
- Builds expire after 90 days
- You can add release notes for each build
- Testers can provide feedback through TestFlight

### Party Preparation (Day 8-9)

For your 20-person party on Day 10:

1. Add all attendee emails 1-2 days BEFORE the party
2. Send them instructions:
   ```
   Hey! Install the "TestFlight" app from the App Store,
   then check your email for an invite to test Momento.
   Accept the invite and install the app before the party!
   ```
3. This gives people time to:
   - Install TestFlight
   - Accept invitation
   - Install your app
   - Troubleshoot any issues

**Don't wait until party day** - some people will have questions or issues.

---

## Section 5: Complete Workflow and Your Timeline

### Day 1 (TODAY) - Initial Setup & Solo Testing

**Morning/Afternoon:**
1. ✅ Create Bundle ID in Apple Developer Portal
2. ✅ Create app record in App Store Connect
3. ✅ Configure Xcode project (signing, version 1.0.0, build 1)
4. ✅ Create/add app icon to Assets.xcassets
5. ✅ Archive and upload Build 1
6. ✅ Wait for processing (~30 minutes)

**Evening:**
7. ✅ Add yourself as internal tester in App Store Connect
8. ✅ Accept invitation email
9. ✅ Install TestFlight app on your iPhone
10. ✅ Install Momento through TestFlight
11. ✅ Test all features thoroughly:
    - Google Sign In
    - Apple Sign In
    - Create Momento flow
    - Join Momento flow
    - Photo upload
    - Settings & Logout

### Day 2-4 - Active Development

**You can keep coding while Build 1 is live!**

- Add your new screens
- Fix bugs discovered during testing
- Improve UI/UX
- Keep testing Build 1 on your device
- Commit changes to git as usual

### Day 5 - Small Group Beta

**Steps:**
1. Archive and upload **Build 2** (version 1.0.0, build 2)
2. Add 2 friends' emails as internal testers
3. They receive invites → install TestFlight → install Momento
4. Gather feedback on new features
5. Note any bugs or issues

**Release Notes for Build 2:**
```
What's New:
- Added [new screen names]
- Bug fixes from initial testing
- UI improvements
```

### Day 6-9 - Polish Phase

- Fix bugs reported by your 2 testers
- Polish UI/UX for party
- Test thoroughly yourself
- Prepare for larger group

### Day 8-9 - Party Preparation

**Critical: Do this BEFORE the party!**

1. Archive and upload **Build 3** (version 1.0.0, build 3)
2. Add all ~20 party attendees as internal testers
3. Send clear instructions:
   ```
   📱 Get Ready for the Party!

   1. Install "TestFlight" from the App Store
   2. Check your email for Momento invite
   3. Open email → tap "View in TestFlight"
   4. Tap "Install" in TestFlight app
   5. Done! See you at the party!
   ```
4. Be available to help people with setup issues
5. Test Build 3 yourself one final time

**Release Notes for Build 3:**
```
Party-Ready Build! 🎉
- All features tested and polished
- [List any final additions]
- Ready for the big day!
```

### Day 10 - Party Launch! 🎉

**Everyone should already have the app installed!**

1. Create the party Momento together
2. Share the join code
3. Everyone takes photos during the event
4. Photos reveal 24 hours later
5. Gather feedback and celebrate!

---

## Common Issues & Solutions

### Build/Upload Issues

| Issue | Solution |
|-------|----------|
| "Archive" is grayed out | Select "Any iOS Device (arm64)" in toolbar, not a simulator |
| "Invalid signature" error | Verify Team and Bundle ID match in Signing & Capabilities |
| Build stuck "Processing" | Wait 30 mins - first builds can take longer. Check email for completion. |
| "No signing certificate" | Enable "Automatically manage signing" in Xcode |
| Upload fails | Check internet connection, try again, or use Xcode → Window → Organizer |

### Tester Issues

| Issue | Solution |
|-------|----------|
| Tester can't find invite email | Check spam folder, resend invite from App Store Connect |
| "App not available in TestFlight" | Build still processing, or tester not added to testing group |
| TestFlight crashes | Have tester reinstall TestFlight app from App Store |
| "Invitation expired" | Resend invitation from App Store Connect |
| Can't install on iPad | Check that you selected "iPhone" or "Universal" not "iPad only" |

### Development Issues

| Issue | Solution |
|-------|----------|
| Forgot to increment build number | Must increment for each upload. If same build, upload will be rejected. |
| Want to remove a build | Can't delete, but can expire it in App Store Connect |
| Tester sees old version | They need to update in TestFlight app (should get notification) |
| Need to test on simulator | Use regular Xcode builds, TestFlight is device-only |

---

## Quick Reference

### Version & Build Tracking

| Upload | Version | Build | Purpose |
|--------|---------|-------|---------|
| Today | 1.0.0 | 1 | Initial solo testing |
| Day 5 | 1.0.0 | 2 | Small group + new screens |
| Day 10 | 1.0.0 | 3 | Party launch build |

### Important Links

- **App Store Connect:** https://appstoreconnect.apple.com
- **Apple Developer Portal:** https://developer.apple.com/account
- **TestFlight Guide:** https://developer.apple.com/testflight/

### Key Reminders

- ✅ Keep developing between builds - TestFlight doesn't block development
- ✅ Test each build yourself before inviting others
- ✅ Add party testers 1-2 days early, not day-of
- ✅ Increment build number for each upload (1, 2, 3...)
- ✅ Keep version at 1.0.0 during beta
- ✅ Add meaningful release notes for each build
- ✅ Internal testing = no review delays = perfect for your timeline

---

## Next Steps After This Guide

Once TestFlight is working and your party is successful:

1. **Gather feedback** from testers during/after party
2. **Iterate** based on real usage data
3. **Consider external beta** if you want more testers (requires Apple review)
4. **Plan App Store launch** when ready for public release
5. **Update version to 2.0.0** for major feature additions

Good luck with your beta launch! 🚀
