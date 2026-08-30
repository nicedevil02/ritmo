package ir.ritmo.app

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.sqlite.SQLiteDatabase
import android.graphics.Color
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class RitmoForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "RitmoForegroundServiceChannel"
        const val NOTIFICATION_ID = 9999

        const val ACTION_START_STATUS = "com.ritmo.app.ACTION_START_STATUS"
        const val ACTION_START_TIMER = "com.ritmo.app.ACTION_START_TIMER"

        const val ACTION_TIMER_TICK = "com.ritmo.app.ACTION_TIMER_TICK"
        const val ACTION_TIMER_COMPLETE = "com.ritmo.app.ACTION_TIMER_COMPLETE"
    }

    private var mode = "STATUS" // STATUS or TIMER
    private var timerTitle = ""
    private var durationSeconds = 0
    private var elapsedSeconds = 0

    // Cached status metrics
    private var lastZone = "آزاد"
    private var lastEnergy = "متوسط"
    private var lastProposedTask = "استراحت 🌿"
    private var lastProposedTaskId: String? = null
    private var lastCompletedRoutines = 0
    private var lastTotalRoutines = 0
    private var lastCompletedPrayers = 0
    private var lastTotalPrayers = 0
    private var lastZoneNames = ArrayList<String>()
    private var lastZoneIds = ArrayList<String>()

    private val handler = Handler(Looper.getMainLooper())
    private val timerRunnable = object : Runnable {
        override fun run() {
            if (elapsedSeconds < durationSeconds) {
                elapsedSeconds++
                sendTimerBroadcast(ACTION_TIMER_TICK)
                handler.postDelayed(this, 1000)
            } else {
                sendTimerBroadcast(ACTION_TIMER_COMPLETE)
                stopSelf()
            }
        }
    }

    private var wakeLock: android.os.PowerManager.WakeLock? = null

    private fun acquireWakeLock(timeoutMs: Long = 300_000L) {
        if (wakeLock == null) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            wakeLock = powerManager.newWakeLock(android.os.PowerManager.PARTIAL_WAKE_LOCK, "Ritmo:ForegroundServiceWakeLock")
        }
        if (wakeLock?.isHeld == false) {
            wakeLock?.acquire(timeoutMs)
        }
    }

    private fun releaseWakeLock() {
        if (wakeLock?.isHeld == true) {
            try {
                wakeLock?.release()
            } catch (e: Exception) {
                Log.e("RitmoForegroundService", "Error releasing wake lock: ${e.message}")
            }
        }
    }

    // Screen State Receiver for Smart Privacy Lockscreen Shield
    private val screenStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (mode == "STATUS") {
                updateStatusNotification()
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        
        // Register screen locking/unlocking receivers
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(screenStateReceiver, filter)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            val action = intent.action
            if (action == ACTION_START_STATUS) {
                handler.removeCallbacks(timerRunnable)
                mode = "STATUS"
                
                lastZone = intent.getStringExtra("zone") ?: "آزاد"
                lastEnergy = intent.getStringExtra("energy") ?: "متوسط"
                lastProposedTask = intent.getStringExtra("proposedTask") ?: "استراحت 🌿"
                lastProposedTaskId = intent.getStringExtra("proposedTaskId")
                lastCompletedRoutines = intent.getIntExtra("completedRoutines", 0)
                lastTotalRoutines = intent.getIntExtra("totalRoutines", 0)
                lastCompletedPrayers = intent.getIntExtra("completedPrayers", 0)
                lastTotalPrayers = intent.getIntExtra("totalPrayers", 0)
                
                val names = intent.getStringArrayListExtra("zoneNames")
                val ids = intent.getStringArrayListExtra("zoneIds")
                if (names != null && ids != null) {
                    lastZoneNames = names
                    lastZoneIds = ids
                }
                
                // Status notifications in Android do not need CPU wakelock; release it so CPU can sleep
                releaseWakeLock()
                startStatusForeground()
            } else if (action == ACTION_START_TIMER) {
                mode = "TIMER"
                timerTitle = intent.getStringExtra("title") ?: "روتین"
                durationSeconds = intent.getIntExtra("durationSeconds", 0)
                elapsedSeconds = intent.getIntExtra("elapsedSeconds", 0)

                // Only acquire temporary wakelock bounded by remaining timer duration
                val remainingMs = ((durationSeconds - elapsedSeconds + 30) * 1000L).coerceIn(10_000L, 7_200_000L)
                acquireWakeLock(remainingMs)

                startTimerForeground()
                handler.removeCallbacks(timerRunnable)
                handler.postDelayed(timerRunnable, 1000)
            }
        }
        return START_NOT_STICKY
    }

    private fun isDeviceLocked(): Boolean {
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return keyguardManager.isKeyguardLocked
    }

    private fun getSettingFromDb(key: String, defaultValue: String): String {
        var value = defaultValue
        try {
            val dbPath = getDatabasePath(DatabaseConfig.DATABASE_NAME)
            if (dbPath.exists()) {
                val db = SQLiteDatabase.openDatabase(dbPath.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
                val cursor = db.query("app_settings", arrayOf("value"), "key = ?", arrayOf(key), null, null, null)
                if (cursor.moveToFirst()) {
                    value = cursor.getString(0) ?: defaultValue
                }
                cursor.close()
                db.close()
            }
        } catch (e: Exception) {
            Log.e("RitmoForegroundService", "Error reading DB setting " + key + ": " + e.message)
        }
        return value
    }

    private fun startStatusForeground() {
        val collapsedViews = buildCollapsedStatusRemoteViews()
        val expandedViews = buildExpandedStatusRemoteViews()

        val notificationIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setCustomContentView(collapsedViews)
            .setCustomBigContentView(expandedViews)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)

        startForeground(NOTIFICATION_ID, builder.build())
    }

    fun updateStatusNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        val collapsedViews = buildCollapsedStatusRemoteViews()
        val expandedViews = buildExpandedStatusRemoteViews()

        val notificationIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setCustomContentView(collapsedViews)
            .setCustomBigContentView(expandedViews)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)

        notificationManager.notify(NOTIFICATION_ID, builder.build())
    }

    private fun toPersianDigits(text: String): String {
        val persianDigits = charArrayOf('۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹')
        val builder = StringBuilder()
        for (ch in text) {
            if (ch in '0'..'9') {
                builder.append(persianDigits[ch - '0'])
            } else {
                builder.append(ch)
            }
        }
        return builder.toString()
    }

    private fun buildCollapsedStatusRemoteViews(): RemoteViews {
        val views = RemoteViews(packageName, R.layout.ritmo_notification_status_collapsed)
        val isLocked = isDeviceLocked()

        if (isLocked) {
            views.setTextViewText(R.id.txt_collapsed_task, "ریتمو در جریان است 🌿")
            views.setTextViewText(R.id.txt_collapsed_status, "برای مشاهده جزئیات قفل را باز کنید")
            views.setViewVisibility(R.id.btn_collapsed_done_container, View.GONE)
        } else {
            val completed = lastCompletedRoutines + lastCompletedPrayers
            val total = lastTotalRoutines + lastTotalPrayers

            val hasTask = lastProposedTaskId != null && lastProposedTaskId!!.isNotEmpty() &&
                !lastProposedTaskId.equals("REST", ignoreCase = true) &&
                !lastProposedTaskId.equals("REST_TIME", ignoreCase = true)

            if (hasTask) {
                views.setTextViewText(R.id.txt_collapsed_task, "اقدام بعدی: " + lastProposedTask)
                views.setTextViewText(
                    R.id.txt_collapsed_status,
                    toPersianDigits(completed.toString()) + " از " + toPersianDigits(total.toString()) + " کار امروز"
                )
                views.setViewVisibility(R.id.btn_collapsed_done_container, View.VISIBLE)

                val doneIntent = Intent(this, NotificationActionReceiver::class.java).apply {
                    action = "COMPLETE_ROUTINE"
                    putExtra("actionType", "COMPLETE_ROUTINE")
                    putExtra("routineId", lastProposedTaskId)
                    val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                    putExtra("dateStr", sdf.format(Date()))
                    putExtra("notifId", NOTIFICATION_ID)
                }
                val donePendingIntent = PendingIntent.getBroadcast(
                    this,
                    3,
                    doneIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.btn_collapsed_done, donePendingIntent)
            } else {
                views.setTextViewText(R.id.txt_collapsed_task, "ریتمو در جریان است 🌿")
                val statusText = if (total > 0 && completed >= total) {
                    "همه " + toPersianDigits(total.toString()) + " کار امروز تکمیل شد ✨"
                } else {
                    "زمان استراحت و ریکاوری ذهنی ☕"
                }
                views.setTextViewText(R.id.txt_collapsed_status, statusText)
                views.setViewVisibility(R.id.btn_collapsed_done_container, View.GONE)
            }
        }

        return views
    }

    private fun buildExpandedStatusRemoteViews(): RemoteViews {
        val views = RemoteViews(packageName, R.layout.ritmo_notification_status_expanded)
        val isLocked = isDeviceLocked()

        if (isLocked) {
            views.setTextViewText(R.id.txt_expanded_task_title, "ریتمو فعال است 🌿")
            views.setTextViewText(R.id.txt_expanded_task_desc, "برای دسترسی سریع قفل را باز کنید")
            views.setViewVisibility(R.id.layout_action_buttons, View.GONE)
            views.setViewVisibility(R.id.progressBar_today, View.GONE)
            views.setTextViewText(R.id.txt_expanded_stats, "")
        } else {
            views.setViewVisibility(R.id.progressBar_today, View.VISIBLE)

            // 1. Calculate and bind progress stats
            val completed = lastCompletedRoutines + lastCompletedPrayers
            val total = lastTotalRoutines + lastTotalPrayers
            val progressPercent = if (total > 0) (completed * 100) / total else 0
            views.setProgressBar(R.id.progressBar_today, 100, progressPercent, false)
            
            views.setTextViewText(
                R.id.txt_expanded_stats,
                "کارهای امروز: " + toPersianDigits(completed.toString()) + " از " + toPersianDigits(total.toString()) + " (" + toPersianDigits(progressPercent.toString()) + "٪)"
            )

            // 2. Set next proposed task and action buttons
            val hasTask = lastProposedTaskId != null && lastProposedTaskId!!.isNotEmpty() &&
                !lastProposedTaskId.equals("REST", ignoreCase = true) &&
                !lastProposedTaskId.equals("REST_TIME", ignoreCase = true)

            if (hasTask) {
                views.setTextViewText(R.id.txt_expanded_task_title, "اقدام بعدی: " + lastProposedTask)
                views.setTextViewText(R.id.txt_expanded_task_desc, "پیشنهاد هوشمند ریتمو بر اساس بازهٔ زمانی جاری")
                views.setViewVisibility(R.id.layout_action_buttons, View.VISIBLE)

                // Action 1: Done
                val doneIntent = Intent(this, NotificationActionReceiver::class.java).apply {
                    action = "COMPLETE_ROUTINE"
                    putExtra("actionType", "COMPLETE_ROUTINE")
                    putExtra("routineId", lastProposedTaskId)
                    val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                    putExtra("dateStr", sdf.format(Date()))
                    putExtra("notifId", NOTIFICATION_ID)
                }
                val donePendingIntent = PendingIntent.getBroadcast(
                    this,
                    4,
                    doneIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.btn_expanded_done, donePendingIntent)

                // Action 2: Start Timer (Direct switch to Timer Mode in service)
                val timerIntent = Intent(this, RitmoForegroundService::class.java).apply {
                    action = ACTION_START_TIMER
                    putExtra("title", lastProposedTask)
                    putExtra("durationSeconds", 25 * 60)
                    putExtra("elapsedSeconds", 0)
                }
                val timerPendingIntent = PendingIntent.getService(
                    this,
                    5,
                    timerIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.btn_expanded_timer, timerPendingIntent)

                // Action 3: Snooze Routine
                val snoozeIntent = Intent(this, NotificationActionReceiver::class.java).apply {
                    action = "SNOOZE_ROUTINE"
                    putExtra("actionType", "SNOOZE_ROUTINE")
                    putExtra("routineId", lastProposedTaskId)
                    putExtra("notifId", NOTIFICATION_ID)
                }
                val snoozePendingIntent = PendingIntent.getBroadcast(
                    this,
                    6,
                    snoozeIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.btn_expanded_snooze, snoozePendingIntent)
            } else {
                views.setTextViewText(R.id.txt_expanded_task_title, "زمان استراحت و ریکاوری 🌿")
                val desc = if (total > 0 && completed >= total) {
                    "تبریک! همهٔ برنامه‌های امروز شما با موفقیت تکمیل شدند ✨"
                } else {
                    "در حال حاضر روتینی در انتظار نیست. ذهن خود را برای بازه بعدی آماده کنید."
                }
                views.setTextViewText(R.id.txt_expanded_task_desc, desc)
                views.setViewVisibility(R.id.layout_action_buttons, View.GONE)
            }
        }

        return views
    }

    private fun startTimerForeground() {
        val notification = buildTimerNotification()
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun updateTimerNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, buildTimerNotification())
    }

    private fun buildTimerNotification(): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val isPaused = timerTitle.contains("متوقف‌شده") || timerTitle.contains("paused")
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("تایمر روتین: " + timerTitle)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true)

        if (isPaused) {
            val remaining = durationSeconds - elapsedSeconds
            val min = remaining / 60
            val sec = remaining % 60
            val timeStr = String.format(Locale.US, "%02d:%02d", min, sec)
            builder.setContentText("زمان باقی‌مانده: " + timeStr)
            builder.setUsesChronometer(false)
        } else {
            builder.setUsesChronometer(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && durationSeconds > 0) {
                val remainingMs = (durationSeconds - elapsedSeconds) * 1000L
                builder.setWhen(System.currentTimeMillis() + remainingMs)
                builder.setChronometerCountDown(true)
            } else {
                builder.setWhen(System.currentTimeMillis() - elapsedSeconds * 1000L)
            }
        }

        return builder.build()
    }

    private fun sendTimerBroadcast(action: String) {
        val intent = Intent(action).apply {
            putExtra("title", timerTitle)
            putExtra("durationSeconds", durationSeconds)
            putExtra("elapsedSeconds", elapsedSeconds)
        }
        sendBroadcast(intent)
    }

    override fun onDestroy() {
        handler.removeCallbacks(timerRunnable)
        releaseWakeLock()
        try {
            unregisterReceiver(screenStateReceiver)
        } catch (e: Exception) {}
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Ritmo Persistent Engine Channel",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }
}