#!/data/data/com.termux/files/usr/bin/bash
# ====================================================================
#  fix_channel_and_independent_popup_timer.sh
#  اجرا کن داخل پوشه پروژه (YaadavarAppFresh) با:
#     bash fix_channel_and_independent_popup_timer.sh
# ====================================================================
set -e

if [ ! -f "App.js" ]; then
  echo "❌ این اسکریپت باید داخل ریشه پروژه (کنار App.js) اجرا بشه."
  exit 1
fi

# --------------------------------------------------------------------
# 1) کانال جدا برای سرویس نوتیفیکیشن دائمی (اگه فایلش هست)
# --------------------------------------------------------------------
if [ -f "android-src2/StickyReminderService.kt" ]; then
  sed -i \
    -e 's/const CHANNEL_ID = "urgent_channel"/const CHANNEL_ID = "sticky_channel"/' \
    -e 's/CHANNEL_ID, "یادآورهای فوری", NotificationManager.IMPORTANCE_HIGH/CHANNEL_ID, "نوتیفیکیشن دائمی", NotificationManager.IMPORTANCE_LOW/' \
    android-src2/StickyReminderService.kt
  echo "✅ کانال سرویس نوتیفیکیشن دائمی از urgent_channel جدا شد"
else
  echo "ℹ️  android-src2/StickyReminderService.kt پیدا نشد، این بخش رد شد"
fi

# --------------------------------------------------------------------
# 2) پچ App.js
# --------------------------------------------------------------------
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

# --- ترمیم کانال خراب‌شده urgent_channel (یک‌بار در استارتاپ) ---
old = "    configureChannel();"
new = """    (async () => {
      // اضافه شد: پاک کردن یک‌باره کانال قدیمی که ممکنه با تنظیمات ضعیف قفل شده باشه
      await Notifications.deleteNotificationChannelAsync('urgent_channel').catch(() => {});
      configureChannel();
    })();"""
content, changed = patch(old, new, "ترمیم کانال urgent_channel", content, changed)

# --- state و ref برای تایمر مستقل پاپ‌آپ ---
old = "  const [lockSecondsInput, setLockSecondsInput] = useState('');"
new = old + "\n  const [popupCustomMinutes, setPopupCustomMinutes] = useState('');\n  const [popupTimerActive, setPopupTimerActive] = useState(false);"
content, changed = patch(old, new, "state تایمر مستقل پاپ‌آپ", content, changed)

old = "  const cdInterval                    = useRef(null);"
new = old + "\n  const popupTimerRef                 = useRef(null);"
content, changed = patch(old, new, "ref تایمر مستقل پاپ‌آپ", content, changed)

# --- بخش UI مستقل، بلافاصله قبل از دکمه «جمله فوری» ---
old = """            <TouchableOpacity
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
          </View>

          <TouchableOpacity style={styles.btnPurple} onPress={quickReminder}>"""
new = """            <TouchableOpacity
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
          </View>

          <Text style={styles.label}>⏰ زمان‌بندی پاپ‌آپ (کاملاً مستقل از نوتیفیکیشن)</Text>
          <View style={styles.customRow}>
            <TextInput
              style={styles.customInput}
              keyboardType="numeric"
              value={popupCustomMinutes}
              onChangeText={setPopupCustomMinutes}
              placeholder="هر چند دقیقه؟"
              placeholderTextColor="#aaa"
              textAlign="right"
            />
            <TouchableOpacity
              style={styles.customBtn}
              onPress={async () => {
                const mins = parseInt(popupCustomMinutes, 10);
                if (!mins || mins <= 0) {
                  Alert.alert('خطا', 'یه عدد صحیح و مثبت برای دقیقه وارد کن');
                  return;
                }
                if (popupTimerRef.current) clearInterval(popupTimerRef.current);
                popupTimerRef.current = setInterval(() => { quickReminder(); }, mins * 60 * 1000);
                setPopupTimerActive(true);
                await addLog('زمان‌بندی مستقل پاپ‌آپ فعال شد: هر ' + mins + ' دقیقه');
                await refreshLogs();
                Alert.alert('انجام شد', 'پاپ‌آپ حالا هر ' + mins + ' دقیقه نمایش داده می‌شه (فقط وقتی اپ باز باشه)');
              }}>
              <Text style={styles.customBtnText}>تنظیم و شروع</Text>
            </TouchableOpacity>
          </View>
          {popupTimerActive ? (
            <TouchableOpacity style={styles.btnGray} onPress={async () => {
              if (popupTimerRef.current) clearInterval(popupTimerRef.current);
              popupTimerRef.current = null;
              setPopupTimerActive(false);
              await addLog('زمان‌بندی مستقل پاپ‌آپ متوقف شد');
              await refreshLogs();
            }}>
              <Ionicons name="stop-circle" size={20} color="#fff" style={{ marginRight: 8 }} />
              <Text style={styles.btnTxt}>توقف زمان‌بندی پاپ‌آپ مستقل</Text>
            </TouchableOpacity>
          ) : null}

          <TouchableOpacity style={styles.btnPurple} onPress={quickReminder}>"""
content, changed = patch(old, new, "UI تایمر مستقل پاپ‌آپ", content, changed)

with open('App.js', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ App.js پردازش شد" if changed else "ℹ️  تغییری لازم نبود")
PYEOF

echo ""
echo "📦 گیت..."
git add .
git commit -m "fix: جدا کردن کانال نوتیفیکیشن دائمی + افزودن زمان‌بندی مستقل پاپ‌آپ" || echo "ℹ️  چیزی برای کامیت نبود"
git push

echo ""
echo "======================================================================"
echo "✅ تمام شد و پوش شد."
echo ""
echo "⚠️ برای مشکل ۱: چون کانال قدیمی urgent_channel روی نسخه فعلی گوشیت با"
echo "   تنظیمات خراب ساخته شده، بعد از نصب APK جدید حتماً اپ رو Force Stop"
echo "   کن یا حذف/نصب کن (نه فقط ببند) تا کانال درست از نو ساخته بشه."
echo ""
echo "✅ برای مشکل ۲: حالا زیر بخش «مدت قفل پاپ‌آپ» یه بخش جدید هست به اسم"
echo "   «زمان‌بندی پاپ‌آپ (کاملاً مستقل از نوتیفیکیشن)» — عدد دقیقه رو بزن،"
echo "   «تنظیم و شروع» رو بزن، بلافاصله (بدون دکمه شروع زمان‌بندی) فعال می‌شه."
echo "   یادت باشه این فقط وقتی اپ بازه کار می‌کنه، نه وقتی بسته‌ست."
echo "======================================================================"
