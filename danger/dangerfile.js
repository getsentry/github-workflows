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
const prFlavor = (function () {
  if (danger.github && danger.github.pr) {
    if (danger.github.pr.title) {
      const parts = danger.github.pr.title.split(":");
      if (parts.length > 1) {
        return parts[0].toLowerCase().trim();
      }
    }
    if (danger.github.pr.head && danger.github.pr.head.ref) {
      const parts = danger.github.pr.head.ref.split("/");
      if (parts.length > 1) {
        return parts[0].toLowerCase();
      }
    }
  }
  return "";
})();
console.log(`::debug:: PR Flavor: '${prFlavor}'`);

async function checkDocs() {
  if (prFlavor.startsWith("feat")) {
    message(
      'Do not forget to update <a href="https://github.com/getsentry/sentry-docs">Sentry-docs</a> with your feature once the pull request gets approved.'
    );
  }
}

async function checkChangelog() {
  const changelogFile = "CHANGELOG.md";

  // Check if skipped
  if (
    ["ci", "test", "deps", "chore(deps)", "build(deps)"].includes(prFlavor) ||
    (danger.github.pr.body + "").includes("#skip-changelog")
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

/// Report missing changelog entry
function reportMissingChangelog(changelogFile) {
  fail("Please consider adding a changelog entry for the next release.", changelogFile);

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

- ${prTitleFormatted} ([#${danger.github.pr.number}](${danger.github.pr.html_url}))
\`\`\`

If none of the above apply, you can opt out of this check by adding \`#skip-changelog\` to the PR description.`.trim(),
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
