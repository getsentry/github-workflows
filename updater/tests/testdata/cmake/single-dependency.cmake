include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    GIT_TAG v0.9.1
    GIT_SHALLOW FALSE
    GIT_SUBMODULES "external/breakpad"
)

FetchContent_MakeAvailable(sentry-native)