#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -f "App.js" ] || { echo "❌ کنار App.js اجرا کن"; exit 1; }

python3 << 'PYEOF'
content = open('App.js', 'r', encoding='utf-8').read()

if "const [keywordsText, setKeywordsText] = useState('');" in content:
    print("ℹ️  قبلاً تعریف شده")
else:
    old = "  const [popupTimerActive, setPopupTimerActive] = useState(false);"
    if old in content:
        content = content.replace(old, old + "\n  const [keywordsText, setKeywordsText] = useState('');", 1)
        print("✅ state keywordsText اضافه شد")
    else:
        old2 = "export default function App"
        idx = content.find(old2)
        content = content[:idx] + "\n" + content[idx:]
        print("⚠️ انکر اصلی پیدا نشد، دستی بررسی کن")

with open('App.js', 'w', encoding='utf-8') as f:
    f.write(content)
PYEOF

git add . && git commit -m "fix: تعریف state keywordsText" || echo "چیزی برای کامیت نبود"
git push
echo "✅ پوش شد"
