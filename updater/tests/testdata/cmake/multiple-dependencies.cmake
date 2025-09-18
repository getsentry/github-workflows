include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    GIT_TAG v0.9.1
    GIT_SHALLOW FALSE
)

FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest
    GIT_TAG v1.14.0
    EXCLUDE_FROM_ALL
)

FetchContent_MakeAvailable(sentry-native googletest)