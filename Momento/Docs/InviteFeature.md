# Invite Feature

## Overview
Users can invite friends to events via long press on any event card or through the context menu.

## User Flow

### Accessing Invite Sheet
1. **Long Press** (0.5s) on any event card → Opens invite sheet with haptic feedback
2. **Context Menu** → "Invite Friends" option → Opens invite sheet

### Invite Sheet Contents
- **Event Header**: Title, member count, join code
- **QR Code**: Large, scannable QR code (placeholder for now)
- **Copy Link Button**: Copies invite link to clipboard with confirmation
- **Share Button**: Opens native share sheet (to be implemented)

## Current Implementation

### InviteSheet Component
```swift
InviteSheet(event: Event, onDismiss: () -> Void)
```

**Features:**
- Premium dark gradient background
- Large QR code display (220x220pt)
- Join code prominently displayed
- Copy link with success confirmation
- Haptic feedback on actions
- "Done" button to dismiss

### Invite Link Format
```
https://momento.app/join/{JOIN_CODE}
```

Currently generates placeholder links. Backend integration needed for:
- Real invite link generation
- Deep linking to app
- Join code validation

### QR Code
Currently shows placeholder QR icon. Needs implementation:
- Generate actual QR code from invite link
- Use CoreImage CIQRCodeGenerator
- Embed join code or invite link

## Interactions

### Copy Link Button
- Tap → Copies link to clipboard
- Shows "Link Copied!" confirmation for 2 seconds
- Success haptic feedback
- Button turns green temporarily

### Share Button
- Tap → Opens native share sheet (to be implemented)
- Medium impact haptic feedback
- Currently falls back to copy link

### Long Press on Card
- 0.5s hold duration
- Medium impact haptic feedback
- Works on all event states (countdown, live, revealed)
- Doesn't interfere with tap gesture

## Design Specifications

### Colors
- Background: Dark gradient (matching app)
- QR Code: White background, black code
- Primary Button: Royal purple
- Success State: Green
- Text: White with varying opacity

### Typography
- Event Title: 28pt, Bold
- Metadata: 14pt, Medium
- Join Code: 14pt, Bold, Monospaced
- Button Text: 17pt, Semibold

### Spacing
- Top padding: 32pt
- Section spacing: 32pt
- Button spacing: 16pt
- Horizontal padding: 24pt

### Shadows
- QR Code: Black 30%, radius 20, y-offset 10

## Future Enhancements

### Phase 1 (MVP)
- [ ] Generate real QR codes
- [ ] Implement native share sheet
- [ ] Backend invite link generation
- [ ] Deep linking support

### Phase 2
- [ ] Track who joined via invite
- [ ] Invite analytics (views, joins)
- [ ] Custom invite messages
- [ ] Social media share templates

### Phase 3
- [ ] Invite limits/permissions
- [ ] Invite expiration
- [ ] Private vs public events
- [ ] Invite-only events

## Technical Notes

### QR Code Generation
```swift
import CoreImage.CIFilterBuiltins

func generateQRCode(from string: String) -> UIImage {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(string.utf8)
    
    if let outputImage = filter.outputImage {
        if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgimg)
        }
    }
    return UIImage(systemName: "qrcode") ?? UIImage()
}
```

### Native Share Sheet
```swift
let activityVC = UIActivityViewController(
    activityItems: [inviteLink],
    applicationActivities: nil
)
// Present activityVC
```

### Deep Linking
```swift
// Info.plist
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>momento</string>
        </array>
    </dict>
</array>

// Handle URL
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first?.url {
        // Parse join code from URL
        // Navigate to join flow
    }
}
```

## Testing Checklist

- [ ] Long press opens invite sheet
- [ ] Context menu "Invite Friends" works
- [ ] Copy link button copies to clipboard
- [ ] "Link Copied!" confirmation shows
- [ ] Haptic feedback fires correctly
- [ ] Done button dismisses sheet
- [ ] Works on all event states
- [ ] QR code displays correctly
- [ ] Join code is readable
- [ ] Sheet dismisses properly

## Accessibility

- VoiceOver labels for all buttons
- Sufficient contrast for QR code
- Large touch targets (56pt height)
- Clear button labels
- Haptic feedback for blind users

