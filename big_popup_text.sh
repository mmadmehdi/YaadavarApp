#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -f "App.js" ] || { echo "❌"; exit 1; }

python3 << 'PYEOF'
import re
content = open('App.js', 'r', encoding='utf-8').read()
changed = False

m = re.search(r'(<Text\s+style=\{styles\.(\w+)\}\s*>\s*\{popupText\}\s*</Text>)', content)
if m:
    old_tag, old_style_key = m.group(1), m.group(2)
    new_tag = (
        '<Text\n'
        '            style={styles.popupQuoteText}\n'
        '            numberOfLines={8}\n'
        '            adjustsFontSizeToFit\n'
        '            minimumFontScale={0.4}>\n'
        '            {popupText}\n'
        '          </Text>'
    )
    if 'styles.popupQuoteText' not in content:
        content = content.replace(old_tag, new_tag, 1)
        changed = True
        print("✅ متن اصلی جمله بزرگ و ریسپانسیو شد")
    else:
        print("ℹ️  قبلاً اعمال شده بود")
else:
    print("⚠️  تگ {popupText} پیدا نشد")

if 'popupQuoteText:' not in content:
    old_style_anchor = "  lockText:"
    if old_style_anchor in content:
        content = content.replace(
            old_style_anchor,
            "  popupQuoteText: { fontSize: 42, fontWeight: '900', color: '#fff', textAlign: 'center', lineHeight: 52 },\n  lockText:",
            1
        )
        changed = True
        print("✅ استایل popupQuoteText اضافه شد")
    else:
        print("⚠️  انکر lockText برای اضافه‌کردن استایل پیدا نشد")

old_lock_style = re.search(r"lockText:\s*\{[^}]*\}", content)
if old_lock_style:
    new_lock_style = "lockText: { fontSize: 12, color: '#fff', opacity: 0.8 }"
    if old_lock_style.group(0) != new_lock_style:
        content = content.replace(old_lock_style.group(0), new_lock_style, 1)
        changed = True
        print("✅ متن شمارش معکوس/قفل ریزتر شد")
else:
    print("⚠️  استایل lockText پیدا نشد")

with open('App.js', 'w', encoding='utf-8') as f:
    f.write(content)
print("پردازش انجام شد" if changed else "تغییری اعمال نشد")
PYEOF

git add .
git commit -m "استایل: جمله پاپ‌آپ خیلی بزرگ و ریسپانسیو، بقیه متن‌ها ریزتر" || echo "چیزی برای کامیت نبود"
git push
echo "✅ تمام شد"
