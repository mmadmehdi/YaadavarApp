#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -f "App.js" ] || { echo "❌"; exit 1; }

python3 << 'PYEOF'
content = open('App.js', 'r', encoding='utf-8').read()
changed = False

def patch(old, new, label, content, changed):
    if new in content:
        print(f"ℹ️  {label}: قبلاً اعمال شده بود")
        return content, changed
    if old not in content:
        print(f"⚠️  {label}: انکر پیدا نشد")
        return content, changed
    return content.replace(old, new, 1), True

old = "  const showPopupRef = useRef(false);"
new = old + "\n  const blinkAnim = useRef(new Animated.Value(0)).current;"
content, changed = patch(old, new, "ref blinkAnim", content, changed)

old = """  useEffect(() => {
    showPopupRef.current = showPopup;
  }, [showPopup]);"""
new = """  useEffect(() => {
    showPopupRef.current = showPopup;
    if (showPopup) {
      const loop = Animated.loop(
        Animated.sequence([
          Animated.timing(blinkAnim, { toValue: 1, duration: 450, useNativeDriver: false }),
          Animated.timing(blinkAnim, { toValue: 0, duration: 450, useNativeDriver: false }),
        ])
      );
      loop.start();
      return () => loop.stop();
    } else {
      blinkAnim.setValue(0);
    }
  }, [showPopup]);"""
content, changed = patch(old, new, "لوپ چشمک‌زدن", content, changed)

old = """<Text
            style={styles.popupQuoteText}
            numberOfLines={8}
            adjustsFontSizeToFit
            minimumFontScale={0.4}>
            {popupText}
          </Text>"""
new = """<View style={{ flex: 1, justifyContent: 'center' }}>
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
content, changed = patch(old, new, "Animated.Text تمام‌قد", content, changed)

old = "  popupQuoteText: { fontSize: 42, fontWeight: '900', color: '#fff', textAlign: 'center', lineHeight: 52 },"
new = "  popupQuoteText: { fontSize: 72, fontWeight: '900', textAlign: 'center', lineHeight: 84 },"
content, changed = patch(old, new, "افزایش سایز فونت", content, changed)

with open('App.js', 'w', encoding='utf-8') as f:
    f.write(content)

print("پردازش انجام شد" if changed else "تغییری اعمال نشد")
PYEOF

git add .
git commit -m "استایل: متن پاپ‌آپ تمام‌قد صفحه، خیلی درشت‌تر، و چشمک‌زن قرمز/سفید" || echo "چیزی برای کامیت نبود"
git push
echo "✅ تمام شد"
