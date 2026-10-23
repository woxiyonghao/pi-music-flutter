import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var audioChannel: FlutterMethodChannel?
    private var routeObserver: NSObjectProtocol?

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HifiPlatformAudio") else { return }
        let channel = FlutterMethodChannel(name: "hifi/platform_audio", binaryMessenger: registrar.messenger())
        audioChannel = channel
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
                        "channels": session.outputNumberOfChannels,
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
