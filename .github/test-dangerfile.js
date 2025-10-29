// Test dangerfile for exercising extra-dangerfile feature
// This demonstrates how repositories can add custom Danger checks

module.exports = async function ({ fail, warn, message, markdown, danger }) {
  console.log('::notice::Running custom dangerfile checks...');

  // Test that we have access to the danger API
  if (!danger || !danger.github || !danger.github.pr) {
    fail('Custom dangerfile cannot access danger API');
    return;
  }

  // Example check: Verify PR has a description
  const prBody = danger.github.pr.body;
  if (!prBody || prBody.trim().length === 0) {
    warn('PR description is empty. Consider adding a description to help reviewers.');
  } else {
    message('✅ Custom dangerfile check: PR has a description');
  }

  // Example check: Verify PR title is not too short
  const prTitle = danger.github.pr.title;
  if (prTitle && prTitle.length < 10) {
    warn('PR title is quite short. Consider making it more descriptive.');
  } else {
    message('✅ Custom dangerfile check: PR title length is reasonable');
  }

  // Show that we can access git information
  const modifiedFiles = danger.git.modified_files || [];
  const createdFiles = danger.git.created_files || [];
  const totalChangedFiles = modifiedFiles.length + createdFiles.length;

  message(`📊 Custom check: This PR changes ${totalChangedFiles} file(s)`);

  console.log('::notice::Custom dangerfile checks completed successfully');
};
