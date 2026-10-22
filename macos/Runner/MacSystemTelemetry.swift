import Foundation
import Darwin
import CoreAudio
import IOKit.ps

/// Read-only telemetry. Calls are serialized by the method channel's queue.
final class MacSystemTelemetry {
  private var previousTicks: [[UInt32]]?

  func snapshot() -> [String: Any] {
    let process = ProcessInfo.processInfo
    var data: [String: Any] = [
      "model": sysctlString("hw.model") ?? "Mac",
      "processor": sysctlString("machdep.cpu.brand_string") ?? "",
      "osVersion": process.operatingSystemVersionString,
      "coreCount": process.processorCount,
      "memoryTotalBytes": process.physicalMemory,
      "uptimeSeconds": process.systemUptime,
      "thermalState": thermalName(process.thermalState),
      "lowPowerMode": process.isLowPowerModeEnabled,
    ]
    readCPU(into: &data)
    readMemory(into: &data)
    readStorage(into: &data)
    readPower(into: &data)
    readAudio(into: &data)
    return data
  }

  private func sysctlString(_ name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
    var buffer = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
    return String(cString: buffer)
  }

  private func readCPU(into data: inout [String: Any]) {
    var count: mach_msg_type_number_t = 0
    var cores: natural_t = 0
    var info: processor_info_array_t?
    let host = mach_host_self()
    defer { mach_port_deallocate(mach_task_self_, host) }
    guard host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cores, &info, &count) == KERN_SUCCESS,
          let info = info else { return }
    defer {
      vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)),
                    vm_size_t(count) * vm_size_t(MemoryLayout<integer_t>.stride))
    }
    let ticks = (0..<Int(cores)).map { core in
      (0..<Int(CPU_STATE_MAX)).map { UInt32(bitPattern: info[core * Int(CPU_STATE_MAX) + $0]) }
    }
    defer { previousTicks = ticks }
    // The first reading establishes a baseline, never a fabricated zero load.
    guard let previous = previousTicks, previous.count == ticks.count else { return }
    var totalBusy: UInt64 = 0
    var totalTicks: UInt64 = 0
    let loads = ticks.enumerated().map { core, values -> Double in
      let delta = values.enumerated().map { UInt64($0.element &- previous[core][$0.offset]) }
      let total = delta.reduce(0, +)
      let busy = total - delta[Int(CPU_STATE_IDLE)]
      totalBusy += busy
      totalTicks += total
      return total > 0 ? Double(busy) / Double(total) * 100 : 0
    }
    if totalTicks > 0 {
      data["cpuPercent"] = Double(totalBusy) / Double(totalTicks) * 100
      data["corePercents"] = loads
    }
  }

  private func readMemory(into data: inout [String: Any]) {
    var stats = vm_statistics64()
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
    let host = mach_host_self()
    defer { mach_port_deallocate(mach_task_self_, host) }
    let status = withUnsafeMutablePointer(to: &stats) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics64(host, HOST_VM_INFO64, $0, &count)
      }
    }
    if status == KERN_SUCCESS {
      // App (internal minus purgeable), wired, and compressed physical pages.
      let appPages = UInt64(stats.internal_page_count) - min(UInt64(stats.internal_page_count), UInt64(stats.purgeable_count))
      let usedPages = appPages + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
      data["memoryUsedBytes"] = min(usedPages * UInt64(vm_page_size), ProcessInfo.processInfo.physicalMemory)
      data["memoryCompressedBytes"] = UInt64(stats.compressor_page_count) * UInt64(vm_page_size)
      data["memoryWiredBytes"] = UInt64(stats.wire_count) * UInt64(vm_page_size)
    }
    var task = task_vm_info_data_t()
    var taskCount = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let taskStatus = withUnsafeMutablePointer(to: &task) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(taskCount)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &taskCount)
      }
    }
    if taskStatus == KERN_SUCCESS { data["appMemoryBytes"] = task.phys_footprint }
  }

  private func readStorage(into data: inout [String: Any]) {
    // The volume containing the user's home, rather than the read-only system volume.
    let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeNameKey]
    guard let values = try? FileManager.default.homeDirectoryForCurrentUser.resourceValues(forKeys: keys) else { return }
    data["storageTotalBytes"] = values.volumeTotalCapacity
    data["storageFreeBytes"] = values.volumeAvailableCapacity
    data["storageName"] = values.volumeName
  }

  private func readPower(into data: inout [String: Any]) {
    guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return }
    if let source = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() {
      data["powerSource"] = source as String
    }
    guard let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return }
    for source in sources {
      guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
            description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
      if let current = description[kIOPSCurrentCapacityKey] as? Int,
         let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0 {
        data["batteryPercent"] = Double(current) / Double(maximum) * 100
      }
      data["batteryCharging"] = description[kIOPSIsChargingKey] as? Bool
      break
    }
  }

  private func readAudio(into data: inout [String: Any]) {
    var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var device = AudioDeviceID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr,
          device != kAudioObjectUnknown else { return }
    address.mSelector = kAudioObjectPropertyName
    var name: Unmanaged<CFString>?
    size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    if AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name) == noErr,
       let name = name {
      // CoreAudio transfers ownership of this property to the caller.
      data["outputName"] = name.takeRetainedValue() as String
    }
    address.mSelector = kAudioDevicePropertyNominalSampleRate
    var rate: Float64 = 0
    size = UInt32(MemoryLayout<Float64>.size)
    if AudioObjectGetPropertyData(device, &address, 0, nil, &size, &rate) == noErr, rate > 0 {
      data["outputSampleRate"] = rate
    }
    address.mSelector = kAudioDevicePropertyBufferFrameSize
    var frames: UInt32 = 0
    size = UInt32(MemoryLayout<UInt32>.size)
    if AudioObjectGetPropertyData(device, &address, 0, nil, &size, &frames) == noErr, frames > 0 {
      data["outputBufferFrames"] = frames
    }
  }

  private func thermalName(_ state: ProcessInfo.ThermalState) -> String {
    switch state {
    case .nominal: return "nominal"
    case .fair: return "fair"
    case .serious: return "serious"
    case .critical: return "critical"
    @unknown default: return "unknown"
    }
  }
}
