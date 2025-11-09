## Camera Storage Rules

### Goals
- Capture photos with the system camera and save them immediately to the local caches directory.
- Keep the on-device experience “disposable”: photos stay hidden until explicit reveal or automatic release window.
- Record enough metadata (event ID, capture timestamp, captured-by placeholder) to map to future Supabase buckets.

### Storage Location
- Base path: `FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first`.
- Each event (Momento) gets a folder named `momento_<eventID>`.
- Photos are written as JPEG files named `<photoID>.jpg`.
- Metadata for future sync is serialized alongside each photo in `<photoID>.json` (same folder).

### Metadata Shape (JSON)
```json
{
  "photoID": "UUID string",
  "eventID": "UUID string",
  "capturedAt": "ISO8601 timestamp",
  "capturedBy": "reserved for future user identifier",
  "isRevealed": false
}
```

### Visibility Rules
- Newly captured photos default to `isRevealed: false`.
- UI in development uses a grey placeholder and requires an explicit reveal action to view the image.
- Future production flow will flip `isRevealed` once the event release window expires (24 hours by default).

### Haptics
- Trigger a light `UIImpactFeedbackGenerator(style: .medium)` when the shutter button fires to acknowledge capture without previewing the photo.

### Cleanup Policy
- Cached files are temporary; they can be purged by the system.
- On logout or completed upload, remove the corresponding event folder to avoid stale data.

### Future Supabase Alignment
- Bucket per event mirrors the `momento_<eventID>` convention.
- Metadata JSON maps one-to-one with storage objects for faster ingestion.
- Additional attributes (e.g. location, device) can extend the JSON without breaking the reader.

