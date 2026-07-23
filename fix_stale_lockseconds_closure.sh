#!/data/data/com.termux/files/usr/bin/bash
# ====================================================================
#  fix_stale_lockseconds_closure.sh
#  اجرا کن داخل پوشه پروژه (YaadavarAppFresh) با:
#     bash fix_stale_lockseconds_closure.sh
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

# --- ref همیشه‌به‌روز برای lockSeconds ---
old = "  const cdInterval                    = useRef(null);"
new = old + """
  const lockSecondsRef = useRef(10);
  useEffect(() => {
    lockSecondsRef.current = lockSeconds;
  }, [lockSeconds]);"""
content, changed = patch(old, new, "ref همیشه‌به‌روز lockSecondsRef", content, changed)

# --- استفاده از ref به‌جای state مستقیم موقع شروع شمارش معکوس ---
old_call = "setSecsLeft(lockSeconds)"
new_call = "setSecsLeft(lockSecondsRef.current)"
if new_call in content:
    print("ℹ️  استفاده از ref در setSecsLeft: قبلاً اعمال شده بود")
elif old_call in content:
    content = content.replace(old_call, new_call)
    changed = True
    print("✅ setSecsLeft حالا از ref همیشه‌به‌روز استفاده می‌کنه")
else:
    print("⚠️  setSecsLeft(lockSeconds) پیدا نشد — این بخش رو دستی چک کن")

with open('App.js', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ App.js پردازش شد" if changed else "ℹ️  تغییری لازم نبود")
PYEOF

echo ""
echo "📦 گیت..."
git add .
git commit -m "fix: رفع stale closure در مدت قفل پاپ‌آپ (استفاده از ref به‌جای state مستقیم)" || echo "ℹ️  چیزی برای کامیت نبود"
git push

echo ""
echo "======================================================================"
echo "✅ تمام شد و پوش شد."
echo "از این به بعد، هر کدوم از این سه مسیر که پاپ‌آپ رو باز کنن (دکمه پنل،"
echo "نوتیفیکیشن دائمی، یا تایمر مستقل) همیشه از آخرین عددی که برای مدت قفل"
echo "تنظیم کرده باشی استفاده می‌کنن."
echo "======================================================================"
