package de.inneso.familynexus

import android.content.Intent
import android.os.Bundle

/**
 * Nimmt den Rücksprung der Anmeldung beim Anbieter (OAuth, E-55, E-91) an und reicht ihn an MainActivity
 * weiter (Muster: AppAuth `RedirectUriReceiverActivity`). Ohne Oberfläche und ohne Flutter-Engine; das Theme
 * `Theme.Translucent.NoTitleBar` ist kein AppCompat-Theme, daher `android.app.Activity`.
 *
 * Weitergeleitet wird nur `io.github.carpeasrael.familynexus:/oauth` mit begrenzter Länge. `CLEAR_TOP` räumt
 * den Custom Tab über MainActivity (`singleTop`) ab; MainActivity nimmt den Link in `onNewIntent` bzw. beim
 * Kaltstart in `onCreate` an. Kein statischer Activity-Verweis.
 */
class OAuthRedirectActivity : android.app.Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val data = intent?.data
        if (intent?.action == Intent.ACTION_VIEW && data != null &&
            data.scheme == "io.github.carpeasrael.familynexus" && data.path == "/oauth" &&
            data.toString().length <= 2048
        ) {
            startActivity(
                Intent(this, MainActivity::class.java)
                    .setAction(Intent.ACTION_VIEW)
                    .setData(data)
                    .addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP,
                    ),
            )
        }
        finish()
    }
}
