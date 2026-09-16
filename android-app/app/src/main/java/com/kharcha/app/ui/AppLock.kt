package com.kharcha.app.ui

import android.content.Context
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.biometric.BiometricManager.Authenticators
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity

/**
 * App lock on top-level resume. Enabled flag in SharedPreferences; when on
 * and a valid credential is enrolled, prompt before showing content. Failed
 * auth → keep locked.
 *
 * Fail-closed, but never bricking (audit): plain BIOMETRIC_STRONG meant a
 * fingerprint-less phone (or a phone whose only fingerprint is re-enrolled)
 * reported enrolled=false and the user could NEVER unlock — permanent lockout.
 * DEVICE_CREDENTIAL (PIN/pattern/face) is the safety net: anyone with a
 * device lock can unlock. This is a lock against casual prying, not a vault.
 */
object AppLock {
    private const val PREFS = "lock"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_GRACE_MIN = "grace_min"
    private const val KEY_LAST_PAUSE_MS = "last_pause_ms"

    // BIOMETRIC_STRONG | DEVICE_CREDENTIAL: strong biometric OR device PIN.
    private val AUTH = Authenticators.BIOMETRIC_STRONG or Authenticators.DEVICE_CREDENTIAL

    fun isEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, false)

    fun setEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    /** Grace minutes before the lock re-engages: 0 = every resume. */
    fun graceMin(context: Context): Int =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt(KEY_GRACE_MIN, 0)

    fun setGraceMin(context: Context, min: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putInt(KEY_GRACE_MIN, min).apply()
    }

    fun stampPause(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putLong(KEY_LAST_PAUSE_MS, System.currentTimeMillis()).apply()
    }

    fun lastPauseMs(context: Context): Long =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(KEY_LAST_PAUSE_MS, 0)

    fun canAuthenticate(context: Context): Boolean =
        BiometricManager.from(context).canAuthenticate(AUTH) == BiometricManager.BIOMETRIC_SUCCESS

    /** Prompt on launch. Result(false) keeps content locked; enrolled=false means no biometrics set up. */
    fun promptIfNeeded(activity: FragmentActivity, onResult: (unlocked: Boolean, enrolled: Boolean) -> Unit) {
        if (!isEnabled(activity)) { onResult(true, true); return }
        if (!canAuthenticate(activity)) { onResult(false, false); return }
        val prompt = BiometricPrompt(
            activity,
            ContextCompat.getMainExecutor(activity),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) = onResult(true, true)
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) = onResult(false, true)
                override fun onAuthenticationFailed() = onResult(false, true)
            },
        )
        prompt.authenticate(
            BiometricPrompt.PromptInfo.Builder()
                .setTitle("Kharcha is locked")
                .setSubtitle("Unlock to see your money")
                .setNegativeButtonText("Cancel")
                .build(),
        )
    }
}
