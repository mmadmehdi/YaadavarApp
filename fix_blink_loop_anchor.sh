#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -f "App.js" ] || { echo "❌"; exit 1; }

python3 << 'PYEOF'
import re
content = open('App.js', 'r', encoding='utf-8').read()

if 'Animated.loop(' in content:
    print("ℹ️  قبلاً اعمال شده بود")
else:
    pattern = re.compile(
        r"useEffect\(\(\)\s*=>\s*\{\s*showPopupRef\.current\s*=\s*showPopup;\s*\}, \[showPopup\]\);",
        re.DOTALL
    )
    m = pattern.search(content)
    if not m:
        print("⚠️ الگو پیدا نشد — چاپ خط‌های نزدیک showPopupRef برای بررسی:")
        idx = content.find('showPopupRef.current = showPopup')
        if idx != -1:
            print(content[max(0, idx-150):idx+150])
        else:
            print("even 'showPopupRef.current = showPopup' پیدا نشد")
    else:
        replacement = """useEffect(() => {
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
        content = content[:m.start()] + replacement + content[m.end():]
        with open('App.js', 'w', encoding='utf-8') as f:
            f.write(content)
        print("✅ لوپ چشمک‌زدن این بار اضافه شد")
PYEOF

git add .
git commit -m "fix: افزودن لوپ چشمک‌زدن با regex مقاوم‌تر" || echo "چیزی برای کامیت نبود"
git push
echo "✅ تمام شد"
