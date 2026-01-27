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

module.exports = {
  FLAVOR_CONFIG,
  getFlavorConfig,
  extractPRFlavor,
  extractLegalBoilerplateSection
};
