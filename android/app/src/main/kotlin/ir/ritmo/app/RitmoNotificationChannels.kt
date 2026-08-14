package ir.ritmo.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build

object RitmoNotificationChannels {
    const val CRITICAL = NotificationChannels.CRITICAL
    const val ROUTINE = NotificationChannels.ROUTINE
    const val WORSHIP = NotificationChannels.WORSHIP
    const val PLANNING = NotificationChannels.PLANNING
    const val INSIGHT = NotificationChannels.INSIGHT
    const val PRIVATE_CHANNEL = NotificationChannels.PRIVATE_CHANNEL

    // Backward compatibility aliases
    const val ESSENTIAL = CRITICAL
    const val NORMAL = ROUTINE

    private val LEGACY = listOf("RitmoEssentialChannel", "RitmoNormalChannel", "RitmoEssentialChannel_v2", "RitmoNormalChannel_v2")

    fun ensure(context: Context, nm: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        LEGACY.forEach { legacyId ->
            try {
                nm.deleteNotificationChannel(legacyId)
            } catch (e: Exception) {}
        }

        val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val alarmAttrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val notifUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val notifAttrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        // 1. Critical Channel (Health, Medical, Vital)
        val criticalChannel = NotificationChannel(
            CRITICAL,
            "دارو و سلامت حیاتی",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "یادآوری‌های پزشکی و سلامت با اولویت بالا و عبور از ساعت سکوت"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 500, 200, 500)
            setSound(alarmUri, alarmAttrs)
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                setBypassDnd(true)
            }
            setShowBadge(true)
        }
        nm.createNotificationChannel(criticalChannel)

        // 2. Routine Channel
        val routineChannel = NotificationChannel(
            ROUTINE,
            "روتین‌ها و عادات روزمره",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "یادآوری کارها و روتین‌های روزمره زمان‌بندی‌شده"
            enableVibration(true)
            setSound(notifUri, notifAttrs)
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            setShowBadge(true)
        }
        nm.createNotificationChannel(routineChannel)

        // 3. Worship Channel
        val worshipChannel = NotificationChannel(
            WORSHIP,
            "اذان و عبادات",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "اوقات شرعی، اذان و یادآوری اعمال دینی با صدای مستقل"
            enableVibration(true)
            setSound(notifUri, notifAttrs)
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            setShowBadge(true)
        }
        nm.createNotificationChannel(worshipChannel)

        // 4. Planning Channel
        val planningChannel = NotificationChannel(
            PLANNING,
            "برنامه‌ریزی و بازبینی",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "برنامه‌ریزی روزانه، یادآور پیش‌خواب و مرورهای شبانه"
            enableVibration(true)
            setSound(notifUri, notifAttrs)
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            setShowBadge(true)
        }
        nm.createNotificationChannel(planningChannel)

        // 5. Insight Channel
        val insightChannel = NotificationChannel(
            INSIGHT,
            "بینش و دستیار هوشمند",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "تحلیل‌های سبک زندگی و توصیه‌های هوشمند دستیار ریتمو"
            enableVibration(true)
            setSound(notifUri, notifAttrs)
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            setShowBadge(true)
        }
        nm.createNotificationChannel(insightChannel)

        // 6. Private Channel
        val privateChannel = NotificationChannel(
            PRIVATE_CHANNEL,
            "اعلان‌های خصوصی",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "یادآوری چرخه سلامت، یادداشت‌های خصوصی و موارد محرمانه"
            enableVibration(true)
            setSound(notifUri, notifAttrs)
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            setShowBadge(false)
        }
        nm.createNotificationChannel(privateChannel)
    }
}
