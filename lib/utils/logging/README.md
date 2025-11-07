# Aria2 Desktop Logging System

> **NOTE: This is a developer-facing document.** End users do not need to be concerned with this information.

## Overview

This logging system is built on top of the [logger](https://pub.dev/packages/logger) package, providing a unified logging functionality for the entire application. It supports easy integration across different pages and components, helping developers track application behavior, debug issues, and monitor performance.

## Core Components

1. **LogConfig** - Centralized configuration class for all logging-related settings
2. **LogManager** - Singleton log manager responsible for creating and managing Logger instances
3. **AppLogger** - Log extension class providing tag-based logging methods
4. **Loggable** - Mixin for easy logging integration in pages or components

## Usage

### 1. Direct Usage with LogManager

```dart
import 'package:aria2_desktop/utils/logging/log_manager.dart';

// Usage in code
LogManager().logger.d('Debug message');
LogManager().logger.e('Error occurred', error: e, stackTrace: stackTrace);
```

### 2. Using AppLogger (Recommended)

```dart
import 'package:aria2_desktop/utils/logging/log_extensions.dart';

class MyClass {
  final AppLogger logger = AppLogger('MyClass');
  
  void doSomething() {
    logger.d('Starting operation');
    try {
      // Business logic
      logger.i('Operation completed successfully');
    } catch (e, stackTrace) {
      logger.e('Operation failed', error: e, stackTrace: stackTrace);
    }
  }
}
```

### 3. Using Loggable Mixin

```dart
import 'package:aria2_desktop/utils/logging/log_extensions.dart';

class MyPage extends StatefulWidget with Loggable {
  @override
  void initState() {
    super.initState();
    initLogger(); // Initialize logger
    logger.i('Page initialized');
  }
  
  void loadData() {
    logger.d('Starting data loading');
    // Data loading logic
  }
}
```

## Log Levels

The system supports the following log levels (from lowest to highest):

- **verbose (t)** - Most detailed log information
- **debug (d)** - Debug information, used during development
- **info (i)** - General information logs
- **warning (w)** - Warning messages
- **error (e)** - Error messages
- **fatal (f)** - Critical error messages

## Configuration

You can modify the default logging configuration in `log_config.dart`, including log levels, output formats, and more.

```dart
// Modify default log level
LogManager().setLogLevel(Level.info);

// Reset logger (apply new configuration)
LogManager().resetLogger();
```

## Best Practices

1. In production builds, set a higher log level (e.g., warning or error) to reduce log volume
2. Avoid logging sensitive information such as passwords or personal data
3. For large objects, consider implementing a custom `toString()` method to optimize log output
4. Use appropriate log levels to filter logs effectively during debugging
5. Include contextual information in logs to make debugging easier