# Aria2 Desktop

A cross-platform desktop Aria2 download manager built with Flutter, providing a user-friendly interface to manage Aria2 download instances and tasks.

## Features

- **Instance Management**
  - Add, edit, and delete Aria2 instances (both local and remote)
  - Connect/disconnect from instances
  - Automatic connection to last used instance
  - Status monitoring for all instances

- **Download Management**
  - Task list display with filtering options
  - Task operations: add, delete, pause, resume
  - Task details viewing
  - Download speed control

- **Configuration**
  - Global settings management
  - Instance-specific configurations
  - Settings persistence

## Supported Platforms

- Windows
- macOS
- Linux

## Technical Stack

- **Frontend**: Flutter
- **State Management**: Provider
- **Network**: Dio, WebSocket Channel
- **Local Storage**: Shared Preferences, Path Provider
- **Process Management**: Process Run
- **UI Components**: Material Design

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version recommended)
- Dart SDK (compatible with your Flutter version)
- For Windows: Visual Studio with C++ workload
- For macOS: Xcode
- For Linux: build-essential, cmake, ninja-build

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/aria2-desktop.git
   cd aria2-desktop
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the application:
   ```bash
   # For Windows
   flutter run -d windows
   
   # For macOS
   flutter run -d macos
   
   # For Linux
   flutter run -d linux
   ```

## Usage

### Managing Instances

1. Go to the "Instances" page
2. Click the "+" button to add a new instance
3. Configure the instance settings:
   - Name: A descriptive name for the instance
   - Type: Local or Remote
   - Protocol: HTTP, HTTPS, WS, or WSS
   - Host: The hostname or IP address
   - Port: The port number
   - Secret: RPC secret (if configured)
   - For local instances: Path to Aria2 executable
4. Save the instance
5. Click on an instance to connect to it

### Managing Downloads

1. Connect to an Aria2 instance
2. Go to the "Downloads" page
3. Use the "+" button to add new download tasks
4. Use the controls to pause, resume, or remove tasks
5. Click on a task to view detailed information

### Settings

1. Go to the "Settings" page
2. Enable/disable auto-connection to last used instance
3. Configure other global settings

## Development

### Project Structure

```
lib/
├── app.dart          # Main application widget
├── components/       # Reusable UI components
├── main.dart         # Entry point
├── managers/         # Business logic managers
├── models/           # Data models
├── pages/            # UI pages
└── services/         # Services (RPC client, etc.)
```

### Key Models

- `Aria2Instance`: Represents an Aria2 instance configuration
- `Settings`: Global application settings
- `GlobalStat`: Global download statistics

## License

[GPLv3](LICENSE)

## Acknowledgements

- [Aria2](https://aria2.github.io/) - The powerful command-line download utility
- [Flutter](https://flutter.dev/) - Cross-platform UI toolkit
