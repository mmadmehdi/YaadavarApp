package __PACKAGE_NAME__

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod

/**
 * ماژول نیتیوی که استارت/استاپ Lock Task Mode (کیوسک) رو از JS در دسترس می‌ذاره.
 *
 * پیش‌نیاز: اپ باید Device Owner باشه (یه بار با ADB تنظیم می‌شه، توضیحش رو
 * توی README گذاشتم). اگه Device Owner نباشه، startLockTask بازم کار می‌کنه
 * ولی یه دیالوگ تایید به کاربر نشون می‌ده و با Back+Recent قابل خروجه —
 * که دقیقاً چیزی نیست که می‌خوای.
 */
class LockTaskModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName() = "LockTaskModule"

    private fun getDpm(): DevicePolicyManager {
        return reactApplicationContext.getSystemService(Context.DEVICE_POLICY_SERVICE)
                as DevicePolicyManager
    }

    private fun getAdminComponent(): ComponentName {
        return ComponentName(reactApplicationContext, MyDeviceAdminReceiver::class.java)
    }

    /** بررسی اینکه آیا اپ الان Device Owner هست یا نه (برای دیباگ مفیده) */
    @ReactMethod
    fun isDeviceOwner(promise: Promise) {
        try {
            val dpm = getDpm()
            promise.resolve(dpm.isDeviceOwnerApp(reactApplicationContext.packageName))
        } catch (e: Exception) {
            promise.reject("ERR_CHECK_OWNER", e)
        }
    }

    /** اگه Device Owner باشیم، این پکیج رو به لیست سفید Lock Task اضافه می‌کنه. */
    @ReactMethod
    fun enableLockTaskPackage(promise: Promise) {
        try {
            val dpm = getDpm()
            val admin = getAdminComponent()
            if (dpm.isDeviceOwnerApp(reactApplicationContext.packageName)) {
                dpm.setLockTaskPackages(admin, arrayOf(reactApplicationContext.packageName))
            }
            promise.resolve(true)
        } catch (e: Exception) {
            promise.reject("ERR_ENABLE_LOCK_PKG", e)
        }
    }

    @ReactMethod
    fun startLockTask(promise: Promise) {
        try {
            val activity: Activity? = currentActivity
            if (activity == null) {
                promise.reject("ERR_NO_ACTIVITY", "اکتیویتی فعالی پیدا نشد")
                return
            }
            activity.startLockTask()
            promise.resolve(true)
        } catch (e: Exception) {
            promise.reject("ERR_START_LOCK", e)
        }
    }

    @ReactMethod
    fun stopLockTask(promise: Promise) {
        try {
            val activity: Activity? = currentActivity
            if (activity == null) {
                promise.reject("ERR_NO_ACTIVITY", "اکتیویتی فعالی پیدا نشد")
                return
            }
            activity.stopLockTask()
            promise.resolve(true)
        } catch (e: Exception) {
            promise.reject("ERR_STOP_LOCK", e)
        }
    }
}
