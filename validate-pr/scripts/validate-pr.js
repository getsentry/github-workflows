// @ts-check

/**
 * Validates non-maintainer PRs by checking that they reference a GitHub issue
 * with prior discussion between the author and a maintainer.
 *
 * Closes PRs that don't meet contribution guidelines.
 *
 * @param {object} params
 * @param {import('@actions/github').getOctokit} params.github
 * @param {import('@actions/github').context} params.context
 * @param {import('@actions/core')} params.core
 */
module.exports = async ({ github, context, core }) => {
  const pullRequest = context.payload.pull_request;
  const repo = context.repo;
  const prAuthor = pullRequest.user.login;
  const contributingUrl = `https://github.com/${repo.owner}/${repo.repo}/blob/${context.payload.repository.default_branch}/CONTRIBUTING.md`;

  // --- Step 0: Skip allowed bots and service accounts ---
  const ALLOWED_BOTS = [
    'codecov-ai[bot]',
    'dependabot[bot]',
    'fix-it-felix-sentry[bot]',
    'getsentry-bot',
    'github-actions[bot]',
    'javascript-sdk-gitflow[bot]',
    'renovate[bot]',
    'sentry-mobile-updater[bot]',
  ];
  if (ALLOWED_BOTS.includes(prAuthor)) {
    core.info(`PR author ${prAuthor} is an allowed bot. Skipping.`);
    core.setOutput('skipped', 'true');
    return;
  }

  // --- Helper: check if a user has admin or maintain permission on a repo (cached) ---
  const maintainerCache = new Map();
  async function isMaintainer(owner, repoName, username) {
    const key = `${owner}/${repoName}:${username}`;
    if (maintainerCache.has(key)) return maintainerCache.get(key);
    let result = false;
    try {
      const { data } = await github.rest.repos.getCollaboratorPermissionLevel({
        owner,
        repo: repoName,
        username,
      });
      // permission field uses legacy values (admin/write/read/none) where
      // maintain maps to write. Use role_name for the actual role.
      result = ['admin', 'maintain'].includes(data.role_name);
    } catch {
      // noop — result stays false
    }
    maintainerCache.set(key, result);
    return result;
  }

  // --- Step 1: Check if PR author is a maintainer (admin or maintain role) ---
  const authorIsMaintainer = await isMaintainer(repo.owner, repo.repo, prAuthor);
  if (authorIsMaintainer) {
    core.info(`PR author ${prAuthor} has admin/maintain access. Skipping.`);
    return;
  }
  core.info(`PR author ${prAuthor} is not a maintainer.`);

  // --- Step 2: Parse issue references from PR body ---
  const body = pullRequest.body || '';

  // Match all issue reference formats:
  //   #123, Fixes #123, getsentry/repo#123, Fixes getsentry/repo#123
  //   https://github.com/getsentry/repo/issues/123
  const issueRefs = [];
  const seen = new Set();

  // Pattern 1: Full GitHub URLs
  const urlPattern = /https?:\/\/github\.com\/(getsentry)\/([\w.-]+)\/issues\/(\d+)/gi;
  for (const match of body.matchAll(urlPattern)) {
    const key = `${match[1]}/${match[2]}#${match[3]}`;
    if (!seen.has(key)) {
      seen.add(key);
      issueRefs.push({ owner: match[1], repo: match[2], number: parseInt(match[3]) });
    }
  }

  // Pattern 2: Cross-repo references (getsentry/repo#123)
  const crossRepoPattern = /(?:(?:fix|fixes|fixed|close|closes|closed|resolve|resolves|resolved)\s+)?(getsentry)\/([\w.-]+)#(\d+)/gi;
  for (const match of body.matchAll(crossRepoPattern)) {
    const key = `${match[1]}/${match[2]}#${match[3]}`;
    if (!seen.has(key)) {
      seen.add(key);
      issueRefs.push({ owner: match[1], repo: match[2], number: parseInt(match[3]) });
    }
  }

  // Pattern 3: Same-repo references (#123)
  // Negative lookbehind to avoid matching cross-repo refs or URLs already captured
  const sameRepoPattern = /(?:(?:fix|fixes|fixed|close|closes|closed|resolve|resolves|resolved)\s+)?(?<![/\w])#(\d+)/gi;
  for (const match of body.matchAll(sameRepoPattern)) {
    const key = `${repo.owner}/${repo.repo}#${match[1]}`;
    if (!seen.has(key)) {
      seen.add(key);
      issueRefs.push({ owner: repo.owner, repo: repo.repo, number: parseInt(match[1]) });
    }
  }

  core.info(`Found ${issueRefs.length} issue reference(s): ${[...seen].join(', ')}`);

  // --- Helper: close PR with comment and labels ---
  async function closePR(message, reasonLabel) {
    await github.rest.issues.addLabels({
      ...repo,
      issue_number: pullRequest.number,
      labels: ['violating-contribution-guidelines', reasonLabel],
    });

    await github.rest.issues.createComment({
      ...repo,
      issue_number: pullRequest.number,
      body: message,
    });

    await github.rest.pulls.update({
      ...repo,
      pull_number: pullRequest.number,
      state: 'closed',
    });

    core.setOutput('was-closed', 'true');
  }

  // --- Step 3: No issue references ---
  if (issueRefs.length === 0) {
    core.info('No issue references found. Closing PR.');
    await closePR([
      'This PR has been automatically closed. All non-maintainer contributions must reference an existing GitHub issue.',
      '',
      '**Next steps:**',
      '1. Find or open an issue describing the problem or feature',
      '2. Discuss the approach with a maintainer in the issue',
      '3. Once a maintainer has acknowledged your proposed approach, open a new PR referencing the issue',
      '',
      `Please review our [contributing guidelines](${contributingUrl}) for more details.`,
    ].join('\n'), 'missing-issue-reference');
    return;
  }

  // --- Step 4: Validate each referenced issue ---
  // A PR is valid if ANY referenced issue passes all checks.
  let hasAssigneeConflict = false;
  let hasNoDiscussion = false;

  for (const ref of issueRefs) {
    core.info(`Checking issue ${ref.owner}/${ref.repo}#${ref.number}...`);

    let issue;
    try {
      const { data } = await github.rest.issues.get({
        owner: ref.owner,
        repo: ref.repo,
        issue_number: ref.number,
      });
      issue = data;
    } catch (e) {
      core.warning(`Could not fetch issue ${ref.owner}/${ref.repo}#${ref.number}: ${e.message}`);
      continue;
    }

    // Check assignee: if assigned to someone other than PR author, flag it
    if (issue.assignees && issue.assignees.length > 0) {
      const assignedToAuthor = issue.assignees.some(a => a.login === prAuthor);
      if (!assignedToAuthor) {
        core.info(`Issue ${ref.owner}/${ref.repo}#${ref.number} is assigned to someone else.`);
        hasAssigneeConflict = true;
        continue;
      }
    }

    // Check discussion: both PR author and a maintainer must have commented
    const comments = await github.paginate(github.rest.issues.listComments, {
      owner: ref.owner,
      repo: ref.repo,
      issue_number: ref.number,
      per_page: 100,
    });

    // Also consider the issue author as a participant (opening the issue is a form of discussion)
    // Guard against null user (deleted/suspended GitHub accounts)
    const prAuthorParticipated =
      issue.user?.login === prAuthor ||
      comments.some(c => c.user?.login === prAuthor);

    let maintainerParticipated = false;
    if (prAuthorParticipated) {
      // Check each commenter (and issue author) for admin/maintain access on the target repo
      const usersToCheck = new Set();
      if (issue.user?.login) usersToCheck.add(issue.user.login);
      for (const comment of comments) {
        if (comment.user?.login && comment.user.login !== prAuthor) {
          usersToCheck.add(comment.user.login);
        }
      }

      for (const user of usersToCheck) {
        if (user === prAuthor) continue;
        if (await isMaintainer(repo.owner, repo.repo, user)) {
          maintainerParticipated = true;
          core.info(`Maintainer ${user} participated in ${ref.owner}/${ref.repo}#${ref.number}.`);
          break;
        }
      }
    }

    if (prAuthorParticipated && maintainerParticipated) {
      core.info(`Issue ${ref.owner}/${ref.repo}#${ref.number} has valid discussion. PR is allowed.`);
      return; // PR is valid — at least one issue passes all checks
    }

    core.info(`Issue ${ref.owner}/${ref.repo}#${ref.number} lacks discussion between author and maintainer.`);
    hasNoDiscussion = true;
  }

  // --- Step 5: No valid issue found — close with the most relevant reason ---
  if (hasAssigneeConflict) {
    core.info('Closing PR: referenced issue is assigned to someone else.');
    await closePR([
      'This PR has been automatically closed. The referenced issue is already assigned to someone else.',
      '',
      'If you believe this assignment is outdated, please comment on the issue to discuss before opening a new PR.',
      '',
      `Please review our [contributing guidelines](${contributingUrl}) for more details.`,
    ].join('\n'), 'issue-already-assigned');
    return;
  }

  if (hasNoDiscussion) {
    core.info('Closing PR: no discussion between PR author and a maintainer in the referenced issue.');
    await closePR([
      'This PR has been automatically closed. The referenced issue does not show a discussion between you and a maintainer.',
      '',
      'To avoid wasted effort on both sides, please discuss your proposed approach in the issue first and wait for a maintainer to respond before opening a PR.',
      '',
      `Please review our [contributing guidelines](${contributingUrl}) for more details.`,
    ].join('\n'), 'missing-maintainer-discussion');
    return;
  }

  // If we get here, all issue refs were unfetchable
  core.info('Could not validate any referenced issues. Closing PR.');
  await closePR([
    'This PR has been automatically closed. The referenced issue(s) could not be found.',
    '',
    '**Next steps:**',
    '1. Ensure the issue exists and is in a `getsentry` repository',
    '2. Discuss the approach with a maintainer in the issue',
    '3. Once a maintainer has acknowledged your proposed approach, open a new PR referencing the issue',
    '',
    `Please review our [contributing guidelines](${contributingUrl}) for more details.`,
  ].join('\n'), 'missing-issue-reference');
};
