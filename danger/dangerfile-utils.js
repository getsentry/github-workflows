/// Unified configuration for PR flavors
const FLAVOR_CONFIG = [
  {
    labels: ["feat", "feature"],
    changelog: "Features",
    isFeature: true
  },
  {
    labels: ["fix", "bug", "bugfix"],
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
    labels: ["docs", "doc"],
    changelog: undefined  // Internal documentation changes
  },
  {
    labels: ["style", "refactor"],
    changelog: undefined  // Internal code improvements - no changelog needed
  },
  {
    labels: ["test"],
    changelog: undefined  // Test updates don't need changelog
  },
  {
    labels: ["build"],
    changelog: undefined  // Build system changes
  },
  {
    labels: ["ci"],
    changelog: undefined  // CI changes don't need changelog
  },
  {
    labels: ["chore"],
    changelog: undefined  // General maintenance
  },
  {
    labels: ["deps", "dep", "chore(deps)", "build(deps)"],
    changelog: undefined  // Dependency updates
  }
];

/// Get flavor configuration for a given PR flavor
function getFlavorConfig(prFlavor) {
  const normalizedFlavor = prFlavor.toLowerCase().trim();

  const config = FLAVOR_CONFIG.find(config =>
    config.labels.includes(normalizedFlavor)
  );

  return config || {
    changelog: "Features"  // Default to Features
  };
}

/// Find the appropriate line to insert a changelog entry
function findChangelogInsertionPoint(lines, sectionName) {
  let unreleasedIndex = -1;
  let sectionIndex = -1;
  let insertionLine = -1;
  let isNewSection = false;

  // Find the "## Unreleased" section
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].match(/^##\s+Unreleased/i)) {
      unreleasedIndex = i;
      break;
    }
  }

  if (unreleasedIndex === -1) {
    // No "Unreleased" section found
    return { success: false };
  }

  // Look for the target section under "Unreleased"
  for (let i = unreleasedIndex + 1; i < lines.length; i++) {
    // Stop if we hit another ## section (next release)
    if (lines[i].match(/^##\s+/)) {
      break;
    }

    // Check if this is our target section
    if (lines[i].match(new RegExp(`^###\\s+${sectionName}`, 'i'))) {
      sectionIndex = i;
      break;
    }
  }

  if (sectionIndex !== -1) {
    // Found the section, find where to insert within it
    for (let i = sectionIndex + 1; i < lines.length; i++) {
      // Stop if we hit another section or end
      if (lines[i].match(/^##[#]?\s+/)) {
        break;
      }

      // Find the first non-empty line after the section header
      if (lines[i].trim() !== '') {
        // Insert before this line if it's not already a bullet point
        insertionLine = lines[i].match(/^-\s+/) ? i + 1 : i;
        break;
      }
    }

    // If we didn't find a good spot, insert right after the section header
    if (insertionLine === -1) {
      insertionLine = sectionIndex + 2; // +1 for the section, +1 for empty line
    }
  } else {
    // Section doesn't exist, we need to create it
    isNewSection = true;

    // Find where to insert the new section
    // Look for the next section after Unreleased or find a good spot
    for (let i = unreleasedIndex + 1; i < lines.length; i++) {
      if (lines[i].match(/^##\s+/)) {
        // Insert before the next release section
        insertionLine = i - 1;
        break;
      } else if (lines[i].match(/^###\s+/)) {
        // Insert before the first existing section
        insertionLine = i;
        break;
      }
    }

    // If no good spot found, insert after a reasonable gap from Unreleased
    if (insertionLine === -1) {
      insertionLine = unreleasedIndex + 2;
    }
  }

  return {
    success: true,
    lineNumber: insertionLine + 1, // Convert to 1-based line numbering
    isNewSection: isNewSection,
    sectionHeader: isNewSection ? `### ${sectionName}` : null
  };
}

/// Extract PR flavor from title or branch name
function extractPRFlavor(prTitle, prBranchRef) {
  if (prTitle) {
    const parts = prTitle.split(":");
    if (parts.length > 1) {
      return parts[0].toLowerCase().trim();
    }
  }
  if (prBranchRef) {
    const parts = prBranchRef.split("/");
    if (parts.length > 1) {
      return parts[0].toLowerCase();
    }
  }
  return "";
}

module.exports = {
  FLAVOR_CONFIG,
  getFlavorConfig,
  findChangelogInsertionPoint,
  extractPRFlavor
};