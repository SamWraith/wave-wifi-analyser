package com.samirpandey.wifi_analyser

import android.app.Activity
import android.os.Build
import android.view.Display
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView

/** Window and Flutter surface requests; Android retains final refresh control. */
class DisplayRefreshPolicy(private val activity: Activity) : AutoCloseable {
    private var surfaceView: SurfaceView? = null
    private var surfaceRequest = 0f
    private val callback = object : SurfaceHolder.Callback {
        override fun surfaceCreated(holder: SurfaceHolder) { requestSurface(holder) }
        override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) { requestSurface(holder) }
        override fun surfaceDestroyed(holder: SurfaceHolder) { surfaceRequest = 0f }
    }

    @Suppress("DEPRECATION")
    private fun display(): Display? =
        if (Build.VERSION.SDK_INT >= 30) activity.display else activity.windowManager.defaultDisplay

    private fun compatibleModes(display: Display): List<Display.Mode> =
        display.supportedModes.filter {
            it.physicalWidth == display.mode.physicalWidth &&
                it.physicalHeight == display.mode.physicalHeight
        }

    private fun fastestMode(): Display.Mode? =
        display()?.let { compatibleModes(it).maxByOrNull { mode -> mode.refreshRate } }

    fun requestHighest() {
        val fastest = fastestMode() ?: return
        activity.window.attributes = activity.window.attributes.apply {
            preferredRefreshRate = fastest.refreshRate
            // Some OEM policies ignore the rate-only vote; keep resolution fixed.
            preferredDisplayModeId = fastest.modeId
        }
        surfaceView?.holder?.let { requestSurface(it) }
    }

    fun attach(view: SurfaceView) {
        close()
        surfaceView = view
        view.holder.addCallback(callback)
        if (Build.VERSION.SDK_INT >= 35) {
            view.requestedFrameRate = fastestMode()?.refreshRate ?: 0f
        }
        requestHighest()
    }

    private fun requestSurface(holder: SurfaceHolder) {
        if (Build.VERSION.SDK_INT < 30 || !holder.surface.isValid) return
        val rate = fastestMode()?.refreshRate ?: return
        val compatibility = if (Build.VERSION.SDK_INT >= 36)
            Surface.FRAME_RATE_COMPATIBILITY_AT_LEAST else Surface.FRAME_RATE_COMPATIBILITY_DEFAULT
        try {
            holder.surface.setFrameRate(rate, compatibility)
            surfaceRequest = rate
        } catch (_: IllegalStateException) {
            surfaceRequest = 0f // Surface can disappear during backgrounding.
        } catch (_: IllegalArgumentException) {
            surfaceRequest = 0f // Optional preference must not prevent startup.
        }
    }

    fun snapshot(): Map<String, Any?> {
        val display = display()
        return mapOf(
            "currentRefreshRate" to display?.refreshRate,
            "requestedRefreshRate" to activity.window.attributes.preferredRefreshRate,
            "surfaceRequestedRefreshRate" to surfaceRequest,
            "supportedRefreshRates" to (display?.let { compatibleModes(it).map { mode -> mode.refreshRate } } ?: emptyList<Float>())
        )
    }

    override fun close() {
        surfaceView?.holder?.removeCallback(callback)
        surfaceView = null
        surfaceRequest = 0f
    }
}
