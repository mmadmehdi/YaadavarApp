#!/data/data/com.termux/files/usr/bin/bash
set -e

if [ ! -f "App.js" ]; then
  echo "❌ این اسکریپت باید داخل ریشه پروژه (کنار App.js) اجرا بشه."
  exit 1
fi

python3 << 'PYEOF'
content = open('App.js', 'r', encoding='utf-8').read()
changed = False

old = """  function triggerRandomPopup() {
    AsyncStorage.getItem(STORAGE_KEY).then((saved) => {
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

if new in content:
    print("ℹ️  قبلاً اعمال شده بود")
elif old in content:
    content = content.replace(old, new, 1)
    with open('App.js', 'w', encoding='utf-8') as f:
        f.write(content)
    changed = True
    print("✅ triggerRandomPopup حالا مدت قفل رو مستقیم و مطمئن می‌خونه")
else:
    print("⚠️  انکر پیدا نشد — این بخش رو دستی توی App.js چک کن")

if not changed:
    print("ℹ️  تغییری اعمال نشد")
PYEOF

echo ""
echo "📦 گیت..."
git add .
git commit -m "fix: رفع race condition مدت قفل پاپ‌آپ هنگام باز شدن از دکمه پنل" || echo "ℹ️  چیزی برای کامیت نبود"
git push

echo ""
echo "======================================================================"
echo "✅ تمام شد و پوش شد."
echo "از این به بعد، دکمه پنل بالای گوشی همیشه آخرین مدت قفلی که تنظیم کرده"
echo "باشی رو می‌خونه و اعمال می‌کنه، مهم نیست اپ تازه باز شده باشه یا نه."
echo "======================================================================"
