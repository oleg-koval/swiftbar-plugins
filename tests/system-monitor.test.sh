#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_SCRIPT="${SCRIPT_DIR}/../system-monitor.5s.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local context="${3:-output}"

    case "$haystack" in
        *"$needle"*) ;;
        *)
            printf 'Expected %s to contain:\n%s\n' "$context" "$needle" >&2
            printf 'Actual %s:\n%s\n' "$context" "$haystack" >&2
            exit 1
            ;;
    esac
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local context="${3:-output}"

    case "$haystack" in
        *"$needle"*)
            printf 'Expected %s not to contain:\n%s\n' "$context" "$needle" >&2
            printf 'Actual %s:\n%s\n' "$context" "$haystack" >&2
            exit 1
            ;;
        *)
            ;;
    esac
}

assert_before() {
    local haystack="$1"
    local first="$2"
    local second="$3"
    local context="${4:-output}"
    local prefix_first prefix_second

    prefix_first="${haystack%%"$first"*}"
    prefix_second="${haystack%%"$second"*}"

    if [ "$prefix_first" = "$haystack" ] || [ "$prefix_second" = "$haystack" ]; then
        printf 'Expected %s to contain both markers:\n%s\n%s\n' "$context" "$first" "$second" >&2
        exit 1
    fi

    if [ "${#prefix_first}" -ge "${#prefix_second}" ]; then
        printf 'Expected %s to place:\n%s\nbefore:\n%s\n' "$context" "$first" "$second" >&2
        exit 1
    fi
}

assert_equals() {
    local actual="$1"
    local expected="$2"
    local context="${3:-value}"

    if [ "$actual" != "$expected" ]; then
        printf 'Expected %s:\n%s\n' "$context" "$expected" >&2
        printf 'Actual %s:\n%s\n' "$context" "$actual" >&2
        exit 1
    fi
}

assert_file_contains() {
    local file="$1"
    local needle="$2"
    local context="${3:-file}"
    local contents

    contents="$(cat "$file")"
    assert_contains "$contents" "$needle" "$context"
}

write_flight_history_fixture() {
    mkdir -p "$CACHE_DIR"
    cat >"$(flight_recorder_file)" <<'EOF'
1000	healthy	No urgent issue	1.0	0	30	120	80	Google Chrome	5.0	Terminal	2.0
1900	critical	Busy app using too much CPU	8.0	1	55	118	75	Google Chrome	120.0	Google Chrome	4.0
EOF
}

write_flight_timeline_fixture() {
    mkdir -p "$CACHE_DIR"
    cat >"$(flight_recorder_file)" <<'EOF'
1000	healthy	No urgent issue	1.0	0	30	120	80	Google Chrome	5.0	Terminal	2.0
1600	warning	System load is rising	6.2	0	44	119	78	WindowServer	42.0	WindowServer	3.0
1840	critical	Busy app using too much CPU	7.6	1	55	118	75	Google Chrome	98.0	Google Chrome	4.0
1900	critical	Busy app using too much CPU	8.0	1	60	118	75	Google Chrome	120.0	Google Chrome	4.0
EOF
}

write_flight_spotlight_fixture() {
    mkdir -p "$CACHE_DIR"
    cat >"$(flight_recorder_file)" <<'EOF'
1000	healthy	No urgent issue	2.0	0	30	120	80	Google Chrome	5.0	Terminal	2.0
1600	warning	System load is rising	6.5	0	35	119	78	mds_stores	35.0	mds_stores	3.0
1900	critical	Busy app using too much CPU	8.4	1	40	118	75	mds_stores	112.0	mds_stores	4.0
EOF
}

write_flight_memory_fixture() {
    mkdir -p "$CACHE_DIR"
    cat >"$(flight_recorder_file)" <<'EOF'
1000	healthy	No urgent issue	1.5	0	30	120	80	Mail	5.0	Terminal	2.0
1600	warning	System load is rising	4.0	0	72	119	78	WindowServer	28.0	WindowServer	3.0
1900	critical	System load is very high	8.2	0	88	118	75	WindowServer	35.0	WindowServer	4.0
EOF
}

