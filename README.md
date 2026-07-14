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

### Reproducible Windows release

Use the checked-in PowerShell build helper instead of reusing an existing
`build/` directory:

```powershell
.\tool\build_windows_release.ps1 -BuildName 1.0.0 -BuildNumber 0
```

The script downloads the pinned aria2 1.37.0 Windows binary, verifies its
SHA-256 checksum, performs a clean Windows build, and injects only `aria2c.exe`
and `aria2.conf`. Runtime settings, logs, and session files are rejected from
release artifacts.

### Application data and credentials

- Configuration, session state, and logs use the platform application support
  directory rather than the executable directory.
- Existing portable `data/` directories are copied on first launch. The source
  directory is retained as a recovery backup and migration is safe to retry.
- RPC secrets and custom RPC headers are stored with
  `flutter_secure_storage` (Windows Credential protection, macOS Keychain, and
  Linux Secret Service). They are removed from JSON after verified migration.
- If secure storage is unavailable, Setsuna keeps legacy data intact and
  refuses to rewrite credentials as plaintext.

Linux development requires `libsecret-1-dev`; packaged applications require
`libsecret-1-0` and an available Secret Service provider such as GNOME Keyring
or KWallet.

```bash
sudo apt-get install libsecret-1-dev libsecret-1-0 gnome-keyring
```

The built-in aria2 binary is currently bundled only by the Windows release
pipeline. macOS and Linux builds continue to support remote aria2 instances
and report a clear remote-only message when no platform core is packaged.

### Runtime architecture

- Repository classes own schema-versioned, atomic JSON persistence.
- RPC clients connect lazily, apply custom headers to HTTP and WebSocket
  transports, and never automatically replay a non-idempotent request after it
  may have been sent.
- Download polling is application-scoped. A failed instance retains its last
  successful task snapshot as stale data without clearing healthy instances.

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
