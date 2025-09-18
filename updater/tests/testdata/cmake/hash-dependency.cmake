include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    GIT_TAG a64d5bd8ee130f2cda196b6fa7d9b65bfa6d32e2 # 0.9.1
    GIT_SHALLOW FALSE
    GIT_SUBMODULES "external/breakpad"
)

FetchContent_MakeAvailable(sentry-native)