write_flight_disk_fixture() {
    mkdir -p "$CACHE_DIR"
    cat >"$(flight_recorder_file)" <<'EOF'
1000	healthy	No urgent issue	2.0	0	30	120	80	Mail	5.0	Terminal	2.0
1600	warning	System load is rising	5.8	0	35	114	78	WindowServer	20.0	WindowServer	3.0
1900	critical	System load is very high	8.5	0	40	108	75	WindowServer	30.0	WindowServer	4.0
EOF
}

write_plugin_update_status_fixture() {
    mkdir -p "$DATA_DIR"
    cat >"$(plugin_update_status_file)" <<'EOF'
1000	success	9.9.9	Updated to v9.9.9 from GitHub.
EOF
}

test_menu_title_animates_when_healthy() {
    local output next_output
    SM_TEST_NOW="0"
    output="$(menu_title "healthy" "1.2" "0")"
    SM_TEST_NOW="15"
    next_output="$(menu_title "healthy" "1.2" "0")"

    assert_contains "$output" "·" "menu title"
    assert_contains "$next_output" "◉" "menu title"
}

test_menu_title_can_disable_animation() {
    local output
    ANIMATE_TITLE="false"
    output="$(menu_title "healthy" "1.2" "0")"

    assert_contains "$output" "SM" "menu title"
}

test_secondary_color_is_high_contrast_in_light_mode() {
    local output

    appearance_mode() {
        printf 'Light'
    }

    output="$(secondary_color)"

    assert_contains "$output" "#475467" "secondary color"
}

test_state_color_uses_accessible_light_palette() {
    local critical warning healthy

    appearance_mode() {
        printf 'Light'
    }

    critical="$(state_color "critical")"
    warning="$(state_color "warning")"
    healthy="$(state_color "healthy")"

    assert_contains "$critical" "#B42318" "critical color"
    assert_contains "$warning" "#B54708" "warning color"
    assert_contains "$healthy" "#157F3B" "healthy color"
}

test_hardware_name_uses_cached_command() {
    local args_file output cached_args
    args_file="$(mktemp "${TMPDIR:-/tmp}/swiftbar-hardware-args.XXXXXX")"

    cached_command() {
        printf '%s' "$*" >"$args_file"
        printf 'Hardware:\n    Model Name: MacBook Pro\n'
    }

    output="$(hardware_name)"
    cached_args="$(cat "$args_file")"

    assert_contains "$output" "MacBook Pro" "hardware name"
    assert_contains "$cached_args" "hardware" "hardware cache command"
    rm -f "$args_file"
}

test_official_checkout_dir_detects_repo_root_from_subfolder() {
    local tmpdir output
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/swiftbar-checkout-root.XXXXXX")"
    trap 'if [ -n "${tmpdir:-}" ]; then rm -rf "$tmpdir"; fi' RETURN

    git -C "$tmpdir" init -q
    git -C "$tmpdir" remote add origin "https://github.com/oleg-koval/swiftbar-plugins.git"
    mkdir -p "$tmpdir/swiftbar"

    PLUGIN_DIR="$tmpdir/swiftbar"
    output="$(official_checkout_dir)"

    assert_equals "$output" "$tmpdir" "checkout root"
    rm -rf "$tmpdir"
    trap - RETURN
}

test_remote_plugin_version_uses_cached_command() {
    local args_file output cached_args
    args_file="$(mktemp "${TMPDIR:-/tmp}/swiftbar-remote-version-args.XXXXXX")"

    cached_command() {
        printf '%s' "$*" >"$args_file"
        printf '#!/bin/bash\nPLUGIN_VERSION="1.9.0"\n'
    }

    output="$(remote_plugin_version)"
    cached_args="$(cat "$args_file")"

    assert_contains "$output" "1.9.0" "remote version"
    assert_contains "$cached_args" "github-plugin-version" "remote version cache command"
    rm -f "$args_file"
}

