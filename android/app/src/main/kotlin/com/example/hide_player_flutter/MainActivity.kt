package com.example.hide_player_flutter

import android.Manifest
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Debug
import android.os.Environment
import android.os.PowerManager
import android.os.StatFs
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var storagePermissionResult: MethodChannel.Result? = null
    private var audioDevices: AndroidAudioDevices? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        audioDevices = AndroidAudioDevices(this, MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "hifi/platform_audio"))
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "hifi/system",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSystemInfo" -> result.success(readSystemInfo())
                "ensureStoragePermission" -> ensureStoragePermission(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun hasStoragePermission(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // CUE is a non-media sidecar. READ_MEDIA_AUDIO alone cannot see it.
            Environment.isExternalStorageManager()
        } else {
            checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        }

    private fun ensureStoragePermission(result: MethodChannel.Result) {
        if (hasStoragePermission()) { result.success(true); return }
        if (storagePermissionResult != null) {
            result.error("permission_pending", "请先完成当前存储授权", null)
            return
        }
        storagePermissionResult = result
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                try {
                    startActivityForResult(Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                        Uri.parse("package:$packageName")), 1002)
                } catch (_: Exception) {
                    startActivityForResult(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION), 1002)
                }
            } else {
                requestPermissions(arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE), 1001)
            }
        } catch (_: Exception) {
            finishStoragePermission()
        }
    }

    private fun finishStoragePermission() {
        val result = storagePermissionResult ?: return
        storagePermissionResult = null
        result.success(hasStoragePermission())
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 1002) finishStoragePermission()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1001) finishStoragePermission()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        audioDevices?.close()
        audioDevices = null
        storagePermissionResult?.success(false)
        storagePermissionResult = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun readSystemInfo(): Map<String, Any?> {
        val values = mutableMapOf<String, Any?>()
        val errors = mutableMapOf<String, String>()

        val manufacturer = Build.MANUFACTURER?.trim().orEmpty()
        val model = Build.MODEL?.trim().orEmpty()
        val deviceName = if (manufacturer.isNotEmpty() && !model.startsWith(manufacturer, ignoreCase = true)) {
            "$manufacturer $model"
        } else {
            model
        }
        values["deviceName"] = deviceName.ifEmpty { "Android Device" }
        values["modelName"] = model.ifEmpty { Build.DEVICE ?: "Android" }
        values["model"] = "${Build.BRAND ?: "Android"} · ${Build.HARDWARE ?: Build.BOARD ?: model}"
        values["systemName"] = "Android"
        values["systemVersion"] = "${Build.VERSION.RELEASE ?: ""} (API ${Build.VERSION.SDK_INT})"
        values["isSimulator"] = Build.FINGERPRINT.startsWith("generic") ||
            Build.MODEL.contains("sdk", ignoreCase = true) ||
            Build.PRODUCT.contains("sdk", ignoreCase = true)
        values["metricScope"] = "public_android"
        values["bridgeVersion"] = 1
        values["sampledAtUnixMs"] = System.currentTimeMillis()

        val cores = Runtime.getRuntime().availableProcessors()
        if (cores > 0) {
            values["processorCount"] = cores
            values["activeProcessorCount"] = cores
        }
        errors["appCpuPercent"] = "not_public"

        try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            if (activityManager != null) {
                val memInfo = ActivityManager.MemoryInfo()
                activityManager.getMemoryInfo(memInfo)
                if (memInfo.totalMem > 0) values["physicalMemoryBytes"] = memInfo.totalMem
                if (memInfo.availMem >= 0) values["physicalFreeMemoryBytes"] = memInfo.availMem
                val pssInfo = Debug.MemoryInfo()
                Debug.getMemoryInfo(pssInfo)
                val pssBytes = pssInfo.totalPss.toLong() * 1024L
                if (pssBytes > 0) {
                    values["appMemoryBytes"] = pssBytes
                    values["appFootprintBytes"] = pssBytes
                }
                val maxHeap = Runtime.getRuntime().maxMemory()
                val usedHeap = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory()
                val availBudget = (maxHeap - usedHeap).coerceAtLeast(0L)
                if (availBudget > 0) {
                    values["appAvailableMemoryBytes"] = availBudget
                }
            }
        } catch (e: Exception) {
            errors["physicalFreeMemoryBytes"] = "memory_error"
        }

        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            if (powerManager != null) {
                values["lowPowerMode"] = powerManager.isPowerSaveMode
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    values["thermalState"] = when (powerManager.currentThermalStatus) {
                        PowerManager.THERMAL_STATUS_NONE,
                        PowerManager.THERMAL_STATUS_LIGHT -> "nominal"
                        PowerManager.THERMAL_STATUS_MODERATE -> "fair"
                        PowerManager.THERMAL_STATUS_SEVERE -> "serious"
                        PowerManager.THERMAL_STATUS_CRITICAL,
                        PowerManager.THERMAL_STATUS_EMERGENCY,
                        PowerManager.THERMAL_STATUS_SHUTDOWN -> "critical"
                        else -> "nominal"
                    }
                } else {
                    values["thermalState"] = "nominal"
                }
            }
        } catch (e: Exception) {
            errors["thermalState"] = "thermal_error"
        }

        try {
            val batteryStatus = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            if (batteryStatus != null) {
                val level = batteryStatus.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                val scale = batteryStatus.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                if (level >= 0 && scale > 0) {
                    values["batteryLevel"] = level.toDouble() / scale.toDouble()
                }
                val status = batteryStatus.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                values["batteryState"] = when (status) {
                    BatteryManager.BATTERY_STATUS_CHARGING -> "charging"
                    BatteryManager.BATTERY_STATUS_FULL -> "full"
                    BatteryManager.BATTERY_STATUS_DISCHARGING,
                    BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "unplugged"
                    else -> null
                }
            }
        } catch (e: Exception) {
            errors["batteryLevel"] = "battery_error"
        }

        try {
            val stat = StatFs(filesDir.absolutePath)
            if (stat.totalBytes > 0) values["storageTotalBytes"] = stat.totalBytes
            if (stat.availableBytes >= 0) values["storageFreeBytes"] = stat.availableBytes
        } catch (e: Exception) {
            errors["storageFreeBytes"] = "storage_error"
        }

        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            if (audioManager != null) {
                val sampleRateStr = audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE)
                val framesStr = audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_FRAMES_PER_BUFFER)
                val sampleRate = sampleRateStr?.toDoubleOrNull()
                val frames = framesStr?.toIntOrNull()
                if (sampleRate != null && sampleRate > 0) {
                    values["audioSampleRate"] = sampleRate
                    if (frames != null && frames > 0) {
                        values["audioBufferFrames"] = frames
                        values["audioBufferDurationMs"] = (frames.toDouble() / sampleRate) * 1000.0
                    }
                }
                values["audioChannels"] = 2
                val outputs = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                val external = outputs.firstOrNull {
                    it.type == AudioDeviceInfo.TYPE_USB_DEVICE ||
                        it.type == AudioDeviceInfo.TYPE_USB_HEADSET ||
                        it.type == AudioDeviceInfo.TYPE_USB_ACCESSORY ||
                        it.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
                        it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                        it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                        it.type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                        it.type == AudioDeviceInfo.TYPE_BLE_SPEAKER
                }
                val chosen = external ?: outputs.firstOrNull {
                    it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
                } ?: outputs.firstOrNull()
                if (chosen != null) {
                    val productName = chosen.productName?.toString()?.trim().orEmpty()
                    values["audioOutputName"] = productName.ifEmpty { "本机音频输出" }
                    values["audioTransport"] = when (chosen.type) {
                        AudioDeviceInfo.TYPE_USB_DEVICE,
                        AudioDeviceInfo.TYPE_USB_HEADSET,
                        AudioDeviceInfo.TYPE_USB_ACCESSORY -> "USB"
                        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                        AudioDeviceInfo.TYPE_BLE_HEADSET,
                        AudioDeviceInfo.TYPE_BLE_SPEAKER -> "Bluetooth"
                        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                        AudioDeviceInfo.TYPE_WIRED_HEADSET -> "Wired"
                        else -> "BuiltIn"
                    }
                }
            }
        } catch (e: Exception) {
            errors["audioOutputName"] = "audio_error"
        }

        values["metricErrors"] = errors
        return values
    }
}
