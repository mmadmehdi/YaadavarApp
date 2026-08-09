package __PACKAGE_NAME__

import android.content.Context
import android.content.Intent
import android.provider.Settings
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod

class KeywordFilterModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName() = "KeywordFilterModule"

    private fun prefs() = reactApplicationContext.getSharedPreferences(
        KeywordAccessibilityService.PREFS_NAME, Context.MODE_PRIVATE
    )

    @ReactMethod
    fun saveKeywords(csv: String, promise: Promise) {
        try {
            prefs().edit().putString(KeywordAccessibilityService.PREFS_KEY, csv).apply()
            promise.resolve(true)
        } catch (e: Exception) {
            promise.reject("ERR_SAVE_KEYWORDS", e)
        }
    }

    @ReactMethod
    fun getKeywords(promise: Promise) {
        try {
            val csv = prefs().getString(KeywordAccessibilityService.PREFS_KEY, "") ?: ""
            promise.resolve(csv)
        } catch (e: Exception) {
            promise.reject("ERR_GET_KEYWORDS", e)
        }
    }

    @ReactMethod
    fun openAccessibilitySettings(promise: Promise) {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            reactApplicationContext.startActivity(intent)
            promise.resolve(true)
        } catch (e: Exception) {
            promise.reject("ERR_OPEN_SETTINGS", e)
        }
    }

    @ReactMethod
    fun getAndClearLastMatchedKeyword(promise: Promise) {
        try {
            val kw = prefs().getString(KeywordAccessibilityService.LAST_MATCH_KEY, null)
            if (kw != null) {
                prefs().edit().remove(KeywordAccessibilityService.LAST_MATCH_KEY).apply()
            }
            promise.resolve(kw)
        } catch (e: Exception) {
            promise.reject("ERR_GET_LAST_MATCH", e)
        }
    }

    @ReactMethod
    fun isAccessibilityServiceEnabled(promise: Promise) {
        try {
            val expectedComponent = reactApplicationContext.packageName + "/__PACKAGE_NAME__.KeywordAccessibilityService"
            val enabledServices = Settings.Secure.getString(
                reactApplicationContext.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: ""
            val isEnabled = enabledServices.split(":").any {
                it.equals(expectedComponent, ignoreCase = true)
            }
            promise.resolve(isEnabled)
        } catch (e: Exception) {
            promise.reject("ERR_CHECK_A11Y", e)
        }
    }
}