test_print_process_list_preserves_full_command() {
    PROCESS_SNAPSHOT=$'USER PID %CPU %MEM VSZ RSS TT STAT STARTED TIME COMMAND\nme 123 50.0 1.0 0 0 ?? S 00:00.00 00:00.01 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --type=renderer --foo bar'

    local output
    output="$(print_process_list "--Top CPU" "3" "CPU" "3" "----")"

    assert_contains "$output" "Google Chrome (CPU 50.0%)" "process list"
    assert_contains "$output" "PID: 123" "process list"
    assert_not_contains "$output" "--type=renderer --foo bar" "process list"
}

test_print_high_cpu_processes_preserves_full_command() {
    USER="me"
    # shellcheck disable=SC2034
    HIGH_CPU_THRESHOLD="10"
    # shellcheck disable=SC2034
    PROCESS_SNAPSHOT=$'USER PID %CPU %MEM VSZ RSS TT STAT STARTED TIME COMMAND\nme 123 95.0 1.0 0 0 ?? S 00:00.00 00:00.01 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --type=renderer --foo bar\nroot 456 92.0 1.0 0 0 ?? S 00:00.00 00:00.01 /usr/libexec/Example Helper --watchdog'

    local output
    output="$(print_high_cpu_processes)"

    assert_contains "$output" "PID: 123" "busy apps"
    assert_contains "$output" "Process Actions" "busy apps"
    assert_contains "$output" "Stop Process" "busy apps"
    assert_contains "$output" "Potentially Disruptive" "busy apps"
    assert_contains "$output" "Force Kill (Immediate)" "busy apps"
    assert_contains "$output" "Protected system process" "busy apps"
    assert_contains "$output" "PID: 456" "busy apps"
    assert_not_contains "$output" "--type=renderer --foo bar" "busy apps"
}

test_print_energy_impact_preserves_full_command() {
    local tmpdir
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/swiftbar-system-monitor-tests.XXXXXX")"
    trap 'if [ -n "${tmpdir:-}" ]; then rm -rf "$tmpdir"; fi' EXIT

    cat >"$tmpdir/top" <<'EOF'
#!/usr/bin/env bash
cat <<'OUT'
PID COMMAND POWER
12345 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --type=renderer --foo bar 27.5
OUT
EOF
    chmod +x "$tmpdir/top"

    PATH="$tmpdir:$PATH"
    # shellcheck disable=SC2034
    SHOW_ENERGY="true"
    battery_state() {
        printf 'discharging'
    }

    local output
    output="$(print_energy_impact)"

    assert_contains "$output" "PID: 12345" "energy view"
    assert_contains "$output" "Open Activity Monitor" "energy view"
    assert_not_contains "$output" "--type=renderer --foo bar" "energy view"
}

test_vpn_summary_handles_empty_service_list() {
    local output

    vpn_services() {
        return 0
    }

    output="$(vpn_summary)"

    assert_contains "$output" "not available" "vpn summary"
}

test_record_flight_snapshot_writes_history() {
    local tmpdir row
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/swiftbar-flight-recorder.XXXXXX")"

    CACHE_DIR="$tmpdir"
    SM_TEST_NOW="2000"
    PROCESS_SNAPSHOT=$'USER PID %CPU %MEM VSZ RSS TT STAT STARTED TIME COMMAND\nme 123 44.0 12.0 0 0 ?? S 00:00.00 00:00.01 /Applications/Terminal.app/Contents/MacOS/Terminal --login'
    memory_pressure_percent() {
        printf '42'
    }

    record_flight_snapshot "healthy" "No urgent issue" "1.2" "0" "120" "80"
    row="$(cat "$(flight_recorder_file)")"

    assert_contains "$row" $'2000	healthy	No urgent issue	1.2	0	42	120	80	Terminal	44.0	Terminal	12.0' "flight snapshot"
    rm -rf "$tmpdir"
}

