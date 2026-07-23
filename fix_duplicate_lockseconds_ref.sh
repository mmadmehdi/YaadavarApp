#!/data/data/com.termux/files/usr/bin/bash
set -e

if [ ! -f "App.js" ]; then
  echo "❌ این اسکریپت باید داخل ریشه پروژه (کنار App.js) اجرا بشه."
  exit 1
fi

python3 << 'PYEOF'
import re

content = open('App.js', 'r', encoding='utf-8').read()

block = """  const lockSecondsRef = useRef(10);
  useEffect(() => {
    lockSecondsRef.current = lockSeconds;
  }, [lockSeconds]);"""

count = content.count(block)
print(f"تعداد نسخه‌های تکراری پیدا‌شده: {count}")

if count > 1:
    # فقط اولین نسخه رو نگه دار، بقیه رو حذف کن
    first = content.find(block)
    after_first = first + len(block)
    before = content[:after_first]
    rest = content[after_first:]
    rest = rest.replace(block, "", count - 1)
    content = before + rest
    with open('App.js', 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ نسخه‌های تکراری حذف شدند، فقط یکی باقی موند")
elif count == 1:
    print("ℹ️  فقط یه نسخه هست، مشکلی نیست — احتمالاً یه تعریف دیگه با اسم مشابه جای دیگه‌ست")
else:
    print("⚠️  بلاک پیدا نشد")
PYEOF

echo ""
echo "📦 گیت..."
git add .
git commit -m "fix: حذف تعریف تکراری lockSecondsRef" || echo "ℹ️  چیزی برای کامیت نبود"
git push

echo "✅ تمام شد و پوش شد."
