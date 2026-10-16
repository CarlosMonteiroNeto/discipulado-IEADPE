package br.org.ieadpe.ieadpe_converts

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var chooser: MethodChannel.Result? = null
    private var selected: Uri? = null
    private var writing = false
    private val exportRequest = 24014

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "br.org.ieadpe/locale")
            .setMethodCallHandler { call, result ->
                if (call.method != "sortPortuguese") {
                    result.notImplemented()
                } else {
                    val names = call.arguments as? List<*>
                    if (names == null || names.any { it !is String }) {
                        result.error("invalid", "Invalid locale input", null)
                    } else {
                        result.success(PortugueseCollation.sort(names.filterIsInstance<String>()))
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "br.org.ieadpe/import-progress")
            .setMethodCallHandler { call, result ->
                val key = call.argument<String>("key")
                val value = call.argument<String>("value")
                val uuid = "[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}"
                if (key == null || !Regex("$uuid:$uuid").matches(key) ||
                    (call.method == "write" && (value == null || !Regex(uuid).matches(value)))) {
                    result.error("invalid", "Invalid progress identifier", null)
                } else {
                    val prefs = getSharedPreferences("ieadpe_import_progress_v1", MODE_PRIVATE)
                    when (call.method) {
                        "read" -> result.success(prefs.getString(key, null))
                        "write" -> if (prefs.edit().putString(key, value).commit()) result.success(true)
                            else result.error("unavailable", "Progress unavailable", null)
                        "remove" -> if (prefs.edit().remove(key).commit()) result.success(true)
                            else result.error("unavailable", "Progress unavailable", null)
                        else -> result.notImplemented()
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "br.org.ieadpe/export")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "choose" -> {
                        val filename = call.argument<String>("filename")
                        if (chooser != null || writing) {
                            result.error("busy", "An export is already active", null)
                        } else if (filename.isNullOrBlank() || filename.contains('/') || filename.contains('\\')) {
                            result.error("invalid", "Invalid filename", null)
                        } else {
                            selected = null
                            chooser = result
                            try {
                                startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                                    putExtra(Intent.EXTRA_TITLE, filename)
                                }, exportRequest)
                            } catch (_: Exception) {
                                chooser = null
                                result.error("unavailable", "Cannot open destination picker", null)
                            }
                        }
                    }
                    "write" -> {
                        val uri = selected
                        val requested = call.argument<String>("uri")
                        val bytes = call.argument<ByteArray>("bytes")
                        if (writing || uri == null || requested != uri.toString() || bytes == null) {
                            result.error("invalid", "No selected destination", null)
                        } else {
                            selected = null
                            writing = true
                            // Dart checks the protected context after the picker, before this handoff.
                            Thread {
                                var success = false
                                try {
                                    ExportWriter.write({ contentResolver.openOutputStream(uri, "wt") }, bytes)
                                    success = true
                                } catch (_: Exception) {
                                    // Do not expose provider exceptions or document identifiers.
                                } finally {
                                    bytes.fill(0)
                                }
                                runOnUiThread {
                                    writing = false
                                    if (success) result.success(true)
                                    else result.error("write_failed", "Could not write destination", null)
                                }
                            }.start()
                        }
                    }
                    "discard" -> { selected = null; result.success(null) }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Android activity callback required by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != exportRequest) return
        val result = chooser ?: return
        chooser = null
        if (resultCode == Activity.RESULT_CANCELED) {
            selected = null
            result.success(null)
        } else if (resultCode == Activity.RESULT_OK && data?.data != null) {
            selected = data.data
            result.success(selected.toString())
        } else {
            selected = null
            result.error("destination_failed", "No destination selected", null)
        }
    }

    override fun onDestroy() {
        chooser?.error("detached", "Export owner was destroyed", null)
        chooser = null
        selected = null
        super.onDestroy()
    }
}
