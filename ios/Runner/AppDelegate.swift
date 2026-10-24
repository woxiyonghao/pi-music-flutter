import Flutter
import UIKit
import AVFoundation
import Darwin

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var audioChannel: FlutterMethodChannel?
    private var routeObserver: NSObjectProtocol?
    private var systemChannel: FlutterMethodChannel?

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HifiPlatformAudio") else { return }
        let channel = FlutterMethodChannel(name: "hifi/platform_audio", binaryMessenger: registrar.messenger())
        audioChannel = channel
        let system = FlutterMethodChannel(name: "hifi/system", binaryMessenger: registrar.messenger())
        systemChannel = system
        system.setMethodCallHandler { [weak self] call, result in
            guard call.method == "getSystemInfo" else {
                result(FlutterMethodNotImplemented); return
            }
            result(self?.systemInfo() ?? [:])
        }
        // Mechanism only: category, activation and interruptions belong to Dart/audio_session.
        channel.setMethodCallHandler { [weak self] call, result in
            let session = AVAudioSession.sharedInstance()
            switch call.method {
            case "getOutputFormat":
                let output = session.currentRoute.outputs.first
                let port = output?.portType
                let transport: String
                if port == .bluetoothA2DP || port == .bluetoothHFP || port == .bluetoothLE {
                    transport = "Bluetooth"
                } else if port == .usbAudio { transport = "USB" }
                else if port == .builtInSpeaker || port == .builtInReceiver || port == .headphones { transport = "BuiltIn" }
                else { transport = port?.rawValue ?? "System" }
                result(["sampleRate": Int(session.sampleRate.rounded()),
                        "channels": session.outputNumberOfChannels, "bufferDuration": session.ioBufferDuration,
                        "id": output?.uid ?? "", "name": output?.portName ?? "", "transport": transport])
            case "setPreferredSampleRate":
                let arguments = call.arguments as? [String: Any]
                guard let rate = arguments?["sampleRate"] as? NSNumber,
                      let routeID = arguments?["routeId"] as? String,
                      let output = session.currentRoute.outputs.first,
                      output.portType == .usbAudio, output.uid == routeID else {
                    result(FlutterError(code: "route_changed", message: "USB output changed", details: nil)); return
                }
                let name = output.portName.precomposedStringWithCompatibilityMapping.uppercased()
                    .replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
                let sampleRate = rate.doubleValue
                guard name.contains("DX1II"), sampleRate.isFinite,
                      (8000...384000).contains(sampleRate) else {
                    result(FlutterError(code: "unsupported_rate", message: "Unsupported DX1 II PCM preference", details: nil)); return
                }
                do {
                    try session.setPreferredSampleRate(sampleRate)
                    result(nil)
                } catch {
                    result(FlutterError(code: "sample_rate_preference", message: error.localizedDescription, details: nil))
                }
            case "setPreferredBufferFrames":
                let arguments = call.arguments as? [String: Any]
                let frames = arguments?["frames"] as? Int ?? 256
                guard (64...16384).contains(frames), session.sampleRate > 0 else {
                    result(FlutterError(code: "invalid_buffer", message: "Invalid output buffer preference", details: nil)); return
                }
                do {
                    try session.setPreferredIOBufferDuration(Double(frames) / session.sampleRate)
                    result(nil)
                } catch { result(FlutterError(code: "buffer_preference", message: error.localizedDescription, details: nil)) }
            case "prepareBackgroundStorage":
                DispatchQueue.global(qos: .utility).async { [weak self] in
                    self?.configureBackgroundReadableFiles()
                    DispatchQueue.main.async { result(nil) }
                }
            default: result(FlutterMethodNotImplemented)
            }
        }
        routeObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification,
            object: nil, queue: .main) { [weak self] notification in
                let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0
                self?.audioChannel?.invokeMethod("routeChanged", arguments: ["reason": reason])
            }
    }

    /// Only values exposed by public iOS APIs. Sensor values such as CPU
    /// frequency and die temperature are deliberately absent.
    private func systemInfo() -> [String: Any] {
        let process = ProcessInfo.processInfo
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        var hardware = utsname()
        uname(&hardware)
        let model = withUnsafeBytes(of: &hardware.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
        let thermal: String
        switch process.thermalState {
        case .nominal: thermal = "nominal"
        case .fair: thermal = "fair"
        case .serious: thermal = "serious"
        case .critical: thermal = "critical"
        @unknown default: thermal = "unknown"
        }
        let battery: String
        switch device.batteryState {
        case .unplugged: battery = "unplugged"
        case .charging: battery = "charging"
        case .full: battery = "full"
        default: battery = "unknown"
        }
        var values: [String: Any] = [
            "model": model,
            "systemVersion": device.systemVersion,
            "processorCount": process.processorCount,
            "physicalMemoryBytes": process.physicalMemory,
            "thermalState": thermal,
            "batteryState": battery,
            "batteryLevel": device.batteryLevel >= 0 ? Double(device.batteryLevel) as Any : NSNull()
        ]
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if status == KERN_SUCCESS { values["appMemoryBytes"] = info.resident_size }
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let attributes = try? FileManager.default.attributesOfFileSystem(forPath: documents.path) {
            values["storageTotalBytes"] = attributes[.systemSize]
            values["storageFreeBytes"] = attributes[.systemFreeSize]
        }
        return values
    }

    private func configureBackgroundReadableFiles() {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path else { return }
        let attributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        try? FileManager.default.setAttributes(attributes, ofItemAtPath: documents)
        if let enumerator = FileManager.default.enumerator(atPath: documents) {
            for case let relative as String in enumerator {
                try? FileManager.default.setAttributes(attributes, ofItemAtPath: (documents as NSString).appendingPathComponent(relative))
            }
        }
    }

    deinit { if let routeObserver { NotificationCenter.default.removeObserver(routeObserver) } }
}
