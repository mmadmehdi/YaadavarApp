const {
  withAndroidManifest,
  withDangerousMod,
} = require('@expo/config-plugins');
const fs = require('fs');
const path = require('path');

function withKeywordAccessibility(config) {
  config = withAndroidManifest(config, (config) => {
    const androidManifest = config.modResults;
    const application = androidManifest.manifest.application[0];
    if (!application.service) application.service = [];

    const already = application.service.some(
      (s) => s.$['android:name'] === '.KeywordAccessibilityService'
    );

    if (!already) {
      application.service.push({
        $: {
          'android:name': '.KeywordAccessibilityService',
          'android:exported': 'true',
          'android:permission': 'android.permission.BIND_ACCESSIBILITY_SERVICE',
        },
        'intent-filter': [
          {
            action: [
              { $: { 'android:name': 'android.accessibilityservice.AccessibilityService' } },
            ],
          },
        ],
        'meta-data': [
          {
            $: {
              'android:name': 'android.accessibilityservice',
              'android:resource': '@xml/accessibility_service_config',
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
      const xmlDir = path.join(platformProjectRoot, 'app/src/main/res/xml');
      const valuesDir = path.join(platformProjectRoot, 'app/src/main/res/values');
      fs.mkdirSync(javaDir, { recursive: true });
      fs.mkdirSync(xmlDir, { recursive: true });
      fs.mkdirSync(valuesDir, { recursive: true });

      const srcDir = path.join(projectRoot, 'android-src3');

      const replacePlaceholders = (content) =>
        content
          .replace(/__PACKAGE_NAME__/g, packageName)
          .replace(/__SCHEME__/g, scheme);

      const ktFiles = [
        'KeywordAccessibilityService.kt',
        'KeywordFilterModule.kt',
        'KeywordFilterPackage.kt',
      ];
      for (const file of ktFiles) {
        const content = fs.readFileSync(path.join(srcDir, file), 'utf8');
        fs.writeFileSync(path.join(javaDir, file), replacePlaceholders(content), 'utf8');
      }

      fs.copyFileSync(
        path.join(srcDir, 'accessibility_service_config.xml'),
        path.join(xmlDir, 'accessibility_service_config.xml')
      );
      fs.copyFileSync(
        path.join(srcDir, 'accessibility_strings.xml'),
        path.join(valuesDir, 'accessibility_strings.xml')
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
        platformProjectRoot, 'app/src/main/java', packagePath, 'MainApplication.kt'
      );

      if (fs.existsSync(mainAppPath)) {
        let content = fs.readFileSync(mainAppPath, 'utf8');
        if (!content.includes('KeywordFilterPackage()')) {
          content = content.replace(
            /(PackageList\(this\)\.packages\s*)/,
            `$1.apply { add(KeywordFilterPackage()) }`
          );
          fs.writeFileSync(mainAppPath, content, 'utf8');
        }
      }

      return config;
    },
  ]);

  return config;
}

module.exports = withKeywordAccessibility;
