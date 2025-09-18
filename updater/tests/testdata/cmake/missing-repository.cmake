include(FetchContent)

FetchContent_Declare(
    sentry-native
    # Missing GIT_REPOSITORY
    GIT_TAG v0.9.1
    GIT_SHALLOW FALSE
)