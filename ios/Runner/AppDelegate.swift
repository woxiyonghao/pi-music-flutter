import Flutter
import UIKit
import AVFoundation
import AVKit
import Darwin
import os

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var audioChannel: FlutterMethodChannel?
    private var routeObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    private var lastRouteChangeReason: UInt = 0
    private var recentRouteChanges: [[String: Any]] = []
    private var systemChannel: FlutterMethodChannel?

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HifiPlatformAudio") else { return }
        registrar.register(AudioRoutePickerFactory(), withId: "hifi/audio_route_picker")
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
                result(self?.outputFormat(session) ?? [:])
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
                self?.lastRouteChangeReason = reason
                if let self {
                    let session = AVAudioSession.sharedInstance()
                    let previous = notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey]
                        as? AVAudioSessionRouteDescription
                    self.recentRouteChanges.append([
                        "reason": reason,
                        "at": ISO8601DateFormatter().string(from: Date()),
                        "previousOutputs": previous?.outputs.map(self.portInfo) ?? [],
                        "outputs": session.currentRoute.outputs.map(self.portInfo),
                        "sampleRate": session.sampleRate,
                        "category": session.category.rawValue,
                        "routeSharingPolicy": session.routeSharingPolicy.rawValue
                    ])
                    self.recentRouteChanges = Array(self.recentRouteChanges.suffix(12))
                }
                self?.audioChannel?.invokeMethod("routeChanged", arguments: ["reason": reason])
            }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.audioChannel?.invokeMethod("routeChanged", arguments: ["reason": 0])
        }
    }

    private func portInfo(_ port: AVAudioSessionPortDescription) -> [String: Any] {
        let transport: String
        switch port.portType {
        case .usbAudio: transport = "USB"
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE: transport = "Bluetooth"
        case .builtInSpeaker, .builtInReceiver, .headphones: transport = "BuiltIn"
        case .airPlay: transport = "AirPlay"
        default: transport = port.portType.rawValue
        }
        return ["id": port.uid, "name": port.portName, "transport": transport,
                "portType": port.portType.rawValue,
                "channelCount": port.channels?.count ?? 0]
    }

    private func outputFormat(_ session: AVAudioSession) -> [String: Any] {
        let route = session.currentRoute
        let outputs = route.outputs.map(portInfo)
        var format = outputs.first ?? ["id": "", "name": "", "transport": "System"]
        format["sampleRate"] = Int(session.sampleRate.rounded())
        format["channels"] = session.outputNumberOfChannels
        format["bufferDuration"] = session.ioBufferDuration
        format["outputLatency"] = session.outputLatency
        format["outputs"] = outputs
        format["inputs"] = route.inputs.map(portInfo)
        format["category"] = session.category.rawValue
        format["mode"] = session.mode.rawValue
        format["routeSharingPolicy"] = session.routeSharingPolicy.rawValue
        format["categoryOptions"] = session.categoryOptions.rawValue
        format["preferredSampleRate"] = session.preferredSampleRate
        format["bridgeVersion"] = 3
        format["lastRouteChangeReason"] = lastRouteChangeReason
        format["recentRouteChanges"] = recentRouteChanges
        return format
    }

    private var telemetryPreviousCPUSeconds: Double?
    private var telemetryPreviousSampleTime: TimeInterval?

    /// Every metric is independent: a denied Mach query or unavailable battery
    /// must not suppress device identity, storage or the actual audio session.
    private func systemInfo() -> [String: Any] {
        let process = ProcessInfo.processInfo
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        var errors: [String: String] = [
            "cpuFrequencyHz": "not_public", "cpuTemperatureCelsius": "not_public"
        ]
        #if targetEnvironment(simulator)
        let isSimulator = true
        #else
        let isSimulator = false
        #endif
        var hardware = utsname()
        let unameStatus = uname(&hardware)
        let architecture = withUnsafeBytes(of: &hardware.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
        let model = isSimulator
            ? (process.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? architecture)
            : architecture
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
            "bridgeVersion": 2,
            "sampledAtUnixMs": Int64(Date().timeIntervalSince1970 * 1000),
            "isSimulator": isSimulator,
            "metricScope": isSimulator ? "simulator_host" : "ios_device",
            "deviceName": isSimulator ? (process.environment["SIMULATOR_DEVICE_NAME"] ?? device.name) : device.name,
            "modelName": device.localizedModel,
            "systemName": device.systemName,
            "systemVersion": device.systemVersion,
            "processorCount": process.processorCount,
            "activeProcessorCount": process.activeProcessorCount,
            "physicalMemoryBytes": process.physicalMemory,
            "thermalState": thermal,
            "lowPowerMode": process.isLowPowerModeEnabled
        ]
        if unameStatus == 0 {
            values["model"] = model
            values["architecture"] = architecture
        } else { errors["model"] = "uname_\(errno)" }
        if !isSimulator {
            if device.batteryLevel >= 0 { values["batteryLevel"] = Double(device.batteryLevel) }
            else { errors["batteryLevel"] = "battery_not_ready" }
            if battery != "unknown" { values["batteryState"] = battery }
            else { errors["batteryState"] = "battery_not_ready" }
        } else {
            errors["batteryLevel"] = "simulator_unavailable"
            errors["batteryState"] = "simulator_unavailable"
        }

        // Process CPU time divided by elapsed sampling time. 100% means one
        // fully occupied core, so a multi-threaded process can exceed 100%.
        var usage = rusage()
        if getrusage(RUSAGE_SELF, &usage) == 0 {
            let cpuSeconds = Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
                + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
            let now = process.systemUptime
            if let previousCPU = telemetryPreviousCPUSeconds,
               let previousTime = telemetryPreviousSampleTime,
               now > previousTime, cpuSeconds >= previousCPU {
                let percent = (cpuSeconds - previousCPU) / (now - previousTime) * 100
                values["appCpuPercent"] = percent
            } else { errors["appCpuPercent"] = "sampling" }
            telemetryPreviousCPUSeconds = cpuSeconds
            telemetryPreviousSampleTime = now
        } else { errors["appCpuPercent"] = "getrusage_\(errno)" }

        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if status == KERN_SUCCESS { values["appMemoryBytes"] = info.resident_size }
        else { errors["appMemoryBytes"] = "task_info_\(status)" }

        var vm = task_vm_info_data_t()
        var vmCount = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let vmStatus = withUnsafeMutablePointer(to: &vm) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &vmCount)
            }
        }
        if vmStatus == KERN_SUCCESS { values["appFootprintBytes"] = vm.phys_footprint }
        else { errors["appFootprintBytes"] = "task_vm_info_\(vmStatus)" }

        let available = os_proc_available_memory()
        if available > 0 || !isSimulator { values["appAvailableMemoryBytes"] = available }
        else { errors["appAvailableMemoryBytes"] = isSimulator ? "simulator_unavailable" : "app_budget_unavailable" }

        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var pages = vm_statistics64()
        var pageCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let pagesStatus = withUnsafeMutablePointer(to: &pages) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(pageCount)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &pageCount)
            }
        }
        var pageSize: vm_size_t = 0
        let pageSizeStatus = host_page_size(host, &pageSize)
        if pagesStatus == KERN_SUCCESS && pageSizeStatus == KERN_SUCCESS {
            // Free physical pages are not the same as this app's memory budget.
            values["physicalFreeMemoryBytes"] = UInt64(pages.free_count) * UInt64(pageSize)
        } else { errors["physicalFreeMemoryBytes"] = "host_vm_info_\(pagesStatus)_\(pageSizeStatus)" }

        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let attributes = try FileManager.default.attributesOfFileSystem(forPath: documents.path)
                values["storageTotalBytes"] = attributes[.systemSize]
                values["storageFreeBytes"] = attributes[.systemFreeSize]
            } catch { errors["storageFreeBytes"] = "storage_\(error.localizedDescription)" }
        } else { errors["storageFreeBytes"] = "documents_unavailable" }

        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs
        if !outputs.isEmpty {
            values["audioOutputName"] = outputs.map { $0.portName }.joined(separator: " + ")
            values["audioTransport"] = outputs.map { $0.portType.rawValue }.joined(separator: " + ")
            values["audioChannels"] = session.outputNumberOfChannels
            if session.sampleRate > 0 {
                values["audioSampleRate"] = session.sampleRate
                values["audioBufferFrames"] = Int((session.sampleRate * session.ioBufferDuration).rounded())
            }
            values["audioBufferDurationMs"] = session.ioBufferDuration * 1000
            values["audioOutputLatencyMs"] = session.outputLatency * 1000
        } else { errors["audioOutputName"] = "audio_route_unavailable" }
        values["metricErrors"] = errors
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

    deinit {
        if let routeObserver { NotificationCenter.default.removeObserver(routeObserver) }
        if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
    }
}

/// Use Apple's public output selector. A playback-only session cannot select a
/// USB output by setting a preferred microphone or a speaker override.
private final class AudioRoutePickerFactory: NSObject, FlutterPlatformViewFactory {
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
                arguments args: Any?) -> FlutterPlatformView {
        AudioRoutePickerPlatformView(frame: frame)
    }
}

private final class AudioRoutePickerPlatformView: NSObject, FlutterPlatformView {
    private let picker: AVRoutePickerView

    init(frame: CGRect) {
        picker = AVRoutePickerView(frame: frame)
        super.init()
        picker.prioritizesVideoDevices = false
        picker.tintColor = .white
        picker.activeTintColor = .systemPink
        picker.backgroundColor = .clear
        picker.accessibilityLabel = "选择音频输出"
    }

    func view() -> UIView { picker }
}
