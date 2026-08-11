#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -f "App.js" ] || { echo "❌"; exit 1; }

python3 << 'PYEOF'
content = open('App.js', 'r', encoding='utf-8').read()

idx = content.find('جملات خود را وارد کن')
if idx == -1:
    print("⚠️ عبارت اصلاً پیدا نشد")
else:
    start = content.rfind('<Text', 0, idx)
    end_marker_idx = content.find('فاصله زمانی', idx)
    if end_marker_idx == -1:
        print("⚠️ انکر پایانی 'فاصله زمانی' پیدا نشد")
    else:
        end = content.rfind('<Text', 0, end_marker_idx)
        if start != -1 and end != -1 and end > start:
            removed = content[start:end]
            content = content[:start] + content[end:]
            with open('App.js', 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✅ باکس قدیمی جملات حذف شد ({len(removed)} کاراکتر)")
            print("--- بخش حذف‌شده (برای تایید) ---")
            print(removed[:300])
        else:
            print("⚠️ محدوده حذف پیدا نشد")
PYEOF

git add .
git commit -m "fix: حذف قطعی باکس قدیمی جملات (عبارت درست)" || echo "چیزی برای کامیت نبود"
git push
echo "✅ تمام شد"
