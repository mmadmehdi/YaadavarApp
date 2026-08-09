#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -f "App.js" ] || { echo "❌"; exit 1; }

python3 << 'PYEOF'
content = open('App.js', 'r', encoding='utf-8').read()

old_ref = "  const lockSecondsRef = useRef(10);"
new_ref = old_ref + "\n  const showPopupRef = useRef(false);"
if new_ref not in content and old_ref in content:
    content = content.replace(old_ref, new_ref, 1)

old_sync = """  useEffect(() => {
    lockSecondsRef.current = lockSeconds;
  }, [lockSeconds]);"""
new_sync = old_sync + """

  useEffect(() => {
    showPopupRef.current = showPopup;
  }, [showPopup]);"""
if new_sync not in content and old_sync in content:
    content = content.replace(old_sync, new_sync, 1)

old_fn = "  function triggerRandomPopup() {"
new_fn = """  function triggerRandomPopup() {
    if (showPopupRef.current) return;
"""
if new_fn not in content and old_fn in content:
    content = content.replace(old_fn, new_fn, 1)

with open('App.js', 'w', encoding='utf-8') as f:
    f.write(content)
PYEOF

git add .
git commit -m "fix: جلوگیری از باز شدن هم‌زمان دو پاپ‌آپ پشت‌سرهم" || echo "چیزی برای کامیت نبود"
git push
echo "✅ تمام شد"