test_detect_incident_cause_reports_cpu_jump() {
    local tmpdir output
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/swiftbar-flight-recorder.XXXXXX")"

    CACHE_DIR="$tmpdir"
    SM_TEST_NOW="1900"
    HIGH_CPU_THRESHOLD="90"
    write_flight_history_fixture

    output="$(detect_incident_cause)"

    assert_contains "$output" "Google Chrome jumped from 5.0% to 120.0% CPU in 15m" "incident cause"
    rm -rf "$tmpdir"
}

test_detect_incident_cause_prefers_spotlight_signal() {
    local tmpdir output
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/swiftbar-flight-recorder.XXXXXX")"

    CACHE_DIR="$tmpdir"
    SM_TEST_NOW="1900"
    HIGH_CPU_THRESHOLD="90"
    write_flight_spotlight_fixture

    output="$(detect_incident_cause)"

    assert_contains "$output" "Spotlight indexing is now driving load (mds_stores 112.0% CPU) in 15m" "spotlight cause"
    rm -rf "$tmpdir"
}

test_detect_incident_cause_prefers_memory_pressure_over_load() {
    local tmpdir output
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/swiftbar-flight-recorder.XXXXXX")"

    CACHE_DIR="$tmpdir"
    SM_TEST_NOW="1900"
    HIGH_CPU_THRESHOLD="90"
    write_flight_memory_fixture

    output="$(detect_incident_cause)"

    assert_contains "$output" "Memory pressure rose from 30% to 88% in 15m" "memory cause"
    rm -rf "$tmpdir"
}

test_detect_incident_cause_prefers_disk_drop_over_load() {
    local tmpdir output
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/swiftbar-flight-recorder.XXXXXX")"

    CACHE_DIR="$tmpdir"
    SM_TEST_NOW="1900"
    HIGH_CPU_THRESHOLD="90"
    write_flight_disk_fixture

    output="$(detect_incident_cause)"

    assert_contains "$output" "Disk free dropped by 12.0GB in 15m" "disk cause"
    rm -rf "$tmpdir"
}

test_detect_incident_cause_sets_warmup_expectations() {
    local tmpdir output
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/swiftbar-flight-recorder.XXXXXX")"

    CACHE_DIR="$tmpdir"
    SM_TEST_NOW="1900"
    mkdir -p "$CACHE_DIR"
    cat >"$(flight_recorder_file)" <<'EOF'
1900	critical	Busy app using too much CPU	8.0	1	55	118	75	Google Chrome	120.0	Google Chrome	4.0
EOF

    output="$(detect_incident_cause)"

    assert_contains "$output" "Learning recent activity. First cause after the next refresh." "warm-up cause"
    rm -rf "$tmpdir"
}

test_print_triage_summary_merges_status_cause_action_rules() {
    local tmpdir output
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/swiftbar-flight-recorder.XXXXXX")"

    CACHE_DIR="$tmpdir"
    SM_TEST_NOW="1900"
    HIGH_CPU_THRESHOLD="90"
    write_flight_timeline_fixture

    output="$(print_triage_summary "critical" "Busy app using too much CPU" "red" "8" "1" "118" "75" "80")"

    assert_contains "$output" "Triage" "triage summary"
    assert_contains "$output" "Status: Critical - Busy app using too much CPU" "triage summary"
    assert_contains "$output" "Likely cause: Google Chrome jumped from 5.0% to 120.0% CPU in 15m" "triage summary"
    assert_contains "$output" "Next step: Open Activity Monitor" "triage summary"
    assert_contains "$output" "How alerts work" "triage summary"
    assert_contains "$output" "Busy app: >=90% CPU" "triage summary"
    assert_contains "$output" "Load: warning >=6, critical >=8" "triage summary"
    assert_contains "$output" "Copy Incident Report" "triage summary"
    assert_contains "$output" "1m ago: critical, load 7.6, CPU Google Chrome 98.0%" "triage summary"
    assert_contains "$output" "5m ago: warning, load 6.2, CPU WindowServer 42.0%" "triage summary"
    assert_contains "$output" "15m ago: healthy, load 1.0, CPU Google Chrome 5.0%" "triage summary"
    rm -rf "$tmpdir"
}

