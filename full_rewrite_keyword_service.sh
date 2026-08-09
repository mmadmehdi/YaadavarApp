#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -d "android-src3" ] || { echo "❌ android-src3 پیدا نشد"; exit 1; }

cat > android-src3/KeywordAccessibilityService.kt << 'KT_EOF'
package __PACKAGE_NAME__

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.util.ArrayDeque

class KeywordAccessibilityService : AccessibilityService() {

    companion object {
        const val PREFS_NAME = "yaadavar_keywords_prefs"
        const val PREFS_KEY = "keywords_csv"
        const val TRIGGER_COOLDOWN_MS = 8000L
        const val SCAN_MIN_INTERVAL_MS = 400L
        const val MAX_NODES = 800
        private var lastTriggerAt = 0L
        private var lastScanAt = 0L
    }

    private lateinit var prefs: SharedPreferences

    override fun onServiceConnected() {
        super.onServiceConnected()
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val info = AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
        info.notificationTimeout = 300
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.packageName != null && event.packageName.toString() == packageName) return

        val now = System.currentTimeMillis()
        if (now - lastScanAt < SCAN_MIN_INTERVAL_MS) return
        lastScanAt = now

        if (now - lastTriggerAt < TRIGGER_COOLDOWN_MS) return

        if (!::prefs.isInitialized) {
            prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }
        val keywordsCsv = prefs.getString(PREFS_KEY, "") ?: ""
        if (keywordsCsv.isBlank()) return
        val keywords = keywordsCsv.split(",")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        if (keywords.isEmpty()) return

        val root = rootInActiveWindow ?: return
        if (root.packageName != null && root.packageName.toString() == packageName) return

        try {
            if (containsKeyword(root, keywords)) {
                lastTriggerAt = now
                openPopupScreen()
            }
        } catch (e: Exception) {
            Log.e("YaadavarA11y", "scan error", e)
        }
    }

    private fun containsKeyword(root: AccessibilityNodeInfo, keywords: List<String>): Boolean {
        val queue: ArrayDeque<AccessibilityNodeInfo> = ArrayDeque()
        queue.add(root)
        var visited = 0

        while (queue.isNotEmpty() && visited < MAX_NODES) {
            val node = queue.poll() ?: continue
            visited++

            val text = node.text?.toString()
            val desc = node.contentDescription?.toString()

            for (kw in keywords) {
                if ((text != null && text.contains(kw, ignoreCase = true)) ||
                    (desc != null && desc.contains(kw, ignoreCase = true))
                ) {
                    return true
                }
            }

            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) queue.add(child)
            }
        }
        return false
    }

    private fun openPopupScreen() {
        val popupIntent = Intent(Intent.ACTION_VIEW, Uri.parse("__SCHEME__://popup"))
        popupIntent.setPackage(packageName)
        popupIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        startActivity(popupIntent)
    }

    override fun onInterrupt() {}
}
KT_EOF

echo "✅ فایل کامل و تمیز از نو نوشته شد"

git add .
git commit -m "fix: بازنویسی کامل و تمیز KeywordAccessibilityService.kt (رفع خرابی احتمالی پچ‌های قبلی)" || echo "چیزی برای کامیت نبود"
git push
echo "✅ تمام شد و پوش شد."
