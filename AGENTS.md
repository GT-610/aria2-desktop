# AGENTS.md - Guidelines for Agentic Coding in Aria2 Desktop

## Build, Lint, and Test Commands

### Development
```bash
flutter run                    # Run in debug mode
flutter run -d <device-id>     # Run with specific device
flutter build                  # Build for current platform (debug)
flutter build windows --release # Build Windows release
```

### Analysis and Linting
```bash
flutter analyze                # Run Flutter analyzer (recommended before committing)
flutter analyze --fix         # Fix auto-fixable issues
flutter analyze --fatal-infos --fatal-warnings  # Stricter rules
```

### Testing
```bash
flutter test                   # Run all tests
flutter test test/aria2_rpc_client.dart  # Run single test file
flutter test --name "testName" # Run specific test by name
flutter test --reporter expanded  # Verbose output
flutter test --coverage        # Run with code coverage
```

### Other Commands
```bash
flutter pub get        # Get dependencies
flutter pub upgrade   # Update dependencies
flutter format .      # Format code
```

---

## Code Style Guidelines

### 1. Imports
**Order**: dart: → package:flutter/ → package: → relative paths
```dart
// Good
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/aria2_instance.dart';
import '../../services/aria2_rpc_client.dart';
```

### 2. Formatting
- Use `flutter format .` automatically
- Max line length: 80 characters
- Use trailing commas
```dart
// Good
return Column(
  children: [
    ItemWidget(),
    ItemWidget(),
  ],
);
```

### 3. Types
- Use strong typing - avoid `dynamic`
- Use `final` by default, `var` only when reassignment needed
```dart
final List<DownloadTask> tasks = [];
void addTask(DownloadTask task) { ... }
```

### 4. Naming Conventions
- Classes/Types: PascalCase (`class DownloadTask`, `enum DownloadStatus`)
- Functions/Variables: camelCase (`addTask()`, `downloadSpeed`)
- Files: snake_case (`download_task.dart`)
- Constants: SCREAMING_SNAKE_CASE for compile-time (`const DefaultPort = 6800`)

### 5. Error Handling
- Use specific exception types
- Handle errors with try-catch, never silently swallow
```dart
try {
  await client.connect();
} on ConnectionFailedException catch (e) {
  log.e('Connection failed: ${e.message}');
  rethrow;
} catch (e) {
  log.e('Unexpected error: $e');
}
```

### 6. Async Code
- Use `async/await` over raw Futures
- Handle async errors with try-catch

### 7. Widgets and UI
- Extract widgets for reusability (>20 lines or repeated 2+ times)
- Use `const` constructors where possible
- Keep `build()` methods clean - delegate to helper methods

### 8. Providers and State Management
- Use `Provider` for dependency injection and state
- Use `Consumer` or `context.watch` for reactive UI

### 9. Logging
- Use project's logging system (`lib/utils/logging.dart`)
- Log levels: `log.d()`, `log.i()`, `log.w()`, `log.e()`
- Don't log sensitive data (passwords, secrets)

### 10. General Best Practices
- **DRY** - Don't Repeat Yourself
- **YAGNI** - Avoid over-engineering
- **Single Responsibility** - each class/method does one thing
- **Keep files small** - typically <200 lines per file
- **Write tests** for critical logic (RPC client, services)

---

## Unimplemented Features (for reference)

When working on this codebase, consider these features that are not yet implemented:
- System tray integration (has settings but no functionality)
- Applying settings to Aria2 via RPC
- Download notifications
- Batch task selection
- Task search/sort
- Full task details with file list

See `.trae/references/` for AriaNg and Motrix reference implementations.

---

## Quick Reference
| Task | Command |
|------|---------|
| Run app | `flutter run` |
| Analyze | `flutter analyze` |
| Format | `flutter format .` |
| Test one file | `flutter test test/file.dart` |
| Build Windows | `flutter build windows --release` |

## Additional Notes

- Reference AriaNg in `.trae/references/AriaNg` for UI patterns and Aria2 options
- Reference Motrix in `.trae/references/Motrix` for system tray and process management
- Aria2 RPC documentation available in `.trae/references/aria2c-docs.rst`