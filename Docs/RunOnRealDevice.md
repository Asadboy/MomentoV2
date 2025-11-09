# Running Momento on Your Real iPhone

## Quick Setup

### 1. Connect Your iPhone
- Plug your iPhone into your Mac via USB cable
- Unlock your iPhone
- If prompted "Trust This Computer?" → tap **Trust**

### 2. Select Your Device in Xcode
- Open `Momento.xcodeproj` in Xcode
- At the top toolbar, click the device dropdown (currently says "iPhone 15 Pro" or similar)
- Select your actual iPhone from the list (it'll show your device name)

### 3. Configure Signing (First Time Only)
- Click on the **Momento** project in the left sidebar (blue icon)
- Select the **Momento** target
- Go to **Signing & Capabilities** tab
- Under "Team", select your Apple ID (or click "Add Account" if needed)
  - You can use a free Apple ID - no paid developer account needed for personal testing
- Xcode will automatically handle the signing certificate

### 4. Build and Run
- Press `Cmd + R` or click the Play button
- First time: Your iPhone will show "Untrusted Developer" warning
  - Go to iPhone Settings → General → VPN & Device Management
  - Tap your Apple ID email
  - Tap "Trust [Your Email]"
  - Go back to Xcode and press `Cmd + R` again

### 5. Test!
- The app will launch on your real iPhone
- Camera will work with your actual camera
- Much faster performance than simulator
- Photos save to the device's cache

## Benefits of Real Device Testing
✅ **Real camera** - test actual photo capture  
✅ **Better performance** - no lag  
✅ **Accurate testing** - real-world conditions  
✅ **Haptic feedback** - feel the actual vibration on capture  
✅ **True UI/UX** - see how it really looks and feels  

## Troubleshooting

**"Failed to prepare device for development"**
- Unplug and replug your iPhone
- Make sure iPhone is unlocked
- Restart Xcode

**"Signing for Momento requires a development team"**
- Add your Apple ID in Xcode → Preferences → Accounts
- Select it in Signing & Capabilities

**App won't launch / crashes immediately**
- Check iPhone Settings → General → VPN & Device Management
- Trust your developer certificate

## Hot Reload / Quick Iteration
- Keep your iPhone plugged in
- Make code changes in Xcode
- Press `Cmd + R` to rebuild and deploy
- App updates in ~10-30 seconds (much faster than simulator!)

