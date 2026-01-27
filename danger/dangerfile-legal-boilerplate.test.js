const { describe, it } = require('node:test');
const assert = require('node:assert');
const { extractLegalBoilerplateSection } = require('./dangerfile-utils.js');

describe('Legal Boilerplate Validation', () => {
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
});
