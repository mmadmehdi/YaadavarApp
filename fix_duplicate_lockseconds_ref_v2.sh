#!/data/data/com.termux/files/usr/bin/bash
set -e

if [ ! -f "App.js" ]; then
  echo "❌ این اسکریپت باید داخل ریشه پروژه (کنار App.js) اجرا بشه."
  exit 1
fi

echo "🔍 خطوطی که 'lockSecondsRef' توشون تعریف شده:"
grep -n "const lockSecondsRef" App.js || true

python3 << 'PYEOF'
import re

with open('App.js', 'r', encoding='utf-8') as f:
    lines = f.readlines()

decl_pattern = re.compile(r'^\s*const lockSecondsRef = useRef\(10\);\s*$')

decl_indices = [i for i, l in enumerate(lines) if decl_pattern.match(l)]
print(f"تعداد خط‌های تعریف پیدا‌شده: {len(decl_indices)}")

if len(decl_indices) <= 1:
    print("ℹ️  فقط یه تعریف هست یا اصلاً پیدا نشد — نیازی به تغییر نیست")
else:
    # برای هر تعریف اضافه (بعد از اولی)، خودِ خط تعریف + بلاک useEffect بعدش (۳ خط) رو حذف کن
    to_delete = set()
    for idx in decl_indices[1:]:
        to_delete.add(idx)
        # حذف بلاک useEffect همراهش اگه بلافاصله بعدش باشه
        j = idx + 1
        if j < len(lines) and 'useEffect(() => {' in lines[j]:
            to_delete.add(j)
            j += 1
            if j < len(lines) and 'lockSecondsRef.current = lockSeconds;' in lines[j]:
                to_delete.add(j)
                j += 1
                if j < len(lines) and lines[j].strip().startswith('}, [lockSeconds]);'):
                    to_delete.add(j)

    new_lines = [l for i, l in enumerate(lines) if i not in to_delete]
    with open('App.js', 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    print(f"✅ {len(to_delete)} خط اضافه حذف شد، فقط اولین تعریف باقی موند")
PYEOF

echo ""
echo "🔍 بررسی نهایی:"
grep -n "const lockSecondsRef" App.js || echo "(هیچی پیدا نشد؟!)"

echo ""
echo "📦 گیت..."
git add .
git commit -m "fix: حذف قطعی تعریف تکراری lockSecondsRef" || echo "ℹ️  چیزی برای کامیت نبود"
git push

echo "✅ تمام شد و پوش شد."