test_print_flight_report_includes_recent_snapshots() {
    local tmpdir output
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/swiftbar-flight-recorder.XXXXXX")"

    CACHE_DIR="$tmpdir"
    SM_TEST_NOW="1900"
    HIGH_CPU_THRESHOLD="90"
    write_flight_history_fixture

    output="$(print_flight_report)"

    assert_contains "$output" "Flight Recorder:" "flight report"
    assert_contains "$output" "Detected cause: Google Chrome jumped from 5.0% to 120.0% CPU in 15m" "flight report"
    assert_contains "$output" "now | critical | load 8.0 | mem 55% | disk 118GB | CPU Google Chrome 120.0%" "flight report"
    rm -rf "$tmpdir"
}

test_print_safe_action_center_groups_disruptive_actions() {
    local output

    remote_plugin_version() {
        printf '1.4.0'
    }

    output="$(print_safe_action_center)"

    assert_contains "$output" "Quick Actions" "action center"
    assert_contains "$output" "Potentially Disruptive" "action center"
    assert_contains "$output" "About" "action center"
    assert_contains "$output" "GitHub: v1.4.0 available" "action center"
    assert_contains "$output" "Update from GitHub" "action center"
    assert_contains "$output" "Empty Trash (Permanent)" "action center"
    assert_contains "$output" "Restart Spotlight Index (Rebuilds search index)" "action center"
    assert_before "$output" "About" "Actions" "action center"
    assert_not_contains "$output" "Advanced" "action center"
}

test_print_plugin_update_notice_shows_recent_success() {
    local tmpdir output
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/swiftbar-update-status.XXXXXX")"

    DATA_DIR="$tmpdir"
    SM_TEST_NOW="1060"
    write_plugin_update_status_fixture

    output="$(print_plugin_update_notice)"

    assert_contains "$output" "Update: Updated to v9.9.9 from GitHub. (1m ago)" "update notice"
    rm -rf "$tmpdir"
}

test_print_plugin_update_notice_hides_stale_status() {
    local tmpdir output
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/swiftbar-update-status.XXXXXX")"

    DATA_DIR="$tmpdir"
    SM_TEST_NOW="5000"
    write_plugin_update_status_fixture

    output="$(print_plugin_update_notice)"

    [ -z "$output" ] || fail "Expected stale update notice to be hidden"
    rm -rf "$tmpdir"
}

test_queue_background_update_writes_pending_status() {
    local tmpdir nohup_log refresh_log old_plugin_path old_plugin_dir old_data_dir
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/swiftbar-update-queue.XXXXXX")"
    nohup_log="$tmpdir/nohup.log"
    refresh_log="$tmpdir/refresh.log"

    old_plugin_path="$PLUGIN_PATH"
    old_plugin_dir="$PLUGIN_DIR"
    old_data_dir="$DATA_DIR"
    PLUGIN_PATH="$tmpdir/system-monitor.5s.sh"
    PLUGIN_DIR="$tmpdir"
    DATA_DIR="$tmpdir/data"

    refresh_plugin_menu() {
        printf 'refresh' >"$refresh_log"
    }

    nohup() {
        printf '%s\n' "$*" >"$nohup_log"
        return 0
    }

    queue_background_update_from_github

    assert_file_contains "$(plugin_update_status_file)" $'pending\t'"$PLUGIN_VERSION"$'\tUpdating from GitHub in the background...' "pending update status"
    assert_file_contains "$nohup_log" "$tmpdir/system-monitor.5s.sh perform-update-from-github" "queued update command"
    assert_file_contains "$refresh_log" "refresh" "queued update refresh"

    PLUGIN_PATH="$old_plugin_path"
    PLUGIN_DIR="$old_plugin_dir"
    DATA_DIR="$old_data_dir"
    rm -rf "$tmpdir"
}

