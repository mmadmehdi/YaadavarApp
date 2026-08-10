#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -f "App.js" ] || { echo "❌"; exit 1; }

if [ -f "android-src3/KeywordAccessibilityService.kt" ]; then
  python3 << 'PYEOF'
path = 'android-src3/KeywordAccessibilityService.kt'
content = open(path, 'r', encoding='utf-8').read()
old = 'val popupIntent = Intent(Intent.ACTION_VIEW, Uri.parse("__SCHEME__://popup"))'
new = 'val popupIntent = Intent(Intent.ACTION_VIEW, Uri.parse("__SCHEME__://popup?ts=" + System.currentTimeMillis()))'
if new in content:
    print("ℹ️  nonce قبلاً اضافه شده بود")
elif old in content:
    content = content.replace(old, new, 1)
    open(path, 'w', encoding='utf-8').write(content)
    print("✅ nonce به دیپ‌لینک اضافه شد")
else:
    print("⚠️  انکر پیدا نشد")
PYEOF
fi

python3 << 'PYEOF'
content = open('App.js', 'r', encoding='utf-8').read()

old_state = "  const [showKeywordsModal, setShowKeywordsModal] = useState(false);"
new_state = old_state + "\n  const [showSentencesModal, setShowSentencesModal] = useState(false);\n  const [sentencesModalText, setSentencesModalText] = useState('');"
if new_state in content:
    print("ℹ️  state جملات قبلاً اضافه شده بود")
elif old_state in content:
    content = content.replace(old_state, new_state, 1)
    print("✅ state لیست جملات اضافه شد")
else:
    print("⚠️  انکر state showKeywordsModal پیدا نشد")

old_btn = """          <TouchableOpacity
            style={styles.btnGray}
            onPress={() => setShowKeywordsModal(true)}>
            <Ionicons name="list" size={20} color="#fff" style={{ marginRight: 8 }} />
            <Text style={styles.btnTxt}>لیست کلمات ({savedKeywordsList.length})</Text>
          </TouchableOpacity>"""
new_btn = old_btn + """

          <TouchableOpacity
            style={styles.btnGray}
            onPress={() => {
              setSentencesModalText(sentences.join(' | '));
              setShowSentencesModal(true);
            }}>
            <Ionicons name="list" size={20} color="#fff" style={{ marginRight: 8 }} />
            <Text style={styles.btnTxt}>لیست جملات ({sentences.length})</Text>
          </TouchableOpacity>

          <Modal
            visible={showSentencesModal}
            transparent
            animationType="fade"
            onRequestClose={() => setShowSentencesModal(false)}>
            <View style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.6)', justifyContent: 'center', padding: 24 }}>
              <View style={{ backgroundColor: '#1E293B', borderRadius: 20, padding: 20, maxHeight: '80%' }}>
                <Text style={[styles.label, { textAlign: 'center', marginBottom: 12 }]}>لیست جملات یادآوری</Text>
                <TextInput
                  style={{
                    backgroundColor: '#0F172A',
                    color: '#fff',
                    borderRadius: 12,
                    padding: 12,
                    minHeight: 220,
                    textAlign: 'right',
                    textAlignVertical: 'top',
                  }}
                  multiline
                  value={sentencesModalText}
                  onChangeText={setSentencesModalText}
                  placeholder="جمله اول | جمله دوم | جمله سوم"
                  placeholderTextColor="#64748B"
                />
                <TouchableOpacity
                  style={[styles.customBtn, { marginTop: 16, alignItems: 'center' }]}
                  onPress={async () => {
                    const list = sentencesModalText
                      .split('|')
                      .map((s) => s.trim())
                      .filter((s) => s.length > 0);
                    setSentences(list);
                    await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(list));
                    setShowSentencesModal(false);
                  }}>
                  <Text style={styles.customBtnText}>ذخیره</Text>
                </TouchableOpacity>
              </View>
            </View>
          </Modal>"""

if new_btn in content:
    print("ℹ️  مودال لیست جملات قبلاً اضافه شده بود")
elif old_btn in content:
    content = content.replace(old_btn, new_btn, 1)
    print("✅ دکمه و مودال لیست جملات اضافه شد")
else:
    print("⚠️  انکر دکمه لیست کلمات پیدا نشد — دستی چک کن")

with open('App.js', 'w', encoding='utf-8') as f:
    f.write(content)
PYEOF

git add .
git commit -m "fix: رفع باگ تکرار تشخیص کلمه با nonce دیپ‌لینک + افزودن مودال لیست جملات با ویرایش دستی" || echo "چیزی برای کامیت نبود"
git push
echo "✅ تمام شد"
