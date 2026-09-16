package com.kharcha.app.ui

import android.content.Context
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity

/**
 * App lock on top-level resume. Enabled flag in SharedPreferences; when on
 * and biometrics enrolled, prompt before showing content. Failed auth → keep locked.
 */
object AppLock {
    private const val PREFS = "lock"
    private const val KEY_ENABLED = "enabled"

    fun isEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, false)

    fun setEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    /** Prompt on launch; if not enrolled or disabled, unlocks with no prompt. */
    fun promptIfNeeded(activity: FragmentActivity, onResult: (Boolean) -> Unit) {
        if (!isEnabled(activity)) { onResult(true); return }
        val manager = BiometricManager.from(activity)
        if (manager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) != BiometricManager.BIOMETRIC_SUCCESS) {
            onResult(true); return // no strong biometrics enrolled — fall through, don't brick the app
        }
        val prompt = BiometricPrompt(
            activity,
            ContextCompat.getMainExecutor(activity),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) = onResult(true)
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) = onResult(false)
                override fun onAuthenticationFailed() = onResult(false)
            },
        )
        prompt.authenticate(BiometricPrompt.PromptInfo.Builder()
            .setTitle("Kharcha is locked")
            .setNegativeButtonText("Cancel")
            .build())
    }
}