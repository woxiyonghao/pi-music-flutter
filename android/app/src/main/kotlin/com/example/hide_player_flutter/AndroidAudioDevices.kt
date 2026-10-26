package com.example.hide_player_flutter

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

/** System device inventory; the C++ AAudio sink owns streams and reports their actual format. */
class AndroidAudioDevices(context: Context, private val channel: MethodChannel) {
    private val manager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val callback = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(devices: Array<out AudioDeviceInfo>) {
            channel.invokeMethod("routeChanged", mapOf("reason" to 1))
        }
        override fun onAudioDevicesRemoved(devices: Array<out AudioDeviceInfo>) {
            channel.invokeMethod("routeChanged", mapOf("reason" to 2))
        }
    }
    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getOutputDevices" -> result.success(readDevices())
                    "getOutputFormat" -> {
                        val devices = readDevices()
                        result.success(devices.firstOrNull { it["isDefault"] == true })
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("audio_route", error.message, null)
            }
        }
        manager.registerAudioDeviceCallback(callback, Handler(Looper.getMainLooper()))
    }

    private fun transport(device: AudioDeviceInfo): String = when (device.type) {
        AudioDeviceInfo.TYPE_USB_DEVICE, AudioDeviceInfo.TYPE_USB_HEADSET, AudioDeviceInfo.TYPE_USB_ACCESSORY -> "USB"
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP, AudioDeviceInfo.TYPE_BLE_HEADSET,
        AudioDeviceInfo.TYPE_BLE_SPEAKER, AudioDeviceInfo.TYPE_HEARING_AID -> "Bluetooth"
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES, AudioDeviceInfo.TYPE_WIRED_HEADSET,
        AudioDeviceInfo.TYPE_LINE_ANALOG, AudioDeviceInfo.TYPE_LINE_DIGITAL -> "Wired"
        AudioDeviceInfo.TYPE_HDMI, AudioDeviceInfo.TYPE_HDMI_ARC, AudioDeviceInfo.TYPE_HDMI_EARC -> "HDMI"
        else -> "BuiltIn"
    }

    private fun readDevices(): List<Map<String, Any>> {
        val devices = manager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).filter {
            // Earpiece, telephony, remote-submix and echo-reference ports aren't music DACs.
            it.type in setOf(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER, AudioDeviceInfo.TYPE_BUILTIN_SPEAKER_SAFE,
                AudioDeviceInfo.TYPE_USB_DEVICE, AudioDeviceInfo.TYPE_USB_HEADSET, AudioDeviceInfo.TYPE_USB_ACCESSORY,
                AudioDeviceInfo.TYPE_BLUETOOTH_A2DP, AudioDeviceInfo.TYPE_BLE_HEADSET, AudioDeviceInfo.TYPE_BLE_SPEAKER,
                AudioDeviceInfo.TYPE_HEARING_AID, AudioDeviceInfo.TYPE_WIRED_HEADPHONES, AudioDeviceInfo.TYPE_WIRED_HEADSET,
                AudioDeviceInfo.TYPE_LINE_ANALOG, AudioDeviceInfo.TYPE_LINE_DIGITAL,
                AudioDeviceInfo.TYPE_HDMI, AudioDeviceInfo.TYPE_HDMI_ARC, AudioDeviceInfo.TYPE_HDMI_EARC)
        }
        val systemIds = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            try {
                manager.getAudioDevicesForAttributes(AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                    .map { it.id }
            } catch (_: Exception) { emptyList() }
        } else emptyList()
        val defaultId = systemIds.firstOrNull { id -> devices.any { it.id == id } }
            ?: devices.firstOrNull { transport(it) == "USB" }?.id
            ?: devices.firstOrNull { transport(it) == "Wired" || transport(it) == "Bluetooth" }?.id
            ?: devices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }?.id
        return devices.map { device ->
            val depths = device.encodings.toList().mapNotNull {
                when (it) {
                    AudioFormat.ENCODING_PCM_8BIT -> 8
                    AudioFormat.ENCODING_PCM_16BIT -> 16
                    AudioFormat.ENCODING_PCM_24BIT_PACKED -> 24
                    AudioFormat.ENCODING_PCM_32BIT, AudioFormat.ENCODING_PCM_FLOAT -> 32
                    else -> null
                }
            }.distinct().sorted()
            val route = transport(device)
            mapOf("id" to device.id.toString(),
                "name" to device.productName.toString().trim().ifEmpty { if (route == "BuiltIn") "Android 内置扬声器" else "$route 音频输出" },
                "transport" to route, "isBuiltIn" to (route == "BuiltIn"), "isDefault" to (device.id == defaultId),
                "sampleRate" to 0, "currentSampleRate" to 0, "bitDepth" to 0,
                "channels" to 2, "bufferFrames" to 0,
                "sampleRates" to device.sampleRates.toList(), "channelCounts" to device.channelCounts.toList(),
                "encodings" to device.encodings.toList(), "bitDepths" to depths,
                "maxSampleRate" to (device.sampleRates.maxOrNull() ?: 0), "maxBitDepth" to (depths.maxOrNull() ?: 0))
        }
    }

    fun close() {
        manager.unregisterAudioDeviceCallback(callback)
        channel.setMethodCallHandler(null)
    }
}