test_print_update_status_line_shows_up_to_date_state() {
    local output

    remote_plugin_version() {
        printf '%s' "$PLUGIN_VERSION"
    }

    output="$(print_update_status_line)"

    assert_contains "$output" "GitHub: up to date (v$PLUGIN_VERSION)" "update status"
}

test_print_update_status_line_handles_unavailable_check() {
    local output

    remote_plugin_version() {
        return 0
    }

    output="$(print_update_status_line)"

    assert_contains "$output" "GitHub: update check unavailable" "update status"
}

test_update_plugin_from_github_downloads_raw_script_for_copied_install() {
    local tmpdir bindir fixture current_script url_log output old_plugin_path old_plugin_dir old_path old_data_dir
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/swiftbar-plugin-update.XXXXXX")"
    bindir="$tmpdir/bin"
    mkdir -p "$bindir"
    fixture="$tmpdir/system-monitor.5s.sh.fixture"
    current_script="$tmpdir/system-monitor.5s.sh"
    url_log="$tmpdir/curl-url.log"

    cat >"$fixture" <<'EOF'
#!/bin/bash
# <xbar.title>System Monitor</xbar.title>
PLUGIN_VERSION="9.9.9"
EOF
    cat >"$current_script" <<'EOF'
#!/bin/bash
# <xbar.title>System Monitor</xbar.title>
PLUGIN_VERSION="1.0.0"
EOF
    chmod +x "$current_script"

    cat >"$bindir/curl" <<'EOF'
#!/usr/bin/env bash
output=""
url=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o)
            output="$2"
            shift 2
            ;;
        *)
            url="$1"
            shift
            ;;
    esac
done
printf '%s' "$url" >"$TEST_CURL_URL_LOG"
cp "$TEST_UPDATE_FIXTURE" "$output"
EOF
    chmod +x "$bindir/curl"

    old_plugin_path="$PLUGIN_PATH"
    old_plugin_dir="$PLUGIN_DIR"
    old_path="$PATH"
    old_data_dir="$DATA_DIR"
    PLUGIN_PATH="$current_script"
    PLUGIN_DIR="$tmpdir"
    DATA_DIR="$tmpdir/data"
    PATH="$bindir:$PATH"
    export TEST_UPDATE_FIXTURE="$fixture"
    export TEST_CURL_URL_LOG="$url_log"

    output="$(update_plugin_from_github)"

    assert_contains "$output" "Updated System Monitor to 9.9.9 from GitHub." "download update output"
    assert_contains "$(cat "$url_log")" "https://raw.githubusercontent.com/oleg-koval/swiftbar-plugins/main/system-monitor.5s.sh" "download update url"
    assert_file_contains "$current_script" 'PLUGIN_VERSION="9.9.9"' "downloaded plugin"
    assert_file_contains "$(plugin_update_status_file)" $'success\t9.9.9\tUpdated to v9.9.9 from GitHub.' "download update status"

    PLUGIN_PATH="$old_plugin_path"
    PLUGIN_DIR="$old_plugin_dir"
    DATA_DIR="$old_data_dir"
    PATH="$old_path"
    rm -rf "$tmpdir"
}

