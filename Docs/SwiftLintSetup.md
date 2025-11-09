# SwiftLint Setup for Momento

SwiftLint is a tool to enforce Swift style and conventions. It helps catch issues before they become problems and keeps code consistent.

## Installation

### Option 1: Using the installer (already downloaded)
```bash
cd /Users/asad/Documents/Momento
sudo installer -pkg /tmp/SwiftLint.pkg -target /
```

### Option 2: Using Homebrew (recommended for future)
```bash
brew install swiftlint
```

## Usage

### Run linting on the project
```bash
cd /Users/asad/Documents/Momento
./lint.sh
```

### Auto-fix issues
```bash
./lint.sh --fix
```

### Strict mode (warnings treated as errors)
```bash
./lint.sh --strict
```

## Xcode Integration

To run SwiftLint automatically on every build:

1. Open `Momento.xcodeproj` in Xcode
2. Select the **Momento** project in the navigator
3. Select the **Momento** target
4. Go to **Build Phases** tab
5. Click **+** → **New Run Script Phase**
6. Drag the new phase above "Compile Sources"
7. Paste this script:

```bash
if which swiftlint >/dev/null; then
  swiftlint --config "${SRCROOT}/.swiftlint.yml"
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
```

8. Name it "SwiftLint"

Now SwiftLint will run on every build and show warnings/errors in Xcode!

## Configuration

The `.swiftlint.yml` file contains all the rules. Current setup:

- **Line length**: 120 chars (warning), 150 (error)
- **File length**: 500 lines (warning), 1000 (error)
- **Function length**: 50 lines (warning), 100 (error)
- **Excludes**: Test files, build folders, Xcode project files

### Common Rules Enabled
- Force unwrapping warnings (avoid `!` where possible)
- Empty count (use `.isEmpty` instead of `.count == 0`)
- Sorted imports
- Vertical whitespace consistency

### Disabled Rules
- Trailing whitespace (can be annoying during dev)
- TODO comments (allowed for now)

## Cursor Integration

Cursor should automatically pick up SwiftLint warnings if:
1. SwiftLint is installed
2. The `.swiftlint.yml` config file exists (✅ already created)
3. You run `./lint.sh` to see issues

## Tips

- Run `./lint.sh --fix` before committing to auto-fix simple issues
- SwiftLint integrates with git hooks for pre-commit checks
- You can disable rules per-file with comments:
  ```swift
  // swiftlint:disable force_unwrapping
  let value = optional!
  // swiftlint:enable force_unwrapping
  ```

## Troubleshooting

**"swiftlint: command not found"**
- Run `./install_swiftlint.sh` or install via Homebrew

**Too many warnings**
- Adjust thresholds in `.swiftlint.yml`
- Disable specific rules you don't want

**Xcode not showing warnings**
- Make sure the Run Script Phase is added
- Clean build folder (`Cmd + Shift + K`) and rebuild

