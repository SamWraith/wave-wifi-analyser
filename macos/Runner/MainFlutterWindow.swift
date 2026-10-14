import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var wifiBridge: WifiBridge?
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    wifiBridge = WifiBridge(messenger: flutterViewController.engine.binaryMessenger)
    minSize = NSSize(width: 420, height: 560)

    super.awakeFromNib()
  }
}
