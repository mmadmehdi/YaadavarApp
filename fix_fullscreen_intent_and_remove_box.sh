#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -f "App.js" ] || { echo "❌"; exit 1; }

if [ -d "android-src3" ]; then
cat > android-src3/KeywordAccessibilityService.kt << 'KT_EOF'
package __PACKAGE_NAME__

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
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
        const val FS_CHANNEL_ID = "keyword_fullscreen_channel"
        const val FS_NOTIF_ID = 9911
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
                triggerPopupViaFullScreenNotification()
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

    private fun triggerPopupViaFullScreenNotification() {
        val popupIntent = Intent(Intent.ACTION_VIEW, Uri.parse("__SCHEME__://popup?ts=" + System.currentTimeMillis()))
        popupIntent.setPackage(packageName)
        popupIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)

        val pendingIntent = PendingIntent.getActivity(
            this,
            System.currentTimeMillis().toInt(),
            popupIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(FS_CHANNEL_ID) == null) {
            val channel = NotificationChannel(
                FS_CHANNEL_ID, "شناسایی کلمه", NotificationManager.IMPORTANCE_HIGH
            )
            manager.createNotificationChannel(channel)
        }

        val notification = Notification.Builder(this, FS_CHANNEL_ID)
            .setContentTitle("یادآور")
            .setContentText("کلمه شناسایی شد")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(Notification.PRIORITY_HIGH)
            .setCategory(Notification.CATEGORY_CALL)
            .setFullScreenIntent(pendingIntent, true)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        manager.notify(FS_NOTIF_ID, notification)
    }

    override fun onInterrupt() {}
}
KT_EOF
echo "✅ سرویس با مکانیزم FullScreenIntent بازنویسی شد"
fi

if [ -f "plugins/withKeywordAccessibility.js" ]; then
  python3 << 'PYEOF'
path = 'plugins/withKeywordAccessibility.js'
content = open(path, 'r', encoding='utf-8').read()

old = "    const application = androidManifest.manifest.application[0];\n    if (!application.service) application.service = [];"
new = """    if (!androidManifest.manifest['uses-permission']) {
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

if "USE_FULL_SCREEN_INTENT" in content:
    print("ℹ️  مجوز قبلاً اضافه شده بود")
elif old in content:
    content = content.replace(old, new, 1)
    open(path, 'w', encoding='utf-8').write(content)
    print("✅ مجوز USE_FULL_SCREEN_INTENT اضافه شد")
else:
    print("⚠️  انکر پلاگین پیدا نشد")
PYEOF
fi

python3 << 'PYEOF'
import re
content = open('App.js', 'r', encoding='utf-8').read()

pattern = re.compile(
    r'[ \t]*<Text style=\{styles\.label\}>📝 جملات خود را وارد کنید.*?(?=<Text style=\{styles\.label\}>⏱️ فاصله زمانی</Text>)',
    re.DOTALL
)

if pattern.search(content):
    content = pattern.sub('', content)
    with open('App.js', 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ باکس قدیمی جملات حذف شد")
else:
    print("ℹ️  باکس قدیمی پیدا نشد (شاید قبلاً حذف شده)")
PYEOF

git add .
git commit -m "fix: استفاده از FullScreenIntent برای تشخیص کلمه + حذف باکس قدیمی جملات" || echo "چیزی برای کامیت نبود"
git push
echo "✅ تمام شد"
