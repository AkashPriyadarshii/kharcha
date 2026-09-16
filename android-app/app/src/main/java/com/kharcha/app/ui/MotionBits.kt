package com.kharcha.app.ui

import androidx.compose.animation.core.animateIntAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition

/** Rolling hero number: interpolates on every Room emission, 300ms ease. 0 deps. */
@Composable
fun AnimatedCurrencyText(paise: Long, style: TextStyle) {
    val anim by animateIntAsState(paise.coerceIn(0, Int.MAX_VALUE.toLong()).toInt(), tween(300), label = "spend")
    Text(formatPaiseCompact(anim.toLong()), style = style)
}

/** Moving highlight for skeleton placeholders. Sweep via infiniteTransition + linearGradient. */
fun Modifier.shimmer(): Modifier = composed {
    val t by rememberInfiniteTransition(label = "shimmer").animateFloat(
        0f, 1200f,
        infiniteRepeatable(tween(1200, easing = LinearEasing), RepeatMode.Restart),
        label = "shimmerX",
    )
    val base = MaterialTheme.colorScheme.surfaceVariant
    val hi = Color.White.copy(alpha = 0.6f)
    background(Brush.linearGradient(listOf(base, hi, base), Offset(t - 400f, 0f), Offset(t, 200f)))
}

/** Shimmer skeleton txn row — matches TransactionLine geometry, no pop on load. */
@Composable
fun SkeletonRow() {
    Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(40.dp).clip(CircleShape).shimmer())
        Spacer(Modifier.width(12.dp))
        androidx.compose.foundation.layout.Column(Modifier.weight(1f)) {
            Box(Modifier.fillMaxWidth(0.5f).height(14.dp).clip(CircleShape).shimmer())
            Spacer(Modifier.height(6.dp))
            Box(Modifier.fillMaxWidth(0.3f).height(12.dp).clip(CircleShape).shimmer())
        }
    }
}
