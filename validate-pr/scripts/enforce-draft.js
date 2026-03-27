// @ts-check

/**
 * Labels a PR that was converted to draft and leaves an informational comment.
 * Skips if a bot comment already exists (to avoid duplicates on reopen).
 *
 * @param {object} params
 * @param {import('@actions/github').getOctokit} params.github
 * @param {import('@actions/github').context} params.context
 * @param {import('@actions/core')} params.core
 */
module.exports = async ({ github, context, core }) => {
  const pullRequest = context.payload.pull_request;
  const repo = context.repo;

  await github.rest.issues.addLabels({
    ...repo,
    issue_number: pullRequest.number,
    labels: ['converted-to-draft'],
  });

  // Check for existing bot comment to avoid duplicates on reopen
  const comments = await github.paginate(github.rest.issues.listComments, {
    ...repo,
    issue_number: pullRequest.number,
    per_page: 100,
  });
  const botComment = comments.find(c =>
    c.user?.type === 'Bot' &&
    c.body.includes('automatically converted to draft')
  );
  if (botComment) {
    core.info('Bot comment already exists, skipping.');
    return;
  }

  const contributingUrl = `https://github.com/${repo.owner}/${repo.repo}/blob/${context.payload.repository.default_branch}/CONTRIBUTING.md`;

  await github.rest.issues.createComment({
    ...repo,
    issue_number: pullRequest.number,
    body: [
      `This PR has been automatically converted to draft. All PRs must start as drafts per our [contributing guidelines](${contributingUrl}).`,
      '',
      '**Next steps:**',
      '1. Ensure CI passes',
      '2. Fill in the PR description completely',
      '3. Mark as "Ready for review" when you\'re done',
    ].join('\n'),
  });
};
