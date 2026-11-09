
package com.localdrop.localdrop

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        requestHighRefreshRate()
    }

    @Suppress("DEPRECATION")
    private fun requestHighRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

        try {
            val display = windowManager.defaultDisplay
            val current = display.mode

            val best = display.supportedModes
                .filter {
                    it.physicalWidth == current.physicalWidth &&
                    it.physicalHeight == current.physicalHeight
                }
                .maxByOrNull { it.refreshRate } ?: return

            val lp = window.attributes
            lp.preferredDisplayModeId = best.modeId

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                lp.preferredRefreshRate = best.refreshRate
            }

            window.attributes = lp
        } catch (_: Exception) {}
    }
}
