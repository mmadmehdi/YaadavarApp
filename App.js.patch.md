# تغییرات لازم در App.js

## ۱) ایمپورت ماژول نیتیو (بالای فایل، کنار بقیه importها)

```javascript
import { NativeModules, Platform } from 'react-native';
const { LockTaskModule } = NativeModules;
```

## ۲) یه بار در startup، اپ رو به لیست سفید Lock Task اضافه کن

داخل همون `useEffect` اولیه (همونی که `loadData()` و `configureChannel()` رو صدا می‌زنه) اضافه کن:

```javascript
useEffect(() => {
  loadData();
  configureChannel();
  checkActive();
  setTimeout(() => {
    createStickyNotification();
  }, 2000);

  // اضافه شد: ثبت پکیج برای Lock Task (فقط وقتی Device Owner باشیم اثر داره)
  if (Platform.OS === 'android' && LockTaskModule) {
    LockTaskModule.enableLockTaskPackage().catch(() => {});
  }

  const subscription = AppState.addEventListener('change', (nextAppState) => {
    ...
```

## ۳) قفل کردن صفحه هنگام باز شدن پاپ‌آپ، باز کردن قفل بعد از ۱۰ ثانیه

تابع `openPopup` رو پیدا کن (جایی که `setShowPopup(true)` و شمارش معکوس `secsLeft` رو راه می‌ندازه) و این‌طوری تغییرش بده:

```javascript
function openPopup(text) {
  setPopupText(text);
  setPalIdx(Math.floor(Math.random() * PALETTES.length));
  setShowPopup(true);
  setSecsLeft(10);

  // اضافه شد: قفل کردن صفحه (بلاک کردن Home/Recents)
  if (Platform.OS === 'android' && LockTaskModule) {
    LockTaskModule.startLockTask().catch((e) =>
      addLog('خطا در قفل صفحه: ' + e.message)
    );
  }

  Animated.timing(popupFade, { toValue: 1, duration: 400, useNativeDriver: true }).start();

  cdInterval.current = setInterval(() => {
    setSecsLeft((prev) => {
      if (prev <= 1) {
        clearInterval(cdInterval.current);

        // اضافه شد: باز کردن قفل درست وقتی ۱۰ ثانیه تموم شد
        if (Platform.OS === 'android' && LockTaskModule) {
          LockTaskModule.stopLockTask().catch(() => {});
        }

        return 0;
      }
      return prev - 1;
    });
  }, 1000);
}
```

> نکته: چون تابع اصلی `openPopup` شما رو ندیدم (خطوط ۱۵۹-۳۵۹ فایل truncate شده بود)،
> این پچ رو بر اساس رفتار توصیف‌شده (شمارش معکوس ۱۰ ثانیه، `secsLeft`, `popupFade`) نوشتم.
> اگه اسم متغیرها یا ساختار دقیق فرق داره، عین همون بخش کد رو برام بفرست تا دقیقاً
> patch رو منطبق کنم.

## ۴) اطمینان از بسته شدن قفل حتی اگه کاربر یه‌جوری از پاپ‌آپ خارج بشه

توی تابع `closePopup` (جایی که با دکمه "بستن ✕" صدا زده می‌شه) هم یه stopLockTask
اضافه کن که safety net باشه:

```javascript
function closePopup() {
  if (Platform.OS === 'android' && LockTaskModule) {
    LockTaskModule.stopLockTask().catch(() => {});
  }
  setShowPopup(false);
  clearInterval(cdInterval.current);
}
```
