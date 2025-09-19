const { describe, it } = require('node:test');
const assert = require('node:assert');
const { getFlavorConfig, findChangelogInsertionPoint, extractPRFlavor, FLAVOR_CONFIG } = require('./dangerfile-utils.js');

describe('dangerfile-utils', () => {
  describe('getFlavorConfig', () => {
    it('should return config for features with isFeature true', () => {
      const featConfig = getFlavorConfig('feat');
      assert.strictEqual(featConfig.changelog, 'Features');
      assert.strictEqual(featConfig.isFeature, true);

      const featureConfig = getFlavorConfig('feature');
      assert.strictEqual(featureConfig.changelog, 'Features');
      assert.strictEqual(featureConfig.isFeature, true);
    });

    it('should return config for fixes without isFeature', () => {
      const fixConfig = getFlavorConfig('fix');
      assert.strictEqual(fixConfig.changelog, 'Fixes');
      assert.strictEqual(fixConfig.isFeature, undefined);

      const bugConfig = getFlavorConfig('bug');
      assert.strictEqual(bugConfig.changelog, 'Fixes');
      assert.strictEqual(bugConfig.isFeature, undefined);

      const bugfixConfig = getFlavorConfig('bugfix');
      assert.strictEqual(bugfixConfig.changelog, 'Fixes');
      assert.strictEqual(bugfixConfig.isFeature, undefined);
    });

    it('should return config with undefined changelog for skipped flavors', () => {
      const skipFlavors = ['docs', 'doc', 'ci', 'test', 'style', 'refactor', 'build', 'chore', 'deps', 'dep', 'chore(deps)', 'build(deps)'];

      skipFlavors.forEach(flavor => {
        const config = getFlavorConfig(flavor);
        assert.strictEqual(config.changelog, undefined, `${flavor} should have undefined changelog`);
        assert.strictEqual(config.isFeature, undefined, `${flavor} should have undefined isFeature`);
      });
    });

    it('should return default config for unknown flavors', () => {
      const unknownConfig = getFlavorConfig('unknown');
      assert.strictEqual(unknownConfig.changelog, 'Features');
      assert.strictEqual(unknownConfig.isFeature, undefined);

      const emptyConfig = getFlavorConfig('');
      assert.strictEqual(emptyConfig.changelog, 'Features');
      assert.strictEqual(emptyConfig.isFeature, undefined);
    });

    it('should be case-insensitive and handle whitespace', () => {
      const config1 = getFlavorConfig('FEAT');
      assert.strictEqual(config1.changelog, 'Features');

      const config2 = getFlavorConfig(' fix ');
      assert.strictEqual(config2.changelog, 'Fixes');
    });

    it('should handle all security-related flavors', () => {
      const secConfig = getFlavorConfig('sec');
      assert.strictEqual(secConfig.changelog, 'Security');

      const securityConfig = getFlavorConfig('security');
      assert.strictEqual(securityConfig.changelog, 'Security');
    });

    it('should handle all performance-related flavors', () => {
      const perfConfig = getFlavorConfig('perf');
      assert.strictEqual(perfConfig.changelog, 'Performance');

      const performanceConfig = getFlavorConfig('performance');
      assert.strictEqual(performanceConfig.changelog, 'Performance');
    });
  });

  describe('extractPRFlavor', () => {
    it('should extract flavor from PR title with colon', () => {
      const flavor = extractPRFlavor('feat: add new feature', null);
      assert.strictEqual(flavor, 'feat');

      const flavor2 = extractPRFlavor('Fix: resolve bug in authentication', null);
      assert.strictEqual(flavor2, 'fix');

      const flavor3 = extractPRFlavor('Docs: Update readme', null);
      assert.strictEqual(flavor3, 'docs');
    });

    it('should extract flavor from branch name with slash', () => {
      const flavor = extractPRFlavor(null, 'feature/new-api');
      assert.strictEqual(flavor, 'feature');

      const flavor2 = extractPRFlavor(null, 'ci/update-workflows');
      assert.strictEqual(flavor2, 'ci');

      const flavor3 = extractPRFlavor(null, 'fix/auth-bug');
      assert.strictEqual(flavor3, 'fix');
    });

    it('should prefer title over branch if both available', () => {
      const flavor = extractPRFlavor('feat: add feature', 'ci/update-workflows');
      assert.strictEqual(flavor, 'feat');
    });

    it('should return empty string if no flavor found', () => {
      const flavor1 = extractPRFlavor('Simple title', null);
      assert.strictEqual(flavor1, '');

      const flavor2 = extractPRFlavor(null, 'simple-branch');
      assert.strictEqual(flavor2, '');

      const flavor3 = extractPRFlavor(null, null);
      assert.strictEqual(flavor3, '');
    });

    it('should handle edge cases', () => {
      const flavor1 = extractPRFlavor(':', null);
      assert.strictEqual(flavor1, '');

      const flavor2 = extractPRFlavor(null, '/');
      assert.strictEqual(flavor2, '');

      const flavor3 = extractPRFlavor('title: with: multiple: colons', null);
      assert.strictEqual(flavor3, 'title');
    });
  });

  describe('findChangelogInsertionPoint', () => {
    it('should find insertion point in existing section', () => {
      const changelog = [
        '# Changelog',
        '',
        '## Unreleased',
        '',
        '### Features',
        '',
        '- Some existing feature ([#123](...))',
        '',
        '## 1.0.0'
      ];

      const result = findChangelogInsertionPoint(changelog, 'Features');
      assert.strictEqual(result.success, true);
      assert.strictEqual(result.lineNumber, 8); // Should insert after existing feature
      assert.strictEqual(result.isNewSection, false);
      assert.strictEqual(result.sectionHeader, null);
    });

    it('should create new section when section does not exist', () => {
      const changelog = [
        '# Changelog',
        '',
        '## Unreleased',
        '',
        '### Features',
        '',
        '- Some existing feature ([#123](...))',
        '',
        '## 1.0.0'
      ];

      const result = findChangelogInsertionPoint(changelog, 'Security');
      assert.strictEqual(result.success, true);
      assert.strictEqual(result.isNewSection, true);
      assert.strictEqual(result.sectionHeader, '### Security');
      // Should insert before existing Features section
      assert.strictEqual(result.lineNumber, 5);
    });

    it('should handle changelog with no existing sections', () => {
      const changelog = [
        '# Changelog',
        '',
        '## Unreleased',
        '',
        '## 1.0.0'
      ];

      const result = findChangelogInsertionPoint(changelog, 'Features');
      assert.strictEqual(result.success, true);
      assert.strictEqual(result.isNewSection, true);
      assert.strictEqual(result.sectionHeader, '### Features');
      // Should insert after Unreleased header
      assert.strictEqual(result.lineNumber, 4);
    });

    it('should fail when no Unreleased section exists', () => {
      const changelog = [
        '# Changelog',
        '',
        '## 1.0.0',
        '',
        '- Initial release'
      ];

      const result = findChangelogInsertionPoint(changelog, 'Features');
      assert.strictEqual(result.success, false);
    });

    it('should handle empty section', () => {
      const changelog = [
        '# Changelog',
        '',
        '## Unreleased',
        '',
        '### Features',
        '',
        '### Fixes',
        '',
        '- Some fix ([#456](...))',
        '',
        '## 1.0.0'
      ];

      const result = findChangelogInsertionPoint(changelog, 'Features');
      assert.strictEqual(result.success, true);
      assert.strictEqual(result.isNewSection, false);
      // Should insert in empty Features section
      assert.strictEqual(result.lineNumber, 7);
    });

    it('should be case-insensitive for section matching', () => {
      const changelog = [
        '# Changelog',
        '',
        '## unreleased',
        '',
        '### features',
        '',
        '- Some existing feature ([#123](...))',
        '',
        '## 1.0.0'
      ];

      const result = findChangelogInsertionPoint(changelog, 'Features');
      assert.strictEqual(result.success, true);
      assert.strictEqual(result.isNewSection, false);
    });
  });

  describe('FLAVOR_CONFIG integrity', () => {
    it('should have unique labels across all configs', () => {
      const allLabels = [];
      FLAVOR_CONFIG.forEach(config => {
        config.labels.forEach(label => {
          assert.ok(!allLabels.includes(label), `Duplicate label found: ${label}`);
          allLabels.push(label);
        });
      });
    });

    it('should have proper structure for all configs', () => {
      FLAVOR_CONFIG.forEach((config, index) => {
        assert.ok(Array.isArray(config.labels), `Config ${index} should have labels array`);
        assert.ok(config.labels.length > 0, `Config ${index} should have at least one label`);
        assert.ok(config.hasOwnProperty('changelog'), `Config ${index} should have changelog property`);

        // changelog should be either a string or undefined
        if (config.changelog !== undefined) {
          assert.strictEqual(typeof config.changelog, 'string', `Config ${index} changelog should be string or undefined`);
        }

        // isFeature should be true or undefined (not false)
        if (config.hasOwnProperty('isFeature')) {
          assert.strictEqual(config.isFeature, true, `Config ${index} isFeature should be true or undefined`);
        }
      });
    });

    it('should have only Features configs with isFeature true', () => {
      FLAVOR_CONFIG.forEach(config => {
        if (config.isFeature === true) {
          assert.strictEqual(config.changelog, 'Features', 'Only Features configs should have isFeature true');
        }
      });
    });
  });
});