#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -f "App.js" ] || { echo "❌ کنار App.js اجرا کن"; exit 1; }

python3 << 'PYEOF'
content = open('App.js', 'r', encoding='utf-8').read()

old = "  const appState = useRef(AppState.currentState);"
new = old + """

  useEffect(() => {
    const loadKeywords = () => {
      if (Platform.OS === 'android' && KeywordFilterModule) {
        KeywordFilterModule.getKeywords()
          .then((csv) => setKeywordsText(csv || ''))
          .catch(() => {});
      }
    };
    loadKeywords();
    const kwSub = AppState.addEventListener('change', (next) => {
      if (next === 'active') loadKeywords();
    });
    return () => kwSub.remove();
  }, []);"""

if new in content:
    print("ℹ️  قبلاً اعمال شده بود")
elif old in content:
    content = content.replace(old, new, 1)
    with open('App.js', 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ بارگذاری لیست کلمات ذخیره‌شده اضافه شد")
else:
    print("⚠️  انکر پیدا نشد — دستی چک کن")
PYEOF

echo ""
grep -n "loadKeywords\|getKeywords" App.js

echo ""
echo "📦 گیت..."
git add .
git commit -m "fix: بارگذاری واقعی لیست کلمات کلیدی ذخیره‌شده هنگام باز شدن/فعال شدن اپ" || echo "ℹ️  چیزی برای کامیت نبود"
git push

echo ""
echo "✅ تمام شد و پوش شد."
