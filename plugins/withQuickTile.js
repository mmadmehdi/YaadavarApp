const { withAndroidManifest, withDangerousMod } = require('@expo/config-plugins');
const fs = require('fs');
const path = require('path');

module.exports = function withQuickTile(config) {
  // ۱. افزودن سرویس Tile به AndroidManifest.xml با آیکون معتبر
  config = withAndroidManifest(config, (config) => {
    const mainApplication = config.modResults.manifest.application[0];
    mainApplication['service'] = mainApplication['service'] || [];
    mainApplication['service'].push({
      '$': {
        'android:name': '.QuickTileService',
        'android:label': 'جمله فوری',
        'android:icon': '@mipmap/ic_launcher',
        'android:permission': 'android.permission.BIND_QUICK_SETTINGS_TILE',
        'android:exported': 'true',
      },
      'intent-filter': [
        {
          'action': [{ '$': { 'android:name': 'android.service.quicksettings.action.QS_TILE' } }],
        },
      ],
    });
    return config;
  });

  // ۲. تولید فایل نیتیو Kotlin موقع prebuild
  config = withDangerousMod(config, [
    'android',
    async (config) => {
      const packagePath = path.join(
        config.modRequest.platformProjectRoot,
        'app/src/main/java/com/mmadmehdi/yaadavar'
      );
      fs.mkdirSync(packagePath, { recursive: true });

      const ktContent = `package com.mmadmehdi.yaadavar

import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.service.quicksettings.TileService

class QuickTileService : TileService() {
    override fun onClick() {
        super.onClick()
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("yaadapp://popup")).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pendingIntent = PendingIntent.getActivity(
                this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            startActivityAndCollapse(pendingIntent)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
`;
      fs.writeFileSync(path.join(packagePath, 'QuickTileService.kt'), ktContent);
      return config;
    },
  ]);

  return config;
};

