# App Store Screenshots

Brand title-card PNGs at the iPhone App Store screenshot sizes. These are the "marketing" / "title slide" assets — typically used as the first screenshot in the App Store listing. Actual app-UI screenshots (create flow, live event, reveal, gallery) get captured from device later and dropped alongside.

## Files

| File | Use |
|---|---|
| `title-6.9-inch.png` | Roll mark only · 1320 × 2868 (iPhone 16/17 Pro Max class) |
| `title-tagline-6.9-inch.png` | Roll mark + tagline · 1320 × 2868 |
| `title-6.7-inch.png` | Roll mark only · 1290 × 2796 (iPhone 15/16 Plus, 14/15/16 Pro Max) |
| `title-tagline-6.7-inch.png` | Roll mark + tagline · 1290 × 2796 |

Apple currently requires one of 6.9" or 6.7"; submitting both is standard. Older sizes (6.5", 5.5") aren't included — they're not required for new submissions and clutter the listing.

## Regenerating

```bash
swift "Docs/launch/App Store Screenshots/generate.swift"
```

The generator reads no inputs — sizes and spec are hard-coded. If the brand wordmark spec in `Momento/Components/BrandWordmark.swift` changes (text size ratio, dot ratio, tracking, spacing), mirror the change in `generate.swift` so the screenshots stay in sync.

## Spec parity with `BrandWordmark`

Both the in-app component and these renders use the same proportional sizing rules. From a single `size` (text point size):

- Text: bold sans, tracking `-0.04 × size`
- Dot row: 10 white circles, diameter `0.17 × size`, gap `0.14 × size`
- Spacing between text and dot row: `0.28 × size`
- Tagline (renders only): `0.20 × size`, gap `0.55 × size` below the lockup
