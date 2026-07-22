#!/data/data/com.termux/files/usr/bin/bash
# ====================================================================
#  setup_foreground_service_notif.sh
#  اجرا کن داخل پوشه پروژه (YaadavarAppFresh) با:
#     bash setup_foreground_service_notif.sh
# ====================================================================
set -e

if [ ! -f "App.js" ] || [ ! -f "app.json" ]; then
  echo "❌ این اسکریپت باید داخل ریشه پروژه (کنار App.js و app.json) اجرا بشه."
  exit 1
fi

echo "📁 ساخت پوشه‌ها..."
mkdir -p plugins android-src2

# --------------------------------------------------------------------
# 1) plugins/withForegroundService.js
# --------------------------------------------------------------------
cat > plugins/withForegroundService.js << 'PLUGIN_EOF'
const {
  withAndroidManifest,
  withDangerousMod,
} = require('@expo/config-plugins');
const fs = require('fs');
const path = require('path');

function ensurePermission(androidManifest, name) {
  if (!androidManifest.manifest['uses-permission']) {
    androidManifest.manifest['uses-permission'] = [];
  }
  const exists = androidManifest.manifest['uses-permission'].some(
    (p) => p.$['android:name'] === name
  );
  if (!exists) {
    androidManifest.manifest['uses-permission'].push({ $: { 'android:name': name } });
  }
}

function withForegroundService(config) {
  config = withAndroidManifest(config, (config) => {
    const androidManifest = config.modResults;
    ensurePermission(androidManifest, 'android.permission.FOREGROUND_SERVICE');
    ensurePermission(androidManifest, 'android.permission.FOREGROUND_SERVICE_SPECIAL_USE');

    const application = androidManifest.manifest.application[0];
    if (!application.service) application.service = [];

    const already = application.service.some(
      (s) => s.$['android:name'] === '.StickyReminderService'
    );

    if (!already) {
      application.service.push({
        $: {
          'android:name': '.StickyReminderService',
          'android:exported': 'false',
          'android:foregroundServiceType': 'specialUse',
        },
        property: [
          {
            $: {
              'android:name': 'android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE',
              'android:value': 'persistent_reminder_notification',
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
      fs.mkdirSync(javaDir, { recursive: true });

      const srcDir = path.join(projectRoot, 'android-src2');

      const replacePlaceholders = (content) =>
        content
          .replace(/__PACKAGE_NAME__/g, packageName)
          .replace(/__SCHEME__/g, scheme);

      const ktFiles = [
        'StickyReminderService.kt',
        'StickyServiceModule.kt',
        'StickyServicePackage.kt',
      ];
      for (const file of ktFiles) {
        const content = fs.readFileSync(path.join(srcDir, file), 'utf8');
        fs.writeFileSync(path.join(javaDir, file), replacePlaceholders(content), 'utf8');
      }

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
        if (!content.includes('StickyServicePackage()')) {
          content = content.replace(
            /(PackageList\(this\)\.packages\s*)/,
            `$1.apply { add(StickyServicePackage()) }`
          );
          fs.writeFileSync(mainAppPath, content, 'utf8');
        }
      }

      return config;
    },
  ]);

  return config;
}

module.exports = withForegroundService;
PLUGIN_EOF
echo "✅ plugins/withForegroundService.js نوشته شد"

# --------------------------------------------------------------------
# 2) android-src2/StickyReminderService.kt
# --------------------------------------------------------------------
cat > android-src2/StickyReminderService.kt << 'KT1_EOF'
package __PACKAGE_NAME__

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.SystemClock

class StickyReminderService : Service() {

    companion object {
        const val CHANNEL_ID = "urgent_channel"
        const val NOTIF_ID = 5501
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIF_ID, buildNotification())
        return START_STICKY
    }

    // اگه اپ از Recent Apps پاک بشه، سرویس (و در نتیجه نوتیفیکیشن) خودکار دوباره راه‌اندازی می‌شه
    override fun onTaskRemoved(rootIntent: Intent?) {
        val restartIntent = Intent(applicationContext, StickyReminderService::class.java)
        restartIntent.setPackage(packageName)
        val restartPendingIntent = PendingIntent.getService(
            applicationContext, 1, restartIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmService = getSystemService(ALARM_SERVICE) as AlarmManager
        alarmService.set(
            AlarmManager.ELAPSED_REALTIME,
            SystemClock.elapsedRealtime() + 1000,
            restartPendingIntent
        )
        super.onTaskRemoved(rootIntent)
    }

    private fun buildNotification(): Notification {
        createChannelIfNeeded()

        val popupIntent = Intent(Intent.ACTION_VIEW, Uri.parse("__SCHEME__://popup"))
        popupIntent.setPackage(packageName)
        popupIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val contentPendingIntent = PendingIntent.getActivity(
            this, 0, popupIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("✨ یادآور جملات")
            .setContentText("برای نمایش جمله فوری کلیک کنید")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(contentPendingIntent)
            .build()
    }

    private fun createChannelIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID, "یادآورهای فوری", NotificationManager.IMPORTANCE_HIGH
                )
                manager.createNotificationChannel(channel)
            }
        }
    }
}
KT1_EOF

# --------------------------------------------------------------------
# 3) android-src2/StickyServiceModule.kt
# --------------------------------------------------------------------
cat > android-src2/StickyServiceModule.kt << 'KT2_EOF'
package __PACKAGE_NAME__

import android.content.Intent
import android.os.Build
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod

class StickyServiceModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName() = "StickyServiceModule"

    @ReactMethod
    fun startStickyService(promise: Promise) {
        try {
            val intent = Intent(reactApplicationContext, StickyReminderService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                reactApplicationContext.startForegroundService(intent)
            } else {
                reactApplicationContext.startService(intent)
            }
            promise.resolve(true)
        } catch (e: Exception) {
            promise.reject("ERR_START_SERVICE", e)
        }
    }

    @ReactMethod
    fun stopStickyService(promise: Promise) {
        try {
            val intent = Intent(reactApplicationContext, StickyReminderService::class.java)
            reactApplicationContext.stopService(intent)
            promise.resolve(true)
        } catch (e: Exception) {
            promise.reject("ERR_STOP_SERVICE", e)
        }
    }
}
KT2_EOF

