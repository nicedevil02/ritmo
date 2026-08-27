package ir.ritmo.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle

/**
 * پایهٔ مشترک هر سطح ناتیوی که از یک اعلان اجرا می‌شود.
 * هیچ موتور Flutter بوت نمی‌کند.
 */
abstract class NotificationSurfaceActivity : Activity() {

    protected var reminderId: String = ""
    protected var notifId: Int = -1
    protected var title: String = ""
    protected var firstPhysicalStep: String? = null
    protected var allowMinimal: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        reminderId = intent.getStringExtra(EXTRA_REMINDER_ID).orEmpty()
        notifId = intent.getIntExtra(EXTRA_NOTIF_ID, -1)
        title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
        firstPhysicalStep = intent.getStringExtra(EXTRA_FIRST_STEP)
        allowMinimal = intent.getBooleanExtra(EXTRA_ALLOW_MINIMAL, false)

        if (reminderId.isEmpty()) {
            finish()
            return
        }
    }

    /** همیشه notifId را می‌فرستد تا گیرنده بتواند اعلان را ببندد. */
    protected fun sendAction(actionType: String, extras: Bundle? = null) {
        val i = Intent(this, NotificationActionReceiver::class.java).apply {
            action = ACTION_NOTIF_ACTION
            putExtra("actionType", actionType)
            putExtra("reminderId", reminderId)
            putExtra("notifId", notifId)
            extras?.let { putExtras(it) }
        }
        sendBroadcast(i)
    }

    protected fun snoozeMinutes(): Int =
        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.realm_quick_override_minutes", "50")
            ?.toIntOrNull() ?: 50

    protected fun toPersianDigits(input: String): String {
        val fa = charArrayOf('۰','۱','۲','۳','۴','۵','۶','۷','۸','۹')
        return buildString { input.forEach { c -> append(if (c in '0'..'9') fa[c - '0'] else c) } }
    }

    companion object {
        const val EXTRA_REMINDER_ID = "reminderId"
        const val EXTRA_NOTIF_ID = "notifId"
        const val EXTRA_TITLE = "title"
        const val EXTRA_FIRST_STEP = "firstPhysicalStep"
        const val EXTRA_ALLOW_MINIMAL = "allowMinimal"
        const val ACTION_NOTIF_ACTION = "com.ritmo.app.NOTIF_ACTION"
    }
}
