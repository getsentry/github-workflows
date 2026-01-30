const { describe, it } = require('node:test');
const assert = require('node:assert');
const { getFlavorConfig, extractPRFlavor, extractLegalBoilerplateSection, checkLegalBoilerplate, FLAVOR_CONFIG } = require('./dangerfile-utils.js');

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

  describe('extractLegalBoilerplateSection', () => {
    it('should extract legal boilerplate section with ### header', () => {
      const template = `
# Pull Request Template

## Description
Please describe your changes

### Legal Boilerplate
Look, I get it. The entity doing business as "Sentry" was incorporated in the State of Delaware in 2015 as Functional Software, Inc. and is gonna need some rights from me in order to utilize my contributions in this here PR. So here's the deal: I retain all rights, title and interest in and to my contributions, and by keeping this boilerplate intact I confirm that Sentry can use, modify, copy, and redistribute my contributions, under Sentry's choice of terms.

## Checklist
- [ ] Tests added
`;

      const result = extractLegalBoilerplateSection(template);
      
      assert.ok(result.includes('### Legal Boilerplate'), 'Should include the header');
      assert.ok(result.includes('Functional Software, Inc.'), 'Should include the legal text');
      assert.ok(!result.includes('## Checklist'), 'Should not include the next section');
    });

    it('should extract legal boilerplate section with ## header', () => {
      const template = `
# Pull Request Template

## Legal Boilerplate

This is a legal notice.

## Other Section
More content
`;

      const result = extractLegalBoilerplateSection(template);
      
      assert.strictEqual(result.trim(), '## Legal Boilerplate\n\nThis is a legal notice.');
    });

    it('should extract legal boilerplate section with different heading levels', () => {
      const testCases = [
        { header: '# Legal Boilerplate', text: 'Level 1 header' },
        { header: '## Legal Boilerplate', text: 'Level 2 header' },
        { header: '### Legal Boilerplate', text: 'Level 3 header' },
        { header: '#### Legal Boilerplate', text: 'Level 4 header' },
        { header: '##### Legal Boilerplate', text: 'Level 5 header' },
        { header: '###### Legal Boilerplate', text: 'Level 6 header' }
      ];

      testCases.forEach(({ header, text }) => {
        const template = `${header}\n${text}\n## Next Section`;
        const result = extractLegalBoilerplateSection(template);
        
        assert.ok(result.includes(header), `Should extract section with ${header}`);
        assert.ok(result.includes(text), `Should include text for ${header}`);
        assert.ok(!result.includes('Next Section'), `Should not include next section for ${header}`);
      });
    });

    it('should handle case-insensitive matching', () => {
      const templates = [
        '### Legal Boilerplate\nContent',
        '### legal boilerplate\nContent',
        '### LEGAL BOILERPLATE\nContent',
        '### Legal BOILERPLATE\nContent'
      ];

      templates.forEach(template => {
        const result = extractLegalBoilerplateSection(template);
        assert.ok(result.length > 0, `Should extract from: ${template.split('\n')[0]}`);
        assert.ok(result.includes('Content'), `Should include content from: ${template.split('\n')[0]}`);
      });
    });

    it('should handle legal boilerplate with multiple paragraphs', () => {
      const template = `
### Legal Boilerplate

First paragraph of legal text.

Second paragraph of legal text.

Third paragraph of legal text.

## Next Section
`;

      const result = extractLegalBoilerplateSection(template);
      
      assert.ok(result.includes('First paragraph'), 'Should include first paragraph');
      assert.ok(result.includes('Second paragraph'), 'Should include second paragraph');
      assert.ok(result.includes('Third paragraph'), 'Should include third paragraph');
      assert.ok(!result.includes('Next Section'), 'Should not include next section');
    });

    it('should handle legal boilerplate at end of template', () => {
      const template = `
# PR Template

## Description
Content

### Legal Boilerplate
Legal text at the end.
`;

      const result = extractLegalBoilerplateSection(template);
      
      assert.ok(result.includes('### Legal Boilerplate'), 'Should include header');
      assert.ok(result.includes('Legal text at the end.'), 'Should include text');
    });

    it('should return empty string when no legal boilerplate section exists', () => {
      const template = `
# Pull Request Template

## Description
Please describe your changes

## Checklist
- [ ] Tests added
`;

      const result = extractLegalBoilerplateSection(template);
      
      assert.strictEqual(result, '', 'Should return empty string when no legal section found');
    });

    it('should handle empty template', () => {
      const result = extractLegalBoilerplateSection('');
      assert.strictEqual(result, '', 'Should return empty string for empty template');
    });

    it('should handle template with only legal boilerplate section', () => {
      const template = '### Legal Boilerplate\nThis is the only content.';
      const result = extractLegalBoilerplateSection(template);
      
      assert.ok(result.includes('### Legal Boilerplate'), 'Should include header');
      assert.ok(result.includes('This is the only content.'), 'Should include content');
    });

    it('should handle legal boilerplate with special characters', () => {
      const template = `
### Legal Boilerplate
Text with special chars: @#$%^&*()_+-={}[]|\\:";'<>?,./
And some unicode: 你好世界 🎉

## Next
`;

      const result = extractLegalBoilerplateSection(template);
      
      assert.ok(result.includes('special chars'), 'Should handle special characters');
      assert.ok(result.includes('你好世界'), 'Should handle unicode');
      assert.ok(result.includes('🎉'), 'Should handle emoji');
    });

    it('should handle legal boilerplate with code blocks', () => {
      const template = `
### Legal Boilerplate

Some text with code:

\`\`\`javascript
const legal = true;
\`\`\`

More text.

## Next Section
`;

      const result = extractLegalBoilerplateSection(template);
      
      assert.ok(result.includes('const legal = true;'), 'Should include code blocks');
      assert.ok(result.includes('More text.'), 'Should include text after code block');
      assert.ok(!result.includes('Next Section'), 'Should not include next section');
    });

    it('should handle legal boilerplate with lists', () => {
      const template = `
### Legal Boilerplate

You agree to:
- Item 1
- Item 2
- Item 3

## Other
`;

      const result = extractLegalBoilerplateSection(template);
      
      assert.ok(result.includes('- Item 1'), 'Should include list items');
      assert.ok(result.includes('- Item 2'), 'Should include list items');
      assert.ok(result.includes('- Item 3'), 'Should include list items');
    });

    it('should handle legal boilerplate with extra whitespace', () => {
      const template = `
###    Legal     Boilerplate   
Content with spaces.
## Next
`;

      const result = extractLegalBoilerplateSection(template);
      
      assert.ok(result.includes('Content with spaces.'), 'Should handle extra whitespace in header');
    });

    it('should stop at first subsequent header', () => {
      const template = `
### Legal Boilerplate
First section content.
### Another Legal Boilerplate
This should not be included.
`;

      const result = extractLegalBoilerplateSection(template);
      
      assert.ok(result.includes('First section content.'), 'Should include first section');
      assert.ok(!result.includes('This should not be included.'), 'Should stop at next header');
    });

    it('should handle blank lines within legal section', () => {
      const template = `
### Legal Boilerplate

First paragraph.


Second paragraph with blank lines above.

## Next
`;

      const result = extractLegalBoilerplateSection(template);

      assert.ok(result.includes('First paragraph.'), 'Should include first paragraph');
      assert.ok(result.includes('Second paragraph'), 'Should include second paragraph');
      // Should preserve blank lines
      const blankLineCount = (result.match(/\n\n/g) || []).length;
      assert.ok(blankLineCount >= 1, 'Should preserve blank lines');
    });
  });

  describe('checkLegalBoilerplate', () => {
    const PR_TEMPLATE_WITH_BOILERPLATE = `# Pull Request Template

## Description
Please describe your changes

### Legal Boilerplate
Look, I get it. The entity doing business as "Sentry" was incorporated in the State of Delaware in 2015 as Functional Software, Inc. and is gonna need some rights from me in order to utilize my contributions in this here PR. So here's the deal: I retain all rights, title and interest in and to my contributions, and by keeping this boilerplate intact I confirm that Sentry can use, modify, copy, and redistribute my contributions, under Sentry's choice of terms.

## Checklist
- [ ] Tests added`;

    // Derived from the template to stay in sync automatically
    const LEGAL_BOILERPLATE_SECTION = extractLegalBoilerplateSection(PR_TEMPLATE_WITH_BOILERPLATE);
    const LEGAL_TEXT = LEGAL_BOILERPLATE_SECTION.replace('### Legal Boilerplate\n', '');

    function buildMockContext({ prOverrides = {}, templateContent = PR_TEMPLATE_WITH_BOILERPLATE } = {}) {
      const failMessages = [];
      const markdownMessages = [];

      const danger = {
        github: {
          pr: {
            author_association: 'CONTRIBUTOR',
            body: '',
            ...prOverrides
          },
          utils: {
            fileContents: async (path) => {
              if (templateContent && path === '.github/PULL_REQUEST_TEMPLATE.md') {
                return templateContent;
              }
              return '';
            }
          }
        }
      };

      return {
        danger,
        fail: (msg) => failMessages.push(msg),
        markdown: (msg) => markdownMessages.push(msg),
        failMessages,
        markdownMessages
      };
    }

    // --- Skips for internal contributors ---

    it('should skip check for OWNER association', async () => {
      const ctx = buildMockContext({ prOverrides: { author_association: 'OWNER' } });
      await checkLegalBoilerplate(ctx);
      assert.strictEqual(ctx.failMessages.length, 0);
      assert.strictEqual(ctx.markdownMessages.length, 0);
    });

    it('should skip check for MEMBER association', async () => {
      const ctx = buildMockContext({ prOverrides: { author_association: 'MEMBER' } });
      await checkLegalBoilerplate(ctx);
      assert.strictEqual(ctx.failMessages.length, 0);
    });

    it('should skip check for COLLABORATOR association', async () => {
      const ctx = buildMockContext({ prOverrides: { author_association: 'COLLABORATOR' } });
      await checkLegalBoilerplate(ctx);
      assert.strictEqual(ctx.failMessages.length, 0);
    });

    // --- External contributor associations that should be checked ---

    it('should check for CONTRIBUTOR association', async () => {
      const ctx = buildMockContext({ prOverrides: { author_association: 'CONTRIBUTOR', body: '' } });
      await checkLegalBoilerplate(ctx);
      assert.strictEqual(ctx.failMessages.length, 1, 'Should fail for external CONTRIBUTOR without boilerplate');
    });

    it('should check for FIRST_TIME_CONTRIBUTOR association', async () => {
      const ctx = buildMockContext({ prOverrides: { author_association: 'FIRST_TIME_CONTRIBUTOR', body: '' } });
      await checkLegalBoilerplate(ctx);
      assert.strictEqual(ctx.failMessages.length, 1);
    });

    it('should check for NONE association', async () => {
      const ctx = buildMockContext({ prOverrides: { author_association: 'NONE', body: '' } });
      await checkLegalBoilerplate(ctx);
      assert.strictEqual(ctx.failMessages.length, 1);
    });

    // --- Template discovery ---

    it('should skip when no PR template is found', async () => {
      const ctx = buildMockContext({ templateContent: null });
      await checkLegalBoilerplate(ctx);
      assert.strictEqual(ctx.failMessages.length, 0, 'Should not fail when no template exists');
    });

    it('should skip when template has no Legal Boilerplate section', async () => {
      const ctx = buildMockContext({ templateContent: '# Template\n\n## Description\nJust a normal template.' });
      await checkLegalBoilerplate(ctx);
      assert.strictEqual(ctx.failMessages.length, 0, 'Should not fail when template lacks legal section');
    });

    it('should find template at the first matching path', async () => {
      const calledPaths = [];
      const ctx = buildMockContext();
      ctx.danger.github.utils.fileContents = async (path) => {
        calledPaths.push(path);
        if (path === '.github/pull_request_template.md') {
          return PR_TEMPLATE_WITH_BOILERPLATE;
        }
        return '';
      };
      ctx.danger.github.pr.body = `## My PR\n\n### Legal Boilerplate\n${LEGAL_TEXT}`;
      await checkLegalBoilerplate(ctx);
      assert.ok(calledPaths.includes('.github/PULL_REQUEST_TEMPLATE.md'), 'Should try uppercase path first');
      assert.ok(calledPaths.includes('.github/pull_request_template.md'), 'Should try lowercase path second');
      assert.ok(!calledPaths.includes('PULL_REQUEST_TEMPLATE.md'), 'Should stop after finding template');
    });

    // --- Missing boilerplate in PR body ---

    it('should fail when external contributor PR body is empty', async () => {
      const ctx = buildMockContext({ prOverrides: { author_association: 'NONE', body: '' } });
      await checkLegalBoilerplate(ctx);
      assert.strictEqual(ctx.failMessages.length, 1);
      assert.ok(ctx.failMessages[0].includes('missing the required legal boilerplate'));
      assert.strictEqual(ctx.markdownMessages.length, 1);
      assert.ok(ctx.markdownMessages[0].includes('Legal Boilerplate Required'));
    });

    it('should fail when external contributor PR body is null', async () => {
      const ctx = buildMockContext({ prOverrides: { author_association: 'CONTRIBUTOR', body: null } });
      await checkLegalBoilerplate(ctx);
      assert.strictEqual(ctx.failMessages.length, 1);
      assert.ok(ctx.failMessages[0].includes('missing the required legal boilerplate'));
    });

    it('should fail when PR body has no legal section', async () => {
      const ctx = buildMockContext({
        prOverrides: {
          author_association: 'FIRST_TIME_CONTRIBUTOR',
          body: '## Description\nMy cool changes\n\n## Checklist\n- [x] Tests'
        }
      });
      await checkLegalBoilerplate(ctx);
      assert.strictEqual(ctx.failMessages.length, 1);
      assert.ok(ctx.failMessages[0].includes('missing the required legal boilerplate'));
    });

    // --- Boilerplate mismatch ---

    it('should fail when boilerplate text is modified', async () => {
      const ctx = buildMockContext({
        prOverrides: {
          author_association: 'CONTRIBUTOR',
          body: '### Legal Boilerplate\nI changed the legal text to something else entirely.'
        }
      });
      await checkLegalBoilerplate(ctx);
      assert.strictEqual(ctx.failMessages.length, 1);
      assert.ok(ctx.failMessages[0].includes('does not match the template'));
      assert.strictEqual(ctx.markdownMessages.length, 1);
      assert.ok(ctx.markdownMessages[0].includes('Legal Boilerplate Mismatch'));
    });

    it('should fail when boilerplate is truncated', async () => {
      const ctx = buildMockContext({
        prOverrides: {
          author_association: 'CONTRIBUTOR',
          body: '### Legal Boilerplate\nLook, I get it. The entity doing business as "Sentry" was incorporated in the State of Delaware in 2015.'
        }
      });
      await checkLegalBoilerplate(ctx);
      assert.strictEqual(ctx.failMessages.length, 1);
      assert.ok(ctx.failMessages[0].includes('does not match the template'));
    });

    // --- Matching boilerplate (success cases) ---

    it('should pass when boilerplate matches exactly', async () => {
      const ctx = buildMockContext({
        prOverrides: {
          author_association: 'CONTRIBUTOR',
          body: `## Description\nMy changes\n\n### Legal Boilerplate\n${LEGAL_TEXT}\n\n## Checklist\n- [x] Done`
        }
      });
      await checkLegalBoilerplate(ctx);
      assert.strictEqual(ctx.failMessages.length, 0, 'Should not fail when boilerplate matches');
      assert.strictEqual(ctx.markdownMessages.length, 0);
    });

    it('should pass when boilerplate matches with different whitespace', async () => {
      const ctx = buildMockContext({
        prOverrides: {
          author_association: 'CONTRIBUTOR',
          body: `### Legal Boilerplate\n${LEGAL_TEXT.replace(/\. /g, '.\n')}`
        }
      });
      await checkLegalBoilerplate(ctx);
      assert.strictEqual(ctx.failMessages.length, 0, 'Should pass with normalized whitespace differences');
    });

    it('should pass when boilerplate has extra surrounding whitespace', async () => {
      const ctx = buildMockContext({
        prOverrides: {
          author_association: 'CONTRIBUTOR',
          body: `### Legal Boilerplate\n\n  ${LEGAL_TEXT}  \n\n## Next`
        }
      });
      await checkLegalBoilerplate(ctx);
      assert.strictEqual(ctx.failMessages.length, 0);
    });

    // --- Markdown message content ---

    it('should include expected boilerplate in the markdown hint when missing', async () => {
      const ctx = buildMockContext({ prOverrides: { author_association: 'NONE', body: '' } });
      await checkLegalBoilerplate(ctx);
      assert.strictEqual(ctx.markdownMessages.length, 1);
      assert.ok(ctx.markdownMessages[0].includes('Functional Software, Inc.'), 'Markdown should include the expected legal text');
    });

    it('should include expected boilerplate in the markdown hint on mismatch', async () => {
      const ctx = buildMockContext({
        prOverrides: {
          author_association: 'CONTRIBUTOR',
          body: '### Legal Boilerplate\nWrong text here.'
        }
      });
      await checkLegalBoilerplate(ctx);
      assert.strictEqual(ctx.markdownMessages.length, 1);
      assert.ok(ctx.markdownMessages[0].includes('Functional Software, Inc.'));
    });
  });
});