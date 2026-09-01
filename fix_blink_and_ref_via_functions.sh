#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -f "App.js" ] || { echo "❌"; exit 1; }

python3 << 'PYEOF'
import re
content = open('App.js', 'r', encoding='utf-8').read()
changed = False

if 'blinkLoopRef' not in content:
    anchor = "  const blinkAnim = useRef(new Animated.Value(0)).current;"
    if anchor in content:
        content = content.replace(anchor, anchor + "\n  const blinkLoopRef = useRef(null);", 1)
        changed = True
        print("✅ blinkLoopRef اضافه شد")
    else:
        print("⚠️ انکر blinkAnim پیدا نشد")
else:
    print("ℹ️  blinkLoopRef از قبل هست")

def inject_after_function_open(src, func_name, code):
    pattern = re.compile(r'(function\s+' + func_name + r'\s*\([^)]*\)\s*\{)')
    m = pattern.search(src)
    if not m:
        print(f"⚠️ تابع {func_name} پیدا نشد")
        return src, False
    if code.strip() in src:
        print(f"ℹ️  کد قبلاً داخل {func_name} هست")
        return src, False
    insert_at = m.end()
    return src[:insert_at] + "\n    " + code + src[insert_at:], True

open_code = (
    "showPopupRef.current = true;\n"
    "    if (blinkLoopRef.current) { blinkLoopRef.current.stop(); }\n"
    "    blinkAnim.setValue(0);\n"
    "    blinkLoopRef.current = Animated.loop(\n"
    "      Animated.sequence([\n"
    "        Animated.timing(blinkAnim, { toValue: 1, duration: 450, useNativeDriver: false }),\n"
    "        Animated.timing(blinkAnim, { toValue: 0, duration: 450, useNativeDriver: false }),\n"
    "      ])\n"
    "    );\n"
    "    blinkLoopRef.current.start();"
)
content, c1 = inject_after_function_open(content, 'openPopup', open_code)
changed = changed or c1

close_code = (
    "showPopupRef.current = false;\n"
    "    if (blinkLoopRef.current) { blinkLoopRef.current.stop(); blinkLoopRef.current = null; }\n"
    "    blinkAnim.setValue(0);"
)
content, c2 = inject_after_function_open(content, 'closePopup', close_code)
changed = changed or c2

with open('App.js', 'w', encoding='utf-8') as f:
    f.write(content)

print("پردازش انجام شد" if changed else "تغییری اعمال نشد")
PYEOF

git add .
git commit -m "fix: وصل کردن مطمئن چشمک‌زدن و ریست شدن showPopupRef مستقیماً داخل openPopup/closePopup" || echo "چیزی برای کامیت نبود"
git push
echo "✅ تمام شد"
