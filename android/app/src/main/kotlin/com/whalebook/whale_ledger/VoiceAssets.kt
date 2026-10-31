package com.whalebook.whale_ledger

import android.app.Activity
import java.io.File
import java.util.concurrent.Executors
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Bounded streaming extraction: never materialize the 227 MB asset in Dart. */
class VoiceAssets(private val activity: Activity) {
    private val executor = Executors.newSingleThreadExecutor()
    private var channel: MethodChannel? = null
    fun attach(engine: FlutterEngine) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "whale_ledger/asr")
        channel!!.setMethodCallHandler { call, result ->
            if (call.method != "prepare") { result.notImplemented(); return@setMethodCallHandler }
            executor.execute {
                try {
                    val dir = File(activity.noBackupFilesDir, "paraformer-90bc03034ae1")
                    check(dir.exists() || dir.mkdirs())
                    val files = mapOf("model.int8.onnx" to ("asr_model.int8.onnx" to 227330205L),
                        "tokens.txt" to ("asr_tokens.txt" to 75354L))
                    for ((asset, info) in files) {
                        val out = File(dir, info.first)
                        if (out.exists() && out.length() == info.second) continue
                        val part = File(dir, "${info.first}.part")
                        try {
                            activity.assets.open("flutter_assets/assets/asr/$asset").use { input ->
                                part.outputStream().use { output -> input.copyTo(output, 65536) }
                            }
                            check(part.length() == info.second) { "离线模型不完整，请安装完整版本" }
                            check(part.renameTo(out))
                        } finally { part.delete() }
                    }
                    activity.runOnUiThread { result.success(dir.absolutePath) }
                } catch (e: Exception) {
                    activity.runOnUiThread { result.error("ASR_ASSETS", e.message, null) }
                }
            }
        }
    }
    fun close() { channel?.setMethodCallHandler(null); executor.shutdown() }
}
