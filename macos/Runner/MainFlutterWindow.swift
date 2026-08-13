import Cocoa
import FlutterMacOS
import IOKit.pwr_mgt

class MainFlutterWindow: NSWindow {
  private var powerAssertion: IOPMAssertionID = 0

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    FlutterMethodChannel(
      name: "setsuna/power_management",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { [weak self] call, result in
      guard call.method == "setPreventSleep",
            let arguments = call.arguments as? [String: Any],
            let enabled = arguments["enabled"] as? Bool else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.setPreventSleep(enabled, result: result)
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

  deinit {
    if powerAssertion != 0 {
      IOPMAssertionRelease(powerAssertion)
    }
  }
}
