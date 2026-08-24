package ir.ritmo.app

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StrikethroughSpan
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject

class RitmoTasksWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    private val TAG = "RitmoTasksWidgetFact"
    private val items = mutableListOf<JSONObject>()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        items.clear()
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.widget_tasks_snapshot", null) ?: return
            val root = JSONObject(raw)
            val list: JSONArray = root.optJSONArray("tasks") ?: return
            for (i in 0 until list.length()) {
                list.optJSONObject(i)?.let { items.add(it) }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error loading/parsing tasks snapshot: ${e.message}", e)
        }
    }

    override fun onDestroy() {
        items.clear()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.ritmo_tasks_widget_item)
        if (position < 0 || position >= items.size) return views

        val m = items[position]
        val taskId = m.optString("id", "")
        val titleText = m.optString("title", "")
        val isDone = m.optBoolean("isDone", false)
        val isImportant = m.optBoolean("isImportant", false)

        // 1. Title formatting (strike-through if done)
        if (isDone) {
            val span = SpannableString(titleText)
            span.setSpan(StrikethroughSpan(), 0, titleText.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            views.setTextViewText(R.id.item_title, span)
            views.setTextColor(R.id.item_title, Color.parseColor("#6B7280"))
        } else {
            views.setTextViewText(R.id.item_title, titleText)
            views.setTextColor(R.id.item_title, Color.parseColor("#ECEEF3"))
        }

        // 2. Checkbox image
        if (isDone) {
            views.setImageViewResource(R.id.item_check_btn, R.drawable.ic_checkbox_checked)
        } else {
            views.setImageViewResource(R.id.item_check_btn, R.drawable.ic_checkbox_unchecked)
        }

        // 3. Star visibility
        views.setViewVisibility(R.id.item_star, if (isImportant) View.VISIBLE else View.GONE)

        // 4. Fill-in intent for checkbox (Toggle task completion)
        val checkFillIn = Intent().apply {
            putExtra("clickAction", "TICK_TASK")
            putExtra("taskId", taskId)
            putExtra("currentDone", isDone)
        }
        views.setOnClickFillInIntent(R.id.item_check_btn, checkFillIn)

        // 5. Fill-in intent for row tap (Open App to tasks)
        val rootFillIn = Intent().apply {
            putExtra("clickAction", "OPEN_TASKS")
            putExtra("taskId", taskId)
        }
        views.setOnClickFillInIntent(R.id.item_root, rootFillIn)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true
}
