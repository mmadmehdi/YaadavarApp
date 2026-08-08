#!/data/data/com.termux/files/usr/bin/bash
# ====================================================================
#  setup_keyword_accessibility.sh
#  اجرا کن داخل پوشه پروژه (YaadavarAppFresh) با:
#     bash setup_keyword_accessibility.sh
# ====================================================================
set -e

if [ ! -f "App.js" ] || [ ! -f "app.json" ]; then
  echo "❌ این اسکریپت باید داخل ریشه پروژه (کنار App.js و app.json) اجرا بشه."
  exit 1
fi

echo "📁 ساخت پوشه‌ها..."
mkdir -p plugins android-src3

# --------------------------------------------------------------------
# 1) plugins/withKeywordAccessibility.js
# --------------------------------------------------------------------
cat > plugins/withKeywordAccessibility.js << 'PLUGIN_EOF'
const {
  withAndroidManifest,
  withDangerousMod,
} = require('@expo/config-plugins');
const fs = require('fs');
const path = require('path');

function withKeywordAccessibility(config) {
  config = withAndroidManifest(config, (config) => {
    const androidManifest = config.modResults;
    const application = androidManifest.manifest.application[0];
    if (!application.service) application.service = [];

    const already = application.service.some(
      (s) => s.$['android:name'] === '.KeywordAccessibilityService'
    );

    if (!already) {
      application.service.push({
        $: {
          'android:name': '.KeywordAccessibilityService',
          'android:exported': 'true',
          'android:permission': 'android.permission.BIND_ACCESSIBILITY_SERVICE',
        },
        'intent-filter': [
          {
            action: [
              { $: { 'android:name': 'android.accessibilityservice.AccessibilityService' } },
            ],
          },
        ],
        'meta-data': [
          {
            $: {
              'android:name': 'android.accessibilityservice',
              'android:resource': '@xml/accessibility_service_config',
            },
          },
        ],
      });
    }

    return config;
  });

  config = withDangerousMod(config, [
    'android',
    async (config) => {
      const projectRoot = config.modRequest.projectRoot;
      const platformProjectRoot = config.modRequest.platformProjectRoot;
      const packageName = config.android.package;
      const packagePath = packageName.replace(/\./g, '/');
      const scheme = Array.isArray(config.scheme)
        ? config.scheme[0]
        : (config.scheme || 'yaadavar');

      const javaDir = path.join(platformProjectRoot, 'app/src/main/java', packagePath);
      const xmlDir = path.join(platformProjectRoot, 'app/src/main/res/xml');
      const valuesDir = path.join(platformProjectRoot, 'app/src/main/res/values');
      fs.mkdirSync(javaDir, { recursive: true });
      fs.mkdirSync(xmlDir, { recursive: true });
      fs.mkdirSync(valuesDir, { recursive: true });

      const srcDir = path.join(projectRoot, 'android-src3');

      const replacePlaceholders = (content) =>
        content
          .replace(/__PACKAGE_NAME__/g, packageName)
          .replace(/__SCHEME__/g, scheme);

      const ktFiles = [
        'KeywordAccessibilityService.kt',
        'KeywordFilterModule.kt',
        'KeywordFilterPackage.kt',
      ];
      for (const file of ktFiles) {
        const content = fs.readFileSync(path.join(srcDir, file), 'utf8');
        fs.writeFileSync(path.join(javaDir, file), replacePlaceholders(content), 'utf8');
      }

      fs.copyFileSync(
        path.join(srcDir, 'accessibility_service_config.xml'),
        path.join(xmlDir, 'accessibility_service_config.xml')
      );
      fs.copyFileSync(
        path.join(srcDir, 'accessibility_strings.xml'),
        path.join(valuesDir, 'accessibility_strings.xml')
      );

      return config;
    },
  ]);

  config = withDangerousMod(config, [
    'android',
    async (config) => {
      const platformProjectRoot = config.modRequest.platformProjectRoot;
      const packageName = config.android.package;
      const packagePath = packageName.replace(/\./g, '/');
      const mainAppPath = path.join(
        platformProjectRoot, 'app/src/main/java', packagePath, 'MainApplication.kt'
      );

      if (fs.existsSync(mainAppPath)) {
        let content = fs.readFileSync(mainAppPath, 'utf8');
        if (!content.includes('KeywordFilterPackage()')) {
          content = content.replace(
            /(PackageList\(this\)\.packages\s*)/,
            `$1.apply { add(KeywordFilterPackage()) }`
          );
          fs.writeFileSync(mainAppPath, content, 'utf8');
        }
      }

      return config;
    },
  ]);

  return config;
}

