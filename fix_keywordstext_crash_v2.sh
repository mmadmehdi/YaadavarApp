#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -f "App.js" ] || { echo "❌"; exit 1; }

python3 << 'PYEOF'
import re
content = open('App.js', 'r', encoding='utf-8').read()

decl = "const [keywordsText, setKeywordsText] = useState('');"

if content.count(decl) >= 1 and "keywordsText" in content:
    # already declared somewhere; just verify usage isn't before declaration by counting
    pass

if decl not in content:
    m = re.search(r'export default function App\([^)]*\)\s*\{', content)
    if m:
        insert_at = m.end()
        content = content[:insert_at] + "\n  " + decl + content[insert_at:]
        print("✅ declared right after function App() {")
    else:
        print("⚠️ App function start not found")
else:
    print("ℹ️ already declared")

with open('App.js', 'w', encoding='utf-8') as f:
    f.write(content)
PYEOF

grep -n "keywordsText" App.js

git add . && git commit -m "fix: declare keywordsText inside App()" || echo "nothing to commit"
git push
