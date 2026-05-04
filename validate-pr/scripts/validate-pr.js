// @ts-check

/**
 * Advisory validation for community PRs. Posts a single friendly comment
 * when the PR doesn't reference an issue with maintainer discussion.
 * Never closes PRs, never applies labels.
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
    return;
  }

  // --- Helpers: cached collaborator-role lookup ---
  const roleCache = new Map();
  async function getRole(owner, repoName, username) {
    const key = `${owner}/${repoName}:${username}`;
    if (roleCache.has(key)) return roleCache.get(key);
    let roleName = null;
    try {
      const { data } = await github.rest.repos.getCollaboratorPermissionLevel({
        owner,
        repo: repoName,
        username,
      });
      roleName = data.role_name;
    } catch {
      // noop — roleName stays null
    }
    roleCache.set(key, roleName);
    return roleName;
  }

  async function hasWriteAccess(owner, repoName, username) {
    const role = await getRole(owner, repoName, username);
    return ['admin', 'maintain', 'push', 'write'].includes(role);
  }

  async function isMaintainer(owner, repoName, username) {
    const role = await getRole(owner, repoName, username);
    return ['admin', 'maintain'].includes(role);
  }

  // --- Step 1: Skip if PR author has write+ access ---
  if (await hasWriteAccess(repo.owner, repo.repo, prAuthor)) {
    core.info(`PR author ${prAuthor} has write+ access. Skipping.`);
    return;
  }
  core.info(`PR author ${prAuthor} does not have write access.`);

  // --- Step 2: Small-PR bypass (excluding lock files) ---
  const LOCK_FILE_BASENAMES = new Set([
    'cargo.lock',
    'package-lock.json',
    'yarn.lock',
    'pnpm-lock.yaml',
    'pipfile.lock',
    'poetry.lock',
    'uv.lock',
    'gemfile.lock',
    'composer.lock',
    'go.sum',
    'mix.lock',
    'pubspec.lock',
    'packages.lock.json',
    'podfile.lock',
    'flake.lock',
  ]);
  const SMALL_PR_THRESHOLD = 100;

  const aggregateLOC = (pullRequest.additions || 0) + (pullRequest.deletions || 0);
  if (aggregateLOC < SMALL_PR_THRESHOLD) {
    core.info(
      `PR has ${aggregateLOC} lines changed (< ${SMALL_PR_THRESHOLD}). Skipping.`
    );
    return;
  }

  // Stage 2: fetch file list and recompute excluding lock files. On API
  // failure, fall through to validation rather than aborting — a transient
  // GitHub error shouldn't break the action.
  let files = null;
  try {
    files = await github.paginate(github.rest.pulls.listFiles, {
      owner: repo.owner,
      repo: repo.repo,
      pull_number: pullRequest.number,
      per_page: 100,
    });
  } catch (e) {
    core.warning(
      `Could not fetch PR file list (${e.message}); skipping lock-file exclusion and proceeding to validation.`
    );
  }
  if (files) {
    function basenameLower(path) {
      const idx = path.lastIndexOf('/');
      return (idx >= 0 ? path.slice(idx + 1) : path).toLowerCase();
    }
    const nonLockLOC = files
      .filter((f) => !LOCK_FILE_BASENAMES.has(basenameLower(f.filename)))
      .reduce((sum, f) => sum + (f.additions || 0) + (f.deletions || 0), 0);
    if (nonLockLOC < SMALL_PR_THRESHOLD) {
      core.info(
        `PR has ${nonLockLOC} non-lock-file lines changed (< ${SMALL_PR_THRESHOLD}). Skipping.`
      );
      return;
    }
  }

  // --- Step 3: Parse issue references from PR body ---
  const body = pullRequest.body || '';
  const issueRefs = [];
  const seen = new Set();

  // Pattern 1: full GitHub URLs
  const urlPattern = /https?:\/\/github\.com\/(getsentry)\/([\w.-]+)\/issues\/(\d+)/gi;
  for (const match of body.matchAll(urlPattern)) {
    const key = `${match[1]}/${match[2]}#${match[3]}`;
    if (!seen.has(key)) {
      seen.add(key);
      issueRefs.push({ owner: match[1], repo: match[2], number: parseInt(match[3]) });
    }
  }

  // Pattern 2: cross-repo references (getsentry/repo#123)
  const crossRepoPattern = /(?:(?:fix|fixes|fixed|close|closes|closed|resolve|resolves|resolved)\s+)?(getsentry)\/([\w.-]+)#(\d+)/gi;
  for (const match of body.matchAll(crossRepoPattern)) {
    const key = `${match[1]}/${match[2]}#${match[3]}`;
    if (!seen.has(key)) {
      seen.add(key);
      issueRefs.push({ owner: match[1], repo: match[2], number: parseInt(match[3]) });
    }
  }

  // Pattern 3: same-repo references (#123)
  const sameRepoPattern = /(?:(?:fix|fixes|fixed|close|closes|closed|resolve|resolves|resolved)\s+)?(?<![/\w])#(\d+)/gi;
  for (const match of body.matchAll(sameRepoPattern)) {
    const key = `${repo.owner}/${repo.repo}#${match[1]}`;
    if (!seen.has(key)) {
      seen.add(key);
      issueRefs.push({ owner: repo.owner, repo: repo.repo, number: parseInt(match[1]) });
    }
  }

  core.info(`Found ${issueRefs.length} issue reference(s): ${[...seen].join(', ')}`);

  // --- Step 4: Validate referenced issues; succeed if any pass all checks ---
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

    // Assignee check: skip this ref if assigned to someone other than PR author.
    if (issue.assignees && issue.assignees.length > 0) {
      const assignedToAuthor = issue.assignees.some((a) => a.login === prAuthor);
      if (!assignedToAuthor) {
        core.info(`Issue ${ref.owner}/${ref.repo}#${ref.number} is assigned to someone else.`);
        continue;
      }
    }

    // Discussion check: PR author and a maintainer must both have participated.
    const comments = await github.paginate(github.rest.issues.listComments, {
      owner: ref.owner,
      repo: ref.repo,
      issue_number: ref.number,
      per_page: 100,
    });

    const prAuthorParticipated =
      issue.user?.login === prAuthor ||
      comments.some((c) => c.user?.login === prAuthor);

    if (!prAuthorParticipated) {
      core.info(`Issue ${ref.owner}/${ref.repo}#${ref.number} has no PR author participation.`);
      continue;
    }

    const usersToCheck = new Set();
    if (issue.user?.login && issue.user.login !== prAuthor) {
      usersToCheck.add(issue.user.login);
    }
    for (const comment of comments) {
      if (comment.user?.login && comment.user.login !== prAuthor) {
        usersToCheck.add(comment.user.login);
      }
    }

    let maintainerParticipated = false;
    for (const user of usersToCheck) {
      if (await isMaintainer(repo.owner, repo.repo, user)) {
        maintainerParticipated = true;
        core.info(`Maintainer ${user} participated in ${ref.owner}/${ref.repo}#${ref.number}.`);
        break;
      }
    }

    if (maintainerParticipated) {
      core.info(`Issue ${ref.owner}/${ref.repo}#${ref.number} has valid discussion. PR is allowed.`);
      return;
    }
    core.info(`Issue ${ref.owner}/${ref.repo}#${ref.number} lacks maintainer participation.`);
  }

  // --- Step 5: Validation failed — post one warm comment (idempotent) ---
  let botLogin = null;
  try {
    const { data: app } = await github.rest.apps.getAuthenticated();
    botLogin = `${app.slug}[bot]`;
  } catch (e) {
    core.warning(
      `Could not resolve bot login (${e.message}); duplicate-comment guard disabled for this run.`
    );
  }

  if (botLogin) {
    const existing = await github.paginate(github.rest.issues.listComments, {
      ...repo,
      issue_number: pullRequest.number,
      per_page: 100,
    });
    if (existing.some((c) => c.user?.login === botLogin)) {
      core.info(`Bot ${botLogin} already commented on this PR. Skipping.`);
      return;
    }
  }

  const commentBody = [
    '👋 Thanks for sending this our way! Before a maintainer reviews the code, we ask community contributors to align with us on the approach first — it keeps your time pointed at changes we can land.',
    '',
    'The easiest way is to open or find a GitHub issue and discuss the approach with a maintainer there, then link that issue from this PR. If the issue is already assigned to someone else, please check in with them (or with us) before continuing — otherwise two people may end up working on the same task.',
    '',
    `See our [contributing guidelines](${contributingUrl}) for the full picture.`,
  ].join('\n');

  await github.rest.issues.createComment({
    ...repo,
    issue_number: pullRequest.number,
    body: commentBody,
  });
  core.info('Posted advisory comment. PR remains open.');
};
