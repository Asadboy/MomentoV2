# Manual Supabase Installation for Older Xcode

Since you have an older Xcode version, here are alternative installation methods:

## Option 1: Update Xcode (Recommended)

The easiest solution is to update Xcode to the latest version:
1. Open **App Store**
2. Search for **Xcode**
3. Click **Update** (if available)
4. After update, restart and try the package manager again

---

## Option 2: Use CocoaPods (If you have it)

### Step 1: Install CocoaPods (if not installed)
```bash
sudo gem install cocoapods
```

### Step 2: Create Podfile
I'll create this for you - just run these commands in Terminal:

```bash
cd /Users/asad/Documents/Momento
pod init
```

### Step 3: Edit Podfile
Open the Podfile and add:
```ruby
platform :ios, '15.0'
use_frameworks!

target 'Momento' do
  pod 'Supabase', '~> 2.0'
end
```

### Step 4: Install
```bash
pod install
```

### Step 5: Use .xcworkspace
From now on, open `Momento.xcworkspace` instead of `Momento.xcodeproj`

---

## Option 3: Manual Framework Installation (Works on Any Xcode)

This is more work but guaranteed to work:

### Step 1: Download Supabase SDK
1. Go to: https://github.com/supabase-community/supabase-swift/releases
2. Download the latest `.zip` file
3. Unzip it

### Step 2: Add to Xcode
1. In Xcode, right-click on Momento folder
2. Select "Add Files to Momento..."
3. Navigate to the unzipped Supabase folder
4. Select the `Sources` folder
5. Make sure "Copy items if needed" is checked
6. Click "Add"

---

## Option 4: Simple REST API (No SDK Required!)

Since Supabase is just a REST API, we can use it without any SDK at all!

I can build a lightweight wrapper using just URLSession. This would:
- Work on ANY Xcode version
- No dependencies needed
- Smaller app size
- Full control

Would you like me to do this instead? It's actually simpler and you don't need to install anything!

---

## Which Option Do You Prefer?

1. **Update Xcode** (best long-term)
2. **Use CocoaPods** (if you have it)
3. **Manual framework** (tedious but works)
4. **Build our own REST wrapper** (my recommendation! ✨)

Let me know and I'll help you set it up!

