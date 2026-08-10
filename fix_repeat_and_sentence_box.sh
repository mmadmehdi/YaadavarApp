#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -f "App.js" ] || { echo "❌"; exit 1; }

python3 << 'PYEOF'
content = open('App.js', 'r', encoding='utf-8').read()

old = """  useEffect(() => {
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

new = """  useEffect(() => {
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
    const checkPendingMatch = () => {
      if (Platform.OS === 'android' && KeywordFilterModule && !showPopupRef.current) {
        KeywordFilterModule.getAndClearLastMatchedKeyword()
          .then((kw) => {
            if (kw) {
              showPopupRef.current = true;
              AsyncStorage.getItem(STORAGE_KEY).then((saved) => {
                const list = saved ? JSON.parse(saved) : sentences;
                if (list && list.length > 0) {
                  const r = list[Math.floor(Math.random() * list.length)];
                  openPopup('🔍 کلمه شناسایی‌شده: ' + kw + '\\n\\n' + r);
                } else {
                  showPopupRef.current = false;
                }
              });
            }
          })
          .catch(() => {});
      }
    };
    loadKeywords();
    checkPendingMatch();
    const kwSub = AppState.addEventListener('change', (next) => {
      if (next === 'active') {
        loadKeywords();
        checkPendingMatch();
      }
    });
    return () => kwSub.remove();
  }, []);"""

if new in content:
    print("ℹ️  چک قطعی کلمه در انتظار قبلاً اضافه شده بود")
elif old in content:
    content = content.replace(old, new, 1)
    print("✅ چک قطعی کلمه در انتظار موقع فعال‌شدن اپ اضافه شد")
else:
    print("⚠️  انکر پیدا نشد — دستی چک کن")

old_modal = """          <TouchableOpacity
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

new_modal = """          <TouchableOpacity
            style={styles.btnGray}
            onPress={() => {
              setSentencesModalText('');
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
                    minHeight: 80,
                    textAlign: 'right',
                    textAlignVertical: 'top',
                  }}
                  multiline
                  value={sentencesModalText}
                  onChangeText={setSentencesModalText}
                  placeholder="جمله جدید | جمله جدید دیگر"
                  placeholderTextColor="#64748B"
                />
                <TouchableOpacity
                  style={[styles.customBtn, { marginTop: 12, alignItems: 'center' }]}
                  onPress={async () => {
                    const newOnes = sentencesModalText
                      .split('|')
                      .map((s) => s.trim())
                      .filter((s) => s.length > 0);
                    if (newOnes.length === 0) return;
                    const merged = [...sentences, ...newOnes];
                    setSentences(merged);
                    await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(merged));
                    setSentencesModalText('');
                  }}>
                  <Text style={styles.customBtnText}>ذخیره</Text>
                </TouchableOpacity>
                <Text style={[styles.label, { marginTop: 16, marginBottom: 8, fontSize: 13 }]}>جملات فعلی:</Text>
                <ScrollView style={{ maxHeight: 200 }}>
                  <Text style={{ color: '#CBD5E1', textAlign: 'right', lineHeight: 22 }}>
                    {sentences.join(' | ')}
                  </Text>
                </ScrollView>
                <TouchableOpacity
                  style={[styles.customBtn, { marginTop: 16, alignItems: 'center' }]}
                  onPress={() => setShowSentencesModal(false)}>
                  <Text style={styles.customBtnText}>بستن</Text>
                </TouchableOpacity>
              </View>
            </View>
          </Modal>"""

if new_modal in content:
    print("ℹ️  مودال جملات قبلاً به حالت افزودن تبدیل شده بود")
elif old_modal in content:
    content = content.replace(old_modal, new_modal, 1)
    print("✅ مودال جملات به حالت افزودن+پاک‌شدن خودکار تبدیل شد")
else:
    print("⚠️  انکر مودال جملات پیدا نشد — دستی چک کن")

with open('App.js', 'w', encoding='utf-8') as f:
    f.write(content)
PYEOF

git add .
git commit -m "fix: تشخیص تکراری کلمه با پولینگ AppState + باکس جملات به حالت افزودن/پاک‌شدن خودکار" || echo "چیزی برای کامیت نبود"
git push
echo "✅ تمام شد"
