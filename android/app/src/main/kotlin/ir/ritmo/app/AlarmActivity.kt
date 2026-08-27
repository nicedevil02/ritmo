package ir.ritmo.app

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AlarmActivity : NotificationSurfaceActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isFinishing) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            km?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        setContentView(R.layout.activity_alarm)

        val displayTitle = if (title.isNotEmpty()) title else getString(R.string.notif_vital_routine_title)

        val clockView = findViewById<TextView>(R.id.alarm_clock_text)
        val titleView = findViewById<TextView>(R.id.alarm_title_text)
        val firstStepContainer = findViewById<LinearLayout>(R.id.first_step_container)
        val firstStepText = findViewById<TextView>(R.id.first_step_text)
        val btnDone = findViewById<Button>(R.id.btn_alarm_done)
        val btnMinimal = findViewById<Button>(R.id.btn_alarm_minimal)
        val btnLater = findViewById<Button>(R.id.btn_alarm_later)

        val timeStr = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
        clockView.text = toPersianDigits(timeStr)
        titleView.text = displayTitle

        if (!firstPhysicalStep.isNullOrEmpty()) {
            firstStepContainer.visibility = View.VISIBLE
            firstStepText.text = firstPhysicalStep
        } else {
            firstStepContainer.visibility = View.GONE
        }

        btnMinimal.visibility = if (allowMinimal) View.VISIBLE else View.GONE

        btnDone.setOnClickListener {
            sendAction("DONE")
            finish()
        }

        btnMinimal.setOnClickListener {
            sendAction("MINIMAL")
            finish()
        }

        btnLater.setOnClickListener {
            sendAction("SNOOZE")
            finish()
        }
    }
}