# --------------------------------------------------------------------
# 4) android-src2/StickyServicePackage.kt
# --------------------------------------------------------------------
cat > android-src2/StickyServicePackage.kt << 'KT3_EOF'
package __PACKAGE_NAME__

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager

class StickyServicePackage : ReactPackage {
    override fun createNativeModules(
        reactContext: ReactApplicationContext
    ): List<NativeModule> {
        return listOf(StickyServiceModule(reactContext))
    }

    override fun createViewManagers(
        reactContext: ReactApplicationContext
    ): List<ViewManager<*, *>> {
        return emptyList()
    }
}
KT3_EOF

echo "✅ فایل‌های android-src2 نوشته شدند"

# --------------------------------------------------------------------
# 5) اضافه کردن پلاگین به app.json
# --------------------------------------------------------------------
python3 << 'PYEOF'
import json

with open('app.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

expo = data.setdefault('expo', {})
plugins = expo.setdefault('plugins', [])

target = './plugins/withForegroundService'
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
# 6) پچ App.js: استفاده از سرویس نیتیو به‌جای نوتیفیکیشن expo-notifications
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

# 1) اضافه کردن StickyServiceModule به ایمپورت نیتیو
old = "const { LockTaskModule } = NativeModules;"
new = "const { LockTaskModule, StickyServiceModule } = NativeModules;"
content, changed = patch(old, new, "ایمپورت StickyServiceModule", content, changed)

# 2) شروع سرویس واقعی به‌جای نوتیفیکیشن expo-notifications در راه‌اندازی اولیه
old = """    setTimeout(() => {
      createStickyNotification();
    }, 2000);"""
new = """    setTimeout(() => {
      Notifications.dismissNotificationAsync(STICKY_NOTIF_ID).catch(() => {});
      if (Platform.OS === 'android' && StickyServiceModule) {
        StickyServiceModule.startStickyService().catch(() => {});
      }
    }, 2000);"""
content, changed = patch(old, new, "شروع Foreground Service", content, changed)

# 3) جایگزینی چک‌های دوره‌ای قدیمی با شروع مجدد سرویس (idempotent-safe)
old_call = "ensureNotificationExists();"
new_call = "if (Platform.OS === 'android' && StickyServiceModule) { StickyServiceModule.startStickyService().catch(() => {}); }"
if old_call in content:
    content = content.replace(old_call, new_call)
    changed = True
    print("✅ چک‌های دوره‌ای به Foreground Service وصل شدند")
else:
    print("ℹ️  چک‌های دوره‌ای قبلاً اصلاح شده بودند")

with open('App.js', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ App.js پردازش شد" if changed else "ℹ️  تغییری لازم نبود")
PYEOF

echo ""
echo "📦 گیت..."
git add .
git commit -m "افزودن Foreground Service واقعی برای نوتیفیکیشن کاملاً پایدار در برابر MIUI" || echo "ℹ️  چیزی برای کامیت نبود"
git push

echo ""
echo "======================================================================"
echo "✅ تمام شد و پوش شد."
echo ""
echo "نکته: اولین بار که اپ رو باز کنی، نوتیفیکیشن قدیمی (اگه هنوز مونده) ممکنه"
echo "یه بار به‌صورت جداگانه دیده بشه؛ به‌محض باز شدن اپ خودش پاک و با نسخه"
echo "سرویس واقعی جایگزین می‌شه. از این به بعد نوتیفیکیشن با پاک کردن، تپ زدن،"
echo "یا حتی بستن اپ از Recent Apps محو نمی‌شه (خودش رو ری‌استارت می‌کنه)."
echo "======================================================================"
