package com.example.crypto_prices

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Renders the portfolio total on the home screen as a compact 4x1 row: total
 * USD value and its 24h change.
 *
 * Values are written from Dart via the `home_widget` package (see
 * WidgetService) and read here from HomeWidgetPlugin's SharedPreferences. The
 * total arrives pre-masked when the user has hidden their balances in the app.
 * Tapping the widget opens the app.
 */
class PortfolioWidgetProvider : AppWidgetProvider() {

    private companion object {
        const val GREEN = 0xFF16C784.toInt()
        const val RED = 0xFFEA3943.toInt()
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = HomeWidgetPlugin.getData(context)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.portfolio_widget)

            // With no holdings the total would read "$0.00", which looks like a
            // wiped portfolio — show the hint instead.
            val isEmpty = (prefs.getString("w_pf_empty", "0") ?: "0") == "1"
            views.setViewVisibility(R.id.pf_empty, if (isEmpty) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.pf_total, if (isEmpty) View.GONE else View.VISIBLE)

            val total = prefs.getString("w_pf_total", "") ?: ""
            views.setTextViewText(R.id.pf_total, total.ifBlank { "$0.00" })

            // Blank change means nothing could be valued yet — hide the field
            // rather than show a misleading +0.00%.
            val change = prefs.getString("w_pf_change", "") ?: ""
            if (isEmpty || change.isBlank()) {
                views.setViewVisibility(R.id.pf_change, View.GONE)
            } else {
                views.setViewVisibility(R.id.pf_change, View.VISIBLE)
                views.setTextViewText(R.id.pf_change, change)
                views.setTextColor(
                    R.id.pf_change,
                    if (change.startsWith("-")) RED else GREEN
                )
            }

            val updated = prefs.getString("w_updated", "") ?: ""
            views.setTextViewText(
                R.id.pf_updated_at,
                if (updated.isBlank()) "Tap to open" else "Updated $updated"
            )

            // Tapping anywhere opens the Flutter app.
            val pendingIntent: PendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java
            )
            views.setOnClickPendingIntent(R.id.portfolio_root, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
