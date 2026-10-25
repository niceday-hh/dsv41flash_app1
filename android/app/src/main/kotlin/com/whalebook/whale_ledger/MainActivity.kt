package com.whalebook.whale_ledger

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * CSV 完整版文件读写：使用系统文件选择器（SAF），无需存储权限。
 *  - save(filename, content) -> Boolean   另存为 CSV
 *  - pick() -> String?                     选择 CSV 并返回文本内容
 */
class MainActivity : FlutterActivity(), EventChannel.StreamHandler {

    private val channelName = "whale_ledger/csv"
    private val micChannelName = "whale_ledger/mic"
    private val reminderChannelName = "whale_ledger/reminder"
    private val micEventName = "whale_ledger/mic_stream"
    private val micPermissionCode = 4303
    private val notifPermissionCode = 4304

    private var eventSink: EventChannel.EventSink? = null
    private var audioRecord: AudioRecord? = null
    private var recordThread: Thread? = null
    @Volatile private var recording = false
    private var permissionResult: MethodChannel.Result? = null
    private var notifResult: MethodChannel.Result? = null
    private var pendingHour = 21
    private var pendingMinute = 30
    private val requestSave = 4301
    private val requestPick = 4302

    private var pendingResult: MethodChannel.Result? = null
    private var pendingContent: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, micEventName).setStreamHandler(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, micChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> startMic(result)
                    "stop" -> {
                        stopMic()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "save" -> {
                        if (pendingResult != null) {
                            result.error("busy", "上一个文件操作尚未结束", null)
                            return@setMethodCallHandler
                        }
                        val filename = call.argument<String>("filename") ?: "whale_ledger.csv"
                        val content = call.argument<String>("content") ?: ""
                        pendingResult = result
                        pendingContent = content
                        try {
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "text/csv"
                                putExtra(Intent.EXTRA_TITLE, filename)
                            }
                            startActivityForResult(intent, requestSave)
                        } catch (e: Exception) {
                            clearPending()
                            result.error("no_picker", e.message, null)
                        }
                    }
                    "pick" -> {
                        if (pendingResult != null) {
                            result.error("busy", "上一个文件操作尚未结束", null)
                            return@setMethodCallHandler
                        }
                        pendingResult = result
                        try {
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                            }
                            startActivityForResult(intent, requestPick)
                        } catch (e: Exception) {
                            clearPending()
                            result.error("no_picker", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, reminderChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "schedule" -> {
                        val hour = call.argument<Int>("hour") ?: 21
                        val minute = call.argument<Int>("minute") ?: 30
                        pendingHour = hour
                        pendingMinute = minute
                        ReminderScheduler.ensureChannel(this)
                        if (Build.VERSION.SDK_INT >= 33 && !ReminderScheduler.hasPermission(this)) {
                            notifResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                notifPermissionCode
                            )
                        } else {
                            ReminderScheduler.schedule(this, hour, minute)
                            result.success(true)
                        }
                    }
                    "cancel" -> {
                        ReminderScheduler.cancel(this)
                        result.success(true)
                    }
                    "test" -> {
                        ReminderScheduler.notifyNow(this)
                        result.success(ReminderScheduler.hasPermission(this))
                    }
                    "restore" -> {
                        ReminderScheduler.restoreIfEnabled(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val result = pendingResult ?: return
        try {
            if (requestCode == requestSave) {
                if (resultCode == Activity.RESULT_OK && data?.data != null) {
                    val uri: Uri = data.data!!
                    contentResolver.openOutputStream(uri, "wt")?.use { out ->
                        out.write((pendingContent ?: "").toByteArray(Charsets.UTF_8))
                        out.flush()
                    }
                    result.success(true)
                } else {
                    result.success(false)
                }
                clearPending()
            } else if (requestCode == requestPick) {
                if (resultCode == Activity.RESULT_OK && data?.data != null) {
                    val text = contentResolver.openInputStream(data.data!!)?.use { input ->
                        input.readBytes().toString(Charsets.UTF_8)
                    }
                    result.success(text)
                } else {
                    result.success(null)
                }
                clearPending()
            }
        } catch (e: Exception) {
            result.error("io_error", e.message, null)
            clearPending()
        }
    }

    private fun clearPending() {
        pendingResult = null
        pendingContent = null
    }

    // ---------------------------------------------------------------- 麦克风

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun hasMicPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    private fun startMic(result: MethodChannel.Result) {
        if (recording) {
            result.success(true)
            return
        }
        if (!hasMicPermission()) {
            permissionResult = result
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                micPermissionCode
            )
            return
        }
        try {
            val sampleRate = 16000
            val minBuf = AudioRecord.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            val bufferSize = if (minBuf > 0) minBuf * 2 else 6400
            val record = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize
            )
            if (record.state != AudioRecord.STATE_INITIALIZED) {
                record.release()
                result.error("mic_init", "无法初始化麦克风", null)
                return
            }
            audioRecord = record
            recording = true
            record.startRecording()
            val chunk = ByteArray(3200)
            recordThread = Thread {
                while (recording) {
                    val n = record.read(chunk, 0, chunk.size)
                    if (n > 0) {
                        val data = chunk.copyOf(n)
                        runOnUiThread { eventSink?.success(data) }
                    }
                }
            }.also { it.start() }
            result.success(true)
        } catch (e: Exception) {
            stopMic()
            result.error("mic_error", e.message, null)
        }
    }

    private fun stopMic() {
        recording = false
        try {
            recordThread?.join(300)
        } catch (_: Exception) {
        }
        recordThread = null
        try {
            audioRecord?.stop()
        } catch (_: Exception) {
        }
        audioRecord?.release()
        audioRecord = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == micPermissionCode) {
            val pending = permissionResult
            permissionResult = null
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                pending?.let { startMic(it) }
            } else {
                pending?.success(false)
            }
            return
        }
        if (requestCode == notifPermissionCode) {
            val pending = notifResult
            notifResult = null
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            // 即使用户拒绝，也先登记闹钟：之后在系统设置里打开权限就能收到
            ReminderScheduler.schedule(this, pendingHour, pendingMinute)
            pending?.success(granted)
        }
    }

    override fun onDestroy() {
        stopMic()
        super.onDestroy()
    }
}
