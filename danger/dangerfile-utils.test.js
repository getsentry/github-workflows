const { describe, it } = require('node:test');
const assert = require('node:assert');
const { getFlavorConfig, extractPRFlavor, FLAVOR_CONFIG } = require('./dangerfile-utils.js');

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
      const skipFlavors = ['docs', 'doc', 'ci', 'tests', 'test', 'style', 'refactor', 'build', 'chore', 'meta', 'deps', 'dep', 'chore(deps)', 'build(deps)'];

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

    it('should handle ref flavor (internal changes - no changelog)', () => {
      const refConfig = getFlavorConfig('ref');
      assert.strictEqual(refConfig.changelog, undefined);
      assert.strictEqual(refConfig.isFeature, undefined);
    });

    it('should handle scoped flavors by stripping scope', () => {
      const scopedFeat = getFlavorConfig('feat(core)');
      assert.strictEqual(scopedFeat.changelog, 'Features');
      assert.strictEqual(scopedFeat.isFeature, true);

      const scopedFix = getFlavorConfig('fix(browser)');
      assert.strictEqual(scopedFix.changelog, 'Fixes');
      assert.strictEqual(scopedFix.isFeature, undefined);

      const scopedChore = getFlavorConfig('chore(deps)');
      assert.strictEqual(scopedChore.changelog, undefined);
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