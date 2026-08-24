package ir.ritmo.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.RemoteViews
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import org.json.JSONObject

class RitmoTasksWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "RitmoTasksWidget"
        const val ACTION_REFRESH = "com.ritmo.app.TASKS_WIDGET_REFRESH"
        const val ACTION_CLICK_ITEM = "com.ritmo.app.TASKS_WIDGET_CLICK"

        private var sBackgroundEngine: FlutterEngine? = null
        private var sMethodChannel: MethodChannel? = null

        fun refreshAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, RitmoTasksWidgetProvider::class.java))
            if (ids.isEmpty()) return
            mgr.notifyAppWidgetViewDataChanged(ids, R.id.tasks_list)
            for (id in ids) {
                updateAppWidget(context, mgr, id)
            }
        }

        private fun updateAppWidget(context: Context, mgr: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.ritmo_tasks_widget_layout)

            // 1. Render Header from SharedPrefs snapshot
            try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val rawJson = prefs.getString("flutter.widget_tasks_snapshot", null)

                if (rawJson != null) {
                    val root = JSONObject(rawJson)
                    val headerTitle = root.optString("headerTitle", "کارهای امروز")
                    val remainingText = root.optString("remainingText", "۰ کار مانده")

                    views.setTextViewText(R.id.widget_tasks_header_text, headerTitle)
                    views.setTextViewText(R.id.widget_tasks_remaining_text, remainingText)
                } else {
                    views.setTextViewText(R.id.widget_tasks_header_text, "کارهای امروز")
                    views.setTextViewText(R.id.widget_tasks_remaining_text, "کاری برای امروز نیست")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error rendering header: ${e.message}", e)
                views.setTextViewText(R.id.widget_tasks_header_text, "کارهای امروز")
                views.setTextViewText(R.id.widget_tasks_remaining_text, "خطا در بارگذاری")
            }

            // 2. Set RemoteAdapter for ListView
            val serviceIntent = Intent(context, RitmoTasksWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.tasks_list, serviceIntent)
            views.setEmptyView(R.id.tasks_list, R.id.widget_tasks_empty)

            // 3. Set click PendingIntent Template
            val mutableFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
            val clickTemplate = PendingIntent.getBroadcast(
                context,
                appWidgetId,
                Intent(context, RitmoTasksWidgetProvider::class.java).apply {
                    action = ACTION_CLICK_ITEM
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                },
                PendingIntent.FLAG_UPDATE_CURRENT or mutableFlag
            )
            views.setPendingIntentTemplate(R.id.tasks_list, clickTemplate)

            // 4. Header click opens MainActivity
            val openAppPendingIntent = PendingIntent.getActivity(
                context,
                100,
                Intent(context, MainActivity::class.java).apply {
                    action = "com.ritmo.app.OPEN_TASKS"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_tasks_header_text, openAppPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_tasks_remaining_text, openAppPendingIntent)

            // 5. Quick Add Button click opens MainActivity with focus_add_task
            val quickAddPendingIntent = PendingIntent.getActivity(
                context,
                101,
                Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    putExtra("focus_add_task", true)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_tasks_add_btn, quickAddPendingIntent)

            // 6. Refresh button click
            val refreshPendingIntent = PendingIntent.getBroadcast(
                context,
                102,
                Intent(context, RitmoTasksWidgetProvider::class.java).apply {
                    action = ACTION_REFRESH
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_tasks_refresh_btn, refreshPendingIntent)

            mgr.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        Log.d(TAG, "onReceive action: ${intent.action}")

        when (intent.action) {
            ACTION_REFRESH -> {
                refreshAll(context)
            }
            ACTION_CLICK_ITEM -> {
                val clickAction = intent.getStringExtra("clickAction") ?: "OPEN_TASKS"
                if (clickAction == "TICK_TASK") {
                    val taskId = intent.getStringExtra("taskId")
                    val currentDone = intent.getBooleanExtra("currentDone", false)

                    if (taskId != null && taskId.isNotEmpty()) {
                        Log.d(TAG, "Toggling task $taskId from widget in background")
                        toggleTaskInBackground(context.applicationContext, taskId, !currentDone)
                    }
                } else {
                    val launchIntent = Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        action = "com.ritmo.app.OPEN_TASKS"
                        putExtra("taskId", intent.getStringExtra("taskId"))
                    }
                    context.startActivity(launchIntent)
                }
            }
        }
    }

    private fun toggleTaskInBackground(context: Context, taskId: String, newDoneState: Boolean) {
        val pendingResult = goAsync()

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val handle = prefs.getLong("flutter.notification_action_callback_handle", 0L)

        if (handle == 0L) {
            Log.e(TAG, "Background execution handle not registered in SharedPrefs")
            pendingResult.finish()
            return
        }

        Handler(Looper.getMainLooper()).post {
            try {
                val flutterLoader = FlutterInjector.instance().flutterLoader()
                flutterLoader.startInitialization(context)
                flutterLoader.ensureInitializationComplete(context, null)

                var isNewEngine = false
                if (sBackgroundEngine == null) {
                    val engine = FlutterEngine(context)
                    val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(handle)
                    if (callbackInfo == null) {
                        Log.e(TAG, "Could not find callback info for handle $handle")
                        pendingResult.finish()
                        return@post
                    }
                    engine.dartExecutor.executeDartCallback(
                        DartExecutor.DartCallback(
                            context.assets,
                            flutterLoader.findAppBundlePath(),
                            callbackInfo
                        )
                    )
                    sBackgroundEngine = engine
                    AlarmChannelRegistrar.register(context, engine.dartExecutor.binaryMessenger)
                    sMethodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.ritmo.app/notif_action_bg")
                    isNewEngine = true
                }

                val channel = sMethodChannel!!
                val invokeDirect = {
                    channel.invokeMethod(
                        "setTaskDoneDirect",
                        mapOf("taskId" to taskId, "done" to newDoneState),
                        object : MethodChannel.Result {
                            override fun success(result: Any?) {
                                Log.d(TAG, "Successfully toggled task $taskId to $newDoneState")
                                refreshAll(context)
                                pendingResult.finish()
                            }

                            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                                Log.e(TAG, "Dart error toggling task: $errorMessage")
                                pendingResult.finish()
                            }

                            override fun notImplemented() {
                                Log.e(TAG, "setTaskDoneDirect not implemented in Dart")
                                pendingResult.finish()
                            }
                        }
                    )
                }

                if (isNewEngine) {
                    channel.setMethodCallHandler { call, result ->
                        if (call.method == "dispatcherReady") {
                            invokeDirect()
                            result.success(null)
                        } else {
                            result.notImplemented()
                        }
                    }
                } else {
                    invokeDirect()
                }

            } catch (e: Exception) {
                Log.e(TAG, "Failed to run background task toggle: ${e.message}", e)
                pendingResult.finish()
            }
        }
    }
}
