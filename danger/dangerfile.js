const { getFlavorConfig, extractPRFlavor, extractLegalBoilerplateSection } = require('./dangerfile-utils.js');

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


/// Report missing changelog entry
function reportMissingChangelog(changelogFile) {
  fail("Please consider adding a changelog entry for the next release.", changelogFile);

  const prTitleFormatted = danger.github.pr.title
    .split(": ")
    .slice(-1)[0]
    .trim()
    .replace(/\.+$/, "");

  // Determine the appropriate section based on PR flavor
  const flavorConfig = getFlavorConfig(prFlavor);
  const sectionName = flavorConfig.changelog || "Features";

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

async function checkLegalBoilerplate() {
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

async function checkFromExternalChecks() {
  // Get the external dangerfile path from environment variable (passed via workflow input)
  // Priority: EXTRA_DANGERFILE (absolute path) -> EXTRA_DANGERFILE_INPUT (relative path)
  const extraDangerFilePath = process.env.EXTRA_DANGERFILE || process.env.EXTRA_DANGERFILE_INPUT;
  console.log(`::debug:: Checking from external checks: ${extraDangerFilePath}`);
  if (extraDangerFilePath) {
    try {
      const workspaceDir = '/github/workspace';
      
      const path = require('path');
      const fs = require('fs');
      const customPath = path.join(workspaceDir, extraDangerFilePath);
      // Ensure the resolved path is within workspace
      const resolvedPath = fs.realpathSync(customPath);
      if (!resolvedPath.startsWith(workspaceDir)) {
        fail(`Invalid dangerfile path: ${extraDangerFilePath}. Must be within workspace.`);
        throw new Error('Security violation: dangerfile path outside workspace');
      }

      const extraModule = require(customPath);
      if (typeof extraModule !== 'function') { 
        warn(`EXTRA_DANGERFILE must export a function at ${customPath}`); 
        return; 
      }
      await extraModule({
        fail: fail, 
        warn: warn,
        message: message, 
        markdown: markdown,
        danger: danger,
      });
    } catch (err) {
      if (err.message && err.message.includes('Cannot use import statement outside a module')) {
        warn(`External dangerfile uses ES6 imports. Please convert to CommonJS syntax (require/module.exports) or use .mjs extension with proper module configuration.\nFile: ${extraDangerFilePath}`);
      } else {
        warn(`Could not load custom Dangerfile: ${extraDangerFilePath}\n${err}`);
      }
    }
  }
}

async function checkAll() {
  await checkDocs();
  await checkChangelog();
  await checkActionsArePinned();
  await checkLegalBoilerplate();
  await checkFromExternalChecks();
}

schedule(checkAll);
