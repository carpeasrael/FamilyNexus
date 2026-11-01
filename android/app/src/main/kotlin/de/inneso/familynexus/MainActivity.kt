package de.inneso.familynexus

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PersistableBundle

/**
 * Android-Adapter. Enthält nur Plattformbrücken; keine Fachlogik.
 * FlutterFragmentActivity wird von local_auth (BiometricPrompt) benötigt.
 */
class MainActivity : FlutterFragmentActivity() {
    private var linkChannel: MethodChannel? = null
    private var initialLink: String? = null

    /**
     * Nur familynexus://join-Links und der Rücksprung der Browser-Anmeldung (OAuth) mit begrenzter
     * Länge werden an Dart weitergereicht.
     */
    private fun linkFrom(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) return null
        val data = intent.data ?: return null
        val invite = data.scheme == "familynexus" && data.host == "join"
        val oauth = data.scheme == "io.github.carpeasrael.familynexus" && data.path == "/oauth"
        if (!invite && !oauth) return null
        val text = data.toString()
        return if (text.length <= 2048) text else null
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        linkFrom(intent)?.let { linkChannel?.invokeMethod("onLink", it) }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        initialLink = linkFrom(intent)
        // Sichere Voreinstellung: Schutz gilt ab dem ersten Frame; Dart schaltet nur ab,
        // wenn der Nutzer es in den Einstellungen so wählt.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        linkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "de.inneso.familynexus/links").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialLink" -> {
                        result.success(initialLink)
                        initialLink = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "de.inneso.familynexus/window")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        val secure = call.arguments as? Boolean ?: true
                        if (secure) {
                            window.setFlags(
                                WindowManager.LayoutParams.FLAG_SECURE,
                                WindowManager.LayoutParams.FLAG_SECURE,
                            )
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    // Notfall-Schlüssel kopieren (E-57/SA-8): als „vertraulich“ markiert, damit Android 13+
                    // keine Vorschau zeigt und Tastatur-Apps ihn nicht in den Verlauf übernehmen.
                    // "copySensitive": längere sensible Texte (Datenprotokoll, #157), Grenze 100 000 Zeichen
                    // wegen des Binder-Limits; schlägt das Setzen fehl, meldet der Kanal "failed" (Dart fällt
                    // dann auf die normale Zwischenablage zurück und leert sie später).
                    "copySecret", "copySensitive" -> {
                        val text = call.arguments as? String
                        val limit = if (call.method == "copySecret") 512 else 100_000
                        if (text == null || text.length > limit) {
                            result.error("invalid", null, null)
                        } else {
                            try {
                                val clip = ClipData.newPlainText("FamilyNexus", text)
                                val extras = PersistableBundle()
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                    extras.putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
                                } else {
                                    extras.putBoolean("android.content.extra.IS_SENSITIVE", true)
                                }
                                clip.description.extras = extras
                                (getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(clip)
                                result.success(null)
                            } catch (e: RuntimeException) {
                                result.error("failed", null, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
