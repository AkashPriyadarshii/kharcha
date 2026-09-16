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
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition

/** Rolling hero number: interpolates on every Room emission, 300ms ease. Two-tone fractional paise. */
@Composable
fun AnimatedCurrencyText(paise: Long, style: TextStyle) {
    val anim by animateIntAsState(paise.coerceIn(0, Int.MAX_VALUE.toLong()).toInt(), tween(300), label = "spend")
    val (rupees, decimal) = formatPaiseParts(anim.toLong())
    val baseStyle = style.copy(fontFeatureSettings = NumberFontFeatures)
    if (decimal.isEmpty()) {
        Text(rupees, style = baseStyle)
    } else {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(rupees, style = baseStyle)
            Text(
                decimal,
                style = baseStyle.copy(
                    fontSize = (baseStyle.fontSize.value * 0.62f).sp,
                    color = baseStyle.color.copy(alpha = 0.65f),
                ),
                modifier = Modifier.padding(bottom = (baseStyle.fontSize.value * 0.08f).dp),
            )
        }
    }
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

/**
 * Tactile micro-interaction: subtle scale dip and spring return on tap.
 * Zero external libs, uses pure Compose pointer interactions.
 */
fun Modifier.pressFeedback(interactionSource: MutableInteractionSource? = null): Modifier = composed {
    val source = interactionSource ?: remember { MutableInteractionSource() }
    val isPressed by source.collectIsPressedAsState()
    val scale by androidx.compose.animation.core.animateFloatAsState(
        targetValue = if (isPressed) 0.97f else 1f,
        animationSpec = tween(durationMillis = 100),
        label = "press_scale",
    )
    scale(scale)
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
