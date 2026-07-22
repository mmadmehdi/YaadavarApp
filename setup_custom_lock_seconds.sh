#!/data/data/com.termux/files/usr/bin/bash
# ====================================================================
#  setup_custom_lock_seconds.sh
#  اجرا کن داخل پوشه پروژه (YaadavarAppFresh) با:
#     bash setup_custom_lock_seconds.sh
# ====================================================================
set -e

if [ ! -f "App.js" ]; then
  echo "❌ این اسکریپت باید داخل ریشه پروژه (کنار App.js) اجرا بشه."
  exit 1
fi

python3 << 'PYEOF'
import re

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

# 1) اضافه کردن state برای مدت قفل دلخواه
old = "  const [customMinutes, setCustomMinutes] = useState('');"
new = old + "\n  const [lockSeconds, setLockSeconds] = useState(10);\n  const [lockSecondsInput, setLockSecondsInput] = useState('');"
content, changed = patch(old, new, "state مدت قفل دلخواه", content, changed)

# 2) استفاده از lockSeconds به‌جای عدد ثابت ۱۰ در شروع شمارش معکوس
if 'setSecsLeft(lockSeconds)' not in content:
    if 'setSecsLeft(10)' in content:
        content = content.replace('setSecsLeft(10)', 'setSecsLeft(lockSeconds)')
        changed = True
        print("✅ شمارش معکوس به مدت قفل دلخواه وصل شد")
    else:
        print("⚠️  setSecsLeft(10) پیدا نشد — این بخش رو دستی توی تابع openPopup چک کن")
else:
    print("ℹ️  شمارش معکوس قبلاً وصل شده بود")

# 3) متن پیام قفل داخل پاپ‌آپ: دینامیک کردن عدد ثانیه
old = "<Text style={styles.lockText}>لطفاً ۱۰ ثانیه صبور باشید...</Text>"
new = "<Text style={styles.lockText}>{'لطفاً ' + lockSeconds + ' ثانیه صبور باشید...'}</Text>"
content, changed = patch(old, new, "متن دینامیک شمارش معکوس", content, changed)

# 4) UI ورودی مدت قفل دلخواه، زیر باکس فاصله زمانی دلخواه
old = """            <TouchableOpacity
              style={styles.customBtn}
              onPress={() => {
                const mins = parseInt(customMinutes, 10);
                if (!mins || mins <= 0) {
                  Alert.alert('خطا', 'یه عدد صحیح و مثبت برای دقیقه وارد کن');
                  return;
                }
                setSelInterval({ label: mins + ' دقیقه (دلخواه)', value: mins * 60 });
              }}>
              <Text style={styles.customBtnText}>تنظیم</Text>
            </TouchableOpacity>
          </View>"""
new = old + """

          <Text style={styles.label}>🔒 مدت قفل پاپ‌آپ (به ثانیه)</Text>
          <View style={styles.customRow}>
            <TextInput
              style={styles.customInput}
              keyboardType="numeric"
              value={lockSecondsInput}
              onChangeText={setLockSecondsInput}
              placeholder={'پیش‌فرض: ' + lockSeconds}
              placeholderTextColor="#aaa"
              textAlign="right"
            />
            <TouchableOpacity
              style={styles.customBtn}
              onPress={() => {
                const secs = parseInt(lockSecondsInput, 10);
                if (!secs || secs <= 0) {
                  Alert.alert('خطا', 'یه عدد صحیح و مثبت برای ثانیه وارد کن');
                  return;
                }
                setLockSeconds(secs);
                Alert.alert('انجام شد', 'پاپ‌آپ از این به بعد ' + secs + ' ثانیه قفل می‌مونه');
              }}>
              <Text style={styles.customBtnText}>تنظیم</Text>
            </TouchableOpacity>
          </View>"""
content, changed = patch(old, new, "UI مدت قفل دلخواه", content, changed)

with open('App.js', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ App.js پردازش شد" if changed else "ℹ️  تغییری لازم نبود، همه‌چیز از قبل اعمال شده بود")
PYEOF

echo ""
echo "📦 گیت..."
git add .
git commit -m "افزودن مدت قفل پاپ‌آپ قابل تنظیم به‌صورت دستی" || echo "ℹ️  چیزی برای کامیت نبود"
git push

echo ""
echo "======================================================================"
echo "✅ تمام شد و پوش شد. حالا زیر باکس 'فاصله دلخواه'، یه باکس دیگه به اسم"
echo "   'مدت قفل پاپ‌آپ (به ثانیه)' می‌بینی — هر عددی بزنی و تنظیم رو بزنی،"
echo "   پاپ‌آپ همون‌قدر ثانیه قفل می‌مونه (پیش‌فرض ۱۰ ثانیه)."
echo "======================================================================"
