#!/data/data/com.termux/files/usr/bin/bash
# ====================================================================
#  setup_custom_interval_and_persistent_notif.sh
#  اجرا کن داخل پوشه پروژه (YaadavarAppFresh) با:
#     bash setup_custom_interval_and_persistent_notif.sh
# ====================================================================
set -e

if [ ! -f "App.js" ]; then
  echo "❌ این اسکریپت باید داخل ریشه پروژه (کنار App.js) اجرا بشه."
  exit 1
fi

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

# 1) اضافه کردن state دقیقه دلخواه
old = "  const [selInterval, setSelInterval] = useState(INTERVALS[2]);"
new = old + "\n  const [customMinutes, setCustomMinutes] = useState('');"
content, changed = patch(old, new, "state دقیقه دلخواه", content, changed)

# 2) نوتیفیکیشن دائمی (autoDismiss + autoCancel)
old = """  async function createStickyNotification() {
    if (Platform.OS !== 'android') return;
    await Notifications.dismissNotificationAsync(STICKY_NOTIF_ID);
    await Notifications.scheduleNotificationAsync({
      identifier: STICKY_NOTIF_ID,
      content: {
        title: '✨ یادآور جملات',
        body: 'برای نمایش جمله فوری کلیک کنید',
        sound: false,
        priority: Notifications.AndroidNotificationPriority.MAX,
        android: {
          channelId: 'urgent_channel',
          sticky: true,
          ongoing: true,
        },
      },
      trigger: null,
    });
  }"""
new = """  async function createStickyNotification() {
    if (Platform.OS !== 'android') return;
    await Notifications.dismissNotificationAsync(STICKY_NOTIF_ID);
    await Notifications.scheduleNotificationAsync({
      identifier: STICKY_NOTIF_ID,
      content: {
        title: '✨ یادآور جملات',
        body: 'برای نمایش جمله فوری کلیک کنید',
        sound: false,
        priority: Notifications.AndroidNotificationPriority.MAX,
        autoDismiss: false,
        android: {
          channelId: 'urgent_channel',
          sticky: true,
          ongoing: true,
          autoCancel: false,
        },
      },
      trigger: null,
    });
  }"""
content, changed = patch(old, new, "نوتیفیکیشن دائمی", content, changed)

# 3) چک دوره‌ای هر ۶۰ ثانیه که نوتیفیکیشن دائمی از بین نرفته باشه
old = """    const subscription = AppState.addEventListener('change', (nextAppState) => {
      if (appState.current.match(/inactive|background/) && nextAppState === 'active') {
        ensureNotificationExists();
      }
      appState.current = nextAppState;
    });

    return () => {
      subscription.remove();
      clearInterval(cdInterval.current);
    };
  }, []);"""
new = """    const subscription = AppState.addEventListener('change', (nextAppState) => {
      if (appState.current.match(/inactive|background/) && nextAppState === 'active') {
        ensureNotificationExists();
      }
      appState.current = nextAppState;
    });

    const stickyWatcher = setInterval(() => {
      ensureNotificationExists();
    }, 60000);

    return () => {
      subscription.remove();
      clearInterval(cdInterval.current);
      clearInterval(stickyWatcher);
    };
  }, []);"""
content, changed = patch(old, new, "چک دوره‌ای نوتیفیکیشن دائمی", content, changed)

# 4) UI فاصله زمانی دلخواه، زیر پیل‌های ثابت
old = """          <Text style={styles.label}>⏱️ فاصله زمانی</Text>
          <View style={styles.pills}>
            {INTERVALS.map(item => (
              <TouchableOpacity
                key={item.value}
                style={[styles.pill, selInterval.value === item.value && styles.pillOn]}
                onPress={() => setSelInterval(item)}>
                <Text style={[styles.pillTxt, selInterval.value === item.value && styles.pillTxtOn]}>{item.label}</Text>
              </TouchableOpacity>
            ))}
          </View>"""
new = old + """

          <Text style={styles.label}>🔧 یا فاصله دلخواه (به دقیقه)</Text>
          <View style={styles.customRow}>
            <TextInput
              style={styles.customInput}
              keyboardType="numeric"
              value={customMinutes}
              onChangeText={setCustomMinutes}
              placeholder="مثلاً 7"
              placeholderTextColor="#aaa"
              textAlign="right"
            />
            <TouchableOpacity
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
content, changed = patch(old, new, "UI دقیقه دلخواه", content, changed)

# 5) استایل‌های جدید
old = "  pillTxtOn: { color: '#fff' },"
new = old + """
  customRow: { flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 24 },
  customInput: { flex: 1, backgroundColor: '#F8FAFC', borderWidth: 1, borderColor: '#E2E8F0', borderRadius: 20, padding: 12, fontSize: 15, color: '#0F172A' },
  customBtn: { backgroundColor: '#0EA5E9', borderRadius: 20, paddingHorizontal: 16, paddingVertical: 12 },
  customBtnText: { color: '#fff', fontSize: 13, fontWeight: '700' },"""
content, changed = patch(old, new, "استایل‌های دقیقه دلخواه", content, changed)

with open('App.js', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ App.js پردازش شد" if changed else "ℹ️  تغییری لازم نبود، همه‌چیز از قبل اعمال شده بود")
PYEOF

echo ""
echo "📦 گیت..."
git add .
git commit -m "افزودن فاصله زمانی دلخواه و نوتیفیکیشن کاملاً دائمی" || echo "ℹ️  چیزی برای کامیت نبود"
git push

echo ""
echo "======================================================================"
echo "✅ تمام شد و پوش شد. حالا توی اپ یه باکس 'فاصله دلخواه (دقیقه)' زیر"
echo "   پیل‌های ثابت می‌بینی، و نوتیفیکیشن 'برای نمایش جمله فوری کلیک کنید'"
echo "   با پاک کردن یا تپ خوردن دیگه محو نمی‌شه."
echo "======================================================================"
