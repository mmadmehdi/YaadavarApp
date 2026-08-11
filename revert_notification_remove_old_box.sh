#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -f "App.js" ] || { echo "❌"; exit 1; }

if [ -d "android-src3" ]; then
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
        const val LAST_MATCH_KEY = "last_matched_keyword"
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
        if (event?.packageName != null && event.packageName == packageName) return

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
        try {
            val matched = findMatchedKeyword(root, keywords)
            if (matched != null) {
                lastTriggerAt = now
                prefs.edit().putString(LAST_MATCH_KEY, matched).apply()
                openPopupScreen()
            }
        } catch (e: Exception) {
            Log.e("YaadavarA11y", "scan error", e)
        }
    }

    private fun findMatchedKeyword(root: AccessibilityNodeInfo, keywords: List<String>): String? {
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
                    return kw
                }
            }

            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) queue.add(child)
            }
        }
        return null
    }

    private fun openPopupScreen() {
        val popupIntent = Intent(Intent.ACTION_VIEW, Uri.parse("__SCHEME__://popup?ts=" + System.currentTimeMillis()))
        popupIntent.setPackage(packageName)
        popupIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        startActivity(popupIntent)
    }

    override fun onInterrupt() {}
}
KT_EOF
echo "✅ سرویس به حالت قبلی (startActivity مستقیم) برگشت"
fi

if [ -f "plugins/withKeywordAccessibility.js" ]; then
  python3 << 'PYEOF'
path = 'plugins/withKeywordAccessibility.js'
content = open(path, 'r', encoding='utf-8').read()

block = """    if (!androidManifest.manifest['uses-permission']) {
      androidManifest.manifest['uses-permission'] = [];
    }
    const hasFsPerm = androidManifest.manifest['uses-permission'].some(
      (p) => p.$['android:name'] === 'android.permission.USE_FULL_SCREEN_INTENT'
    );
    if (!hasFsPerm) {
      androidManifest.manifest['uses-permission'].push({
        $: { 'android:name': 'android.permission.USE_FULL_SCREEN_INTENT' },
      });
    }

    const application = androidManifest.manifest.application[0];
    if (!application.service) application.service = [];"""

replacement = """    const application = androidManifest.manifest.application[0];
    if (!application.service) application.service = [];"""

if block in content:
    content = content.replace(block, replacement, 1)
    open(path, 'w', encoding='utf-8').write(content)
    print("✅ مجوز FullScreenIntent حذف شد")
else:
    print("ℹ️  مجوز پیدا نشد (شاید قبلاً حذف شده)")
PYEOF
fi

python3 << 'PYEOF'
content = open('App.js', 'r', encoding='utf-8').read()

idx = content.find('جملات خود را وارد کنید')
if idx == -1:
    print("⚠️ عبارت 'جملات خود را وارد کنید' اصلاً توی App.js پیدا نشد")
else:
    start = content.rfind('<Text', 0, idx)
    end_marker_idx = content.find('فاصله زمانی', idx)
    if end_marker_idx == -1:
        print("⚠️ انکر پایانی 'فاصله زمانی' پیدا نشد")
    else:
        end = content.rfind('<Text', 0, end_marker_idx)
        if start != -1 and end != -1 and end > start:
            removed = content[start:end]
            content = content[:start] + content[end:]
            with open('App.js', 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✅ باکس قدیمی جملات حذف شد ({len(removed)} کاراکتر)")
        else:
            print("⚠️ محدوده حذف پیدا نشد")
PYEOF

git add .
git commit -m "revert: بازگشت تشخیص کلمه به startActivity مستقیم + حذف قطعی باکس قدیمی جملات" || echo "چیزی برای کامیت نبود"
git push
echo "✅ تمام شد"
