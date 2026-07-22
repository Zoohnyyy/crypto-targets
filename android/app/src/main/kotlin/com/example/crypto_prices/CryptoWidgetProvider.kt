package com.example.crypto_prices

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Renders up to 4 coins with live price + 24h change on the home screen.
 *
 * Values are written from Dart via the `home_widget` package
 * (see WidgetService) and read here from HomeWidgetPlugin's SharedPreferences.
 * Tapping the widget opens the app.
 */
class CryptoWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = HomeWidgetPlugin.getData(context)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.crypto_widget)

            // Row ids in the layout, paired with their data keys.
            val rows = listOf(
                Triple(R.id.ticker_0, R.id.price_0, R.id.change_0),
                Triple(R.id.ticker_1, R.id.price_1, R.id.change_1),
                Triple(R.id.ticker_2, R.id.price_2, R.id.change_2),
                Triple(R.id.ticker_3, R.id.price_3, R.id.change_3),
            )
            val rowContainers = listOf(
                R.id.row_0, R.id.row_1, R.id.row_2, R.id.row_3
            )

            for (i in rows.indices) {
                val ticker = prefs.getString("w_ticker_$i", "") ?: ""
                val price = prefs.getString("w_price_$i", "") ?: ""
                val change = prefs.getString("w_change_$i", "") ?: ""

                if (ticker.isBlank()) {
                    views.setViewVisibility(rowContainers[i], android.view.View.GONE)
                    continue
                }
                views.setViewVisibility(rowContainers[i], android.view.View.VISIBLE)
                views.setTextViewText(rows[i].first, ticker)
                views.setTextViewText(rows[i].second, price)
                views.setTextViewText(rows[i].third, change)

                // Colour the change green/red.
                val color = if (change.startsWith("-"))
                    0xFFEA3943.toInt() else 0xFF16C784.toInt()
                views.setTextColor(rows[i].third, color)
            }

            val updated = prefs.getString("w_updated", "") ?: ""
            views.setTextViewText(
                R.id.updated_at,
                if (updated.isBlank()) "Tap to open" else "Updated $updated"
            )

            // Tapping anywhere opens the Flutter app.
            val pendingIntent: PendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
