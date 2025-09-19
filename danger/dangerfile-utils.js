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

/// Find insertion point for changelog entry in a specific section
function findChangelogInsertionPoint(changelogContent, sectionName) {
  const lines = changelogContent.split('\n');

  // Find "## Unreleased" section
  let unreleasedIndex = -1;
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].trim().match(/^##\s+Unreleased/i)) {
      unreleasedIndex = i;
      break;
    }
  }

  if (unreleasedIndex === -1) {
    return null; // No Unreleased section found
  }

  // Find the target subsection (e.g., "### Features")
  let sectionIndex = -1;
  for (let i = unreleasedIndex + 1; i < lines.length; i++) {
    // Stop if we hit another main section (##)
    if (lines[i].trim().match(/^##\s+/)) {
      break;
    }

    // Check for our target subsection
    if (lines[i].trim().match(new RegExp(`^###\\s+${sectionName}`, 'i'))) {
      sectionIndex = i;
      break;
    }
  }

  if (sectionIndex === -1) {
    // Section doesn't exist, we need to create it
    // Find insertion point after "## Unreleased"
    let insertAfter = unreleasedIndex;

    // Skip empty lines after "## Unreleased"
    while (insertAfter + 1 < lines.length && lines[insertAfter + 1].trim() === '') {
      insertAfter++;
    }

    return {
      lineNumber: insertAfter + 1, // 1-indexed for GitHub API
      createSection: true,
      sectionName: sectionName
    };
  }

  // Section exists, find first bullet point or insertion point
  let insertionPoint = sectionIndex + 1;

  // Skip empty lines after section header
  while (insertionPoint < lines.length && lines[insertionPoint].trim() === '') {
    insertionPoint++;
  }

  // If next line is a bullet point, insert before it
  // If it's another section or end of file, insert here
  return {
    lineNumber: insertionPoint + 1, // 1-indexed for GitHub API
    createSection: false
  };
}

/// Generate suggestion text for changelog entry
function generateChangelogSuggestion(prTitle, prNumber, prUrl, sectionName, insertionInfo) {
  // Clean up PR title (remove conventional commit prefix if present)
  const cleanTitle = prTitle
    .split(": ")
    .slice(-1)[0]
    .trim()
    .replace(/\.+$/, "");

  const bulletPoint = `- ${cleanTitle} ([#${prNumber}](${prUrl}))`;

  if (insertionInfo.createSection) {
    // Need to create the section
    return `\n### ${sectionName}\n\n${bulletPoint}`;
  } else {
    // Just add the bullet point
    return bulletPoint;
  }
}

module.exports = {
  FLAVOR_CONFIG,
  getFlavorConfig,
  extractPRFlavor,
  findChangelogInsertionPoint,
  generateChangelogSuggestion
};
