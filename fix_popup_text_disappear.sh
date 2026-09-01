#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -f "App.js" ] || { echo "❌"; exit 1; }

python3 << 'PYEOF'
content = open('App.js', 'r', encoding='utf-8').read()

old = "<View style={{ flex: 1, justifyContent: 'center' }}>"
new = "<View style={{ minHeight: 260, justifyContent: 'center' }}>"

if new in content:
    print("ℹ️  قبلاً اعمال شده بود")
elif old in content:
    content = content.replace(old, new, 1)
    with open('App.js', 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ ظرف متن اصلی از flex:1 به minHeight ثابت تغییر کرد")
else:
    print("⚠️ انکر پیدا نشد")
PYEOF

git add .
git commit -m "fix: رفع ناپدید شدن متن پاپ‌آپ" || echo "چیزی برای کامیت نبود"
git push
echo "✅ تمام شد"
