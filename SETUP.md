# 10shots — Setup Guide

## Secrets / API Keys (Required)

The app reads API keys from `Secrets.xcconfig` via Info.plist. This file is **gitignored** and never committed.

### First-time setup:

1. The file `Momento/Config/Secrets.xcconfig` should already exist with your keys
2. If not, copy `Secrets.example.xcconfig` → `Secrets.xcconfig` and fill in your values

### Wire it up in Xcode (one-time):

1. Open `Momento.xcodeproj` in Xcode
2. Click the **Momento project** (blue icon, top of file navigator)
3. Go to the **Info** tab
4. Under **Configurations**, expand both **Debug** and **Release**
5. For each, click the dropdown next to the **Momento** target and select `Secrets`
6. Build and run — the keys flow: `Secrets.xcconfig` → Info.plist → Swift code

### How it works:

- `Secrets.xcconfig` defines build settings (SUPABASE_URL, SUPABASE_ANON_KEY, etc.)
- `Info.plist` references them via `$(SUPABASE_URL)` syntax
- `SupabaseConfig.swift` and `PostHogConfig.swift` read from `Bundle.main.infoDictionary`
- If keys are missing, Supabase will fatalError on launch; PostHog will silently disable

### For Xcode Cloud / CI:

Set the same keys as environment variables in your CI config. The xcconfig values
will be overridden by environment variables if present.
