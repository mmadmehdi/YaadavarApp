#!/data/data/com.termux/files/usr/bin/bash
# ====================================================================
#  setup_device_owner.sh
#  اجرا کن داخل پوشه پروژه (YaadavarAppFresh) با:
#     bash setup_device_owner.sh
# ====================================================================
set -e

if [ ! -f "App.js" ] || [ ! -f "app.json" ]; then
  echo "❌ این اسکریپت باید داخل ریشه پروژه (کنار App.js و app.json) اجرا بشه."
  exit 1
fi

echo "📁 ساخت پوشه‌ها..."
mkdir -p plugins android-src

# --------------------------------------------------------------------
# 1) plugins/withDeviceOwnerLock.js
# --------------------------------------------------------------------
cat > plugins/withDeviceOwnerLock.js << 'PLUGIN_EOF'
const {
  withAndroidManifest,
  withDangerousMod,
} = require('@expo/config-plugins');
const fs = require('fs');
const path = require('path');

function withDeviceOwnerLock(config) {
  config = withAndroidManifest(config, (config) => {
    const androidManifest = config.modResults;
    const application = androidManifest.manifest.application[0];

    if (!application.receiver) application.receiver = [];

    const alreadyAdded = application.receiver.some(
      (r) => r.$['android:name'] === '.MyDeviceAdminReceiver'
    );

    if (!alreadyAdded) {
      application.receiver.push({
        $: {
          'android:name': '.MyDeviceAdminReceiver',
          'android:label': 'یادآور - مدیریت دستگاه',
          'android:permission': 'android.permission.BIND_DEVICE_ADMIN',
          'android:exported': 'true',
        },
        'meta-data': [
          {
            $: {
              'android:name': 'android.app.device_admin',
              'android:resource': '@xml/device_admin_receiver',
            },
          },
        ],
        'intent-filter': [
          {
            action: [
              { $: { 'android:name': 'android.app.action.DEVICE_ADMIN_ENABLED' } },
            ],
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

      const javaDir = path.join(
        platformProjectRoot,
        'app/src/main/java',
        packagePath
      );
      const xmlDir = path.join(platformProjectRoot, 'app/src/main/res/xml');

      fs.mkdirSync(javaDir, { recursive: true });
      fs.mkdirSync(xmlDir, { recursive: true });

      const srcDir = path.join(projectRoot, 'android-src');

      const replacePackage = (content) =>
        content.replace(/__PACKAGE_NAME__/g, packageName);

      const ktFiles = [
        'MyDeviceAdminReceiver.kt',
        'LockTaskModule.kt',
        'LockTaskPackage.kt',
      ];
      for (const file of ktFiles) {
        const content = fs.readFileSync(path.join(srcDir, file), 'utf8');
        fs.writeFileSync(
          path.join(javaDir, file),
          replacePackage(content),
          'utf8'
        );
      }

      fs.copyFileSync(
        path.join(srcDir, 'device_admin_receiver.xml'),
        path.join(xmlDir, 'device_admin_receiver.xml')
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
        platformProjectRoot,
        'app/src/main/java',
        packagePath,
        'MainApplication.kt'
      );

      if (fs.existsSync(mainAppPath)) {
        let content = fs.readFileSync(mainAppPath, 'utf8');
        if (!content.includes('LockTaskPackage()')) {
          content = content.replace(
            /(PackageList\(this\)\.packages\s*)/,
            `$1.apply { add(LockTaskPackage()) }`
          );
          fs.writeFileSync(mainAppPath, content, 'utf8');
        }
      }

      return config;
    },
  ]);

  return config;
}

module.exports = withDeviceOwnerLock;
PLUGIN_EOF
echo "✅ plugins/withDeviceOwnerLock.js نوشته شد"

# --------------------------------------------------------------------
# 2) android-src/MyDeviceAdminReceiver.kt
# --------------------------------------------------------------------
cat > android-src/MyDeviceAdminReceiver.kt << 'KT1_EOF'
package __PACKAGE_NAME__

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class MyDeviceAdminReceiver : DeviceAdminReceiver() {

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.d("YaadavarAdmin", "Device Admin فعال شد")
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.d("YaadavarAdmin", "Device Admin غیرفعال شد")
    }
}
KT1_EOF

# --------------------------------------------------------------------
# 3) android-src/LockTaskModule.kt
# --------------------------------------------------------------------
cat > android-src/LockTaskModule.kt << 'KT2_EOF'
package __PACKAGE_NAME__

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod

class LockTaskModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName() = "LockTaskModule"

    private fun getDpm(): DevicePolicyManager {
        return reactApplicationContext.getSystemService(Context.DEVICE_POLICY_SERVICE)
                as DevicePolicyManager
    }

    private fun getAdminComponent(): ComponentName {
        return ComponentName(reactApplicationContext, MyDeviceAdminReceiver::class.java)
    }

    @ReactMethod
    fun isDeviceOwner(promise: Promise) {
        try {
            val dpm = getDpm()
            promise.resolve(dpm.isDeviceOwnerApp(reactApplicationContext.packageName))
        } catch (e: Exception) {
            promise.reject("ERR_CHECK_OWNER", e)
        }
    }

    @ReactMethod
    fun enableLockTaskPackage(promise: Promise) {
        try {
            val dpm = getDpm()
            val admin = getAdminComponent()
            if (dpm.isDeviceOwnerApp(reactApplicationContext.packageName)) {
                dpm.setLockTaskPackages(admin, arrayOf(reactApplicationContext.packageName))
            }
            promise.resolve(true)
        } catch (e: Exception) {
            promise.reject("ERR_ENABLE_LOCK_PKG", e)
        }
    }

    @ReactMethod
    fun startLockTask(promise: Promise) {
        try {
            val activity: Activity? = currentActivity
            if (activity == null) {
                promise.reject("ERR_NO_ACTIVITY", "اکتیویتی فعالی پیدا نشد")
                return
            }
            activity.startLockTask()
            promise.resolve(true)
        } catch (e: Exception) {
            promise.reject("ERR_START_LOCK", e)
        }
    }

    @ReactMethod
    fun stopLockTask(promise: Promise) {
        try {
            val activity: Activity? = currentActivity
            if (activity == null) {
                promise.reject("ERR_NO_ACTIVITY", "اکتیویتی فعالی پیدا نشد")
                return
            }
            activity.stopLockTask()
            promise.resolve(true)
        } catch (e: Exception) {
            promise.reject("ERR_STOP_LOCK", e)
        }
    }
}
KT2_EOF

# --------------------------------------------------------------------
# 4) android-src/LockTaskPackage.kt
# --------------------------------------------------------------------
cat > android-src/LockTaskPackage.kt << 'KT3_EOF'
package __PACKAGE_NAME__

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager

class LockTaskPackage : ReactPackage {
    override fun createNativeModules(
        reactContext: ReactApplicationContext
    ): List<NativeModule> {
        return listOf(LockTaskModule(reactContext))
    }

    override fun createViewManagers(
        reactContext: ReactApplicationContext
    ): List<ViewManager<*, *>> {
        return emptyList()
    }
}
KT3_EOF

# --------------------------------------------------------------------
# 5) android-src/device_admin_receiver.xml
# --------------------------------------------------------------------
cat > android-src/device_admin_receiver.xml << 'XML_EOF'
<?xml version="1.0" encoding="utf-8"?>
<device-admin xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-policies>
        <limit-password />
    </uses-policies>
</device-admin>
XML_EOF

echo "✅ فایل‌های android-src نوشته شدند"

# --------------------------------------------------------------------
# 6) ویرایش app.json: اضافه کردن پلاگین به لیست plugins
# --------------------------------------------------------------------
python3 << 'PYEOF'
import json

with open('app.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

expo = data.setdefault('expo', {})
plugins = expo.setdefault('plugins', [])

target = './plugins/withDeviceOwnerLock'
already = any(
    (p == target) or (isinstance(p, list) and len(p) > 0 and p[0] == target)
    for p in plugins
)
if not already:
    plugins.append(target)

with open('app.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write('\n')

pkg = expo.get('android', {}).get('package', '<< applicationId را در app.json پیدا نشد >>')
with open('.device_owner_package.txt', 'w') as f:
    f.write(pkg)

print("✅ app.json آپدیت شد (applicationId: " + pkg + ")")
PYEOF

# --------------------------------------------------------------------
# 7) پچ App.js: اضافه کردن import و فراخوانی startLockTask/stopLockTask
# --------------------------------------------------------------------
python3 << 'PYEOF'
import re

with open('App.js', 'r', encoding='utf-8') as f:
    content = f.read()

changed = False

# اضافه کردن import ماژول نیتیو (اگه قبلاً نیست)
if 'LockTaskModule' not in content:
    import_line = "import { NativeModules } from 'react-native';\nconst { LockTaskModule } = NativeModules;\n"
    marker = "import { Ionicons } from '@expo/vector-icons';"
    if marker in content:
        content = content.replace(marker, marker + "\n" + import_line, 1)
        changed = True
    else:
        content = import_line + content
        changed = True

# اضافه کردن enableLockTaskPackage بعد از بلاک useEffect اولیه (loadData/configureChannel/checkActive)
anchor = """  useEffect(() => {
    loadData();
    configureChannel();
    checkActive();
    setTimeout(() => {
      createStickyNotification();
    }, 2000);"""

if anchor in content and 'enableLockTaskPackage' not in content:
    replacement = anchor + """

    // اضافه شد: ثبت پکیج برای Lock Task (فقط وقتی Device Owner باشیم اثر داره)
    if (Platform.OS === 'android' && LockTaskModule) {
      LockTaskModule.enableLockTaskPackage().catch(() => {});
    }"""
    content = content.replace(anchor, replacement, 1)
    changed = True
else:
    print("⚠️  انکر useEffect اولیه پیدا نشد یا قبلاً پچ شده — این بخش دستی نیاز به بررسی داره")

# اضافه کردن startLockTask داخل تعریف تابع openPopup (هر امضایی که داشته باشه)
def patch_function(src, func_name, call_line):
    pattern = re.compile(r'(function\s+' + func_name + r'\s*\([^)]*\)\s*\{)')
    m = pattern.search(src)
    if not m:
        print(f"⚠️  تابع {func_name} پیدا نشد — این بخش رو دستی طبق App.js.patch.md اضافه کن")
        return src, False
    if call_line.strip() in src:
        return src, False
    insert_at = m.end()
    injected = "\n    " + call_line
    return src[:insert_at] + injected + src[insert_at:], True

lock_call = "if (Platform.OS === 'android' && LockTaskModule) { LockTaskModule.startLockTask().catch(() => {}); }"
unlock_call = "if (Platform.OS === 'android' && LockTaskModule) { LockTaskModule.stopLockTask().catch(() => {}); }"

content, c1 = patch_function(content, 'openPopup', lock_call)
content, c2 = patch_function(content, 'closePopup', unlock_call)
changed = changed or c1 or c2

with open('App.js', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ App.js پردازش شد" if changed else "ℹ️  App.js از قبل پچ شده بود، تغییری اعمال نشد")
PYEOF

PKG=$(cat .device_owner_package.txt)
rm -f .device_owner_package.txt

# --------------------------------------------------------------------
# 8) git add / commit / push
# --------------------------------------------------------------------
echo ""
echo "📦 گیت..."
git add .
git commit -m "افزودن Device Owner Lock Task برای قفل کامل صفحه پاپ‌آپ" || echo "ℹ️  چیزی برای کامیت نبود"
git push

echo ""
echo "======================================================================"
echo "✅ تمام شد و پوش شد. GitHub Actions حالا APK جدید رو می‌سازه."
echo ""
echo "بعد از دانلود و نصب APK جدید (بدون باز کردن اپ)، روی گوشی با ADB بزن:"
echo ""
echo "   adb shell dpm set-device-owner ${PKG}/.MyDeviceAdminReceiver"
echo ""
echo "⚠️  این دستور فقط وقتی کار می‌کنه که هیچ اکانت گوگلی روی گوشی نباشه."
echo "======================================================================"