test_update_plugin_from_github_uses_git_pull_for_official_checkout() {
    local tmpdir bindir fixture current_script plugin_link git_log output old_plugin_path old_plugin_dir old_path old_data_dir
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/swiftbar-plugin-update.XXXXXX")"
    bindir="$tmpdir/bin"
    mkdir -p "$bindir" "$tmpdir/.git" "$tmpdir/swiftbar"
    fixture="$tmpdir/system-monitor.5s.sh.fixture"
    current_script="$tmpdir/system-monitor.5s.sh"
    plugin_link="$tmpdir/swiftbar/system-monitor.5s.sh"
    git_log="$tmpdir/git.log"

    cat >"$fixture" <<'EOF'
#!/bin/bash
# <xbar.title>System Monitor</xbar.title>
PLUGIN_VERSION="2.3.4"
EOF
    cat >"$current_script" <<'EOF'
#!/bin/bash
# <xbar.title>System Monitor</xbar.title>
PLUGIN_VERSION="1.0.0"
EOF
    chmod +x "$current_script"
    ln -s ../system-monitor.5s.sh "$plugin_link"

    cat >"$bindir/git" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TEST_GIT_LOG"
if [ "$1" = "-C" ] && [ "$3" = "rev-parse" ] && [ "$4" = "--show-toplevel" ]; then
    printf '%s\n' "$TEST_GIT_TOPLEVEL"
    exit 0
fi
if [ "$1" = "-C" ] && [ "$3" = "remote" ] && [ "$4" = "get-url" ] && [ "$5" = "origin" ]; then
    printf 'git@github.com:oleg-koval/swiftbar-plugins.git\n'
    exit 0
fi
if [ "$1" = "-C" ] && [ "$3" = "pull" ] && [ "$4" = "--ff-only" ]; then
    cp "$TEST_UPDATE_FIXTURE" "$TEST_PLUGIN_TARGET"
    exit 0
fi
exit 1
EOF
    chmod +x "$bindir/git"

    old_plugin_path="$PLUGIN_PATH"
    old_plugin_dir="$PLUGIN_DIR"
    old_path="$PATH"
    old_data_dir="$DATA_DIR"
    PLUGIN_PATH="$plugin_link"
    PLUGIN_DIR="$tmpdir/swiftbar"
    DATA_DIR="$tmpdir/data"
    PATH="$bindir:$PATH"
    export TEST_UPDATE_FIXTURE="$fixture"
    export TEST_GIT_LOG="$git_log"
    export TEST_PLUGIN_TARGET="$current_script"
    export TEST_GIT_TOPLEVEL="$tmpdir"

    output="$(update_plugin_from_github)"

    assert_contains "$output" "Updated System Monitor to 2.3.4 from GitHub." "git update output"
    assert_file_contains "$current_script" 'PLUGIN_VERSION="2.3.4"' "git-updated plugin"
    assert_file_contains "$git_log" "-C $tmpdir pull --ff-only" "git pull log"
    assert_file_contains "$(plugin_update_status_file)" $'success\t2.3.4\tUpdated to v2.3.4 from GitHub.' "git update status"

    PLUGIN_PATH="$old_plugin_path"
    PLUGIN_DIR="$old_plugin_dir"
    DATA_DIR="$old_data_dir"
    PATH="$old_path"
    rm -rf "$tmpdir"
}

main() {
    # shellcheck source=../system-monitor.5s.sh
    source "$PLUGIN_SCRIPT"

    test_menu_title_animates_when_healthy
    test_menu_title_can_disable_animation
    test_secondary_color_is_high_contrast_in_light_mode
    test_state_color_uses_accessible_light_palette
    test_hardware_name_uses_cached_command
    test_remote_plugin_version_uses_cached_command
    test_print_process_list_preserves_full_command
    test_print_high_cpu_processes_preserves_full_command
    test_print_energy_impact_preserves_full_command
    test_vpn_summary_handles_empty_service_list
    test_record_flight_snapshot_writes_history
    test_detect_incident_cause_reports_cpu_jump
    test_detect_incident_cause_prefers_spotlight_signal
    test_detect_incident_cause_prefers_memory_pressure_over_load
    test_detect_incident_cause_prefers_disk_drop_over_load
    test_detect_incident_cause_sets_warmup_expectations
    test_print_triage_summary_merges_status_cause_action_rules
    test_print_flight_report_includes_recent_snapshots
    test_print_safe_action_center_groups_disruptive_actions
    test_print_plugin_update_notice_shows_recent_success
    test_print_plugin_update_notice_hides_stale_status
    test_queue_background_update_writes_pending_status
    test_print_update_status_line_shows_up_to_date_state
    test_print_update_status_line_handles_unavailable_check
    test_update_plugin_from_github_downloads_raw_script_for_copied_install
    test_update_plugin_from_github_uses_git_pull_for_official_checkout

    printf 'OK\n'
}

main "$@"
