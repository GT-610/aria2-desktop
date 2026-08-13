import Cocoa
import FlutterMacOS
import IOKit.pwr_mgt

class MainFlutterWindow: NSWindow {
  private var powerAssertion: IOPMAssertionID = 0
  private var dockProgressIndicator: NSProgressIndicator?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    FlutterMethodChannel(
      name: "setsuna/power_management",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { [weak self] call, result in
      guard call.method == "setPreventSleep" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let enabled = arguments["enabled"] as? Bool else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Expected an enabled boolean.",
            details: nil
          )
        )
        return
      }
      guard let self else {
        result(
          FlutterError(
            code: "window_unavailable",
            message: "The application window is unavailable.",
            details: nil
          )
        )
        return
      }
      self.setPreventSleep(enabled, result: result)
    }

    FlutterMethodChannel(
      name: "setsuna/desktop_progress",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { [weak self] call, result in
      guard call.method == "setProgress" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let progressValue = arguments["progress"] as? NSNumber else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Expected a progress number.",
            details: nil
          )
        )
        return
      }
      guard let self else {
        result(
          FlutterError(
            code: "window_unavailable",
            message: "The application window is unavailable.",
            details: nil
          )
        )
        return
      }
      self.setDesktopProgress(progressValue.doubleValue)
      result(nil)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  private func setPreventSleep(_ enabled: Bool, result: FlutterResult) {
    if enabled && powerAssertion == 0 {
      let status = IOPMAssertionCreateWithName(
        kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
        IOPMAssertionLevel(kIOPMAssertionLevelOn),
        "Active downloads in Setsuna" as CFString,
        &powerAssertion
      )
      if status != kIOReturnSuccess {
        powerAssertion = 0
        result(
          FlutterError(
            code: "power_request_failed",
            message: "Failed to create a macOS power assertion.",
            details: status
          )
        )
        return
      }
    } else if !enabled && powerAssertion != 0 {
      IOPMAssertionRelease(powerAssertion)
      powerAssertion = 0
    }
    result(nil)
  }

  private func setDesktopProgress(_ progress: Double) {
    let dockTile = NSApp.dockTile
    if progress < 0 {
      dockProgressIndicator?.isHidden = true
      dockProgressIndicator?.stopAnimation(nil)
      dockTile.display()
      return
    }

    let indicator: NSProgressIndicator
    if let existingIndicator = dockProgressIndicator {
      indicator = existingIndicator
    } else {
      let imageView = NSImageView()
      imageView.image = NSApp.applicationIconImage
      dockTile.contentView = imageView
      indicator = NSProgressIndicator(
        frame: NSRect(x: 0, y: 0, width: dockTile.size.width, height: 15)
      )
      indicator.style = .bar
      indicator.minValue = 0
      indicator.maxValue = 1
      imageView.addSubview(indicator)
      dockProgressIndicator = indicator
    }

    indicator.isHidden = false
    if progress > 1 {
      indicator.isIndeterminate = true
      indicator.startAnimation(nil)
    } else {
      indicator.stopAnimation(nil)
      indicator.isIndeterminate = false
      indicator.doubleValue = min(max(progress, 0), 1)
    }
    dockTile.display()
  }

  deinit {
    if powerAssertion != 0 {
      IOPMAssertionRelease(powerAssertion)
    }
  }
}
