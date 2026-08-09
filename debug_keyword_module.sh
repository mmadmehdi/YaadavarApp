#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -f "App.js" ] && [ -f "app.json" ] || { echo "❌"; exit 1; }

echo "🔍 بررسی وجود فایل‌های پلاگین:"
[ -f "plugins/withKeywordAccessibility.js" ] && echo "✅ plugins/withKeywordAccessibility.js هست" || echo "❌ plugins/withKeywordAccessibility.js نیست!"
[ -f "android-src3/KeywordAccessibilityService.kt" ] && echo "✅ android-src3/KeywordAccessibilityService.kt هست" || echo "❌ android-src3/KeywordAccessibilityService.kt نیست!"
[ -f "android-src3/KeywordFilterModule.kt" ] && echo "✅ android-src3/KeywordFilterModule.kt هست" || echo "❌ android-src3/KeywordFilterModule.kt نیست!"
[ -f "android-src3/KeywordFilterPackage.kt" ] && echo "✅ android-src3/KeywordFilterPackage.kt هست" || echo "❌ android-src3/KeywordFilterPackage.kt نیست!"

echo ""
echo "🔍 لیست پلاگین‌های app.json:"
python3 -c "
import json
data = json.load(open('app.json', encoding='utf-8'))
plugins = data.get('expo', {}).get('plugins', [])
for p in plugins:
    print(' -', p)
if not any('withKeywordAccessibility' in str(p) for p in plugins):
    print('❌ withKeywordAccessibility توی لیست پلاگین‌های app.json نیست!')
else:
    print('✅ withKeywordAccessibility توی لیست پلاگین‌های app.json هست')
"

# --------------------------------------------------------------------
# اضافه کردن دکمه دیباگ موقت به App.js
# --------------------------------------------------------------------
python3 << 'PYEOF'
content = open('App.js', 'r', encoding='utf-8').read()

old = "          <TouchableOpacity style={styles.btnPurple} onPress={quickReminder}>"
new = """          <TouchableOpacity
            style={styles.btnRed}
            onPress={() => {
              Alert.alert(
                'دیباگ ماژول‌ها',
                'LockTaskModule: ' + (LockTaskModule ? 'موجوده' : 'undefined') +
                '\\nStickyServiceModule: ' + (StickyServiceModule ? 'موجوده' : 'undefined') +
                '\\nKeywordFilterModule: ' + (KeywordFilterModule ? 'موجوده' : 'undefined')
              );
            }}>
            <Ionicons name="bug" size={20} color="#fff" style={{ marginRight: 8 }} />
            <Text style={styles.btnTxt}>دیباگ ماژول‌ها (موقت)</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.btnPurple} onPress={quickReminder}>"""

if 'دیباگ ماژول‌ها' in content:
    print("ℹ️  دکمه دیباگ قبلاً اضافه شده بود")
elif old in content:
    content = content.replace(old, new, 1)
    with open('App.js', 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ دکمه دیباگ اضافه شد")
else:
    print("⚠️  انکر پیدا نشد")
PYEOF

echo ""
echo "📦 گیت..."
git add .
git commit -m "debug: افزودن دکمه موقت بررسی وضعیت ماژول‌های نیتیو" || echo "ℹ️  چیزی برای کامیت نبود"
git push

echo ""
echo "======================================================================"
echo "بعد از نصب APK جدید، اول همین خروجی بالا (بررسی فایل‌ها) رو برام بفرست،"
echo "بعد توی اپ روی دکمه قرمز جدید 'دیباگ ماژول‌ها (موقت)' بزن و عکس از"
echo "پیامی که میاد برام بفرست. این دقیقاً مشخص می‌کنه مشکل کجاست."
echo "======================================================================"
