package com.mmadmehdi.yaadavar

import android.app.ActivityManager
import android.content.Context
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.Promise

class LockTaskModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
    override fun getName() = "LockTaskModule"

    @ReactMethod
    fun startLockTask(promise: Promise) {
        try {
            val activity = currentActivity
            activity?.let {
                it.runOnUiThread {
                    it.startLockTask()
                    promise.resolve(true)
                }
            } ?: promise.reject("ERROR", "Activity is null")
        } catch (e: Exception) {
            promise.reject("ERROR", e.message)
        }
    }

    @ReactMethod
    fun stopLockTask(promise: Promise) {
        try {
            val activity = currentActivity
            activity?.let {
                it.runOnUiThread {
                    it.stopLockTask()
                    promise.resolve(true)
                }
            } ?: promise.reject("ERROR", "Activity is null")
        } catch (e: Exception) {
            promise.reject("ERROR", e.message)
        }
    }

    @ReactMethod
    fun enableLockTaskPackage(promise: Promise) {
        try {
            promise.resolve(true)
        } catch (e: Exception) {
            promise.reject("ERROR", e.message)
        }
    }
}
