# کیوسک واقعی (Device Owner) برای یادآور — راهنمای نصب

## ⚠️ قبل از هر چیز بخون

- تنظیم Device Owner **فقط وقتی گوشی هیچ اکانت گوگلی نداشته باشه** ممکنه (یعنی
  باید یا از صفر ست‌آپ کنی، یا Factory Reset بزنی و از اکانت‌ها رد بشی).
- این حالت غیرقابل‌برگشت نیست، ولی برای برداشتنش هم به ADB نیاز داری (پایین توضیح دادم).
- روی MIUI (Poco M5s) بعضی وقت‌ها نیاز داری قبلش **"MIUI Optimization"** رو توی
  Developer Options خاموش کنی، وگرنه `dpm set-device-owner` با خطای مجوز رد می‌شه.

## فایل‌ها

```
plugins/withDeviceOwnerLock.js      ← کانفیگ پلاگین اکسپو (ثبت خودکار موقع prebuild)
android-src/MyDeviceAdminReceiver.kt
android-src/LockTaskModule.kt
android-src/LockTaskPackage.kt
android-src/device_admin_receiver.xml
app.json.snippet.json               ← نمونه‌ی اضافه کردن پلاگین به app.json
App.js.patch.md                     ← تغییرات لازم توی App.js
```

## مراحل نصب توی پروژه

1. پوشه `plugins/` رو با محتوای `withDeviceOwnerLock.js` merge کن با پوشه
   `plugins/` فعلی پروژه‌ت (کنار `withQuickTile.js`).
2. پوشه `android-src/` رو دقیقاً با همین اسم توی ریشه پروژه (کنار `App.js`) بذار.
   پلاگین موقع prebuild خودش فایل‌ها رو از اینجا می‌خونه و به مسیر نیتیو کپی می‌کنه.
3. توی `app.json`، پلاگین جدید رو اضافه کن (طبق `app.json.snippet.json`):
   ```json
   "plugins": [
     "./plugins/withQuickTile",
     "./plugins/withDeviceOwnerLock"
   ]
   ```
4. تغییرات `App.js.patch.md` رو دستی توی `App.js` اعمال کن (چون فایل کامل شما
   رو نداشتم، این‌طوری دقیق‌تر از overwrite کردنه).
5. کامیت و پوش کن — GitHub Actions خودش `expo prebuild` رو اجرا می‌کنه و همه‌چیز
   خودکار wire می‌شه، دقیقاً مثل مکانیزم فعلی `withQuickTile`.

## مراحل روی خود گوشی (یک‌بار، بعد از نصب APK جدید)

1. APK جدید (از آرتیفکت `YaadavarApp-Signed-APK`) رو نصب کن، ولی **باز نکن**.
2. گوشی رو به کامپیوتر وصل کن، USB Debugging رو فعال کن (Developer Options).
3. مطمئن شو **هیچ اکانت گوگلی روی گوشی نیست** (اگه هست، از Settings > Accounts
   پاکش کن یا از صفر Factory Reset کن و از مرحله‌ی اکانت رد شو / Skip بزن).
4. توی ترمینال کامپیوتر:
   ```bash
   adb devices                # مطمئن شو گوشی دیده می‌شه
   adb shell dpm set-device-owner com.yaadavar.app/.MyDeviceAdminReceiver
   ```
   (به‌جای `com.yaadavar.app` دقیقاً همون applicationId واقعی پروژه‌ت رو بذار)
5. اگه پیام `Success: Device owner set` رو دیدی، تمومه. حالا اپ رو باز کن.

## تست

- روی دکمه "جمله فوری" (چه از پنل بالای گوشی چه از داخل اپ) بزن.
- توی پاپ‌آپ، سعی کن Home بزنی — نباید هیچ اتفاقی بیفته.
- بعد از ۱۰ ثانیه که دکمه "بستن ✕" ظاهر شد، قفل خودکار برداشته می‌شه.

## اگه خواستی برگردونی (حذف Device Owner)

```bash
adb shell dpm remove-active-admin com.yaadavar.app/.MyDeviceAdminReceiver
```

## مشکلات رایج

| مشکل | راه‌حل |
|---|---|
| `Not allowed to set the device owner because there are already several accounts` | همه اکانت‌های گوگل رو از گوشی پاک کن یا Factory Reset بزن |
| MIUI بازم اجازه نمی‌ده | Settings > Additional Settings > Developer Options > "MIUI Optimization" رو خاموش کن، ری‌استارت بزن، دوباره امتحان کن |
| `startLockTask` خطا می‌ده ولی isDeviceOwner true هست | مطمئن شو `enableLockTaskPackage()` قبلش صدا زده شده (مرحله ۲ پچ App.js) |
