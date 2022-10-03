# Contributing

## How to run dangerfile locally

- [Working on your Dangerfile](https://danger.systems/js/guides/the_dangerfile.html#working-on-your-dangerfile)
- [Using danger and Faking being on a CI](https://danger.systems/js/guides/the_dangerfile.html#using-danger-and-faking-being-on-a-ci)

## TLDR

```shell-script
export DANGER_GITHUB_API_TOKEN='XXX'
export DANGER_FAKE_CI="YEP"
export DANGER_TEST_REPO='username/reponame'
cd reponame
export DANGER_TEST_PR='1234'
git checkout branch-for-pr-1234
npx danger ci --text-only --failOnErrors --dangerfile=../github-workflows/danger/dangerfile.js
```