module.exports = withKeywordAccessibility;
PLUGIN_EOF
echo "✅ plugins/withKeywordAccessibility.js نوشته شد"

# --------------------------------------------------------------------
# 2) android-src3/KeywordAccessibilityService.kt
# --------------------------------------------------------------------
cat > android-src3/KeywordAccessibilityService.kt << 'KT1_EOF'
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
KT1_EOF

# --------------------------------------------------------------------
# 3) android-src3/KeywordFilterModule.kt
# --------------------------------------------------------------------
cat > android-src3/KeywordFilterModule.kt << 'KT2_EOF'
package __PACKAGE_NAME__

import android.content.Context
import android.content.Intent
import android.provider.Settings
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod

class KeywordFilterModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName() = "KeywordFilterModule"

    private fun prefs() = reactApplicationContext.getSharedPreferences(
        KeywordAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE
    )

    @ReactMethod
    fun saveKeywords(csv: String, promise: Promise) {
        try {
            prefs().edit().putString(KeywordAccessibilityService.PREFS_KEY, csv).apply()
            promise.resolve(true)
        } catch (e: Exception) {
            promise.reject("ERR_SAVE_KEYWORDS", e)
        }
    }

    @ReactMethod
    fun getKeywords(promise: Promise) {
        try {
            val csv = prefs().getString(KeywordAccessibilityService.PREFS_KEY, "") ?: ""
            promise.resolve(csv)
        } catch (e: Exception) {
            promise.reject("ERR_GET_KEYWORDS", e)
        }
    }

    @ReactMethod
    fun openAccessibilitySettings(promise: Promise) {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            reactApplicationContext.startActivity(intent)
            promise.resolve(true)
        } catch (e: Exception) {
            promise.reject("ERR_OPEN_SETTINGS", e)
        }
    }

    @ReactMethod
    fun isAccessibilityServiceEnabled(promise: Promise) {
        try {
            val expectedComponent = reactApplicationContext.packageName + "/__PACKAGE_NAME__.KeywordAccessibilityService"
            val enabledServices = Settings.Secure.getString(
                reactApplicationContext.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: ""
            val isEnabled = enabledServices.split(":").any {
                it.equals(expectedComponent, ignoreCase = true)
            }
            promise.resolve(isEnabled)
        } catch (e: Exception) {
            promise.reject("ERR_CHECK_A11Y", e)
        }
    }
}
KT2_EOF

# --------------------------------------------------------------------
# 4) android-src3/KeywordFilterPackage.kt
# --------------------------------------------------------------------
cat > android-src3/KeywordFilterPackage.kt << 'KT3_EOF'
package __PACKAGE_NAME__

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager

class KeywordFilterPackage : ReactPackage {
    override fun createNativeModules(
        reactContext: ReactApplicationContext
    ): List<NativeModule> {
        return listOf(KeywordFilterModule(reactContext))
    }

    override fun createViewManagers(
        reactContext: ReactApplicationContext
    ): List<ViewManager<*, *>> {
        return emptyList()
    }
}
KT3_EOF

# --------------------------------------------------------------------
# 5) android-src3/accessibility_service_config.xml
# --------------------------------------------------------------------
cat > android-src3/accessibility_service_config.xml << 'XML1_EOF'
<?xml version="1.0" encoding="utf-8"?>
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:accessibilityEventTypes="typeWindowContentChanged|typeWindowStateChanged"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:accessibilityFlags="flagIncludeNotImportantViews"
    android:canRetrieveWindowContent="true"
    android:notificationTimeout="300"
    android:description="@string/accessibility_service_description" />
XML1_EOF

# --------------------------------------------------------------------
# 6) android-src3/accessibility_strings.xml
# --------------------------------------------------------------------
cat > android-src3/accessibility_strings.xml << 'XML2_EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="accessibility_service_description">یادآور: بررسی متن صفحه برای پیدا کردن کلمات کلیدی تعیین‌شده و نمایش پاپ‌آپ</string>
</resources>
XML2_EOF

echo "✅ فایل‌های android-src3 نوشته شدند"

# --------------------------------------------------------------------
# 7) اضافه کردن پلاگین به app.json
# --------------------------------------------------------------------
python3 << 'PYEOF'
import json

