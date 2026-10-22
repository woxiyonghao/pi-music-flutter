import Cocoa
import FlutterMacOS
import CoreAudio

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
      switch call.method {
      case "snapshot":
        telemetryQueue.async {
          let snapshot = telemetry.snapshot()
          DispatchQueue.main.async { result(snapshot) }
        }
      case "setSampleRate":
        guard let args = call.arguments as? [String: Any],
              let targetRate = args["sampleRate"] as? Double else {
          result(FlutterError(code: "INVALID_ARGS", message: "sampleRate required", details: nil))
          return
        }
        telemetryQueue.async {
          var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
          )
          var defaultDeviceID = AudioDeviceID(kAudioObjectUnknown)
          var size = UInt32(MemoryLayout<AudioDeviceID>.size)
          let getStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            0,
            nil,
            &size,
            &defaultDeviceID
          )
          guard getStatus == noErr, defaultDeviceID != kAudioObjectUnknown else {
            DispatchQueue.main.async { result(false) }
            return
          }

          var rateAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
          )
          var newRate: Float64 = targetRate
          let setStatus = AudioObjectSetPropertyData(
            defaultDeviceID,
            &rateAddress,
            0,
            nil,
            UInt32(MemoryLayout<Float64>.size),
            &newRate
          )
          DispatchQueue.main.async { result(setStatus == noErr) }
        }
      case "getAudioDeviceInfo":
        telemetryQueue.async {
          var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
          )
          var defaultDeviceID = AudioDeviceID(kAudioObjectUnknown)
          var size = UInt32(MemoryLayout<AudioDeviceID>.size)
          let getStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            0,
            nil,
            &size,
            &defaultDeviceID
          )
          guard getStatus == noErr, defaultDeviceID != kAudioObjectUnknown else {
            DispatchQueue.main.async {
              result([
                "name": "",
                "manufacturer": "",
                "isToppingDx1ii": false,
                "currentSampleRate": 0.0
              ])
            }
            return
          }

          var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
          )
          var deviceName: CFString = "" as CFString
          var nameSize = UInt32(MemoryLayout<CFString>.size)
          let nameStatus = AudioObjectGetPropertyData(
            defaultDeviceID,
            &nameAddress,
            0,
            nil,
            &nameSize,
            &deviceName
          )

          var mfgAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceManufacturer,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
          )
          var mfgName: CFString = "" as CFString
          var mfgSize = UInt32(MemoryLayout<CFString>.size)
          let mfgStatus = AudioObjectGetPropertyData(
            defaultDeviceID,
            &mfgAddress,
            0,
            nil,
            &mfgSize,
            &mfgName
          )

          var rateAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
          )
          var currentRate: Float64 = 0.0
          var rateSize = UInt32(MemoryLayout<Float64>.size)
          let _ = AudioObjectGetPropertyData(
            defaultDeviceID,
            &rateAddress,
            0,
            nil,
            &rateSize,
            &currentRate
          )

          let nameStr = (nameStatus == noErr) ? (deviceName as String) : ""
          let mfgStr = (mfgStatus == noErr) ? (mfgName as String) : ""
          let isTopping = nameStr.localizedCaseInsensitiveContains("DX1") ||
                          nameStr.localizedCaseInsensitiveContains("TOPPING") ||
                          mfgStr.localizedCaseInsensitiveContains("TOPPING")

          DispatchQueue.main.async {
            result([
              "name": nameStr,
              "manufacturer": mfgStr,
              "isToppingDx1ii": isTopping,
              "currentSampleRate": Double(currentRate)
            ])
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
    self.title = "PiHifiPlayer - High Fidelity Music Player"
  }
}
