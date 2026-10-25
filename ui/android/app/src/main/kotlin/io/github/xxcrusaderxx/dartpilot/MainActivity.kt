package io.github.xxcrusaderxx.dartpilot

import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Android drops incoming multicast (mDNS) for apps without this lock; held only while searching for engines.
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dartpilot/multicast").setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> {
                    val lock = multicastLock ?: (applicationContext.getSystemService(WIFI_SERVICE) as WifiManager)
                        .createMulticastLock("dartpilot-discovery").also {
                            it.setReferenceCounted(false)
                            multicastLock = it
                        }
                    lock.acquire()
                    result.success(null)
                }
                "release" -> {
                    multicastLock?.release()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        multicastLock?.release()
        super.onDestroy()
    }
}
