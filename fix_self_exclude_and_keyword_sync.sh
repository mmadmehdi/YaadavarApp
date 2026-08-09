#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -f "App.js" ] || { echo "❌ کنار App.js اجرا کن"; exit 1; }

# --------------------------------------------------------------------
# 1) استثنا کردن خود اپ توی سرویس Accessibility
# --------------------------------------------------------------------
if [ -f "android-src3/KeywordAccessibilityService.kt" ]; then
  python3 << 'PYEOF'
path = 'android-src3/KeywordAccessibilityService.kt'
content = open(path, 'r', encoding='utf-8').read()

old = """    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val now = System.currentTimeMillis()"""
new = """    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // اضافه شد: خود اپ یادآور از اسکن استثنا بشه تا با متن‌های خودش قاطی نشه
        if (event?.packageName != null && event.packageName == packageName) return

        val now = System.currentTimeMillis()"""

if new in content:
    print("ℹ️  استثنای خود اپ قبلاً اعمال شده بود")
elif old in content:
    content = content.replace(old, new, 1)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ خود اپ یادآور از اسکن کلمات استثنا شد")
else:
    print("⚠️  انکر پیدا نشد — دستی چک کن")
PYEOF
else
  echo "ℹ️  android-src3/KeywordAccessibilityService.kt پیدا نشد، این بخش رد شد"
fi

# --------------------------------------------------------------------
# 2) هم‌گام‌سازی خودکار لیست کلمات هر بار که اپ باز/فعال می‌شه
# --------------------------------------------------------------------
python3 << 'PYEOF'
content = open('App.js', 'r', encoding='utf-8').read()

old = """  useEffect(() => {
    if (Platform.OS === 'android' && KeywordFilterModule) {
      KeywordFilterModule.getKeywords()
        .then((csv) => setKeywordsText(csv || ''))
        .catch(() => {});
    }
  }, []);"""

new = old + """

  useEffect(() => {
    const kwSub = AppState.addEventListener('change', (next) => {
      if (next === 'active' && Platform.OS === 'android' && KeywordFilterModule) {
        KeywordFilterModule.getKeywords()
          .then((csv) => setKeywordsText(csv || ''))
          .catch(() => {});
      }
    });
    return () => kwSub.remove();
  }, []);"""

if new in content:
    print("ℹ️  هم‌گام‌سازی خودکار قبلاً اعمال شده بود")
elif old in content:
    content = content.replace(old, new, 1)
    with open('App.js', 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ لیست کلمات حالا هر بار اپ فعال بشه دوباره از حافظه گوشی خونده می‌شه")
else:
    print("⚠️  انکر پیدا نشد — دستی چک کن (شاید بخش کلمات کلیدی حذف شده باشه)")
PYEOF

echo ""
echo "📦 گیت..."
git add .
git commit -m "fix: استثنا کردن خود اپ از اسکن کلمات + هم‌گام‌سازی خودکار لیست ذخیره‌شده" || echo "ℹ️  چیزی برای کامیت نبود"
git push

echo ""
echo "======================================================================"
echo "✅ تمام شد و پوش شد."
echo "- خود اپ یادآور دیگه هیچ‌وقت توسط سرویس Accessibility اسکن نمی‌شه."
echo "- هر بار اپ رو باز/فعال کنی، لیست کلمات ذخیره‌شده دوباره از حافظه گوشی"
echo "  خونده و توی باکس نمایش داده می‌شه (خودِ لیست هیچ‌وقت با خاموش/روشن"
echo "  کردن Accessibility پاک نمی‌شه چون توی حافظه دائمی گوشیه، نه موقت)."
echo "======================================================================"
