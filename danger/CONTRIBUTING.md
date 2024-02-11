# Contributing

## How to run dangerfile locally

- [Working on your Dangerfile](https://danger.systems/js/guides/the_dangerfile.html#working-on-your-dangerfile)
- [Using danger and Faking being on a CI](https://danger.systems/js/guides/the_dangerfile.html#using-danger-and-faking-being-on-a-ci)

## TLDR

```pwsh
$env:DANGER_GITHUB_API_TOKEN = gh auth token
$env:DANGER_FAKE_CI = 'YEP'
$env:DANGER_TEST_REPO = 'username/reponame'
$env:DANGER_TEST_PR = 1234

cd reponame
gh pr checkout $env:DANGER_TEST_PR
npx danger ci --text-only --failOnErrors --dangerfile=../github-workflows/danger/dangerfile.js
```
