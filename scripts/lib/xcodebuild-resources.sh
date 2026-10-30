#!/bin/bash
# Shared local resource budget. Sourced before build/simulator work begins.

configure_xcodebuild_resources() {
    local mode="$1"
    local jobs index_store
    XCODEBUILD_RESOURCE_ARGS=()

    if [[ "${CI:-}" == "true" ]]; then
        if [[ "$mode" == "build" ]]; then
            jobs="${DAILVE_XCODEBUILD_JOBS-4}"
            index_store="${DAILVE_COMPILER_INDEX_STORE_ENABLE-NO}"
        else
            jobs="${DAILVE_XCODEBUILD_JOBS-}"
            index_store="${DAILVE_COMPILER_INDEX_STORE_ENABLE-}"
        fi
    else
        jobs="${DAILVE_XCODEBUILD_JOBS-2}"
        index_store="${DAILVE_COMPILER_INDEX_STORE_ENABLE-NO}"
        if [[ "$mode" == "unit" ]]; then
            XCODEBUILD_RESOURCE_ARGS+=(-parallel-testing-enabled NO)
        fi
    fi

    if [[ -n "$jobs" ]]; then
        if [[ ! "$jobs" =~ ^[1-9][0-9]*$ ]]; then
            echo "DAILVE_XCODEBUILD_JOBS must be a positive integer" >&2
            return 2
        fi
        XCODEBUILD_RESOURCE_ARGS+=(-jobs "$jobs")
    elif [[ "${CI:-}" != "true" ]]; then
        echo "DAILVE_XCODEBUILD_JOBS cannot be empty for a local run" >&2
        return 2
    fi

    if [[ -n "$index_store" ]]; then
        if [[ "$index_store" != "YES" && "$index_store" != "NO" ]]; then
            echo "DAILVE_COMPILER_INDEX_STORE_ENABLE must be YES or NO" >&2
            return 2
        fi
        XCODEBUILD_RESOURCE_ARGS+=("COMPILER_INDEX_STORE_ENABLE=$index_store")
    fi
}
