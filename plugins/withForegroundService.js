const {
  withAndroidManifest,
  withDangerousMod,
} = require('@expo/config-plugins');
const fs = require('fs');
const path = require('path');

function ensurePermission(androidManifest, name) {
  if (!androidManifest.manifest['uses-permission']) {
    androidManifest.manifest['uses-permission'] = [];
  }
  const exists = androidManifest.manifest['uses-permission'].some(
    (p) => p.$['android:name'] === name
  );
  if (!exists) {
    androidManifest.manifest['uses-permission'].push({ $: { 'android:name': name } });
  }
}

function withForegroundService(config) {
  config = withAndroidManifest(config, (config) => {
    const androidManifest = config.modResults;
    ensurePermission(androidManifest, 'android.permission.FOREGROUND_SERVICE');
    ensurePermission(androidManifest, 'android.permission.FOREGROUND_SERVICE_SPECIAL_USE');

    const application = androidManifest.manifest.application[0];
    if (!application.service) application.service = [];

    const already = application.service.some(
      (s) => s.$['android:name'] === '.StickyReminderService'
    );

    if (!already) {
      application.service.push({
        $: {
          'android:name': '.StickyReminderService',
          'android:exported': 'false',
          'android:foregroundServiceType': 'specialUse',
        },
        property: [
          {
            $: {
              'android:name': 'android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE',
              'android:value': 'persistent_reminder_notification',
            },
          },
        ],
      });
    }

    return config;
  });

  config = withDangerousMod(config, [
    'android',
    async (config) => {
      const projectRoot = config.modRequest.projectRoot;
      const platformProjectRoot = config.modRequest.platformProjectRoot;
      const packageName = config.android.package;
      const packagePath = packageName.replace(/\./g, '/');
      const scheme = Array.isArray(config.scheme)
        ? config.scheme[0]
        : (config.scheme || 'yaadavar');

      const javaDir = path.join(platformProjectRoot, 'app/src/main/java', packagePath);
      fs.mkdirSync(javaDir, { recursive: true });

      const srcDir = path.join(projectRoot, 'android-src2');

      const replacePlaceholders = (content) =>
        content
          .replace(/__PACKAGE_NAME__/g, packageName)
          .replace(/__SCHEME__/g, scheme);

      const ktFiles = [
        'StickyReminderService.kt',
        'StickyServiceModule.kt',
        'StickyServicePackage.kt',
      ];
      for (const file of ktFiles) {
        const content = fs.readFileSync(path.join(srcDir, file), 'utf8');
        fs.writeFileSync(path.join(javaDir, file), replacePlaceholders(content), 'utf8');
      }

      return config;
    },
  ]);

  config = withDangerousMod(config, [
    'android',
    async (config) => {
      const platformProjectRoot = config.modRequest.platformProjectRoot;
      const packageName = config.android.package;
      const packagePath = packageName.replace(/\./g, '/');
      const mainAppPath = path.join(
        platformProjectRoot, 'app/src/main/java', packagePath, 'MainApplication.kt'
      );

      if (fs.existsSync(mainAppPath)) {
        let content = fs.readFileSync(mainAppPath, 'utf8');
        if (!content.includes('StickyServicePackage()')) {
          content = content.replace(
            /(PackageList\(this\)\.packages\s*)/,
            `$1.apply { add(StickyServicePackage()) }`
          );
          fs.writeFileSync(mainAppPath, content, 'utf8');
        }
      }

      return config;
    },
  ]);

  return config;
}

module.exports = withForegroundService;
