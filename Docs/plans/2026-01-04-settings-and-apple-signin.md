# Beta Readiness: Settings Screen + Apple Sign In

**Goal:** Add logout functionality via new Settings screen and enable Apple Sign In for beta launch.

**User Requirements:**
- ✅ Apple Developer account approved - ready to enable Apple Sign In
- ✅ Create dedicated Settings screen (not just menu option)
- ✅ Keep it minimal - just logout for now, no extra profile features

---

## Part 1: Enable Apple Sign In (5 min)

Apple Sign In is **fully implemented** - just needs Xcode capability and UI enablement.

### Step 1.1: Add Capability in Xcode (Manual)
**Action:** Must be done in Xcode UI, cannot be automated
1. Open `Momento.xcodeproj` in Xcode
2. Select "Momento" target → "Signing & Capabilities" tab
3. Click "+ Capability" → Add "Sign in with Apple"
4. Xcode auto-creates/updates `Momento.entitlements` file

### Step 1.2: Enable Button in UI
**File:** `Momento/SignInView.swift`

**Change at line 90:**
- Remove: `.opacity(0.5) // Disabled until Apple Developer account approved`
- The button is already functional - this just makes it visible

**No other code changes needed!** All backend logic already exists:
- SupabaseManager has `signInWithApple()` method (lines 70-88)
- Nonce generation implemented (lines 300-314)
- OAuth callback handling ready

---

## Part 2: Create Settings Screen with Logout (Main Work)

### Step 2.1: Create New SettingsView File
**New File:** `Momento/SettingsView.swift`

**Features:**
- Dark gradient background (matches app aesthetic)
- User info display (email, user ID)
- Logout button with confirmation dialog
- Loading state during async signOut()
- Error handling with alerts
- Royal purple accent color (consistent with app)

**Key Implementation Details:**
```swift
- @StateObject private var supabaseManager = SupabaseManager.shared
- @State private var isLoggingOut = false
- @State private var showLogoutConfirmation = false
- Uses .confirmationDialog() for destructive action
- Calls supabaseManager.signOut() in Task
- AuthenticationRootView auto-handles navigation when isAuthenticated = false
```

**Design Pattern:** Follows existing sheet patterns (InviteSheet, JoinEventSheet)

### Step 2.2: Add Settings Button to ContentView
**File:** `Momento/ContentView.swift`

**Changes:**

1. **Add state variable** (around line 73):
```swift
@State private var showSettings = false
```

2. **Add toolbar button** (after line 194 in toolbar):
```swift
ToolbarItem(placement: .topBarTrailing) {
    Button {
        showSettings = true
    } label: {
        Image(systemName: "gearshape.fill")
            .font(.system(size: 20, weight: .medium))
    }
    .tint(.white)
}
```

3. **Add sheet presentation** (after line 274, after existing .alert):
```swift
.sheet(isPresented: $showSettings) {
    SettingsView()
}
```

**Toolbar Layout After:**
- Left: QR code menu (Join Event, Clear Queue)
- Center: "Momentos" title
- Right: Settings gear + Plus button

---

## Part 3: Testing Checklist

### Apple Sign In Testing (Physical Device Required)
- [ ] Build and run on physical device
- [ ] Sign out if logged in
- [ ] Tap "Sign in with Apple" button
- [ ] Complete Apple ID authentication
- [ ] Verify successful login to ContentView

### Settings Screen Testing
- [ ] Open settings from toolbar gear icon
- [ ] Verify user email displays correctly
- [ ] Tap "Sign Out" button
- [ ] Confirm in dialog
- [ ] Verify loading spinner shows
- [ ] Verify auto-redirect to SignInView
- [ ] Sign back in to confirm flow works

### Error Scenarios
- [ ] Test logout in airplane mode (network error)
- [ ] Test rapid logout taps (should disable button)
- [ ] Dismiss settings without logging out

---

## Critical Files

### Files to Modify:
1. **`Momento/SignInView.swift`** - Remove `.opacity(0.5)` at line 90
2. **`Momento/SettingsView.swift`** - CREATE NEW FILE (complete settings screen)
3. **`Momento/ContentView.swift`** - Add state variable, toolbar button, sheet modifier

### Reference Files (No Changes):
4. **`Momento/Services/SupabaseManager.swift`** - Has `signOut()` method (lines 157-167)
5. **`Momento/AuthenticationRootView.swift`** - Auto-handles navigation on logout

---

## Implementation Order

1. **Enable Apple Sign In** → Modify SignInView.swift
2. **Create SettingsView** → New file with full implementation
3. **Integrate Settings** → Modify ContentView.swift
4. **Test on device** → Both features end-to-end

**Estimated Time:** 50 minutes total

---

## Notes

- **No manual navigation needed:** AuthenticationRootView automatically shows SignInView when `isAuthenticated = false`
- **Consistent design:** All UI matches existing dark gradient + royal purple theme
- **Future extensions:** Profile editing, account deletion, app settings can be added later
- **Apple Sign In limitation:** Only works on physical devices, not Simulator
