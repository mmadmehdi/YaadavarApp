#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -f "App.js" ] || { echo "❌"; exit 1; }

python3 << 'PYEOF'
content = open('App.js', 'r', encoding='utf-8').read()

old = """<View style={{ minHeight: 260, justifyContent: 'center' }}>
            <Animated.Text
              style={[
                styles.popupQuoteText,
                {
                  color: blinkAnim.interpolate({
                    inputRange: [0, 1],
                    outputRange: ['#FFFFFF', '#FF1744'],
                  }),
                },
              ]}
              numberOfLines={10}
              adjustsFontSizeToFit
              minimumFontScale={0.3}>
              {popupText}
            </Animated.Text>
          </View>"""

new = """<View style={{ minHeight: 260, justifyContent: 'center' }}>
            {popupText.startsWith('🔍') && (
              <Text style={{ fontSize: 14, color: '#fff', textAlign: 'center', marginBottom: 12, opacity: 0.85 }}>
                {popupText.split('\\n\\n')[0]}
              </Text>
            )}
            <Animated.Text
              style={[
                styles.popupQuoteText,
                {
                  color: blinkAnim.interpolate({
                    inputRange: [0, 1],
                    outputRange: ['#FFFFFF', '#FF1744'],
                  }),
                },
              ]}
              numberOfLines={10}
              adjustsFontSizeToFit
              minimumFontScale={0.3}>
              {popupText.startsWith('🔍') ? popupText.split('\\n\\n').slice(1).join('\\n\\n') : popupText}
            </Animated.Text>
          </View>"""

if new in content:
    print("ℹ️  قبلاً اعمال شده بود")
elif old in content:
    content = content.replace(old, new, 1)
    with open('App.js', 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ بنر کلمه شناسایی‌شده ثابت شد، فقط جمله چشمک می‌زنه")
else:
    print("⚠️ انکر پیدا نشد")
PYEOF

git add .
git commit -m "استایل: جدا کردن بنر کلمه شناسایی‌شده (ثابت) از جمله (چشمک‌زن)" || echo "چیزی برای کامیت نبود"
git push
echo "✅ تمام شد"
