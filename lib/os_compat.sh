#!/bin/bash
# OS Compatibility Layer for Ralph
# Provides cross-platform functions for macOS and Linux

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            echo "linux"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Get current OS (cached for performance)
RALPH_OS="${RALPH_OS:-$(detect_os)}"

# Get ISO 8601 formatted date (compatible with both macOS and Linux)
# Usage: get_iso_date
get_iso_date() {
    if [[ "$RALPH_OS" == "macos" ]]; then
        # macOS BSD date - construct ISO format manually
        date -u +"%Y-%m-%dT%H:%M:%S+00:00"
    else
        # GNU date - use -Iseconds
        date -Iseconds
    fi
}

# Get date with offset (compatible with both macOS and Linux)
# Usage: get_future_date "+1 hour" or get_future_date "+30 minutes"
get_future_date() {
    local offset="$1"

    if [[ "$RALPH_OS" == "macos" ]]; then
        # Parse offset and convert to macOS format
        case "$offset" in
            "+1 hour"|"+1H")
                date -v +1H -u +"%Y-%m-%dT%H:%M:%S+00:00"
                ;;
            "+30 minutes"|"+30M")
                date -v +30M -u +"%Y-%m-%dT%H:%M:%S+00:00"
                ;;
            *)
                # Default: return current time
                get_iso_date
                ;;
        esac
    else
        # GNU date
        date -d "$offset" -Iseconds 2>/dev/null || date -Iseconds
    fi
}

# Get next hour reset time (for rate limiting display)
get_next_hour_time() {
    if [[ "$RALPH_OS" == "macos" ]]; then
        # Get time component of next hour
        date -v +1H +"%H:%M:%S"
    else
        date -d '+1 hour' +"%H:%M:%S" 2>/dev/null || date +"%H:%M:%S"
    fi
}

# Timeout command wrapper (compatible with both macOS and Linux)
# Usage: run_with_timeout <seconds> <command> [args...]
# Returns: exit code of command, or 124 on timeout
run_with_timeout() {
    local timeout_seconds="$1"
    shift

    if [[ "$RALPH_OS" == "macos" ]]; then
        # Check for gtimeout (from coreutils)
        if command -v gtimeout &> /dev/null; then
            gtimeout "${timeout_seconds}s" "$@"
            return $?
        fi

        # Fallback: use perl-based timeout (available on macOS by default)
        perl -e '
            use strict;
            use warnings;

            my $timeout = shift @ARGV;
            my $pid = fork();

            if ($pid == 0) {
                exec @ARGV;
                exit 127;
            }

            local $SIG{ALRM} = sub {
                kill "TERM", $pid;
                waitpid($pid, 0);
                exit 124;
            };

            alarm($timeout);
            waitpid($pid, 0);
            alarm(0);
            exit($? >> 8);
        ' "$timeout_seconds" "$@"
        return $?
    else
        # Linux: use timeout command directly
        timeout "${timeout_seconds}s" "$@"
        return $?
    fi
}

# Check if required dependencies are available for the current OS
check_os_dependencies() {
    local missing_deps=()

    if [[ "$RALPH_OS" == "macos" ]]; then
        # Check for optional but recommended dependencies on macOS
        if ! command -v gtimeout &> /dev/null; then
            echo "Note: 'gtimeout' not found. Using Perl-based timeout fallback."
            echo "      For better performance, install coreutils: brew install coreutils"
        fi
    fi

    # Required dependencies for all platforms
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi

    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi

    if [[ ${#missing_deps[@]} -ne 0 ]]; then
        echo "Missing required dependencies: ${missing_deps[*]}"
        if [[ "$RALPH_OS" == "macos" ]]; then
            echo "Install with: brew install ${missing_deps[*]}"
        else
            echo "Install with: apt-get install ${missing_deps[*]} (Debian/Ubuntu)"
            echo "         or: yum install ${missing_deps[*]} (CentOS/RHEL)"
        fi
        return 1
    fi

    return 0
}

# Export functions for use in other scripts
export -f detect_os
export -f get_iso_date
export -f get_future_date
export -f get_next_hour_time
export -f run_with_timeout
export -f check_os_dependencies
export RALPH_OS
