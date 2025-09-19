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

/// Find insertion point and determine what content needs to be inserted
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

  // Case 1: No Unreleased section exists
  if (unreleasedIndex === -1) {
    // Find first ## section or top of changelog to insert before it
    let insertionPoint = 0;

    // Skip title and initial content, look for first version section
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].trim().match(/^##\s+/)) {
        insertionPoint = i;
        break;
      }
    }

    // If no version sections exist, insert at end
    if (insertionPoint === 0) {
      insertionPoint = lines.length;
    }

    return {
      lineNumber: insertionPoint + 1, // 1-indexed for GitHub API
      insertContent: 'unreleased-and-section'
    };
  }

  // Case 2: Unreleased section exists, find the target subsection
  let sectionIndex = -1;
  let nextSectionIndex = lines.length; // End of file by default

  for (let i = unreleasedIndex + 1; i < lines.length; i++) {
    // Stop if we hit another main section (##)
    if (lines[i].trim().match(/^##\s+/)) {
      nextSectionIndex = i;
      break;
    }

    // Check for our target subsection
    if (lines[i].trim().match(new RegExp(`^###\\s+${sectionName}`, 'i'))) {
      sectionIndex = i;
      break;
    }
  }

  // Case 3: Subsection doesn't exist, need to create it within Unreleased
  if (sectionIndex === -1) {
    // Find insertion point after "## Unreleased" but before next main section
    let insertAfter = unreleasedIndex;

    // Skip empty lines after "## Unreleased"
    while (insertAfter + 1 < nextSectionIndex && lines[insertAfter + 1].trim() === '') {
      insertAfter++;
    }

    return {
      lineNumber: insertAfter + 1, // 1-indexed for GitHub API
      insertContent: 'section-and-entry'
    };
  }

  // Case 4: Both Unreleased and subsection exist, just add entry
  let insertionPoint = sectionIndex + 1;

  // Skip empty lines after section header
  while (insertionPoint < nextSectionIndex && lines[insertionPoint].trim() === '') {
    insertionPoint++;
  }

  return {
    lineNumber: insertionPoint + 1, // 1-indexed for GitHub API
    insertContent: 'entry-only'
  };
}

/// Generate suggestion text for changelog entry based on what needs to be inserted
function generateChangelogSuggestion(prTitle, prNumber, prUrl, sectionName, insertionInfo) {
  // Clean up PR title (remove conventional commit prefix if present)
  const cleanTitle = prTitle
    .split(": ")
    .slice(-1)[0]
    .trim()
    .replace(/\.+$/, "");

  const bulletPoint = `- ${cleanTitle} ([#${prNumber}](${prUrl}))`;

  switch (insertionInfo.insertContent) {
    case 'unreleased-and-section':
      // Need to create both Unreleased section and subsection
      return `## Unreleased\n\n### ${sectionName}\n\n${bulletPoint}\n`;

    case 'section-and-entry':
      // Need to create subsection within existing Unreleased
      return `\n### ${sectionName}\n\n${bulletPoint}`;

    case 'entry-only':
      // Just add the bullet point to existing section
      return bulletPoint;

    default:
      // Fallback to entry-only
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
