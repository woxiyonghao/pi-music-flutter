import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // 发烧控制台默认尺寸 1024 x 600 (最小 960 x 540，对齐 C++ 原版)
    let initialSize = NSSize(width: 1024, height: 600)
    self.minSize = NSSize(width: 960, height: 540)
    self.setContentSize(initialSize)
    self.center()
    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
    self.title = "PiHifiPlayer - High Fidelity Music Player"
  }
}
