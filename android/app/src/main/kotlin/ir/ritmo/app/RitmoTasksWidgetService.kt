package ir.ritmo.app

import android.content.Intent
import android.widget.RemoteViewsService

class RitmoTasksWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return RitmoTasksWidgetFactory(applicationContext)
    }
}
