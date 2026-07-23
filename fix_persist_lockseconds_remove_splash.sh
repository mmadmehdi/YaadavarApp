#!/data/data/com.termux/files/usr/bin/bash
# ====================================================================
#  fix_persist_lockseconds_remove_splash.sh
#  اجرا کن داخل پوشه پروژه (YaadavarAppFresh) با:
#     bash fix_persist_lockseconds_remove_splash.sh
# ====================================================================
set -e

if [ ! -f "App.js" ]; then
  echo "❌ این اسکریپت باید داخل ریشه پروژه (کنار App.js) اجرا بشه."
  exit 1
fi

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

# --- کلید ذخیره‌سازی مدت قفل ---
old = "const ERROR_LOG_KEY = '@yaad_logs';"
new = old + "\nconst LOCK_SECONDS_KEY = '@yaad_lock_seconds';"
content, changed = patch(old, new, "کلید LOCK_SECONDS_KEY", content, changed)

# --- خوندن مقدار ذخیره‌شده موقع لود اولیه ---
old = """      const st = await AsyncStorage.getItem(NEXT_TIME_KEY);
      if (st) setNextTime(st);
      await refreshLogs();"""
new = """      const st = await AsyncStorage.getItem(NEXT_TIME_KEY);
      if (st) setNextTime(st);
      const ls = await AsyncStorage.getItem(LOCK_SECONDS_KEY);
      if (ls) setLockSeconds(parseInt(ls, 10));
      await refreshLogs();"""
content, changed = patch(old, new, "خواندن مدت قفل ذخیره‌شده در loadData", content, changed)

# --- ذخیره مقدار موقع زدن دکمه «تنظیم» مدت قفل ---
old = """            <TouchableOpacity
              style={styles.customBtn}
              onPress={() => {
                const secs = parseInt(lockSecondsInput, 10);
                if (!secs || secs <= 0) {
                  Alert.alert('خطا', 'یه عدد صحیح و مثبت برای ثانیه وارد کن');
                  return;
                }
                setLockSeconds(secs);
                Alert.alert('انجام شد', 'پاپ‌آپ از این به بعد ' + secs + ' ثانیه قفل می‌مونه');
              }}>"""
new = """            <TouchableOpacity
              style={styles.customBtn}
              onPress={async () => {
                const secs = parseInt(lockSecondsInput, 10);
                if (!secs || secs <= 0) {
                  Alert.alert('خطا', 'یه عدد صحیح و مثبت برای ثانیه وارد کن');
                  return;
                }
                setLockSeconds(secs);
                await AsyncStorage.setItem(LOCK_SECONDS_KEY, String(secs));
                Alert.alert('انجام شد', 'پاپ‌آپ از این به بعد ' + secs + ' ثانیه قفل می‌مونه');
              }}>"""
content, changed = patch(old, new, "ذخیره مدت قفل هنگام تنظیم", content, changed)

# --- حذف صفحه Splash موقع باز کردن اپ (فقط همین، بدون تاثیر روی پاپ‌آپ واقعی) ---
old = "  const [showSplash, setShowSplash]   = useState(true);"
new = "  const [showSplash, setShowSplash]   = useState(false);"
content, changed = patch(old, new, "غیرفعال کردن صفحه Splash", content, changed)

with open('App.js', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ App.js پردازش شد" if changed else "ℹ️  تغییری لازم نبود")
PYEOF

echo ""
echo "📦 گیت..."
git add .
git commit -m "fix: ذخیره‌سازی دائمی مدت قفل پاپ‌آپ + حذف صفحه Splash هنگام باز کردن اپ" || echo "ℹ️  چیزی برای کامیت نبود"
git push

echo ""
echo "======================================================================"
echo "✅ تمام شد و پوش شد."
echo ""
echo "- مدت قفل پاپ‌آپ از این به بعد توی خود گوشی ذخیره می‌شه و با بستن اپ از"
echo "  بین نمی‌ره."
echo "- صفحه‌ای که با جمله تصادفی موقع باز کردن اپ نشون داده می‌شد حذف شد؛"
echo "  پاپ‌آپ‌های واقعی (دکمه جمله فوری، نوتیفیکیشن، تایمر مستقل) بدون تغییرن."
echo "======================================================================"
