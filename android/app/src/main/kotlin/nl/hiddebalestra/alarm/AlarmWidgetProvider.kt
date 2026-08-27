package nl.hiddebalestra.alarm

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Shows the next upcoming alarm on the homescreen. Data is pushed from Dart
 * via [HomeWidgetService] any time the alarm list, or the "pause all"
 * setting, changes — see `app.dart`'s `syncNow`.
 */
class AlarmWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.alarm_widget_layout).apply {
                val time = widgetData.getString("next_alarm_time", null)
                if (time.isNullOrEmpty()) {
                    setTextViewText(R.id.widget_alarm_time, context.getString(R.string.widget_no_alarm))
                    setViewVisibility(R.id.widget_alarm_label, View.GONE)
                } else {
                    setTextViewText(R.id.widget_alarm_time, time)
                    val label = widgetData.getString("next_alarm_label", null)
                    if (label.isNullOrEmpty()) {
                        setViewVisibility(R.id.widget_alarm_label, View.GONE)
                    } else {
                        setViewVisibility(R.id.widget_alarm_label, View.VISIBLE)
                        setTextViewText(R.id.widget_alarm_label, label)
                    }
                }
                setOnClickPendingIntent(R.id.widget_root, openAppPendingIntent(context, widgetId))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    /// Tapping the widget just opens the app — no in-widget snooze/dismiss
    /// actions (that would need a background-isolate callback and a
    /// broadcast receiver, a lot more native surface for something that
    /// can't be verified on a device from here).
    private fun openAppPendingIntent(context: Context, widgetId: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            widgetId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
