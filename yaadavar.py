python3 -c '
import zipfile, os

zip_name = "files (1).zip"
os.makedirs("plugins", exist_ok=True)
os.makedirs("android-src", exist_ok=True)
os.makedirs("extracted_tmp", exist_ok=True)

with zipfile.ZipFile(zip_name, "r") as z:
    z.extractall("extracted_tmp")

tmp_dir = "extracted_tmp"
for root, dirs, files in os.walk(tmp_dir):
    for f in files:
        src_path = os.path.join(root, f)
        if f == "withDeviceOwnerLock.js":
            os.rename(src_path, os.path.join("plugins", f))
            print(f"Moved {f} to plugins/")
        elif f in ["MyDeviceAdminReceiver.kt", "LockTaskModule.kt", "LockTaskPackage.kt", "device_admin_receiver.xml"]:
            os.rename(src_path, os.path.join("android-src", f))
            print(f"Moved {f} to android-src/")
        elif f in ["app.json.snippet.json", "App.js.patch.md", "README.md"]:
            os.rename(src_path, f)
            print(f"Kept {f} in root directory")

print("✅ همه فایل‌ها با موفقیت در پوشه‌های خود قرار گرفتند!")
'
