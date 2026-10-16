package br.org.ieadpe.ieadpe_converts

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
    }
}
