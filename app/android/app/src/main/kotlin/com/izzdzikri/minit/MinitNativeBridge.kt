package com.izzdzikri.minit

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.AudioRecordingConfiguration
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.StatFs
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import kotlin.math.max

/**
 * Shared native Android bridge attached to both the UI FlutterEngine and the
 * foreground-service background FlutterEngine.
 */
class MinitNativeBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val METHOD_CHANNEL = "com.izzdzikri.minit/native"
        private const val EVENT_CHANNEL = "com.izzdzikri.minit/audio_events"

        private val SAMPLE_RATES = intArrayOf(
            96000, 88200, 64000, 48000, 44100, 32000,
            24000, 22050, 16000, 12000, 11025, 8000,
        )
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    private val connectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    private var eventSink: EventChannel.EventSink? = null
    private var deviceCallback: AudioDeviceCallback? = null
    private var recordingCallback: AudioManager.AudioRecordingCallback? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var lastClientSilenced: Boolean = false

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    fun dispose() {
        stopAudioCallbacks()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        executor.shutdownNow()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "mergeAacSegmentsToM4a" -> {
                val segmentPaths = call.argument<List<String>>("segmentPaths") ?: emptyList()
                val outputPath = call.argument<String>("outputPath")
                if (segmentPaths.isEmpty() || outputPath.isNullOrBlank()) {
                    result.error("invalid_args", "segmentPaths and outputPath are required", null)
                    return
                }
                executor.execute {
                    try {
                        val merged = mergeAacSegmentsToM4a(segmentPaths, outputPath)
                        mainHandler.post { result.success(merged) }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("merge_failed", e.message ?: e.toString(), null)
                        }
                    }
                }
            }

            "getAvailableStorageBytes" -> {
                val path = call.argument<String>("path") ?: context.filesDir.absolutePath
                try {
                    val target = File(path).let { if (it.exists()) it else it.parentFile ?: context.filesDir }
                    val stat = StatFs(target.absolutePath)
                    result.success(stat.availableBytes)
                } catch (e: Exception) {
                    result.error("stat_failed", e.message ?: e.toString(), null)
                }
            }

            "getAudioEnvironmentState" -> {
                val mode = audioManager.mode
                val isCallActive = mode == AudioManager.MODE_RINGTONE ||
                    mode == AudioManager.MODE_IN_CALL ||
                    mode == AudioManager.MODE_IN_COMMUNICATION
                val isPowerSave = powerManager.isPowerSaveMode
                val isClientSilenced = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    audioManager.activeRecordingConfigurations.any { it.isClientSilenced }
                } else {
                    false
                }
                result.success(
                    mapOf(
                        "audioMode" to mode,
                        "isCallActive" to isCallActive,
                        "isPowerSaveMode" to isPowerSave,
                        "isClientSilenced" to isClientSilenced,
                    )
                )
            }

            "openAutoStartSettings" -> {
                result.success(openAutoStartSettings())
            }

            "isNetworkOnline" -> {
                result.success(checkNetworkOnline())
            }

            "showTranscriptReadyNotification" -> {
                val meetingId = call.argument<String>("meetingId") ?: ""
                val title = call.argument<String>("title") ?: "Meeting"
                result.success(showTranscriptReadyNotification(meetingId, title))
            }

            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        startAudioCallbacks()
    }

    override fun onCancel(arguments: Any?) {
        stopAudioCallbacks()
        eventSink = null
    }

    private fun startAudioCallbacks() {
        stopAudioCallbacks()

        val devCallback = object : AudioDeviceCallback() {
            override fun onAudioDevicesRemoved(removedDevices: Array<AudioDeviceInfo>) {
                for (device in removedDevices) {
                    if (isHeadsetOrExternalMic(device.type)) {
                        emitEvent(
                            mapOf(
                                "type" to "headset_unplugged",
                                "deviceName" to (device.productName?.toString() ?: "Headset"),
                                "isSource" to device.isSource,
                            )
                        )
                        break
                    }
                }
            }
        }
        deviceCallback = devCallback
        audioManager.registerAudioDeviceCallback(devCallback, mainHandler)

        val recCallback = object : AudioManager.AudioRecordingCallback() {
            override fun onRecordingConfigChanged(configs: List<AudioRecordingConfiguration>) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val silenced = configs.any { it.isClientSilenced }
                    if (silenced != lastClientSilenced) {
                        lastClientSilenced = silenced
                        val mode = audioManager.mode
                        val isCall = mode == AudioManager.MODE_RINGTONE ||
                            mode == AudioManager.MODE_IN_CALL ||
                            mode == AudioManager.MODE_IN_COMMUNICATION
                        emitEvent(
                            mapOf(
                                "type" to "mic_silenced",
                                "silenced" to silenced,
                                "isCallActive" to isCall,
                                "audioMode" to mode,
                            )
                        )
                    }
                }
            }
        }
        lastClientSilenced = false
        recordingCallback = recCallback
        audioManager.registerAudioRecordingCallback(recCallback, mainHandler)

        try {
            val netCb = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    emitEvent(mapOf("type" to "connectivity", "isOnline" to true))
                }

                override fun onLost(network: Network) {
                    emitEvent(mapOf("type" to "connectivity", "isOnline" to checkNetworkOnline()))
                }
            }
            networkCallback = netCb
            connectivityManager.registerDefaultNetworkCallback(netCb)
        } catch (_: Exception) {
            // Best-effort connectivity monitoring.
        }
    }

    private fun checkNetworkOnline(): Boolean {
        return try {
            val network = connectivityManager.activeNetwork ?: return false
            val caps = connectivityManager.getNetworkCapabilities(network) ?: return false
            caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        } catch (_: Exception) {
            false
        }
    }

    private fun stopAudioCallbacks() {
        deviceCallback?.let { audioManager.unregisterAudioDeviceCallback(it) }
        deviceCallback = null
        recordingCallback?.let { audioManager.unregisterAudioRecordingCallback(it) }
        recordingCallback = null
        networkCallback?.let {
            try {
                connectivityManager.unregisterNetworkCallback(it)
            } catch (_: Exception) {}
        }
        networkCallback = null
        lastClientSilenced = false
    }

    private fun isHeadsetOrExternalMic(type: Int): Boolean {
        return type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
            type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
            type == AudioDeviceInfo.TYPE_USB_HEADSET ||
            type == AudioDeviceInfo.TYPE_USB_DEVICE ||
            type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
            type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                (type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                    type == AudioDeviceInfo.TYPE_BLE_SPEAKER))
    }

    private fun emitEvent(payload: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(payload)
        }
    }

    /**
     * Remuxes ADTS AAC segment files in order into a single MPEG-4 (.m4a) file
     * without re-encoding, assigning exact sample-aligned presentation timestamps.
     */
    private fun mergeAacSegmentsToM4a(segmentPaths: List<String>, outputPath: String): Map<String, Any> {
        val outputFile = File(outputPath)
        outputFile.parentFile?.mkdirs()
        val tempFile = File("${outputFile.absolutePath}.tmp")
        if (tempFile.exists()) tempFile.delete()

        val validFiles = segmentPaths.map { File(it) }.filter { it.exists() && it.length() > 7 }
        if (validFiles.isEmpty()) {
            throw IllegalStateException("No valid audio segments to merge.")
        }

        var muxer: MediaMuxer? = null
        var muxerStarted = false
        var muxerTrackIndex = -1
        var totalFrames = 0L
        var sampleRate = 16000
        var channelCount = 1
        var segmentsMerged = 0

        try {
            var buffer = ByteBuffer.allocate(64 * 1024)
            val bufferInfo = MediaCodec.BufferInfo()

            for (segmentFile in validFiles) {
                val extractor = MediaExtractor()
                try {
                    extractor.setDataSource(segmentFile.absolutePath)
                    val trackIndex = findAudioTrackIndex(extractor)
                    if (trackIndex < 0) continue

                    extractor.selectTrack(trackIndex)
                    val srcFormat = extractor.getTrackFormat(trackIndex)

                    if (!muxerStarted) {
                        sampleRate = if (srcFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                            srcFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        } else {
                            16000
                        }
                        channelCount = if (srcFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                            srcFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        } else {
                            1
                        }
                        val aacProfile = if (srcFormat.containsKey(MediaFormat.KEY_AAC_PROFILE)) {
                            srcFormat.getInteger(MediaFormat.KEY_AAC_PROFILE)
                        } else {
                            2 // AAC-LC
                        }
                        val maxInputSize = if (srcFormat.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                            srcFormat.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
                        } else {
                            64 * 1024
                        }
                        if (maxInputSize > buffer.capacity()) {
                            buffer = ByteBuffer.allocate(max(maxInputSize, 64 * 1024))
                        }

                        val muxFormat = MediaFormat.createAudioFormat(
                            MediaFormat.MIMETYPE_AUDIO_AAC,
                            sampleRate,
                            channelCount,
                        )
                        val csd = srcFormat.getByteBuffer("csd-0")
                            ?: buildAacCsd0(aacProfile, sampleRate, channelCount)
                        muxFormat.setByteBuffer("csd-0", csd)

                        muxer = MediaMuxer(tempFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
                        muxerTrackIndex = muxer.addTrack(muxFormat)
                        muxer.start()
                        muxerStarted = true
                    }

                    var segmentHadSamples = false
                    while (true) {
                        buffer.clear()
                        val sampleSize = try {
                            extractor.readSampleData(buffer, 0)
                        } catch (_: Exception) {
                            // If the final tail frame was truncated on crash, preserve everything prior.
                            break
                        }
                        if (sampleSize < 0) break

                        bufferInfo.offset = 0
                        bufferInfo.size = sampleSize
                        bufferInfo.presentationTimeUs = (totalFrames * 1024L * 1_000_000L) / sampleRate
                        bufferInfo.flags = extractor.sampleFlags

                        muxer?.writeSampleData(muxerTrackIndex, buffer, bufferInfo)
                        totalFrames++
                        segmentHadSamples = true

                        if (!extractor.advance()) break
                    }

                    if (segmentHadSamples) {
                        segmentsMerged++
                    }
                } catch (_: Exception) {
                    // Skip damaged tail segment without losing earlier valid segments.
                } finally {
                    extractor.release()
                }
            }

            if (!muxerStarted || totalFrames == 0L) {
                throw IllegalStateException("Could not extract any playable AAC frames from segments.")
            }

            muxer?.stop()
            muxerStarted = false
            muxer?.release()
            muxer = null

            if (outputFile.exists()) outputFile.delete()
            if (!tempFile.renameTo(outputFile)) {
                tempFile.copyTo(outputFile, overwrite = true)
                tempFile.delete()
            }

            val durationMs = (totalFrames * 1024L * 1000L) / sampleRate
            return mapOf(
                "outputPath" to outputFile.absolutePath,
                "durationMs" to durationMs,
                "sizeBytes" to outputFile.length(),
                "segmentsMerged" to segmentsMerged,
                "sampleRate" to sampleRate,
                "channelCount" to channelCount,
            )
        } catch (e: Exception) {
            if (muxerStarted) {
                try {
                    muxer?.stop()
                } catch (_: Exception) {}
            }
            muxer?.release()
            if (tempFile.exists()) tempFile.delete()
            throw e
        }
    }

    private fun findAudioTrackIndex(extractor: MediaExtractor): Int {
        for (i in 0 until extractor.trackCount) {
            val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME)
            if (mime != null && mime.startsWith("audio/")) {
                return i
            }
        }
        return -1
    }

    private fun buildAacCsd0(aacProfile: Int, sampleRate: Int, channelCount: Int): ByteBuffer {
        val freqIndex = SAMPLE_RATES.indexOf(sampleRate).let { if (it >= 0) it else 8 }
        val config = ((aacProfile and 0x1F) shl 11) or
            ((freqIndex and 0x0F) shl 7) or
            ((channelCount and 0x0F) shl 3)
        return ByteBuffer.wrap(
            byteArrayOf(
                ((config shr 8) and 0xFF).toByte(),
                (config and 0xFF).toByte(),
            )
        )
    }

    private fun openAutoStartSettings(): Boolean {
        val oemIntents = listOf(
            // Vivo / iQOO (Funtouch OS / OriginOS)
            Intent().setComponent(ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")),
            Intent().setComponent(ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManagerActivity")),
            Intent().setComponent(ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")),
            Intent().setComponent(ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.SoftManagerDetailActivity")),
            Intent().setComponent(ComponentName("com.vivo.abe", "com.vivo.applicationbehaviorengine.ui.ExcessivePowerManagerActivity")),
            // Xiaomi / Redmi / POCO
            Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
            // Oppo / Realme / OnePlus
            Intent().setComponent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")),
            Intent().setComponent(ComponentName("com.oplus.safecenter", "com.oplus.safecenter.permission.startup.StartupAppListActivity")),
            Intent().setComponent(ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity")),
            // Samsung
            Intent().setComponent(ComponentName("com.samsung.android.lool", "com.samsung.android.sm.battery.ui.BatteryActivity")),
            Intent().setComponent(ComponentName("com.samsung.android.sm", "com.samsung.android.sm.battery.ui.BatteryActivity")),
        )

        for (intent in oemIntents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                return true
            } catch (_: Exception) {
                // Try the next OEM settings screen.
            }
        }

        // Standard Android App Details fallback
        return try {
            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(fallback)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun showTranscriptReadyNotification(meetingId: String, title: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }

        return try {
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channelId = "minit_transcripts"
            val channel = NotificationChannel(
                channelId,
                "Transcript notifications",
                NotificationManager.IMPORTANCE_DEFAULT,
            )
            manager.createNotificationChannel(channel)

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("meetingId", meetingId)
            }
            val reqCode = meetingId.hashCode() and 0x7FFFFFFF
            val pendingIntent = PendingIntent.getActivity(
                context,
                reqCode,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val notification = Notification.Builder(context, channelId)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("Transcript ready")
                .setContentText(title)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)
                .build()

            manager.notify(10000 + (reqCode % 50000), notification)
            true
        } catch (_: Exception) {
            false
        }
    }
}
