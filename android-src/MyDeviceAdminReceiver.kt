package __PACKAGE_NAME__

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * این کلاس اپ رو به عنوان "Device Admin" معرفی می‌کنه.
 * وقتی از طریق ADB دستور `dpm set-device-owner` اجرا بشه، اندروید این
 * کلاس رو به عنوان صاحب دستگاه (Device Owner) ثبت می‌کنه و از اون به بعد
 * متد startLockTaskMode بدون نیاز به تایید کاربر کار می‌کنه.
 */
class MyDeviceAdminReceiver : DeviceAdminReceiver() {

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.d("YaadavarAdmin", "Device Admin فعال شد")
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.d("YaadavarAdmin", "Device Admin غیرفعال شد")
    }
}
