import Flutter
import UIKit
import AVFoundation

private var gPreferredIOBufferFrames: UInt32 = 256
private let audioSessionQueue = DispatchQueue(label: "com.pihifi.audio-session")

private func logCurrentAudioRoute(_ session: AVAudioSession, reason: String) {
    let output = session.currentRoute.outputs.first
    let port = output?.portType.rawValue ?? "none"
    let sampleRate = session.sampleRate
    let ioBufferMs = session.ioBufferDuration * 1000.0
    print("[AVAudioSession] \(reason): output=\(port), sampleRate=\(Int(sampleRate)), ioBuffer=\(String(format: "%.2f", ioBufferMs))ms")
}

public func keepPadAudioSessionActive(reason: String) {
    audioSessionQueue.async {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(true)
            logCurrentAudioRoute(session, reason: reason)
        } catch {
            print("[AVAudioSession] \(reason) activation error: \(error.localizedDescription)")
        }
    }
}

// iPad / iPhone 专用桥接：系统设置中的 64/256/512 表示 AVAudioSession 的首选
// 硬件 I/O 帧数，而不是 AudioQueue 每个应用层推流 buffer 的分配尺寸。
@_cdecl("HifiPadSetPreferredIOBufferFrames")
public func HifiPadSetPreferredIOBufferFrames(frames: UInt32) -> Bool {
    let session = AVAudioSession.sharedInstance()
    gPreferredIOBufferFrames = frames
    let sampleRate = session.sampleRate > 0.0 ? session.sampleRate : 48000.0
    let duration = TimeInterval(frames) / sampleRate
    do {
        try session.setPreferredIOBufferDuration(duration)
    } catch {
        print("[AVAudioSession] setPreferredIOBufferDuration(\(frames)) error: \(error.localizedDescription)")
    }
    logCurrentAudioRoute(session, reason: "preferred buffer=\(frames) frames")
    return true
}

// 在 iOS (iPad / iPhone) 的 A2DP 输出上返回实际采样率；其他设备与平台返回 0，继续沿用解码与直通路径。
@_cdecl("HifiPadGetBluetoothOutputSampleRate")
public func HifiPadGetBluetoothOutputSampleRate() -> UInt32 {
    let session = AVAudioSession.sharedInstance()
    for output in session.currentRoute.outputs {
        if output.portType == .bluetoothA2DP {
            return session.sampleRate > 0.0 ? UInt32(session.sampleRate + 0.5) : 48000
        }
    }
    return 0
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var wasPlayingBeforeInterruption = false

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        application.isIdleTimerDisabled = true
        configureBackgroundReadableFiles()
        setupAudioSession()
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }

    override func applicationDidEnterBackground(_ application: UIApplication) {
        keepPadAudioSessionActive(reason: "application background")
        super.applicationDidEnterBackground(application)
    }

    override func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .landscape
    }

    private func configureBackgroundReadableFiles() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path else {
            return
        }

        let configDir = (documentsDirectory as NSString).appendingPathComponent("hifi_player")
        try? FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true, attributes: nil)

        let attributes: [FileAttributeKey: Any] = [
            .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
        ]

        // 音乐与数据库在首次解锁后保持可读，确保锁屏期间解码线程不会把“文件暂不可读”误判成 EOF
        do {
            try FileManager.default.setAttributes(attributes, ofItemAtPath: documentsDirectory)
        } catch {
            print("[BackgroundAudio] Documents protection update failed: \(error.localizedDescription)")
        }

        if let enumerator = FileManager.default.enumerator(atPath: documentsDirectory) {
            for case let relativePath as String in enumerator {
                let fullPath = (documentsDirectory as NSString).appendingPathComponent(relativePath)
                do {
                    try FileManager.default.setAttributes(attributes, ofItemAtPath: fullPath)
                } catch {
                    print("[BackgroundAudio] protection update failed for \(relativePath): \(error.localizedDescription)")
                }
            }
        }
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()

        // Playback 本身就支持 A2DP。AllowBluetoothA2DP 只适用于支持输入的类别，
        // 与 Playback 组合会返回 OSStatus -50，并留下不稳定的旧会话配置。
        // 复刻 iPad 稳定做法：options 设为 []。
        do {
            try session.setCategory(.playback, mode: .default, options: [])
        } catch {
            print("[AVAudioSession] setCategory error: \(error.localizedDescription)")
        }

        _ = HifiPadSetPreferredIOBufferFrames(frames: gPreferredIOBufferFrames)

        // 串行激活，避免锁屏/中断恢复与启动流程并发操作同一个 AudioSession。
        keepPadAudioSessionActive(reason: "activated")

        // 监听音频硬件路由变更 (例如 AirPods Pro 佩戴/摘下/重新连接)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            print("[AVAudioSession] 音频输出设备路由变更: \(note.userInfo ?? [:])")
            let currentSession = AVAudioSession.sharedInstance()
            // 不在路由通知里 setActive 或重提缓冲偏好；两者都会再次触发 A2DP 配置协商，形成反复跳转与爆音
            logCurrentAudioRoute(currentSession, reason: "route changed")
        }

        // 监听音频中断 (例如电话呼入/系统强占恢复)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self = self,
                  let info = note.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }

            if type == .began {
                self.wasPlayingBeforeInterruption = hifi_audio_is_playing()
                print("[AVAudioSession] 电话呼入/系统中断开始，当前播放状态: \(self.wasPlayingBeforeInterruption)")
                if self.wasPlayingBeforeInterruption {
                    hifi_audio_pause()
                }
            } else if type == .ended {
                print("[AVAudioSession] 电话挂断/系统中断结束，重新激活音频会话")
                keepPadAudioSessionActive(reason: "interruption ended")
                if self.wasPlayingBeforeInterruption {
                    self.wasPlayingBeforeInterruption = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        print("[AVAudioSession] 挂断电话恢复播放，正在启动 hifi_audio_play()...")
                        hifi_audio_play()
                    }
                }
            }
        }
    }
}
