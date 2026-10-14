import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // 发烧控制台默认尺寸 1200 x 750 (最小 1024 x 600，保证横屏 HiFi 视觉比例)
    let initialSize = NSSize(width: 1200, height: 750)
    self.minSize = NSSize(width: 1024, height: 600)
    self.setContentSize(initialSize)
    self.center()
    self.title = "HiFi Master Audio Console"

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
