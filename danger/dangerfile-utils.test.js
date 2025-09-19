const { describe, it } = require('node:test');
const assert = require('node:assert');
const { getFlavorConfig, extractPRFlavor, FLAVOR_CONFIG, findChangelogInsertionPoint, generateChangelogSuggestion } = require('./dangerfile-utils.js');

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

      // Test edge cases for scope stripping
      const nestedParens = getFlavorConfig('feat(scope(nested))');
      assert.strictEqual(nestedParens.changelog, 'Features'); // Should strip at first (

      const noCloseParen = getFlavorConfig('feat(scope');
      assert.strictEqual(noCloseParen.changelog, 'Features'); // Should still work

      const multipleParens = getFlavorConfig('feat(scope1)(scope2)');
      assert.strictEqual(multipleParens.changelog, 'Features'); // Should strip at first (
    });

    it('should handle non-conventional action words', () => {
      // Feature-related words
      const addConfig = getFlavorConfig('add');
      assert.strictEqual(addConfig.changelog, 'Features');
      assert.strictEqual(addConfig.isFeature, true);

      const implementConfig = getFlavorConfig('implement');
      assert.strictEqual(implementConfig.changelog, 'Features');
      assert.strictEqual(implementConfig.isFeature, true);

      // Fix-related words
      const resolveConfig = getFlavorConfig('resolve');
      assert.strictEqual(resolveConfig.changelog, 'Fixes');

      const correctConfig = getFlavorConfig('correct');
      assert.strictEqual(correctConfig.changelog, 'Fixes');

      // Internal change words
      const updateConfig = getFlavorConfig('update');
      assert.strictEqual(updateConfig.changelog, undefined);

      const bumpConfig = getFlavorConfig('bump');
      assert.strictEqual(bumpConfig.changelog, undefined);

      const cleanupConfig = getFlavorConfig('cleanup');
      assert.strictEqual(cleanupConfig.changelog, undefined);

      const formatConfig = getFlavorConfig('format');
      assert.strictEqual(formatConfig.changelog, undefined);
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
      // Empty or whitespace-only strings
      const flavor1 = extractPRFlavor('', null);
      assert.strictEqual(flavor1, '');

      const flavor2 = extractPRFlavor('   ', null);
      assert.strictEqual(flavor2, '');

      // No branch with slash
      const flavor3 = extractPRFlavor(null, 'simple-branch');
      assert.strictEqual(flavor3, '');

      // All null/undefined
      const flavor4 = extractPRFlavor(null, null);
      assert.strictEqual(flavor4, '');
    });

    it('should handle edge cases', () => {
      const flavor1 = extractPRFlavor(':', null);
      assert.strictEqual(flavor1, '');

      const flavor2 = extractPRFlavor(null, '/');
      assert.strictEqual(flavor2, '');

      const flavor3 = extractPRFlavor('title: with: multiple: colons', null);
      assert.strictEqual(flavor3, 'title');
    });

    it('should validate input parameters and handle non-string types', () => {
      // Number inputs
      const flavor1 = extractPRFlavor(123, 456);
      assert.strictEqual(flavor1, '');

      // Object inputs
      const flavor2 = extractPRFlavor({ test: 'object' }, ['array']);
      assert.strictEqual(flavor2, '');

      // Boolean inputs
      const flavor3 = extractPRFlavor(true, false);
      assert.strictEqual(flavor3, '');

      // Mixed valid/invalid inputs
      const flavor4 = extractPRFlavor(null, 'valid/branch');
      assert.strictEqual(flavor4, 'valid');

      const flavor5 = extractPRFlavor('valid: title', 42);
      assert.strictEqual(flavor5, 'valid');
    });

    it('should extract first word from non-conventional PR titles', () => {
      // Non-conventional titles starting with action words
      const flavor1 = extractPRFlavor('Fix memory leak in authentication', null);
      assert.strictEqual(flavor1, 'fix');

      const flavor2 = extractPRFlavor('Add support for new API endpoint', null);
      assert.strictEqual(flavor2, 'add');

      const flavor3 = extractPRFlavor('Update dependencies to latest versions', null);
      assert.strictEqual(flavor3, 'update');

      const flavor4 = extractPRFlavor('Remove deprecated configuration options', null);
      assert.strictEqual(flavor4, 'remove');

      const flavor5 = extractPRFlavor('Bump version to 2.0.0', null);
      assert.strictEqual(flavor5, 'bump');

      // Should still prefer conventional format over first word
      const flavor6 = extractPRFlavor('chore: Update dependencies to latest versions', null);
      assert.strictEqual(flavor6, 'chore');

      // Handle extra whitespace
      const flavor7 = extractPRFlavor('  Fix   memory   leak  ', null);
      assert.strictEqual(flavor7, 'fix');
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

  describe('findChangelogInsertionPoint', () => {
    it('should find insertion point for existing Features section', () => {
      const changelog = `# Changelog

## Unreleased

### Features

- Existing feature ([#100](url))

### Fixes

- Existing fix ([#99](url))

## 1.0.0

Released content`;

      const result = findChangelogInsertionPoint(changelog, 'Features');
      assert.deepStrictEqual(result, {
        lineNumber: 7, // Before "- Existing feature"
        insertContent: 'entry-only'
      });
    });

    it('should find insertion point when Features section exists but is empty', () => {
      const changelog = `# Changelog

## Unreleased

### Features

### Fixes

- Existing fix ([#99](url))`;

      const result = findChangelogInsertionPoint(changelog, 'Features');
      assert.deepStrictEqual(result, {
        lineNumber: 7, // Right after "### Features" and empty line
        insertContent: 'entry-only'
      });
    });

    it('should create section when Features section does not exist', () => {
      const changelog = `# Changelog

## Unreleased

### Fixes

- Existing fix ([#99](url))`;

      const result = findChangelogInsertionPoint(changelog, 'Features');
      assert.deepStrictEqual(result, {
        lineNumber: 4, // Right after "## Unreleased"
        insertContent: 'section-and-entry'
      });
    });

    it('should handle changelog with only Unreleased section', () => {
      const changelog = `# Changelog

## Unreleased

## 1.0.0

Released content`;

      const result = findChangelogInsertionPoint(changelog, 'Features');
      assert.deepStrictEqual(result, {
        lineNumber: 4, // Right after "## Unreleased"
        insertContent: 'section-and-entry'
      });
    });

    it('should create Unreleased section when none exists', () => {
      const changelog = `# Changelog

## 1.0.0

Released content`;

      const result = findChangelogInsertionPoint(changelog, 'Features');
      assert.deepStrictEqual(result, {
        lineNumber: 3, // Before "## 1.0.0"
        insertContent: 'unreleased-and-section'
      });
    });

    it('should handle case-insensitive Unreleased section', () => {
      const changelog = `# Changelog

## unreleased

### Features

- Existing feature ([#100](url))`;

      const result = findChangelogInsertionPoint(changelog, 'Features');
      assert.deepStrictEqual(result, {
        lineNumber: 7,
        insertContent: 'entry-only'
      });
    });

    it('should handle different section names', () => {
      const changelog = `# Changelog

## Unreleased

### Security

- Security fix ([#101](url))`;

      const result = findChangelogInsertionPoint(changelog, 'Fixes');
      assert.deepStrictEqual(result, {
        lineNumber: 4, // After "## Unreleased"
        insertContent: 'section-and-entry'
      });
    });

    it('should handle extra whitespace around sections', () => {
      const changelog = `# Changelog

## Unreleased

   ### Features

   - Existing feature ([#100](url))`;

      const result = findChangelogInsertionPoint(changelog, 'Features');
      assert.deepStrictEqual(result, {
        lineNumber: 7, // Before "   - Existing feature"
        insertContent: 'entry-only'
      });
    });
  });

  describe('generateChangelogSuggestion', () => {
    it('should generate bullet point for existing section', () => {
      const insertionInfo = { lineNumber: 7, insertContent: 'entry-only' };
      const result = generateChangelogSuggestion(
        'feat: add new feature',
        123,
        'https://github.com/repo/pull/123',
        'Features',
        insertionInfo
      );

      assert.strictEqual(result, '- add new feature ([#123](https://github.com/repo/pull/123))');
    });

    it('should generate section with bullet point for new section', () => {
      const insertionInfo = { lineNumber: 4, insertContent: 'section-and-entry' };
      const result = generateChangelogSuggestion(
        'feat: add new feature',
        123,
        'https://github.com/repo/pull/123',
        'Features',
        insertionInfo
      );

      assert.strictEqual(result, '\n### Features\n\n- add new feature ([#123](https://github.com/repo/pull/123))');
    });

    it('should generate full Unreleased section when none exists', () => {
      const insertionInfo = { lineNumber: 3, insertContent: 'unreleased-and-section' };
      const result = generateChangelogSuggestion(
        'feat: add new feature',
        123,
        'https://github.com/repo/pull/123',
        'Features',
        insertionInfo
      );

      assert.strictEqual(result, '## Unreleased\n\n### Features\n\n- add new feature ([#123](https://github.com/repo/pull/123))\n');
    });

    it('should clean up PR title by removing conventional commit prefix', () => {
      const insertionInfo = { lineNumber: 7, insertContent: 'entry-only' };

      const result1 = generateChangelogSuggestion(
        'feat(auth): add OAuth support',
        123,
        'url',
        'Features',
        insertionInfo
      );
      assert.strictEqual(result1, '- add OAuth support ([#123](url))');

      const result2 = generateChangelogSuggestion(
        'fix: resolve memory leak',
        124,
        'url',
        'Fixes',
        insertionInfo
      );
      assert.strictEqual(result2, '- resolve memory leak ([#124](url))');
    });

    it('should handle non-conventional PR titles', () => {
      const insertionInfo = { lineNumber: 7, insertContent: 'entry-only' };

      const result = generateChangelogSuggestion(
        'Fix memory leak in authentication',
        125,
        'url',
        'Fixes',
        insertionInfo
      );
      assert.strictEqual(result, '- Fix memory leak in authentication ([#125](url))');
    });

    it('should remove trailing periods from title', () => {
      const insertionInfo = { lineNumber: 7, insertContent: 'entry-only' };

      const result = generateChangelogSuggestion(
        'feat: add new feature...',
        126,
        'url',
        'Features',
        insertionInfo
      );
      assert.strictEqual(result, '- add new feature ([#126](url))');
    });

    it('should handle various section names', () => {
      const insertionInfo = { lineNumber: 4, insertContent: 'section-and-entry' };

      const securityResult = generateChangelogSuggestion(
        'sec: fix vulnerability',
        127,
        'url',
        'Security',
        insertionInfo
      );
      assert.strictEqual(securityResult, '\n### Security\n\n- fix vulnerability ([#127](url))');

      const perfResult = generateChangelogSuggestion(
        'perf: optimize queries',
        128,
        'url',
        'Performance',
        insertionInfo
      );
      assert.strictEqual(perfResult, '\n### Performance\n\n- optimize queries ([#128](url))');
    });
  });

  describe('Edge Cases and Missing Sections', () => {
    it('should handle completely empty changelog', () => {
      const changelog = '';
      const result = findChangelogInsertionPoint(changelog, 'Features');
      assert.deepStrictEqual(result, {
        lineNumber: 2, // Insert at end of empty file (lines.length + 1)
        insertContent: 'unreleased-and-section'
      });
    });

    it('should handle changelog with only title', () => {
      const changelog = '# Changelog';
      const result = findChangelogInsertionPoint(changelog, 'Features');
      assert.deepStrictEqual(result, {
        lineNumber: 2, // Insert after title
        insertContent: 'unreleased-and-section'
      });
    });

    it('should handle changelog with title and description but no versions', () => {
      const changelog = `# Changelog

This is a description of the changelog.

Some additional notes.`;

      const result = findChangelogInsertionPoint(changelog, 'Features');
      assert.deepStrictEqual(result, {
        lineNumber: 6, // Insert at end since no version sections
        insertContent: 'unreleased-and-section'
      });
    });

    it('should insert before first version when no Unreleased exists', () => {
      const changelog = `# Changelog

## 2.0.0

### Features

- Feature in 2.0.0

## 1.0.0

### Features

- Feature in 1.0.0`;

      const result = findChangelogInsertionPoint(changelog, 'Features');
      assert.deepStrictEqual(result, {
        lineNumber: 3, // Before "## 2.0.0"
        insertContent: 'unreleased-and-section'
      });
    });

    it('should handle Unreleased section with only other subsections', () => {
      const changelog = `# Changelog

## Unreleased

### Dependencies

- Update lodash to v4.17.21

### Documentation

- Update README`;

      const result = findChangelogInsertionPoint(changelog, 'Features');
      assert.deepStrictEqual(result, {
        lineNumber: 4, // Right after "## Unreleased"
        insertContent: 'section-and-entry'
      });
    });

    it('should handle mixed case and spacing in section headers', () => {
      const changelog = `# Changelog

##   unreleased

###   features

- Existing feature`;

      const result = findChangelogInsertionPoint(changelog, 'Features');
      assert.deepStrictEqual(result, {
        lineNumber: 7, // Before existing feature
        insertContent: 'entry-only'
      });
    });

    it('should handle Unreleased section at end of file', () => {
      const changelog = `# Changelog

## 1.0.0

### Features

- Old feature

## Unreleased`;

      const result = findChangelogInsertionPoint(changelog, 'Features');
      assert.deepStrictEqual(result, {
        lineNumber: 9, // After "## Unreleased"
        insertContent: 'section-and-entry'
      });
    });

    it('should create full structure for completely new changelog', () => {
      const insertionInfo = { lineNumber: 1, insertContent: 'unreleased-and-section' };
      const result = generateChangelogSuggestion(
        'feat: initial release',
        1,
        'https://github.com/repo/pull/1',
        'Features',
        insertionInfo
      );

      assert.strictEqual(result, '## Unreleased\n\n### Features\n\n- initial release ([#1](https://github.com/repo/pull/1))\n');
    });
  });
});