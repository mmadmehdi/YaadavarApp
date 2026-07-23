#!/data/data/com.termux/files/usr/bin/bash
# ====================================================================
#  cleanup_and_fix_locksecond_staleness.sh
#  اجرا کن داخل پوشه پروژه (YaadavarAppFresh) با:
#     bash cleanup_and_fix_locksecond_staleness.sh
# ====================================================================
set -e

if [ ! -f "App.js" ]; then
  echo "❌ این اسکریپت باید داخل ریشه پروژه (کنار App.js) اجرا بشه."
  exit 1
fi

# --------------------------------------------------------------------
# اطمینان از جدا بودن کانال سرویس دائمی از urgent_channel (idempotent)
# --------------------------------------------------------------------
if [ -f "android-src2/StickyReminderService.kt" ]; then
  sed -i \
    -e 's/const CHANNEL_ID = "urgent_channel"/const CHANNEL_ID = "sticky_channel"/' \
    -e 's/CHANNEL_ID, "یادآورهای فوری", NotificationManager.IMPORTANCE_HIGH/CHANNEL_ID, "نوتیفیکیشن دائمی", NotificationManager.IMPORTANCE_LOW/' \
    android-src2/StickyReminderService.kt
  echo "✅ کانال سرویس دائمی: $(grep CHANNEL_ID android-src2/StickyReminderService.kt | head -1)"
else
  echo "ℹ️  android-src2/StickyReminderService.kt پیدا نشد، این بخش رد شد"
fi

# --------------------------------------------------------------------
# پچ App.js
# --------------------------------------------------------------------
python3 << 'PYEOF'
content = open('App.js', 'r', encoding='utf-8').read()
changed = False

def remove(old, label, content, changed):
    if old not in content:
        print(f"ℹ️  {label}: قبلاً حذف شده یا پیدا نشد")
        return content, changed
    return content.replace(old, '', 1), True

def patch(old, new, label, content, changed):
    if new in content:
        print(f"ℹ️  {label}: قبلاً اعمال شده بود")
        return content, changed
    if old not in content:
        print(f"⚠️  {label}: انکر پیدا نشد — این بخش رو دستی چک کن")
        return content, changed
    return content.replace(old, new, 1), True

# 1) حذف state های تایمر مستقل پاپ‌آپ
old = "\n  const [popupCustomMinutes, setPopupCustomMinutes] = useState('');\n  const [popupTimerActive, setPopupTimerActive] = useState(false);"
content, changed = remove(old, "حذف state تایمر مستقل", content, changed)

# 2) حذف ref تایمر مستقل
old = "\n  const popupTimerRef                 = useRef(null);"
content, changed = remove(old, "حذف ref تایمر مستقل", content, changed)

# 3) حذف کل بخش UI تایمر مستقل پاپ‌آپ
old = """
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
"""
content, changed = remove(old, "حذف UI تایمر مستقل", content, changed)

# 4) اضافه کردن ref برای مقدار همیشه‌به‌روز مدت قفل (رفع مشکل closure یخ‌زده)
old = "  const [lockSecondsInput, setLockSecondsInput] = useState('');"
new = old + "\n  const lockSecondsRef = useRef(10);\n  lockSecondsRef.current = lockSeconds;"
content, changed = patch(old, new, "ref همیشه‌به‌روز مدت قفل", content, changed)

# 5) استفاده از مقدار همیشه‌به‌روز داخل openPopup به‌جای مقدار احتمالاً یخ‌زده
old = "    setSecsLeft(lockSeconds);"
new = "    setSecsLeft(lockSecondsRef.current);"
content, changed = patch(old, new, "استفاده از مقدار لحظه‌ای در openPopup", content, changed)

with open('App.js', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ App.js پردازش شد" if changed else "ℹ️  تغییری لازم نبود")
PYEOF

echo ""
echo "📦 گیت..."
git add .
git commit -m "fix: حذف تایمر اضافه، رفع مشکل اعمال‌نشدن فوری مدت قفل، اطمینان از جدا بودن کانال urgent" || echo "ℹ️  چیزی برای کامیت نبود"
git push

echo ""
echo "======================================================================"
echo "✅ تمام شد و پوش شد."
echo ""
echo "- دکمه/بخش «زمان‌بندی پاپ‌آپ مستقل» کاملاً حذف شد."
echo "- مدت قفل پاپ‌آپ حالا همیشه از مقدار لحظه‌ای استفاده می‌کنه، حتی وقتی"
echo "  پاپ‌آپ از طریق تپ روی نوتیفیکیشن باز بشه — دیگه نیازی به زدن"
echo "  «شروع زمان‌بندی» نیست."
echo "- کانال نوتیفیکیشن دائمی (sticky_channel) جدا از کانال نوتیف‌های urgent"
echo "  (urgent_channel) هست. یادت نره بعد از نصب APK جدید، اپ رو Force Stop"
echo "  یا حذف/نصب کنی تا کانال قدیمی خراب‌شده کامل پاک بشه و اثر بذاره."
echo "======================================================================"
