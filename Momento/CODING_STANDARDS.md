# Coding Standards

This document outlines the coding standards and best practices for the Momento project.

## Language & Framework

- **Swift and SwiftUI only**: Use Swift as the programming language and SwiftUI for UI development
- Avoid UIKit unless absolutely necessary for SwiftUI limitations
- Prefer native SwiftUI solutions over third-party alternatives

## Naming Conventions

- **Variables**: Use camelCase for all variables
  - ? `var eventTitle: String`
  - ? `var releaseDate: Date`
  - ? `var event_title: String`
  - ? `var ReleaseDate: Date`

- **Constants**: Use camelCase (prefer `let` over `var` for constants)
  - ? `let defaultEmoji = "??"`
  - ? `let maxEvents = 100`

- **Functions**: Use camelCase with descriptive names
  - ? `func saveNewEvent()`
  - ? `func deleteEvents(at offsets: IndexSet)`

- **Types**: Use PascalCase for structs, classes, and enums
  - ? `struct Event`
  - ? `class EventManager`
  - ? `enum EventStatus`

## Code Quality

### Clean & Elegant

- Write code that is **clean and elegant**, but **not complicated**
- Prioritize readability and simplicity over cleverness
- Prefer clear, explicit code over concise but obscure solutions
- Use meaningful variable and function names that self-document the code

### Examples

**Good:**
```swift
// Calculate time remaining until event release
func timeRemaining(until releaseDate: Date, from now: Date) -> TimeInterval {
    return releaseDate.timeIntervalSince(now)
}
```

**Bad:**
```swift
// Too clever and hard to understand
func tr(u: Date, f: Date) -> TimeInterval { u.timeIntervalSince(f) }
```

## Dependencies & Libraries

- **Avoid external libraries** unless they are deemed necessary
- Prefer native Swift/SwiftUI solutions
- When a library is necessary, document why it's needed
- Keep dependencies minimal and well-maintained

### When Libraries Are Acceptable

- Standard Apple frameworks (Foundation, SwiftUI, Combine, etc.)
- Libraries that solve complex problems impractical to implement ourselves
- Libraries that are essential for core functionality

## Code Comments

- **Comment code blocks** to explain complex logic or important functionality
- Use `// MARK:` comments to organize code sections
- Prefer self-documenting code over excessive comments
- Comments should explain "why" not "what"

### Comment Examples

**Good:**
```swift
// MARK: - State Management

/// Current time for countdown updates (updated by timer)
@State private var now: Date = .now

// MARK: - Actions

/// Deletes eventos at specified indices
/// - Parameter offsets: The indices of events to delete
private func deleteEvents(at offsets: IndexSet) {
    events.remove(atOffsets: offsets)
}
```

**Bad:**
```swift
// This is a variable
var now: Date = .now

// This function deletes events
func deleteEvents(at offsets: IndexSet) {
    events.remove(atOffsets: offsets) // Remove events
}
```

## Code Organization

- Use `// MARK:` comments to organize code into logical sections:
  - `// MARK: - State Management`
  - `// MARK: - Initialization`
  - `// MARK: - Actions`
  - `// MARK: - Body`
  - `// MARK: - Constants`

- Group related properties and methods together
- Keep views modular and reusable

## File Structure

- Follow the existing project structure
- Keep files focused on a single responsibility
- Use descriptive file names that match their contents

## Summary

1. ? Use Swift and SwiftUI only
2. ? Use camelCase for variables
3. ? Write clean, elegant, but simple code
4. ? Avoid libraries unless necessary
5. ? Comment code blocks appropriately

---

*Last updated: 2025*
