const { getFlavorConfig, extractPRFlavor, findChangelogInsertionPoint, generateChangelogSuggestion } = require('./dangerfile-utils.js');

const headRepoName = danger.github.pr.head.repo.git_url;
const baseRepoName = danger.github.pr.base.repo.git_url;
const isFork = headRepoName != baseRepoName;

if (isFork) {
  console.log(
    "::warning::Running from a forked repo. Danger won't be able to post comments and workflow status on the main repo, printing directly."
  );

  // Override DangerJS default functions to print to console & create annotations instead.
  const log = function (type, message, file, line) {
    message = message.replace(/%/g, "%25");
    message = message.replace(/\n/g, "%0A");
    message = message.replace(/\r/g, "%0D");
    console.log(`::${type} file=${file},line=${line}::${message}`);
  };

  const dangerFail = fail;
  fail = function (message, file, line) {
    log("error", message, file, line);
    dangerFail(message, file, line);
  };

  warn = function (message, file, line) {
    log("warning", message, file, line);
  };

  message = function (message, file, line) {
    log("notice", message, file, line);
  };

  markdown = function (message, file, line) {
    log("notice", message, file, line);
  };
}

// e.g. "feat" if PR title is "Feat : add more useful stuff"
// or  "ci" if PR branch is "ci/update-danger"
const prFlavor = extractPRFlavor(
  danger.github?.pr?.title,
  danger.github?.pr?.head?.ref
);
console.log(`::debug:: PR Flavor: '${prFlavor}'`);

async function checkDocs() {
  const flavorConfig = getFlavorConfig(prFlavor);
  if (flavorConfig.isFeature) {
    message(
      'Do not forget to update <a href="https://github.com/getsentry/sentry-docs">Sentry-docs</a> with your feature once the pull request gets approved.'
    );
  }
}

async function checkChangelog() {
  const changelogFile = "CHANGELOG.md";
  const flavorConfig = getFlavorConfig(prFlavor);

  // Check if skipped - either by flavor config, explicit skip, or skip label
  if (
    flavorConfig.changelog === undefined ||
    (danger.github.pr.body + "").includes("#skip-changelog") ||
    (danger.github.pr.labels || []).some(label => label.name === 'skip-changelog')
  ) {
    return;
  }

  // Check if current PR has an entry in changelog
  const changelogContents = await danger.github.utils.fileContents(
    changelogFile
  );

  const changelogMatch = RegExp(`^(.*?)\n[^\n]+(\\(${danger.github.pr.html_url}\\)|#${danger.github.pr.number}\\b)`, 's').exec(
    changelogContents
  );

  // check if a changelog entry exists
  if (!changelogMatch) {
    return reportMissingChangelog(changelogFile);
  }

  // Check if the entry is added to an Unreleased section (or rather, check that it's not added to a released one)
  const textBeforeEntry = changelogMatch[1]
  const section = RegExp('^(## +v?[0-9.]+)([\-\n _]|$)', 'm').exec(textBeforeEntry)
  if (section) {
    const lineNr = 1 + textBeforeEntry.split(/\r\n|\r|\n/).length
    fail(
      `The changelog entry seems to be part of an already released section \`${section[1]}\`.
      Consider moving the entry to the \`## Unreleased\` section, please.`,
      changelogFile,
      lineNr
    );
  }
}


