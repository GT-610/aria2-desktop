# Aria2 Desktop Logging

This project uses `package:logging` for log levels and routes all log records
through `fl_lib`'s `DebugProvider`, keeping output and in-app inspection on the
same path.

## Architecture

- `lib/utils/logging.dart` is the single logging facade for app code.
- `initializeAppLogging()` configures `Logger.root.level` and the root record
  listener.
- The root listener forwards each `LogRecord` to `DebugProvider.addLog(record)`.
- The same listener writes formatted output through `Loggers.log(...)`.
- Errors and stack traces are emitted from the root listener, not ad hoc in
  feature code.

## Startup

Call `initializeAppLogging()` as early as possible in `main()` after
`WidgetsFlutterBinding.ensureInitialized()`.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeAppLogging();
  runApp(const MyApp());
}
```

## Usage

Use either a tagged logger or the `Loggable` mixin. Both map to real
`Logger/Level` records.

### Tagged logger

```dart
final logger = taggedLogger('RemoteInstanceStatusPage');

logger.i('Remote session saved');
logger.w('Fell back to cached value');
logger.e(
  'Failed to load remote status',
  error: e,
  stackTrace: stackTrace,
);
```

### `Loggable` mixin

```dart
class InstanceManager with ChangeNotifier, Loggable {
  Future<void> refresh() async {
    i('Refreshing instances');
  }
}
```

## Level Guidelines

- `i`: important lifecycle milestones, successful saves, successful connects,
  state transitions worth keeping in release logs
- `w`: recoverable failures, retries, fallbacks, skipped work, partial success
- `e`: operation failures, unexpected exceptions, paths that need
  troubleshooting

Keep messages contextual. Include the instance, task, or action being handled,
and pass `error` / `stackTrace` instead of manually appending duplicate error
text multiple times.

## Default policy

- App default: `Level.INFO`

This keeps output focused on actionable lifecycle, warning, and error signals.

## Do and Don't

- Do use `taggedLogger(...)` or `Loggable`.
- Do pass `error` and `stackTrace` for failures.
- Do choose the lowest level that matches the event severity.
- Don't call `debugPrint`, `dprint`, or `lprint` directly in business code.
- Don't log secrets such as RPC tokens, passwords, or private headers.
