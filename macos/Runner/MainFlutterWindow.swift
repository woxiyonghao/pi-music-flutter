import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var telemetryChannel: FlutterMethodChannel?
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // 发烧控制台默认尺寸 1024 x 600 (最小 960 x 540，对齐 C++ 原版)
    let initialSize = NSSize(width: 1024, height: 600)
    self.minSize = NSSize(width: 960, height: 540)
    self.setContentSize(initialSize)
    self.center()
    RegisterGeneratedPlugins(registry: flutterViewController)

    let telemetry = MacSystemTelemetry()
    let telemetryQueue = DispatchQueue(label: "pihifi.macos.telemetry", qos: .utility)
    telemetryChannel = FlutterMethodChannel(name: "pihifi/macos_system",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    telemetryChannel?.setMethodCallHandler { call, result in
      guard call.method == "snapshot" else {
        result(FlutterMethodNotImplemented)
        return
      }
      telemetryQueue.async {
        let snapshot = telemetry.snapshot()
        DispatchQueue.main.async { result(snapshot) }
      }
    }

    super.awakeFromNib()
    self.title = "PiHifiPlayer - High Fidelity Music Player"
  }
}
