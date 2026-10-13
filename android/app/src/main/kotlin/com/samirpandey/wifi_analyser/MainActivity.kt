package com.samirpandey.wifi_analyser

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.wifi.WifiManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val displayRefresh by lazy { DisplayRefreshPolicy(this) }
    private val wifi by lazy { applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager }
    private var sink: EventChannel.EventSink? = null
    private var permissionReply: MethodChannel.Result? = null
    private var registered = false
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val fresh = intent?.getBooleanExtra(WifiManager.EXTRA_RESULTS_UPDATED, false) == true
            sink?.success(snapshot(if (fresh) "Scan complete" else "Scan not updated. Showing cached results.", fresh))
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.samirpandey.wifi_analyser/display")
            .setMethodCallHandler { call, result ->
                if (call.method == "refreshRate") result.success(displayRefresh.snapshot())
                else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.samirpandey.wifi_analyser/wifi")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "snapshot" -> result.success(snapshot())
                    "requestPermission" -> {
                        if (hasPermission()) result.success(true)
                        else if (permissionReply != null) result.error("busy", "Permission request already open", null)
                        else {
                            permissionReply = result
                            requestPermissions(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), 91)
                        }
                    }
                    "scan" -> {
                        val state = snapshot()
                        if (!hasPermission() || !locationEnabled() || !wifi.isWifiEnabled) result.success(state)
                        else try {
                            val started = wifi.startScan()
                            state["scanRequested"] = started
                            state["status"] = if (started) "Scanning… Cached results shown until new scan arrives." else "Scan throttled or unavailable. Showing cached results."
                            result.success(state)
                        } catch (e: SecurityException) { result.error("permission", "Location permission required for WiFi scanning", null) }
                    }
                    "openSettings" -> {
                        val intent = when (call.argument<String>("target")) {
                            "location" -> Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                            "permission" -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                            else -> Intent(Settings.ACTION_WIFI_SETTINGS)
                        }
                        try { startActivity(intent); result.success(null) }
                        catch (e: android.content.ActivityNotFoundException) { result.error("settings_unavailable", "Android settings unavailable", null) }
                    }
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.samirpandey.wifi_analyser/scan_results")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events; registerScanReceiver() }
                override fun onCancel(arguments: Any?) { sink = null; unregisterScanReceiver() }
            })
    }
    override fun onFlutterSurfaceViewCreated(view: FlutterSurfaceView) {
        super.onFlutterSurfaceViewCreated(view)
        displayRefresh.attach(view)
    }
    private fun registerScanReceiver() {
        if (registered || sink == null) return
        val filter = IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        else registerReceiver(receiver, filter)
        registered = true
    }
    private fun unregisterScanReceiver() { if (registered) { unregisterReceiver(receiver); registered = false } }
    override fun onResume() { super.onResume(); displayRefresh.requestHighest(); registerScanReceiver() }
    override fun onPause() { unregisterScanReceiver(); super.onPause() }
    override fun onDestroy() { displayRefresh.close(); unregisterScanReceiver(); permissionReply?.error("cancelled", "Activity closed", null); permissionReply = null; super.onDestroy() }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 91) { permissionReply?.success(hasPermission()); permissionReply = null }
    }
    private fun hasPermission() = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
    private fun locationEnabled(): Boolean {
        val manager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return if (Build.VERSION.SDK_INT >= 28) manager.isLocationEnabled
        else manager.isProviderEnabled(LocationManager.GPS_PROVIDER) || manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }
    @Suppress("DEPRECATION")
    private fun snapshot(message: String? = null, fresh: Boolean = false): MutableMap<String, Any?> {
        val allowed = hasPermission()
        val location = locationEnabled()
        val enabled = wifi.isWifiEnabled
        val points = mutableListOf<Map<String, Any?>>()
        var state = message ?: when {
            !allowed -> "Allow precise location to discover nearby WiFi networks."
            !location -> "Enable Location services in Android settings to scan WiFi."
            !enabled -> "Enable WiFi in Android settings to start scanning."
            else -> "Ready • cached scan results"
        }
        if (allowed && location && enabled) try {
            val currentBssid = wifi.connectionInfo?.bssid
            for (ap in wifi.scanResults) {
                if (ap.frequency !in 2400..2500 && ap.frequency !in 4900..5900 && ap.frequency !in 5925..7125) continue
                val capabilities = ap.capabilities
                val security = when {
                    capabilities.contains("SAE") -> "WPA3"
                    capabilities.contains("OWE") -> "Enhanced Open"
                    capabilities.contains("EAP") -> "Enterprise"
                    capabilities.contains("WPA2") || capabilities.contains("RSN") -> "WPA2"
                    capabilities.contains("WPA") -> "WPA"
                    capabilities.contains("WEP") -> "WEP"
                    else -> "Open"
                }
                val width = when (ap.channelWidth) { 1 -> 40; 2 -> 80; 3, 4 -> 160; 5 -> 320; else -> 20 }
                points.add(mapOf("ssid" to ap.SSID, "bssid" to ap.BSSID, "rssi" to ap.level,
                    "frequency" to ap.frequency, "centerFrequency" to ap.centerFreq0, "width" to width, "security" to security,
                    "connected" to (ap.BSSID == currentBssid), "timestamp" to ap.timestamp))
            }
        } catch (e: SecurityException) { state = "WiFi scan access denied. Check precise location permission." }
        return mutableMapOf("permission" to allowed, "locationEnabled" to location,
            "wifiEnabled" to enabled, "status" to state, "fresh" to fresh,
            "scanRequested" to false, "accessPoints" to points)
    }
}
