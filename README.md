# Setsuna

Setsuna is a Flutter desktop client for aria2 that combines:

- built-in aria2 management for local daily use
- remote aria2 connection profiles and task management
- desktop-focused integrations such as tray, notifications, protocol handling, UPnP/NAT-PMP, and run-at-startup

The current product goal is to cover the day-to-day workflow of a Motrix-style desktop downloader while also providing AriaNg-style remote aria2 management in a single app.

## Current Capabilities

### Built-in instance

- Managed built-in aria2 instance with start, reconnect, and settings application
- Hardened engine lifecycle: proxy environment stripping (host proxies never
  leak into downloads), SOCKS rejection for `--all-proxy`, and automatic RPC
  port-conflict recovery with persistence and a user-visible notice
- `--detach-share-only` on Aria2 Next engines so seeding tasks do not consume
  concurrent-download slots
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
- Optional magnet metadata-only flow: stage magnets with `pause-metadata`,
  pick files once the torrent metadata arrives, and resume; canceling removes
  the staged task entirely
- Pause, resume, retry (with rollback on partial re-submission), remove, open
  folder, and batch task actions across instances
- Task details dialog with Overview / Pieces / Files / Options / Trackers /
  Peers tabs: piece-map visualization, BT swarm health estimation, peer client
  identification with per-peer piece bars, copy-magnet-link action, and live
  per-task option editing (`getOption`/`changeOption`) gated by aria2 status
  rules
- IDM-style file-category routing: extension-based subdirectory rules applied
  to URI tasks at add time
- BT seeding detection aligned with aria2 task semantics

### Speed control

- Status-bar speed capsule: tap to toggle limits, long-press for a quick
  up/down limit editor
- Global speed-limit settings card with an optional weekday + time-window
  schedule (overnight windows supported); the scheduler passively pushes or
  releases `max-overall-*-limit` without ever mutating user-configured values
- Per-task download/upload limits through the details dialog options tab

### Automation

- Shut down after downloads complete, with a cancellable 60-second countdown;
  new activity cancels it automatically (seeding does not block shutdown)
- Clipboard monitoring for http(s)/ftp/magnet/thunder links with self-copy
  suppression and size guards; detected links open the add-task dialog
  prefilled
- Daily background update check against GitHub Releases plus a manual check in
  maintenance settings

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

### Reproducible desktop releases

Release builds download the platform-specific Aria2 Next binary described in
`tool/aria2_next_release.json`, verify its SHA-256 checksum, and run a process
and JSON-RPC smoke test before packaging it with Setsuna. The engine license and
exact source link are included beside the binary.

Use the checked-in helpers instead of reusing an existing `build/` directory.
On Windows:

```powershell
.\tool\build_windows_release.ps1 -BuildName 1.0.0 -BuildNumber 0
```

On macOS for local package validation:

```bash
MACOS_AD_HOC_SIGNING=true \
  tool/package_macos_release.sh macos-arm64 1.0.0 0 local arm64 dist
```

On Linux x64:

```bash
tool/package_linux_release.sh \
  linux-x64 linux-x64 x64 amd64 1.0.0 0 local x64 dist
```

On Linux ARM64:

```bash
tool/package_linux_release.sh \
  linux-arm64 linux-arm64 arm64 arm64 1.0.0 0 local arm64 dist
```

Runtime settings, logs, and session files are rejected from every release
artifact. GitHub Actions publishes a Windows x64 ZIP, Apple Silicon and Intel
macOS DMGs, and Linux x64/ARM64 tarballs and Debian packages.

Published macOS packages require these GitHub Actions secrets:
`MACOS_CERTIFICATE_BASE64`, `MACOS_CERTIFICATE_PASSWORD`,
`MACOS_SIGNING_IDENTITY`, `MACOS_NOTARY_APPLE_ID`, `MACOS_NOTARY_TEAM_ID`, and
`MACOS_NOTARY_PASSWORD`. The certificate must be a base64-encoded Developer ID
Application PKCS #12 file, and the notarization password must be an app-specific
password.

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

The built-in engine is Aria2 Next, launched as a separate process and managed
through the aria2-compatible JSON-RPC interface. Windows, macOS, and Linux
release packages all include the matching platform binary. Development builds
without a packaged core continue to support remote aria2 instances.

### Runtime architecture

- Repository classes own schema-versioned, atomic JSON persistence.
- RPC clients connect lazily, apply custom headers to HTTP and WebSocket
  transports, and never automatically replay a non-idempotent request after it
  may have been sent.
- Download polling is application-scoped. A failed instance retains its last
  successful task snapshot as stale data without clearing healthy instances.
- Polling uses an AriaNg-style two-phase refresh: cheap basic-field
  projections every tick, with a full `files`/`bittorrent` re-fetch only when
  the projected snapshot actually changed. `aria2.getGlobalStat` rides the
  same multicall and feeds the status bar and tray speeds.

## Roadmap

Deferred for now, in rough priority order:

- ED2K support surface (the bundled Aria2 Next engine can provide it; needs
  dedicated RPC/UI design)
- Local HTTP API for browser-extension integration
- A lightweight/headless mode that keeps downloads running with the window
  closed

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

- [Aria2 Next](https://github.com/AnInsomniacy/aria2-next)
- [aria2](https://aria2.github.io/)
- [Flutter](https://flutter.dev/)
