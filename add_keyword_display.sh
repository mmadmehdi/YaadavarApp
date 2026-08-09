#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -d "android-src3" ] && [ -f "App.js" ] || { echo "❌"; exit 1; }

# --------------------------------------------------------------------
# 1) بازنویسی کامل سرویس: کلمه‌ی پیداشده رو هم ذخیره کن
# --------------------------------------------------------------------
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
        val popupIntent = Intent(Intent.ACTION_VIEW, Uri.parse("__SCHEME__://popup"))
        popupIntent.setPackage(packageName)
        popupIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        startActivity(popupIntent)
    }

    override fun onInterrupt() {}
}
KT_EOF
echo "✅ سرویس آپدیت شد"

# --------------------------------------------------------------------
# 2) اضافه کردن متد خوندن+پاک‌کردن کلمه‌ی پیداشده به KeywordFilterModule
# --------------------------------------------------------------------
if [ -f "android-src3/KeywordFilterModule.kt" ]; then
  python3 << 'PYEOF'
path = 'android-src3/KeywordFilterModule.kt'
content = open(path, 'r', encoding='utf-8').read()

marker = "    @ReactMethod\n    fun isAccessibilityServiceEnabled"
addition = """    @ReactMethod
    fun getAndClearLastMatchedKeyword(promise: Promise) {
        try {
            val kw = prefs().getString(KeywordAccessibilityService.LAST_MATCH_KEY, null)
            if (kw != null) {
                prefs().edit().remove(KeywordAccessibilityService.LAST_MATCH_KEY).apply()
            }
            promise.resolve(kw)
        } catch (e: Exception) {
            promise.reject("ERR_GET_LAST_MATCH", e)
        }
    }

"""
if "getAndClearLastMatchedKeyword" in content:
    print("ℹ️  متد قبلاً اضافه شده بود")
elif marker in content:
    content = content.replace(marker, addition + marker, 1)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ متد getAndClearLastMatchedKeyword اضافه شد")
else:
    print("⚠️  انکر پیدا نشد")
PYEOF
fi

# --------------------------------------------------------------------
# 3) App.js: نمایش کلمه‌ی پیداشده با اضافه‌کردنش به متن پاپ‌آپ
# --------------------------------------------------------------------
python3 << 'PYEOF'
content = open('App.js', 'r', encoding='utf-8').read()

old = """  function triggerRandomPopup() {
    // اضافه شد: خوندن مستقیم و مطمئن مدت قفل هم‌زمان با جمله‌ها، تا با
    // ریس‌کاندیشن بین لود اولیه و باز شدن پاپ‌آپ از دکمه پنل مشکلی پیش نیاد
    Promise.all([
      AsyncStorage.getItem(STORAGE_KEY),
      AsyncStorage.getItem(LOCK_SECONDS_KEY),
    ]).then(([saved, ls]) => {
      if (ls) {
        const parsedLs = parseInt(ls, 10);
        if (parsedLs > 0) {
          lockSecondsRef.current = parsedLs;
          setLockSeconds(parsedLs);
        }
      }
      const list = saved ? JSON.parse(saved) : sentences;
      if (list && list.length > 0) {
        const r = list[Math.floor(Math.random() * list.length)];
        openPopup(r);
        addLog('از دکمه بالای گوشی: ' + r.substring(0, 25) + '...');
        refreshLogs();
      }
    });
  }"""

new = """  function triggerRandomPopup() {
    // اضافه شد: خوندن مستقیم و مطمئن مدت قفل هم‌زمان با جمله‌ها، تا با
    // ریس‌کاندیشن بین لود اولیه و باز شدن پاپ‌آپ از دکمه پنل مشکلی پیش نیاد
    const kwPromise =
      Platform.OS === 'android' && KeywordFilterModule
        ? KeywordFilterModule.getAndClearLastMatchedKeyword().catch(() => null)
        : Promise.resolve(null);

    Promise.all([
      AsyncStorage.getItem(STORAGE_KEY),
      AsyncStorage.getItem(LOCK_SECONDS_KEY),
      kwPromise,
    ]).then(([saved, ls, matchedKeyword]) => {
      if (ls) {
        const parsedLs = parseInt(ls, 10);
        if (parsedLs > 0) {
          lockSecondsRef.current = parsedLs;
          setLockSeconds(parsedLs);
        }
      }
      const list = saved ? JSON.parse(saved) : sentences;
      if (list && list.length > 0) {
        const r = list[Math.floor(Math.random() * list.length)];
        const finalText = matchedKeyword
          ? '🔍 کلمه شناسایی‌شده: ' + matchedKeyword + '\\n\\n' + r
          : r;
        openPopup(finalText);
        addLog('از دکمه بالای گوشی: ' + r.substring(0, 25) + '...');
        refreshLogs();
      }
    });
  }"""

if new in content:
    print("ℹ️  قبلاً اعمال شده بود")
elif old in content:
    content = content.replace(old, new, 1)
    with open('App.js', 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ نمایش کلمه شناسایی‌شده اضافه شد")
else:
    print("⚠️  انکر triggerRandomPopup پیدا نشد — دستی چک کن")
PYEOF

echo ""
echo "📦 گیت..."
git add .
git commit -m "افزودن نمایش کلمه شناسایی‌شده بالای متن پاپ‌آپ" || echo "چیزی برای کامیت نبود"
git push
echo "✅ تمام شد و پوش شد."
