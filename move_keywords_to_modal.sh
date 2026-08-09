#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -f "App.js" ] || { echo "❌"; exit 1; }

python3 << 'PYEOF'
content = open('App.js', 'r', encoding='utf-8').read()

old = """          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 16 }}>
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

new = """          <TouchableOpacity
            style={styles.btnGray}
            onPress={() => setShowKeywordsModal(true)}>
            <Ionicons name="list" size={20} color="#fff" style={{ marginRight: 8 }} />
            <Text style={styles.btnTxt}>لیست کلمات ({savedKeywordsList.length})</Text>
          </TouchableOpacity>

          <Modal
            visible={showKeywordsModal}
            transparent
            animationType="fade"
            onRequestClose={() => setShowKeywordsModal(false)}>
            <View style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.6)', justifyContent: 'center', padding: 24 }}>
              <View style={{ backgroundColor: '#1E293B', borderRadius: 20, padding: 20, maxHeight: '70%' }}>
                <Text style={[styles.label, { textAlign: 'center', marginBottom: 12 }]}>لیست کلمات شناسایی</Text>
                <ScrollView>
                  <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
                    {savedKeywordsList.length === 0 ? (
                      <Text style={{ color: '#94A3B8' }}>هنوز کلمه‌ای اضافه نکردی</Text>
                    ) : (
                      savedKeywordsList.map((kw) => (
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
                      ))
                    )}
                  </View>
                </ScrollView>
                <TouchableOpacity
                  style={[styles.customBtn, { marginTop: 16, alignItems: 'center' }]}
                  onPress={() => setShowKeywordsModal(false)}>
                  <Text style={styles.customBtnText}>بستن</Text>
                </TouchableOpacity>
              </View>
            </View>
          </Modal>"""

if new in content:
    print("ℹ️  قبلاً اعمال شده بود")
elif old in content:
    content = content.replace(old, new, 1)
    print("✅ لیست کلمات به یه مودال جدا با دکمه منتقل شد")
else:
    print("⚠️  انکر پیدا نشد — دستی چک کن")

old_state = "  const [savedKeywordsList, setSavedKeywordsList] = useState([]);"
new_state = old_state + "\n  const [showKeywordsModal, setShowKeywordsModal] = useState(false);"
if new_state in content:
    print("ℹ️  state مودال قبلاً اضافه شده بود")
elif old_state in content:
    content = content.replace(old_state, new_state, 1)
    print("✅ state showKeywordsModal اضافه شد")
else:
    print("⚠️  انکر state savedKeywordsList پیدا نشد")

with open('App.js', 'w', encoding='utf-8') as f:
    f.write(content)
PYEOF

git add .
git commit -m "افزودن مودال جدا برای لیست کلمات شناسایی به‌جای نمایش توی صفحه اصلی" || echo "چیزی برای کامیت نبود"
git push
echo "✅ تمام شد"
