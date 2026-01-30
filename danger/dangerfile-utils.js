/// Unified configuration for PR flavors (based on real Sentry usage analysis)
const FLAVOR_CONFIG = [
  {
    labels: ["feat", "feature", "add", "implement"],
    changelog: "Features",
    isFeature: true
  },
  {
    labels: ["fix", "bug", "bugfix", "resolve", "correct"],
    changelog: "Fixes"
  },
  {
    labels: ["sec", "security"],
    changelog: "Security"
  },
  {
    labels: ["perf", "performance"],
    changelog: "Performance"
  },
  {
    // Internal changes - no changelog needed
    changelog: undefined,
    labels: [
      "docs",
      "doc",
      "style",
      "ref",
      "refactor",
      "tests",
      "test",
      "build",
      "ci",
      "chore",
      "meta",
      "deps",
      "dep",
      "update",
      "bump",
      "cleanup",
      "format"
    ]
  }
];

/// Get flavor configuration for a given PR flavor
function getFlavorConfig(prFlavor) {
  const normalizedFlavor = prFlavor.toLowerCase().trim();

  // Strip scope/context from conventional commit format: "type(scope)" -> "type"
  const parenIndex = normalizedFlavor.indexOf('(');
  const baseType = parenIndex !== -1 ? normalizedFlavor.substring(0, parenIndex) : normalizedFlavor;

  const config = FLAVOR_CONFIG.find(config =>
    config.labels.includes(normalizedFlavor) || config.labels.includes(baseType)
  );

  return config || {
    changelog: "Features"  // Default to Features
  };
}


/// Extract PR flavor from title or branch name
function extractPRFlavor(prTitle, prBranchRef) {
  // Validate input parameters to prevent runtime errors
  if (prTitle && typeof prTitle === 'string') {
    // First try conventional commit format: "type(scope): description"
    const colonParts = prTitle.split(":");
    if (colonParts.length > 1) {
      return colonParts[0].toLowerCase().trim();
    }

    // Fallback: try first word for non-conventional titles like "fix memory leak"
    const firstWord = prTitle.trim().split(/\s+/)[0];
    if (firstWord) {
      return firstWord.toLowerCase();
    }
  }

  if (prBranchRef && typeof prBranchRef === 'string') {
    const parts = prBranchRef.split("/");
    if (parts.length > 1) {
      return parts[0].toLowerCase();
    }
  }
  return "";
}

/** @returns {string} The legal boilerplate section extracted from the content, or empty string if none found */
function extractLegalBoilerplateSection(content) {
  const lines = content.split('\n');
  const legalHeaderIndex = lines.findIndex(line => /^#{1,6}\s+Legal\s+Boilerplate/i.test(line));

  if (legalHeaderIndex === -1) {
    return '';
  }

  const sectionLines = [lines[legalHeaderIndex]];

  for (let i = legalHeaderIndex + 1; i < lines.length; i++) {
    if (/^#{1,6}\s+/.test(lines[i])) {
      break;
    }
    sectionLines.push(lines[i]);
  }

  return sectionLines.join('\n').trim();
}

const INTERNAL_ASSOCIATIONS = ['OWNER', 'MEMBER', 'COLLABORATOR'];

const PR_TEMPLATE_PATHS = [
  '.github/PULL_REQUEST_TEMPLATE.md',
  '.github/pull_request_template.md',
  'PULL_REQUEST_TEMPLATE.md',
  'pull_request_template.md',
  '.github/PULL_REQUEST_TEMPLATE/pull_request_template.md'
];

/**
 * Check that external contributors include the required legal boilerplate in their PR body.
 * Accepts danger context and reporting functions as parameters for testability.
 */
async function checkLegalBoilerplate({ danger, fail, markdown }) {
  console.log('::debug:: Checking legal boilerplate requirements...');

  const authorAssociation = danger.github.pr.author_association;
  if (INTERNAL_ASSOCIATIONS.includes(authorAssociation)) {
    console.log('::debug:: Skipping legal boilerplate check for organization member/collaborator');
    return;
  }

  const prTemplateContent = await findPRTemplate(danger);
  if (!prTemplateContent) {
    console.log('::debug:: No PR template found, skipping legal boilerplate check');
    return;
  }

  const expectedBoilerplate = extractLegalBoilerplateSection(prTemplateContent);
  if (!expectedBoilerplate) {
    console.log('::debug:: PR template does not contain a Legal Boilerplate section');
    return;
  }

  const actualBoilerplate = extractLegalBoilerplateSection(danger.github.pr.body || '');

  if (!actualBoilerplate) {
    fail('This PR is missing the required legal boilerplate. As an external contributor, please include the "Legal Boilerplate" section from the PR template in your PR description.');

    markdown(`
### ⚖️ Legal Boilerplate Required

As an external contributor, your PR must include the legal boilerplate from the PR template.

Please add the following section to your PR description:

\`\`\`markdown
${expectedBoilerplate}
\`\`\`

This is required to ensure proper intellectual property rights for your contributions.
    `.trim());
    return;
  }

  // Normalize whitespace so minor formatting differences don't cause false negatives
  const normalizeWhitespace = (str) => str.replace(/\s+/g, ' ').trim();

  if (normalizeWhitespace(expectedBoilerplate) !== normalizeWhitespace(actualBoilerplate)) {
    fail('The legal boilerplate in your PR description does not match the template. Please ensure you include the complete, unmodified legal text from the PR template.');

    markdown(`
### ⚖️ Legal Boilerplate Mismatch

Your PR contains a "Legal Boilerplate" section, but it doesn't match the required text from the template.

Please replace it with the exact text from the template:

\`\`\`markdown
${expectedBoilerplate}
\`\`\`

This is required to ensure proper intellectual property rights for your contributions.
    `.trim());
    return;
  }

  console.log('::debug:: Legal boilerplate validated successfully ✓');
}

/** Try each known PR template path and return the first one with content. */
async function findPRTemplate(danger) {
  for (const templatePath of PR_TEMPLATE_PATHS) {
    const content = await danger.github.utils.fileContents(templatePath);
    if (content) {
      console.log(`::debug:: Found PR template at ${templatePath}`);
      return content;
    }
  }
  return null;
}

module.exports = {
  FLAVOR_CONFIG,
  getFlavorConfig,
  extractPRFlavor,
  extractLegalBoilerplateSection,
  checkLegalBoilerplate
};
