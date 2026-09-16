package com.kharcha.app.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.kharcha.app.KharchaApp
import com.kharcha.app.MainActivity
import com.kharcha.app.ui.formatPaiseCompact
import com.kharcha.app.ui.monthRange
import java.time.YearMonth

class KharchaWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = KharchaWidget()
}

/**
 * Month spend + quick-add tap. Widget never writes Room directly —
 * tap deep-links into MainActivity, the real write stays in-app
 * (avoids widget-process DB lock). ponytail: no periodic worker,
 * engine calls update() after each Insert; hourly XML floor otherwise.
 */
class KharchaWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val db = (context.applicationContext as KharchaApp).database
        val (s, e) = monthRange(YearMonth.now())
        val spend = db.dao().spendBetween(s, e)
        provideContent {
            Column(
                GlanceModifier.fillMaxWidth().background(ColorProvider(Color(0xFF1E1F1A))).padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("Spent this month", style = TextStyle(color = ColorProvider(Color(0xFFB0B0A8))))
                Text(
                    formatPaiseCompact(spend),
                    style = TextStyle(color = ColorProvider(Color.White), fontWeight = FontWeight.Bold),
                )
                Spacer(GlanceModifier.height(8.dp))
                Row(
                    GlanceModifier.fillMaxWidth()
                        .background(ColorProvider(Color(0xFFFFB020))).padding(12.dp)
                        .clickable(actionStartActivity<MainActivity>()),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text("+ Log spend", style = TextStyle(color = ColorProvider(Color.Black), fontWeight = FontWeight.Bold))
                }
            }
        }
    }

    companion object {
        suspend fun refresh(context: Context) {
            androidx.glance.appwidget.GlanceAppWidgetManager(context)
                .getGlanceIds(KharchaWidget::class.java)
                .forEach { KharchaWidget().update(context, it) }
        }
    }
}
