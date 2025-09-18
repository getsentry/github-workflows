include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    # Missing GIT_TAG
    GIT_SHALLOW FALSE
)