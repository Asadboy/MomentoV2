# Install Supabase Swift SDK - Step by Step

## The Right Way (Follow This!)

### Step 1: Open Package Dependencies
1. In Xcode, with Momento project open
2. Click **File** in the menu bar
3. Select **Add Package Dependencies...** (NOT "Add Package Collection"!)

### Step 2: Search for Supabase
1. In the search bar at the TOP RIGHT, paste:
   ```
   https://github.com/supabase-community/supabase-swift
   ```
2. Press **Enter** or click the magnifying glass icon
3. Wait a few seconds for it to load

### Step 3: Add the Package
1. You should see "supabase-swift" appear in the list
2. Make sure it's selected
3. Under "Dependency Rule", select **"Up to Next Major Version"**
4. Version should be **2.0.0** or higher
5. Click **Add Package** button (bottom right)

### Step 4: Select Libraries
On the next screen, you'll see a list of libraries. Check these boxes:
- ✅ **Supabase** (main library)
- ✅ **Auth** (authentication)
- ✅ **PostgREST** (database queries)
- ✅ **Storage** (file uploads)
- ✅ **Realtime** (live updates)

Then click **Add Package**

### Step 5: Wait for Installation
- Xcode will download and install the package
- You'll see progress in the top bar
- This might take 1-2 minutes

### Step 6: Verify Installation
1. In Xcode's left sidebar (Project Navigator)
2. Look for **"Package Dependencies"** section
3. You should see **"supabase-swift"** listed there
4. If you see it, you're done! ✅

---

## If You See Errors

### Error: "Received invalid response"
- This means you tried to add it as a "Package Collection" instead of a "Package Dependency"
- Close the dialog and follow Step 1 again carefully

### Error: "Failed to resolve package"
- Check your internet connection
- Try again in a few minutes
- Make sure the URL is correct: `https://github.com/supabase-community/supabase-swift`

### Error: "Package not found"
- Double-check the URL has no typos
- Make sure you're using HTTPS (not HTTP)

---

## Alternative: Manual Installation (If Above Doesn't Work)

### Option A: Download and Drag
1. Go to https://github.com/supabase-community/supabase-swift/releases
2. Download the latest release
3. Unzip it
4. Drag the `Supabase` folder into your Xcode project
5. Make sure "Copy items if needed" is checked

### Option B: Use Terminal (Advanced)
```bash
cd /Users/asad/Documents/Momento
# Add package via xcodebuild
xcodebuild -resolvePackageDependencies
```

---

## After Installation

Once installed, you should be able to:
1. Build the project (`Cmd + B`)
2. See no errors about "Module 'Supabase' not found"
3. The SupabaseManager.swift file should compile successfully

---

## Need Help?

If you're still stuck:
1. Take a screenshot of the error
2. Tell me exactly what step you're on
3. I'll help you troubleshoot!

The key thing: Use **"Add Package Dependencies"** NOT "Add Package Collection"!


