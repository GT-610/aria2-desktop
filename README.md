# Setsuna

Setsuna is a Flutter desktop client for aria2 that combines:

- built-in aria2 management for local daily use
- remote aria2 connection profiles and task management
- desktop-focused integrations such as tray, notifications, protocol handling, UPnP/NAT-PMP, and run-at-startup

The current product goal is to cover the day-to-day workflow of a Motrix-style desktop downloader while also providing AriaNg-style remote aria2 management in a single app.

## Current Capabilities

### Built-in instance

- Managed built-in aria2 instance with start, reconnect, and settings application
- Built-in aria2 settings page with desktop-oriented options
- Session reset tool for built-in aria2 recovery
- BT and seeding support, including seeding-aware task state handling
- UPnP / NAT-PMP integration for built-in aria2

### Remote instances

- Saved remote RPC profiles with protocol, host, port, secret, RPC path, and custom RPC headers
- Remote aria2 global settings page for common transfer, BT, network, and proxy options
- Remote status and maintenance page with runtime summary, save session, and stopped-record cleanup
- Unified download list and task operations across connected built-in and remote instances

### Download workflow

- Add tasks through URI, Torrent, and Metalink
- Pause, resume, retry, remove, open folder, and batch task actions
- Task details dialog with files, peers, trackers, pieces, and BT-specific overview data
- BT seeding detection aligned with aria2 task semantics

### Desktop shell

- System tray integration
- Desktop notifications
- Protocol handling for supported external download links
- Run-at-startup integration
- Optional custom title bar and window behavior controls

## Supported Platforms

- Windows
- macOS
- Linux

Desktop integration quality is currently strongest on Windows, which is the primary development target.

## Development

### Prerequisites

- Flutter SDK compatible with this repository
- Dart SDK compatible with the installed Flutter SDK
- Platform toolchain for your target desktop OS

### Common commands

```bash
flutter pub get
flutter run -d windows
flutter analyze
flutter test
flutter build windows --release
```

### Project structure

```text
lib/
  app.dart
  constants/
  generated/
  l10n/
  models/
  pages/
  services/
  utils/
test/
```

## Notes

- Built-in instance management remains the primary product path.
- Remote instance management is designed as a desktop companion workflow, not a browser-style frontend clone.

## License

[GPLv3](LICENSE)

## Acknowledgements

- [aria2](https://aria2.github.io/)
- [Flutter](https://flutter.dev/)
