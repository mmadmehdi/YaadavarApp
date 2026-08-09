#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -f "App.js" ] || { echo "❌"; exit 1; }

python3 << 'PYEOF'
content = open('App.js', 'r', encoding='utf-8').read()

old = """  function triggerRandomPopup() {
    if (showPopupRef.current) return;
"""
new = """  function triggerRandomPopup() {
    if (showPopupRef.current) return;
    showPopupRef.current = true;
"""
if new in content:
    print("ℹ️  رفع ریس‌کاندیشن قبلاً اعمال شده بود")
elif old in content:
    content = content.replace(old, new, 1)
    print("✅ ریس‌کاندیشن پرچم پاپ‌آپ رفع شد")
else:
    print("⚠️  انکر ریس‌کاندیشن پیدا نشد")

old_ui = """          <Text style={styles.label}>🔍 شناسایی کلمه در کل صفحه گوشی (نیاز به Accessibility)</Text>
          <View style={styles.customRow}>
            <TextInput
              style={[styles.customInput, { flex: 2 }]}
              value={keywordsText}
              onChangeText={setKeywordsText}
              placeholder="کلمه۱, کلمه۲, کلمه۳"
              placeholderTextColor="#aaa"
              textAlign="right"
            />
            <TouchableOpacity
              style={styles.customBtn}
              onPress={async () => {
                if (Platform.OS !== 'android' || !KeywordFilterModule) return;
                await KeywordFilterModule.saveKeywords(keywordsText);
                Alert.alert('ذخیره شد', 'لیست کلمات کلیدی به‌روزرسانی شد');
              }}>
              <Text style={styles.customBtnText}>ذخیره</Text>
            </TouchableOpacity>
          </View>"""

new_ui = """          <Text style={styles.label}>🔍 شناسایی کلمه در کل صفحه گوشی (نیاز به Accessibility)</Text>
          <View style={styles.customRow}>
            <TextInput
              style={[styles.customInput, { flex: 2 }]}
              value={keywordsText}
              onChangeText={setKeywordsText}
              placeholder="کلمه۱, کلمه۲, کلمه۳"
              placeholderTextColor="#aaa"
              textAlign="right"
            />
            <TouchableOpacity
              style={styles.customBtn}
              onPress={async () => {
                if (Platform.OS !== 'android' || !KeywordFilterModule) return;
                const newOnes = keywordsText
                  .split(',')
                  .map((k) => k.trim())
                  .filter((k) => k.length > 0);
                if (newOnes.length === 0) return;
                const existing = savedKeywordsList.filter((k) => k.length > 0);
                const merged = Array.from(new Set([...existing, ...newOnes]));
                await KeywordFilterModule.saveKeywords(merged.join(','));
                setSavedKeywordsList(merged);
                setKeywordsText('');
              }}>
              <Text style={styles.customBtnText}>ذخیره</Text>
            </TouchableOpacity>
          </View>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 16 }}>
            {savedKeywordsList.map((kw) => (
              <TouchableOpacity
                key={kw}
                style={styles.keywordChip}
                onPress={async () => {
                  if (Platform.OS !== 'android' || !KeywordFilterModule) return;
                  const updated = savedKeywordsList.filter((k) => k !== kw);
                  await KeywordFilterModule.saveKeywords(updated.join(','));
                  setSavedKeywordsList(updated);
                }}>
                <Text style={styles.keywordChipText}>{kw} ✕</Text>
              </TouchableOpacity>
            ))}
          </View>"""

if new_ui in content:
    print("ℹ️  UI کلمات کلیدی قبلاً بازسازی شده بود")
elif old_ui in content:
    content = content.replace(old_ui, new_ui, 1)
    print("✅ UI کلمات کلیدی به حالت افزودن + چیپ حذف‌شونده تبدیل شد")
else:
    print("⚠️  انکر UI کلمات کلیدی پیدا نشد — این بخش رو دستی چک کن")

old_state = "  const [keywordsText, setKeywordsText] = useState('');"
new_state = old_state + "\n  const [savedKeywordsList, setSavedKeywordsList] = useState([]);"
if new_state in content:
    print("ℹ️  state لیست ذخیره‌شده قبلاً اضافه شده بود")
elif old_state in content:
    content = content.replace(old_state, new_state, 1)
    print("✅ state savedKeywordsList اضافه شد")
else:
    print("⚠️  انکر state keywordsText پیدا نشد")

old_load = """  useEffect(() => {
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
new_load = """  useEffect(() => {
    const loadKeywords = () => {
      if (Platform.OS === 'android' && KeywordFilterModule) {
        KeywordFilterModule.getKeywords()
          .then((csv) => {
            const list = (csv || '').split(',').map((k) => k.trim()).filter((k) => k.length > 0);
            setSavedKeywordsList(list);
          })
          .catch(() => {});
      }
    };
    loadKeywords();
    const kwSub = AppState.addEventListener('change', (next) => {
      if (next === 'active') loadKeywords();
    });
    return () => kwSub.remove();
  }, []);"""
if new_load in content:
    print("ℹ️  لود اولیه لیست قبلاً اصلاح شده بود")
elif old_load in content:
    content = content.replace(old_load, new_load, 1)
    print("✅ لود اولیه حالا لیست savedKeywordsList رو پر می‌کنه")
else:
    print("⚠️  انکر لود اولیه کلمات پیدا نشد")

with open('App.js', 'w', encoding='utf-8') as f:
    f.write(content)
PYEOF

python3 << 'PYEOF'
content = open('App.js', 'r', encoding='utf-8').read()
old = "  customBtnText: { color: '#fff', fontSize: 13, fontWeight: '700' },"
new = old + "\n  keywordChip: { backgroundColor: '#334155', borderRadius: 16, paddingHorizontal: 12, paddingVertical: 6 },\n  keywordChipText: { color: '#fff', fontSize: 13 },"
if new in content:
    print("ℹ️  استایل چیپ قبلاً اضافه شده بود")
elif old in content:
    content = content.replace(old, new, 1)
    with open('App.js', 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ استایل چیپ اضافه شد")
else:
    print("⚠️  انکر استایل پیدا نشد")
PYEOF

git add .
git commit -m "fix: رفع باگ گم‌شدن بنر کلمه + لیست کلمات کلیدی به‌صورت چیپ قابل‌حذف" || echo "چیزی برای کامیت نبود"
git push
echo "✅ تمام شد"
