# Momento - Claude Code Guidelines

## Build & Testing

- **Never run xcodebuild, simulators, or automated builds.** The developer builds locally on a physical iPhone. Do not suggest or attempt simulator-based verification.

## File Organization

### Folder Structure
- `App/` - Entry point and root navigation (MomentoApp.swift, ContentView.swift)
- `Features/<FeatureName>/` - Feature-specific views organized by domain:
  - `Auth/` - Authentication and user setup
  - `Camera/` - Camera and photo capture (includes `Filters/` subfolder)
  - `Events/` - Event listing, creation, joining (includes `CreateMomento/` subfolder)
  - `Gallery/` - Photo galleries and browsing
  - `Profile/` - User profile and settings
  - `Reveal/` - Photo reveal experience
- `Services/` - All manager classes (*Manager.swift)
- `Models/` - Data models and utilities
- `Components/` - Reusable UI components
- `Config/` - Configuration files

### Adding New Files
When creating new Swift files:
1. Place the file in the appropriate folder on disk following the structure above
2. **Always update the Xcode project** by editing `Momento.xcodeproj/project.pbxproj`:
   - Add a PBXFileReference entry for the file
   - Add the file to the appropriate PBXGroup
   - Add the file to the PBXSourcesBuildPhase
3. New features get their own folder under `Features/`
4. Reusable UI goes in `Components/`, business logic in `Services/`