with open('app.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

expo = data.setdefault('expo', {})
plugins = expo.setdefault('plugins', [])

target = './plugins/withKeywordAccessibility'
already = any(
    (p == target) or (isinstance(p, list) and len(p) > 0 and p[0] == target)
    for p in plugins
)
if not already:
    plugins.append(target)

with open('app.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write('\n')

print("✅ app.json آپدیت شد")
PYEOF

# --------------------------------------------------------------------
# 8) پچ App.js
# --------------------------------------------------------------------
python3 << 'PYEOF'
content = open('App.js', 'r', encoding='utf-8').read()
changed = False

def patch(old, new, label, content, changed):
    if new in content:
        print(f"ℹ️  {label}: قبلاً اعمال شده بود")
        return content, changed
    if old not in content:
        print(f"⚠️  {label}: انکر پیدا نشد — این بخش رو دستی چک کن")
        return content, changed
    return content.replace(old, new, 1), True

old = "const { LockTaskModule, StickyServiceModule } = NativeModules;"
new = "const { LockTaskModule, StickyServiceModule, KeywordFilterModule } = NativeModules;"
content, changed = patch(old, new, "ایمپورت KeywordFilterModule", content, changed)

old = "  const [popupTimerActive, setPopupTimerActive] = useState(false);"
new = old + "\n  const [keywordsText, setKeywordsText] = useState('');"
content, changed = patch(old, new, "state کلمات کلیدی", content, changed)

old = """  const lockSecondsRef = useRef(10);
  useEffect(() => {
    lockSecondsRef.current = lockSeconds;
  }, [lockSeconds]);"""
new = old + """

  useEffect(() => {
    if (Platform.OS === 'android' && KeywordFilterModule) {
      KeywordFilterModule.getKeywords()
        .then((csv) => setKeywordsText(csv || ''))
        .catch(() => {});
    }
  }, []);"""
content, changed = patch(old, new, "لود اولیه کلمات کلیدی", content, changed)

old = "          <TouchableOpacity style={styles.btnPurple} onPress={quickReminder}>"
new = """          <Text style={styles.label}>🔍 شناسایی کلمه در کل صفحه گوشی (نیاز به Accessibility)</Text>
          <View style={styles.customRow}>
            <TextInput
              style={[styles.customInput, { flex: 2 }]}
              value={keywordsText}
              onChangeText={setKeywordsText}
              placeholder="کلمه۱, کلمه۲, کلمه۳"
              placeholderTextColor="#aaa"
              textAlign="right"
            />
            <TouchableOpacity
              style={styles.customBtn}
              onPress={async () => {
                if (Platform.OS !== 'android' || !KeywordFilterModule) return;
                await KeywordFilterModule.saveKeywords(keywordsText);
                Alert.alert('ذخیره شد', 'لیست کلمات کلیدی به‌روزرسانی شد');
              }}>
              <Text style={styles.customBtnText}>ذخیره</Text>
            </TouchableOpacity>
          </View>
          <TouchableOpacity
            style={styles.btnGray}
            onPress={async () => {
              if (Platform.OS !== 'android' || !KeywordFilterModule) return;
              await KeywordFilterModule.openAccessibilitySettings();
            }}>
            <Ionicons name="accessibility" size={20} color="#fff" style={{ marginRight: 8 }} />
            <Text style={styles.btnTxt}>فعال‌سازی دسترسی Accessibility</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.btnPurple} onPress={quickReminder}>"""
content, changed = patch(old, new, "UI کلمات کلیدی + دکمه Accessibility", content, changed)

with open('App.js', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ App.js پردازش شد" if changed else "ℹ️  تغییری لازم نبود")
PYEOF

echo ""
echo "📦 گیت..."
git add .
git commit -m "افزودن شناسایی کلمات کلیدی در کل صفحه گوشی از طریق Accessibility Service" || echo "ℹ️  چیزی برای کامیت نبود"
git push

echo ""
echo "======================================================================"
echo "✅ تمام شد و پوش شد."
echo ""
echo "بعد از نصب APK جدید:"
echo "1. توی اپ، توی بخش جدید 'شناسایی کلمه در کل صفحه گوشی'، کلماتت رو با"
echo "   کاما جدا کن و بزن 'ذخیره'."
echo "2. دکمه 'فعال‌سازی دسترسی Accessibility' رو بزن — می‌بره به تنظیمات"
echo "   اندروید. اونجا 'یادآور' رو پیدا کن و روشنش کن (این مرحله رو فقط"
echo "   اندروید اجازه می‌ده دستی و با تایید خودت انجام بشه، هیچ اپی نمی‌تونه"
echo "   خودکار فعالش کنه)."
echo "3. از این به بعد، هر جای گوشی (تلگرام، مرورگر، هرجا) یکی از اون کلمات"
echo "   دیده بشه، پاپ‌آپ خودکار باز می‌شه."
echo ""
echo "⚠️ محدودیت‌ها: فقط متن قابل‌خوندن (نه عکس/ویدیو) اسکن می‌شه، و بین هر"
echo "   بار فعال شدن حداقل ۸ ثانیه فاصله می‌ندازه که مدام باز نشه."
echo "======================================================================"