/// Report missing changelog entry with inline suggestion
async function reportMissingChangelog(changelogFile) {
  fail("Please consider adding a changelog entry for the next release.", changelogFile);

  // Determine the appropriate section based on PR flavor
  const flavorConfig = getFlavorConfig(prFlavor);
  const sectionName = flavorConfig.changelog || "Features";

  // Check if changelog file is part of the PR diff
  // GitHub API can only create review comments on files that are modified in the PR
  const allChangedFiles = danger.git.created_files
    .concat(danger.git.modified_files)
    .concat(danger.git.deleted_files);

  const isChangelogInDiff = allChangedFiles.includes(changelogFile);

  if (!isChangelogInDiff) {
    // Cannot create inline suggestions on files not in the diff
    console.log(`::warning::Cannot create inline suggestion: ${changelogFile} is not modified in this PR`);
    showMarkdownInstructions(changelogFile, sectionName);
    return;
  }

  try {
    // Get changelog content
    const changelogContent = await danger.github.utils.fileContents(changelogFile);

    // Find insertion point
    const insertionInfo = findChangelogInsertionPoint(changelogContent, sectionName);

    if (insertionInfo) {
      // Generate suggestion text
      const suggestionText = generateChangelogSuggestion(
        danger.github.pr.title,
        danger.github.pr.number,
        danger.github.pr.html_url,
        sectionName,
        insertionInfo
      );

      // Create GitHub suggestion comment
      await danger.github.api.rest.pulls.createReviewComment({
        owner: danger.github.pr.base.repo.owner.login,
        repo: danger.github.pr.base.repo.name,
        pull_number: danger.github.pr.number,
        body: `\`\`\`suggestion\n${suggestionText}\n\`\`\``,
        commit_id: danger.github.pr.head.sha,
        path: changelogFile,
        line: insertionInfo.lineNumber,
        side: "RIGHT"
      });

      message(`💡 I've suggested a changelog entry above. Click "Apply suggestion" to add it!`);
    } else {
      // Fallback to markdown instructions if parsing fails
      showMarkdownInstructions(changelogFile, sectionName);
    }
  } catch (error) {
    console.log(`::warning::Failed to create inline suggestion: ${error.message}`);
    // Fallback to markdown instructions
    showMarkdownInstructions(changelogFile, sectionName);
  }
}

/// Fallback function to show markdown instructions
function showMarkdownInstructions(changelogFile, sectionName) {
  const prTitleFormatted = danger.github.pr.title
    .split(": ")
    .slice(-1)[0]
    .trim()
    .replace(/\.+$/, "");

  markdown(
    `
### Instructions and example for changelog

Please add an entry to \`${changelogFile}\` to the "Unreleased" section. Make sure the entry includes this PR's number.

Example:

\`\`\`markdown
## Unreleased

### ${sectionName}

- ${prTitleFormatted} ([#${danger.github.pr.number}](${danger.github.pr.html_url}))
\`\`\`

If none of the above apply, you can opt out of this check by adding \`#skip-changelog\` to the PR description or adding a \`skip-changelog\` label.`.trim(),
    changelogFile
  );
}

async function checkActionsArePinned() {
  const workflowFiles = danger.git.created_files
    .concat(danger.git.modified_files)
    .filter((path) => path.startsWith(".github/workflows/"));

  if (workflowFiles.length == 0) {
    return;
  }

  console.log(
    `::debug:: Some workflow files have been changed - checking whether actions are pinned: ${workflowFiles}`
  );

  const usesRegex = /^\+? *uses:/;
  const usesActionRegex =
    /^\+? *uses: *(?<user>[^\/]+)\/(?<action>[^@]+)@(?<ref>[^\s]+)/;
  const usesLocalRegex = /^\+? *uses: *\.\//; // e.g. 'uses: ./.github/actions/something'
  const shaRegex = /^[a-f0-9]{40}$/;
  const whitelistedUsers = ["getsentry", "actions", "github"];

  for (const path of workflowFiles) {
    const diff = await danger.git.structuredDiffForFile(path);
    for (const chunk of diff.chunks) {
      for (const change of chunk.changes) {
        if (change.add) {
          const line = change.content;
          const match = line.match(usesActionRegex);
          // Example of `match.groups`:
          // [Object: null prototype] {
          //   user: 'getsentry',
          //   action: 'action-prepare-release',
          //   ref: 'v1'
          // }
          if (match && match.groups) {
            if (!match.groups.ref.match(shaRegex)) {
              if (!whitelistedUsers.includes(match.groups.user)) {
                fail(
                  "Please pin the action by specifying a commit SHA instead of a tag/branch.",
                  path,
                  change.ln
                );
              }
            }
          } else if (line.match(usesRegex) && !line.match(usesLocalRegex)) {
            warn(
              "Couldn't parse 'uses:' declaration while checking for action pinning.",
              path,
              change.ln
            );
          }
        }
      }
    }
  }
}

async function checkAll() {
  await checkDocs();
  await checkChangelog();
  await checkActionsArePinned();
}

schedule(checkAll);
