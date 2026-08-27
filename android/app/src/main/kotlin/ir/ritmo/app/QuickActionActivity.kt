package ir.ritmo.app

import android.app.NotificationManager
import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.Button
import android.widget.TextView

class QuickActionActivity : NotificationSurfaceActivity() {

    private val autoDismiss = Handler(Looper.getMainLooper())
    private val dismissRunnable = Runnable { finish() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isFinishing) return

        setContentView(R.layout.dialog_quick_action)

        findViewById<TextView>(R.id.popup_title).text = title
        findViewById<TextView>(R.id.popup_realm).text = realmLabel()

        val stepView = findViewById<TextView>(R.id.popup_first_step)
        if (firstPhysicalStep.isNullOrBlank()) {
            stepView.visibility = View.GONE
        } else {
            stepView.visibility = View.VISIBLE
            stepView.text = getString(R.string.popup_first_step, firstPhysicalStep)
        }

        findViewById<Button>(R.id.popup_btn_done).setOnClickListener {
            sendAction("DONE")
            dismissNotification()
            finish()
        }

        val mins = snoozeMinutes()
        findViewById<Button>(R.id.popup_btn_snooze).apply {
            text = getString(R.string.popup_snooze, toPersianDigits(mins.toString()))
            setOnClickListener {
                sendAction("SNOOZE")
                dismissNotification()
                finish()
            }
        }

        findViewById<Button>(R.id.popup_btn_open).setOnClickListener {
            startActivity(NotificationIntents.openRoutineIntent(this, reminderId))
            finish()
        }

        // بستن خودکار پس از ۳۰ ثانیه تا روی صفحه نماند
        autoDismiss.postDelayed(dismissRunnable, 30_000L)
    }

    override fun onDestroy() {
        autoDismiss.removeCallbacks(dismissRunnable)
        super.onDestroy()
    }

    private fun dismissNotification() {
        if (notifId > 0) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.cancel(notifId)
        }
    }

    private fun realmLabel(): String {
        val p = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val icon = p.getString("flutter.active_realm_icon", "🎯") ?: "🎯"
        val name = p.getString("flutter.active_realm_name", "آزاد") ?: "آزاد"
        return "$icon $name"
    }
}
