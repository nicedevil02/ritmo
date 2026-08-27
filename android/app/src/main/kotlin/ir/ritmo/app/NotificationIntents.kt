package ir.ritmo.app

import android.app.PendingIntent
import android.content.Context
import android.content.Intent

object NotificationIntents {

    const val ACTION_OPEN_ROUTINE = "com.ritmo.app.OPEN_ROUTINE"

    const val TAP_OPEN_APP = "OPEN_APP"
    const val TAP_POPUP = "POPUP"
    const val TAP_POPUP_ESSENTIAL = "POPUP_FOR_ESSENTIAL"

    private const val PREFS = "FlutterSharedPreferences"
    private const val KEY_TAP_BEHAVIOR = "flutter.notif_tap_behavior"
    private const val KEY_REALM_MODE = "flutter.active_realm_mode"

    fun tapBehavior(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_TAP_BEHAVIOR, TAP_POPUP_ESSENTIAL) ?: TAP_POPUP_ESSENTIAL

    fun openRoutineIntent(context: Context, reminderId: String): Intent =
        Intent(context, MainActivity::class.java).apply {
            action = ACTION_OPEN_ROUTINE
            putExtra(NotificationSurfaceActivity.EXTRA_REMINDER_ID, reminderId)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

    /**
     * تنها منبع حقیقت برای «ضربه روی بدنهٔ اعلان چه می‌کند».
     * جایگزین هر چهار setContentIntent موجود می‌شود.
     */
    fun buildTapIntent(
        context: Context,
        reminderId: String,
        notifId: Int,
        title: String,
        firstPhysicalStep: String?,
        isEssential: Boolean,
    ): PendingIntent {
        val mode = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_REALM_MODE, "NORMAL")

        val behavior = tapBehavior(context)
        val wantsPopup = when (behavior) {
            TAP_POPUP -> true
            TAP_POPUP_ESSENTIAL -> isEssential
            else -> false
        } && mode != "SILENT"

        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

        return if (wantsPopup) {
            val i = Intent(context, QuickActionActivity::class.java).apply {
                putExtra(NotificationSurfaceActivity.EXTRA_REMINDER_ID, reminderId)
                putExtra(NotificationSurfaceActivity.EXTRA_NOTIF_ID, notifId)
                putExtra(NotificationSurfaceActivity.EXTRA_TITLE, title)
                putExtra(NotificationSurfaceActivity.EXTRA_FIRST_STEP, firstPhysicalStep)
                this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            PendingIntent.getActivity(
                context,
                AlarmChannelRegistrar.generateRequestCode(reminderId, "_POPUP"),
                i,
                pendingFlags,
            )
        } else {
            PendingIntent.getActivity(
                context,
                AlarmChannelRegistrar.generateRequestCode(reminderId, "_NOTIF"),
                openRoutineIntent(context, reminderId),
                pendingFlags,
            )
        }
    }
}
