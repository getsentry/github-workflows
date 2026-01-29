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

/**
 * Extract the legal boilerplate section from the PR template
 * @param {string} templateContent - The PR template content
 * @returns {string} The extracted legal boilerplate section
 */
function extractLegalBoilerplateSection(templateContent) {
  // Find the legal boilerplate section and extract it
  const lines = templateContent.split('\n');
  let inLegalSection = false;
  let legalSection = [];
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    // Check if this line is the legal boilerplate header
    if (/^#{1,6}\s+Legal\s+Boilerplate/i.test(line)) {
      inLegalSection = true;
      legalSection.push(line);
      continue;
    }
    
    // If we're in the legal section
    if (inLegalSection) {
      // Check if we've reached another header (end of legal section)
      if (/^#{1,6}\s+/.test(line)) {
        break;
      }
      legalSection.push(line);
    }
  }
  
  return legalSection.join('\n').trim();
}

/**
 * Check that external contributors include the required legal boilerplate in their PR body.
 * Accepts danger context and reporting functions as parameters for testability.
 *
 * @param {object} options
 * @param {object} options.danger - The DangerJS danger object
 * @param {Function} options.fail - DangerJS fail function
 * @param {Function} options.markdown - DangerJS markdown function
 */
async function checkLegalBoilerplate({ danger, fail, markdown }) {
  console.log('::debug:: Checking legal boilerplate requirements...');

  // Check if the PR author is an external contributor using author_association
  const authorAssociation = danger.github.pr.author_association;
  const isExternalContributor = !['OWNER', 'MEMBER', 'COLLABORATOR'].includes(authorAssociation);

  if (!isExternalContributor) {
    console.log('::debug:: Skipping legal boilerplate check for organization member/collaborator');
    return;
  }

  // Find PR template
  let prTemplateContent = null;
  const possibleTemplatePaths = [
    '.github/PULL_REQUEST_TEMPLATE.md',
    '.github/pull_request_template.md',
    'PULL_REQUEST_TEMPLATE.md',
    'pull_request_template.md',
    '.github/PULL_REQUEST_TEMPLATE/pull_request_template.md'
  ];

  for (const templatePath of possibleTemplatePaths) {
    const content = await danger.github.utils.fileContents(templatePath);
    if (content) {
      prTemplateContent = content;
      console.log(`::debug:: Found PR template at ${templatePath}`);
      break;
    }
  }

  if (!prTemplateContent) {
    console.log('::debug:: No PR template found, skipping legal boilerplate check');
    return;
  }

  // Check if template contains a Legal Boilerplate section
  const legalBoilerplateHeaderRegex = /^#{1,6}\s+Legal\s+Boilerplate/im;
  if (!legalBoilerplateHeaderRegex.test(prTemplateContent)) {
    console.log('::debug:: PR template does not contain a Legal Boilerplate section');
    return;
  }

  // Extract expected boilerplate from template
  const expectedBoilerplate = extractLegalBoilerplateSection(prTemplateContent);
  const prBody = danger.github.pr.body || '';

  // Extract actual boilerplate from PR body
  const actualBoilerplate = extractLegalBoilerplateSection(prBody);

  // Check if PR body contains the legal boilerplate section
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

  // Verify the actual boilerplate matches the expected one
  // Normalize whitespace for comparison
  const normalizeWhitespace = (str) => str.replace(/\s+/g, ' ').trim();
  const expectedNormalized = normalizeWhitespace(expectedBoilerplate);
  const actualNormalized = normalizeWhitespace(actualBoilerplate);

  if (expectedNormalized !== actualNormalized) {
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

module.exports = {
  FLAVOR_CONFIG,
  getFlavorConfig,
  extractPRFlavor,
  extractLegalBoilerplateSection,
  checkLegalBoilerplate
};
