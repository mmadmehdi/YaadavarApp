const {
  withAndroidManifest,
  withDangerousMod,
} = require('@expo/config-plugins');
const fs = require('fs');
const path = require('path');

function withDeviceOwnerLock(config) {
  config = withAndroidManifest(config, (config) => {
    const androidManifest = config.modResults;
    const application = androidManifest.manifest.application[0];

    if (!application.receiver) application.receiver = [];

    const alreadyAdded = application.receiver.some(
      (r) => r.$['android:name'] === '.MyDeviceAdminReceiver'
    );

    if (!alreadyAdded) {
      application.receiver.push({
        $: {
          'android:name': '.MyDeviceAdminReceiver',
          'android:label': 'یادآور - مدیریت دستگاه',
          'android:permission': 'android.permission.BIND_DEVICE_ADMIN',
          'android:exported': 'true',
        },
        'meta-data': [
          {
            $: {
              'android:name': 'android.app.device_admin',
              'android:resource': '@xml/device_admin_receiver',
            },
          },
        ],
        'intent-filter': [
          {
            action: [
              { $: { 'android:name': 'android.app.action.DEVICE_ADMIN_ENABLED' } },
            ],
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

      const javaDir = path.join(
        platformProjectRoot,
        'app/src/main/java',
        packagePath
      );
      const xmlDir = path.join(platformProjectRoot, 'app/src/main/res/xml');

      fs.mkdirSync(javaDir, { recursive: true });
      fs.mkdirSync(xmlDir, { recursive: true });

      const srcDir = path.join(projectRoot, 'android-src');

      const replacePackage = (content) =>
        content.replace(/__PACKAGE_NAME__/g, packageName);

      const ktFiles = [
        'MyDeviceAdminReceiver.kt',
        'LockTaskModule.kt',
        'LockTaskPackage.kt',
      ];
      for (const file of ktFiles) {
        const content = fs.readFileSync(path.join(srcDir, file), 'utf8');
        fs.writeFileSync(
          path.join(javaDir, file),
          replacePackage(content),
          'utf8'
        );
      }

      fs.copyFileSync(
        path.join(srcDir, 'device_admin_receiver.xml'),
        path.join(xmlDir, 'device_admin_receiver.xml')
      );

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
        platformProjectRoot,
        'app/src/main/java',
        packagePath,
        'MainApplication.kt'
      );

      if (fs.existsSync(mainAppPath)) {
        let content = fs.readFileSync(mainAppPath, 'utf8');
        if (!content.includes('LockTaskPackage()')) {
          content = content.replace(
            /(PackageList\(this\)\.packages\s*)/,
            `$1.apply { add(LockTaskPackage()) }`
          );
          fs.writeFileSync(mainAppPath, content, 'utf8');
        }
      }

      return config;
    },
  ]);

  return config;
}

module.exports = withDeviceOwnerLock;
