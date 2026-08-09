#!/data/data/com.termux/files/usr/bin/bash
set -e
[ -f "android-src3/KeywordAccessibilityService.kt" ] || { echo "❌"; exit 1; }

python3 << 'PYEOF'
path = 'android-src3/KeywordAccessibilityService.kt'
content = open(path, 'r', encoding='utf-8').read()

old = """    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val now = System.currentTimeMillis()
        if (now - lastScanAt < SCAN_MIN_INTERVAL_MS) return
        lastScanAt = now

        if (now - lastTriggerAt < TRIGGER_COOLDOWN_MS) return

        if (!::prefs.isInitialized) {
            prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }
        val keywordsCsv = prefs.getString(PREFS_KEY, "") ?: ""
        if (keywordsCsv.isBlank()) return
        val keywords = keywordsCsv.split(",")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        if (keywords.isEmpty()) return

        val root = rootInActiveWindow ?: return

        // اضافه شد: استثنا بر اساس پنجره‌ای که واقعاً داره اسکن می‌شه، نه منبع ایونت
        if (root.packageName?.toString() == packageName) return

        try {"""

new = """    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.packageName != null && event.packageName == packageName) return

        val now = System.currentTimeMillis()
        if (now - lastScanAt < SCAN_MIN_INTERVAL_MS) return
        lastScanAt = now

        if (now - lastTriggerAt < TRIGGER_COOLDOWN_MS) return

        if (!::prefs.isInitialized) {
            prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }
        val keywordsCsv = prefs.getString(PREFS_KEY, "") ?: ""
        if (keywordsCsv.isBlank()) return
        val keywords = keywordsCsv.split(",")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        if (keywords.isEmpty()) return

        val root = rootInActiveWindow ?: return
        try {"""

if new in content:
    print("ℹ️  قبلاً برگردونده شده")
elif old in content:
    content = content.replace(old, new, 1)
    open(path, 'w', encoding='utf-8').write(content)
    print("✅ برگردونده شد به نسخه قبلی")
else:
    print("⚠️  انکر پیدا نشد")
PYEOF

git add .
git commit -m "revert: بازگشت به استثنای خود اپ بر اساس event.packageName" || echo "چیزی برای کامیت نبود"
git push
echo "✅ تمام شد"
