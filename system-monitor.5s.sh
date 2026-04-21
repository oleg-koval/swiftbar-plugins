#!/bin/bash

# <xbar.title>System Monitor</xbar.title>
# <xbar.version>v1.2.4</xbar.version>
# <xbar.author>Oleg Koval</xbar.author>
# <xbar.author.github>oleg-koval</xbar.author.github>
# <xbar.desc>Power-user macOS health dashboard for SwiftBar.</xbar.desc>
# <xbar.abouturl>https://github.com/oleg-koval/swiftbar-plugins</xbar.abouturl>
# <xbar.dependencies>bash</xbar.dependencies>
# <swiftbar.refreshInterval>5s</swiftbar.refreshInterval>
# <swiftbar.refreshOnOpen>false</swiftbar.refreshOnOpen>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <xbar.var>number(VAR_SM_LOAD_WARN=6): Load average warning threshold.</xbar.var>
# <xbar.var>number(VAR_SM_LOAD_CRIT=8): Load average critical threshold.</xbar.var>
# <xbar.var>number(VAR_SM_HIGH_CPU_THRESHOLD=90): CPU percent treated as runaway.</xbar.var>
# <xbar.var>number(VAR_SM_LOW_DISK_WARN_GB=20): Free disk GB warning threshold.</xbar.var>
# <xbar.var>boolean(VAR_SM_SHOW_DEVICES=false): Show display, USB, Bluetooth, and network sections.</xbar.var>
# <xbar.var>boolean(VAR_SM_SHOW_SYSTEM_ALERTS=true): Show update, iCloud, and Spotlight alerts.</xbar.var>
# <xbar.var>boolean(VAR_SM_CHECK_SOFTWARE_UPDATES=false): Run the slow software update check.</xbar.var>
# <xbar.var>boolean(VAR_SM_SHOW_DOCKER=true): Show Docker/OrbStack section when available.</xbar.var>
# <xbar.var>boolean(VAR_SM_SHOW_DOCKER_STATS=false): Show per-container CPU/memory stats.</xbar.var>
# <xbar.var>boolean(VAR_SM_SHOW_ENERGY=false): Show energy impact while on battery.</xbar.var>
# <xbar.var>boolean(VAR_SM_ANIMATE_TITLE=true): Animate the healthy menu bar indicator.</xbar.var>

set -u

PLUGIN_VERSION="1.2.4"
AUTHOR_GITHUB="oleg-koval"
REPO_NAME="swiftbar-plugins"
REPO_DEFAULT_BRANCH="main"
REPO_PLUGIN_FILE="system-monitor.5s.sh"
REPO_URL="https://github.com/${AUTHOR_GITHUB}/${REPO_NAME}"

if [ -n "${SWIFTBAR_PLUGIN_PATH:-}" ]; then
    PLUGIN_PATH="$SWIFTBAR_PLUGIN_PATH"
else
    PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
    PLUGIN_PATH="$PLUGIN_DIR/$(basename "$0")"
fi
DATA_DIR="${SWIFTBAR_PLUGIN_DATA_PATH:-$HOME/.config/swiftbar-system-monitor}"
CACHE_DIR="${SWIFTBAR_PLUGIN_CACHE_PATH:-$HOME/.cache/swiftbar-system-monitor}"

LOAD_WARN="6"
LOAD_CRIT="8"
HIGH_CPU_THRESHOLD="90"
LOW_DISK_WARN_GB="20"
SHOW_DEVICES="false"
SHOW_SYSTEM_ALERTS="true"
CHECK_SOFTWARE_UPDATES="false"
SHOW_DOCKER="true"
SHOW_DOCKER_STATS="false"
SHOW_ENERGY="false"
ANIMATE_TITLE="true"
SLOW_CACHE_TTL_SECONDS="300"
HARDWARE_CACHE_TTL_SECONDS="86400"
GITHUB_VERSION_CACHE_TTL_SECONDS="21600"
FLIGHT_RECORDER_WINDOW_SECONDS="900"
FLIGHT_RECORDER_MAX_ROWS="240"
UPDATE_STATUS_TTL_SECONDS="900"
PROCESS_SNAPSHOT=""
APPEARANCE_MODE=""

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

is_true() {
    case "${1:-}" in
        1|true|TRUE|yes|YES|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}

is_number() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

appearance_mode() {
    if [ -z "$APPEARANCE_MODE" ]; then
        if defaults read -g AppleInterfaceStyle >/dev/null 2>&1; then
            APPEARANCE_MODE="Dark"
        else
            APPEARANCE_MODE="Light"
        fi
    fi

    printf '%s' "$APPEARANCE_MODE"
}

secondary_color() {
    if [ "$(appearance_mode)" = "Dark" ]; then
        printf '#B0B8C1'
    else
        printf '#475467'
    fi
}

critical_color() {
    if [ "$(appearance_mode)" = "Dark" ]; then
        printf '#FF8A80'
    else
        printf '#B42318'
    fi
}

warning_color() {
    if [ "$(appearance_mode)" = "Dark" ]; then
        printf '#F5C451'
    else
        printf '#B54708'
    fi
}

healthy_color() {
    if [ "$(appearance_mode)" = "Dark" ]; then
        printf '#4AD97A'
    else
        printf '#157F3B'
    fi
}

set_config_value() {
    local key="$1"
    local value="$2"

    case "$key" in
        LOAD_WARN|SM_LOAD_WARN) LOAD_WARN="$value" ;;
        LOAD_CRIT|SM_LOAD_CRIT) LOAD_CRIT="$value" ;;
        HIGH_CPU_THRESHOLD|SM_HIGH_CPU_THRESHOLD) HIGH_CPU_THRESHOLD="$value" ;;
        LOW_DISK_WARN_GB|SM_LOW_DISK_WARN_GB) LOW_DISK_WARN_GB="$value" ;;
        SHOW_DEVICES|SM_SHOW_DEVICES) SHOW_DEVICES="$value" ;;
        SHOW_SYSTEM_ALERTS|SM_SHOW_SYSTEM_ALERTS) SHOW_SYSTEM_ALERTS="$value" ;;
        CHECK_SOFTWARE_UPDATES|SM_CHECK_SOFTWARE_UPDATES) CHECK_SOFTWARE_UPDATES="$value" ;;
        SHOW_DOCKER|SM_SHOW_DOCKER) SHOW_DOCKER="$value" ;;
        SHOW_DOCKER_STATS|SM_SHOW_DOCKER_STATS) SHOW_DOCKER_STATS="$value" ;;
        SHOW_ENERGY|SM_SHOW_ENERGY) SHOW_ENERGY="$value" ;;
        ANIMATE_TITLE|SM_ANIMATE_TITLE) ANIMATE_TITLE="$value" ;;
        SLOW_CACHE_TTL_SECONDS|SM_SLOW_CACHE_TTL_SECONDS) SLOW_CACHE_TTL_SECONDS="$value" ;;
    esac
}

load_config_file() {
    local file="$1"
    local line key value

    [ -f "$file" ] || return 0

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ''|\#*) continue ;;
            *=*)
                key="${line%%=*}"
                value="${line#*=}"
                key="$(printf '%s' "$key" | tr -d '[:space:]')"
                value="$(printf '%s' "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')"
                set_config_value "$key" "$value"
                ;;
        esac
    done <"$file"
}

apply_env_override() {
    local env_name="$1"
    local key="$2"
    local value

    eval "value=\${$env_name:-}"
    [ -n "$value" ] && set_config_value "$key" "$value"
}

load_config() {
    load_config_file "$HOME/.config/swiftbar-system-monitor/config"
    load_config_file "$DATA_DIR/config"

    apply_env_override "VAR_SM_LOAD_WARN" "LOAD_WARN"
    apply_env_override "VAR_SM_LOAD_CRIT" "LOAD_CRIT"
    apply_env_override "VAR_SM_HIGH_CPU_THRESHOLD" "HIGH_CPU_THRESHOLD"
    apply_env_override "VAR_SM_LOW_DISK_WARN_GB" "LOW_DISK_WARN_GB"
    apply_env_override "VAR_SM_SHOW_DEVICES" "SHOW_DEVICES"
    apply_env_override "VAR_SM_SHOW_SYSTEM_ALERTS" "SHOW_SYSTEM_ALERTS"
    apply_env_override "VAR_SM_CHECK_SOFTWARE_UPDATES" "CHECK_SOFTWARE_UPDATES"
    apply_env_override "VAR_SM_SHOW_DOCKER" "SHOW_DOCKER"
    apply_env_override "VAR_SM_SHOW_DOCKER_STATS" "SHOW_DOCKER_STATS"
    apply_env_override "VAR_SM_SHOW_ENERGY" "SHOW_ENERGY"
    apply_env_override "VAR_SM_ANIMATE_TITLE" "ANIMATE_TITLE"
    apply_env_override "VAR_SM_SLOW_CACHE_TTL_SECONDS" "SLOW_CACHE_TTL_SECONDS"

    is_number "$LOAD_WARN" || LOAD_WARN="6"
    is_number "$LOAD_CRIT" || LOAD_CRIT="8"
    is_number "$HIGH_CPU_THRESHOLD" || HIGH_CPU_THRESHOLD="90"
    is_number "$LOW_DISK_WARN_GB" || LOW_DISK_WARN_GB="20"
    is_number "$SLOW_CACHE_TTL_SECONDS" || SLOW_CACHE_TTL_SECONDS="300"
}

cache_is_fresh() {
    local file="$1"
    local ttl="$2"
    local now modified age

    [ -f "$file" ] || return 1
    now="$(date +%s)"
    modified="$(stat -f %m "$file" 2>/dev/null || echo 0)"
    age=$((now - modified))
    [ "$age" -lt "$ttl" ]
}

cached_command() {
    local name="$1"
    local ttl="$2"
    shift 2

    mkdir -p "$CACHE_DIR" 2>/dev/null || true
    local cache_file="$CACHE_DIR/$name"

    if cache_is_fresh "$cache_file" "$ttl"; then
        cat "$cache_file"
        return 0
    fi

    if "$@" >"$cache_file.tmp" 2>/dev/null; then
        mv "$cache_file.tmp" "$cache_file"
        cat "$cache_file"
    else
        rm -f "$cache_file.tmp"
        [ -f "$cache_file" ] && cat "$cache_file"
    fi
}

normalize_git_remote_url() {
    local url="$1"

    case "$url" in
        git@github.com:*)
            url="https://github.com/${url#git@github.com:}"
            ;;
        ssh://git@github.com/*)
            url="https://github.com/${url#ssh://git@github.com/}"
            ;;
    esac

    printf '%s' "${url%.git}"
}

official_checkout_dir() {
    local checkout_dir origin_url normalized_origin

    command_exists git || return 1
    checkout_dir="$(git -C "$PLUGIN_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
    [ -n "$checkout_dir" ] || return 1

    origin_url="$(git -C "$checkout_dir" remote get-url origin 2>/dev/null || true)"
    [ -n "$origin_url" ] || return 1

    normalized_origin="$(normalize_git_remote_url "$origin_url")"
    [ "$normalized_origin" = "$REPO_URL" ] || return 1

    printf '%s' "$checkout_dir"
}

plugin_update_url() {
    printf 'https://raw.githubusercontent.com/%s/%s/%s/%s' \
        "$AUTHOR_GITHUB" \
        "$REPO_NAME" \
        "$REPO_DEFAULT_BRANCH" \
        "$REPO_PLUGIN_FILE"
}

version_is_newer() {
    local candidate="$1"
    local current="$2"

    awk -v candidate="$candidate" -v current="$current" '
        BEGIN {
            candidate_count = split(candidate, candidate_parts, ".")
            current_count = split(current, current_parts, ".")
            max_parts = candidate_count > current_count ? candidate_count : current_count

            for (part_index = 1; part_index <= max_parts; part_index++) {
                candidate_value = (part_index in candidate_parts && candidate_parts[part_index] ~ /^[0-9]+$/) ? candidate_parts[part_index] + 0 : 0
                current_value = (part_index in current_parts && current_parts[part_index] ~ /^[0-9]+$/) ? current_parts[part_index] + 0 : 0

                if (candidate_value > current_value) exit 0
                if (candidate_value < current_value) exit 1
            }

            exit 1
        }'
}

installed_plugin_version() {
    sed -n 's/^PLUGIN_VERSION="\([^"]*\)"/\1/p' "$PLUGIN_PATH" | head -1
}

remote_plugin_version() {
    local plugin_contents remote_version

    command_exists curl || return 0

    plugin_contents="$(cached_command github-plugin-version "$GITHUB_VERSION_CACHE_TTL_SECONDS" \
        curl -fsSL --connect-timeout 2 --max-time 4 "$(plugin_update_url)")"
    remote_version="$(printf '%s\n' "$plugin_contents" | sed -n 's/^PLUGIN_VERSION="\([^"]*\)"/\1/p' | head -1)"

    [ -n "$remote_version" ] && printf '%s' "$remote_version"
}

validate_downloaded_plugin() {
    local file="$1"

    grep -q '^# <xbar.title>System Monitor</xbar.title>$' "$file" &&
        grep -q '^PLUGIN_VERSION="' "$file"
}

download_plugin_update() {
    local url="$1"
    local target="$2"

    curl -fsSL "$url" -o "$target"
}

print_update_status_line() {
    local subtle remote_version

    subtle="$(secondary_color)"
    remote_version="$(remote_plugin_version)"

    if [ -z "$remote_version" ]; then
        echo "----GitHub: update check unavailable | color=$subtle"
    elif version_is_newer "$remote_version" "$PLUGIN_VERSION"; then
        echo "----GitHub: v${remote_version} available | color=$(healthy_color)"
    elif version_is_newer "$PLUGIN_VERSION" "$remote_version"; then
        echo "----GitHub: local version differs from main (v${remote_version}) | color=$(warning_color)"
    else
        echo "----GitHub: up to date (v${PLUGIN_VERSION}) | color=$subtle"
    fi
}

plugin_update_status_file() {
    printf '%s/plugin-update-status.tsv' "$DATA_DIR"
}

write_plugin_update_status() {
    local state="$1"
    local version="$2"
    local message="$3"

    mkdir -p "$DATA_DIR" 2>/dev/null || true
    printf '%s\t%s\t%s\t%s\n' \
        "$(sanitize_snapshot_field "$(flight_recorder_now)")" \
        "$(sanitize_snapshot_field "$state")" \
        "$(sanitize_snapshot_field "$version")" \
        "$(sanitize_snapshot_field "$message")" >"$(plugin_update_status_file)"
}

refresh_plugin_menu() {
    if command_exists open; then
        open -g "swiftbar://refreshplugin?plugin=$(basename "$PLUGIN_PATH")" >/dev/null 2>&1 || true
    fi
}

notify_update_result() {
    local title="$1"
    local message="$2"

    if command_exists osascript; then
        osascript -e "display notification \"${message//\"/\\\"}\" with title \"${title//\"/\\\"}\"" >/dev/null 2>&1 || true
    fi
}

print_plugin_update_notice() {
    local file now status_time status version message age label

    file="$(plugin_update_status_file)"
    [ -f "$file" ] || return 0

    IFS=$'\t' read -r status_time status version message <"$file" || return 0
    case "$status_time" in
        ''|*[!0-9]*) return 0 ;;
    esac

    now="$(flight_recorder_now)"
    age=$((now - status_time))
    [ "$age" -lt "$UPDATE_STATUS_TTL_SECONDS" ] || return 0

    if [ "$age" -lt 60 ]; then
        label="just now"
    else
        label="$((age / 60))m ago"
    fi

    case "$status" in
        success)
            echo "--Update: ${message} (${label}) | color=$(healthy_color)"
            ;;
        pending)
            echo "--Update: ${message} | color=$(warning_color)"
            ;;
        *)
            echo "--Update: ${message} (${label}) | color=$(critical_color)"
            ;;
    esac
}

flight_recorder_file() {
    printf '%s/flight-recorder.tsv' "$CACHE_DIR"
}

flight_recorder_now() {
    if [ -n "${SM_TEST_NOW:-}" ]; then
        printf '%s' "$SM_TEST_NOW"
    else
        date +%s
    fi
}

sanitize_snapshot_field() {
    local cleaned

    cleaned="$(printf '%s' "${1:-unknown}" | tr '\t\r\n' '   ' | sed -e 's/[[:space:]][[:space:]]*/ /g' -e 's/^ //' -e 's/ $//')"
    if [ -n "$cleaned" ]; then
        printf '%s' "$cleaned"
    else
        printf 'unknown'
    fi
}

load_average() {
    uptime | awk -F'load averages?: ' '{print $2}' | awk '{print $1}' | tr ',' '.'
}

integer_part() {
    printf '%s' "$1" | awk -F. '{print $1}'
}

memory_compressed_gb() {
    local pages page_size
    pages="$(vm_stat 2>/dev/null | awk '/occupied by compressor/ {gsub(/\./, "", $5); print $5}')"
    page_size="$(pagesize 2>/dev/null || echo 16384)"

    if is_number "$pages" && is_number "$page_size"; then
        awk -v pages="$pages" -v page_size="$page_size" 'BEGIN { printf "%.1f", pages * page_size / 1073741824 }'
    else
        printf '?'
    fi
}

disk_available_human() {
    df -h / 2>/dev/null | awk 'NR==2 {print $4}' | sed -e 's/Gi$/ GB/' -e 's/Mi$/ MB/'
}

disk_available_gb() {
    df -g / 2>/dev/null | awk 'NR==2 {print $4}'
}

process_awk_helpers() {
    cat <<'AWK'
function join_fields(start_idx, end_idx,   i, value) {
    value = $(start_idx)
    for (i = start_idx + 1; i <= end_idx; i++) {
        value = value " " $i
    }
    return value
}

function app_name_from_cmd(cmd,   cmd_path, parts, name) {
    cmd_path = cmd
    sub(/[[:space:]]+-.*/, "", cmd_path)
    split(cmd_path, parts, "/")
    name = parts[length(parts)]
    if (length(name) > 40) name = substr(name, 1, 37) "..."
    return name
}
AWK
}

top_process_summary() {
    local sort_key="$1"
    local metric_index="$2"
    local awk_script summary

    awk_script="$(process_awk_helpers)
{
    metric = \$metric_index
    cmd = join_fields(11, NF)
    app_name = app_name_from_cmd(cmd)
    printf \"%s|%.1f\", app_name, metric
    exit
}"

    summary="$(printf '%s\n' "$PROCESS_SNAPSHOT" |
        tail -n +2 |
        sort -nrk "$sort_key" |
        awk -v metric_index="$metric_index" "$awk_script")"

    if [ -n "$summary" ]; then
        printf '%s' "$summary"
    else
        printf 'unknown|0.0'
    fi
}

hardware_name() {
    local model_name

    model_name="$(cached_command hardware "$HARDWARE_CACHE_TTL_SECONDS" /usr/sbin/system_profiler SPHardwareDataType | awk -F': ' '/Model Name/ {print $2; exit}')"
    if [ -n "$model_name" ]; then
        printf '%s' "$model_name"
    else
        sysctl -n hw.model 2>/dev/null || printf 'Mac'
    fi
}

macos_version() {
    sw_vers -productVersion 2>/dev/null || printf 'unknown'
}

memory_pressure_percent() {
    vm_stat 2>/dev/null | awk '
        /Pages active/ {gsub(/\./, "", $3); active = $3}
        /Pages wired down/ {gsub(/\./, "", $4); wired = $4}
        /Pages occupied by compressor/ {gsub(/\./, "", $5); compressed = $5}
        /Pages free/ {gsub(/\./, "", $3); free = $3}
        /Pages inactive/ {gsub(/\./, "", $3); inactive = $3}
        /Pages speculative/ {gsub(/\./, "", $3); speculative = $3}
        END {
            total = active + wired + compressed + free + inactive + speculative
            if (total > 0) printf "%.0f", ((active + wired + compressed) / total) * 100
        }'
}

human_rate() {
    awk -v bytes="${1:-0}" 'BEGIN {
        if (bytes >= 1048576) printf "%.1f MB/s", bytes / 1048576
        else if (bytes >= 1024) printf "%.0f KB/s", bytes / 1024
        else printf "%.0f B/s", bytes
    }'
}

network_rates() {
    local now totals in_bytes out_bytes cache_file prev_now prev_in prev_out elapsed in_rate out_rate

    mkdir -p "$CACHE_DIR" 2>/dev/null || true
    cache_file="$CACHE_DIR/network-counters"
    now="$(date +%s)"
    totals="$(netstat -ibn 2>/dev/null | awk '$1 !~ /^lo/ && $7 ~ /^[0-9]+$/ && $10 ~ /^[0-9]+$/ {inb += $7; outb += $10} END {printf "%s %s", inb + 0, outb + 0}')"
    in_bytes="${totals%% *}"
    out_bytes="${totals##* }"

    if [ -f "$cache_file" ]; then
        read -r prev_now prev_in prev_out <"$cache_file" || true
        elapsed=$((now - ${prev_now:-0}))
        if [ "$elapsed" -gt 0 ] && is_number "${prev_in:-}" && is_number "${prev_out:-}"; then
            in_rate=$(((in_bytes - prev_in) / elapsed))
            out_rate=$(((out_bytes - prev_out) / elapsed))
            [ "$in_rate" -lt 0 ] && in_rate=0
            [ "$out_rate" -lt 0 ] && out_rate=0
            printf '%s down, %s up' "$(human_rate "$in_rate")" "$(human_rate "$out_rate")"
        else
            printf 'warming up'
        fi
    else
        printf 'warming up'
    fi

    printf '%s %s %s\n' "$now" "$in_bytes" "$out_bytes" >"$cache_file"
}

wifi_profile_json() {
    cached_command wifi-profile 120 /usr/sbin/system_profiler SPAirPortDataType -json
}

wifi_interface_device() {
    networksetup -listallhardwareports 2>/dev/null |
        awk '
            /Hardware Port: Wi-Fi/ { found = 1; next }
            found && /Device:/ { print $2; exit }
        '
}

wifi_connected() {
    local device profile status

    device="$(wifi_interface_device)"
    [ -n "$device" ] || return 1
    profile="$(wifi_profile_json)"
    [ -n "$profile" ] || return 1

    status="$(printf '%s' "$profile" | jq -r --arg dev "$device" '.SPAirPortDataType[0].spairport_airport_interfaces[]? | select(._name == $dev) | .spairport_status_information // empty' 2>/dev/null)"
    [ "$status" = "spairport_status_connected" ]
}

wifi_ssid_label() {
    local device profile ssid

    device="$(wifi_interface_device)"
    [ -n "$device" ] || return 1
    profile="$(wifi_profile_json)"
    [ -n "$profile" ] || return 1

    ssid="$(printf '%s' "$profile" | jq -r --arg dev "$device" '.SPAirPortDataType[0].spairport_airport_interfaces[]? | select(._name == $dev) | .spairport_current_network_information._name // empty' 2>/dev/null)"
    case "$ssid" in
        ''|'<redacted>'|'<SSID Redacted>'|'SSID Redacted') printf 'SSID hidden by macOS' ;;
        *) printf '%s' "$ssid" ;;
    esac
}

wifi_detail_value() {
    local jq_filter="$1"
    local fallback="${2:-}"
    local device profile value

    device="$(wifi_interface_device)"
    [ -n "$device" ] || { printf '%s' "$fallback"; return 0; }
    profile="$(wifi_profile_json)"
    [ -n "$profile" ] || { printf '%s' "$fallback"; return 0; }

    value="$(printf '%s' "$profile" | jq -r --arg dev "$device" "$jq_filter" 2>/dev/null)"
    case "$value" in
        ''|'null') printf '%s' "$fallback" ;;
        *) printf '%s' "$value" ;;
    esac
}

wifi_security_label() {
    case "$1" in
        spairport_security_mode_none) printf 'Open' ;;
        spairport_security_mode_wpa2_personal) printf 'WPA2 Personal' ;;
        spairport_security_mode_wpa3_personal) printf 'WPA3 Personal' ;;
        spairport_security_mode_wpa3_transition) printf 'WPA3 Transition' ;;
        *) printf '%s' "$1" ;;
    esac
}

wifi_network_type_label() {
    case "$1" in
        spairport_network_type_station) printf 'Infrastructure' ;;
        spairport_network_type_ibss) printf 'Ad hoc' ;;
        spairport_network_type_auto) printf 'Auto' ;;
        *) printf '%s' "$1" ;;
    esac
}

wifi_current_details() {
    local ssid channel security signal rate phy_mode network_type router ip_addr device profile

    device="$(wifi_interface_device)"
    [ -n "$device" ] || return 1
    profile="$(wifi_profile_json)"
    [ -n "$profile" ] || return 1

    ssid="$(printf '%s' "$profile" | jq -r --arg dev "$device" '.SPAirPortDataType[0].spairport_airport_interfaces[]? | select(._name == $dev) | .spairport_current_network_information._name // empty' 2>/dev/null)"
    channel="$(printf '%s' "$profile" | jq -r --arg dev "$device" '.SPAirPortDataType[0].spairport_airport_interfaces[]? | select(._name == $dev) | .spairport_current_network_information.spairport_network_channel // empty' 2>/dev/null)"
    security="$(printf '%s' "$profile" | jq -r --arg dev "$device" '.SPAirPortDataType[0].spairport_airport_interfaces[]? | select(._name == $dev) | .spairport_current_network_information.spairport_security_mode // empty' 2>/dev/null)"
    signal="$(printf '%s' "$profile" | jq -r --arg dev "$device" '.SPAirPortDataType[0].spairport_airport_interfaces[]? | select(._name == $dev) | .spairport_current_network_information.spairport_signal_noise // empty' 2>/dev/null)"
    rate="$(printf '%s' "$profile" | jq -r --arg dev "$device" '.SPAirPortDataType[0].spairport_airport_interfaces[]? | select(._name == $dev) | .spairport_current_network_information.spairport_network_rate // empty' 2>/dev/null)"
    phy_mode="$(printf '%s' "$profile" | jq -r --arg dev "$device" '.SPAirPortDataType[0].spairport_airport_interfaces[]? | select(._name == $dev) | .spairport_current_network_information.spairport_network_phymode // empty' 2>/dev/null)"
    network_type="$(printf '%s' "$profile" | jq -r --arg dev "$device" '.SPAirPortDataType[0].spairport_airport_interfaces[]? | select(._name == $dev) | .spairport_current_network_information.spairport_network_type // empty' 2>/dev/null)"

    ip_addr="$(ifconfig "$device" 2>/dev/null | awk '/inet / && $2 != "127.0.0.1" {print $2; exit}')"
    router="$(ipconfig getsummary "$device" 2>/dev/null | awk -F' : ' '/Router/ {print $2; exit}')"

    case "$ssid" in
        ''|'<redacted>'|'<SSID Redacted>'|'SSID Redacted') ssid="SSID hidden by macOS" ;;
    esac
    [ -n "$channel" ] || channel="Unknown channel"
    [ -n "$signal" ] || signal="Signal unavailable"
    [ -n "$rate" ] || rate="?"
    [ -n "$phy_mode" ] || phy_mode="Unknown"
    network_type="$(wifi_network_type_label "$network_type")"
    [ -n "$network_type" ] || network_type="Unknown"
    [ -n "$ip_addr" ] || ip_addr="Unknown"
    [ -n "$router" ] || router="Unknown"

    printf '%s|%s|%s|%s|%s|%s|%s|%s' \
        "$ssid" \
        "$channel" \
        "$(wifi_security_label "$security")" \
        "$signal" \
        "$rate" \
        "$phy_mode" \
        "$network_type" \
        "$ip_addr|$router"
}

vpn_services() {
    scutil --nc list 2>/dev/null | perl -ne 'if (/\((Connected|Disconnected)\).*"([^"]+)".*\[VPN:([^\]]+)\]/) { print "$1|$2|$3\n" }'
}

vpn_summary() {
    local status name connected configured line

    connected=""
    configured=""

    while IFS='|' read -r status name _; do
        [ -n "$name" ] || continue
        configured="${configured}${configured:+, }$name"
        if [ "$status" = "Connected" ]; then
            connected="${connected}${connected:+, }$name"
        fi
    done <<EOF
$(vpn_services)
EOF

    if [ -n "$connected" ]; then
        printf '%s connected' "$connected"
    elif [ -n "$configured" ]; then
        printf 'none active (%s)' "$configured"
    else
        printf 'not available'
    fi
}

high_cpu_count() {
    printf '%s\n' "$PROCESS_SNAPSHOT" | awk -v threshold="$HIGH_CPU_THRESHOLD" 'NR > 1 && $3 > threshold { count++ } END { print count + 0 }'
}

valid_flight_history() {
    local file="${1:-$(flight_recorder_file)}"

    [ -f "$file" ] || return 0
    awk -F '\t' 'NF >= 12 && $1 ~ /^[0-9]+$/ { print }' "$file"
}

prune_flight_history() {
    local file now cutoff tmp

    file="$(flight_recorder_file)"
    [ -f "$file" ] || return 0

    now="$(flight_recorder_now)"
    cutoff=$((now - FLIGHT_RECORDER_WINDOW_SECONDS))
    tmp="$file.tmp"

    valid_flight_history "$file" |
        awk -F '\t' -v cutoff="$cutoff" '$1 >= cutoff { print }' |
        tail -n "$FLIGHT_RECORDER_MAX_ROWS" >"$tmp"
    mv "$tmp" "$file"
}

record_flight_snapshot() {
    local state="$1"
    local issue="$2"
    local load1="$3"
    local high_cpu="$4"
    local disk_gb="$5"
    local batt_pct="$6"
    local now mem_pressure top_cpu top_mem top_cpu_app top_cpu_pct top_mem_app top_mem_pct file

    mkdir -p "$CACHE_DIR" 2>/dev/null || true
    file="$(flight_recorder_file)"
    now="$(flight_recorder_now)"
    mem_pressure="$(memory_pressure_percent)"
    top_cpu="$(top_process_summary "3" "3")"
    top_mem="$(top_process_summary "4" "4")"
    top_cpu_app="${top_cpu%%|*}"
    top_cpu_pct="${top_cpu##*|}"
    top_mem_app="${top_mem%%|*}"
    top_mem_pct="${top_mem##*|}"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$(sanitize_snapshot_field "$now")" \
        "$(sanitize_snapshot_field "$state")" \
        "$(sanitize_snapshot_field "$issue")" \
        "$(sanitize_snapshot_field "$load1")" \
        "$(sanitize_snapshot_field "$high_cpu")" \
        "$(sanitize_snapshot_field "$mem_pressure")" \
        "$(sanitize_snapshot_field "$disk_gb")" \
        "$(sanitize_snapshot_field "$batt_pct")" \
        "$(sanitize_snapshot_field "$top_cpu_app")" \
        "$(sanitize_snapshot_field "$top_cpu_pct")" \
        "$(sanitize_snapshot_field "$top_mem_app")" \
        "$(sanitize_snapshot_field "$top_mem_pct")" >>"$file"

    prune_flight_history
}

flight_checkpoint_rows() {
    local file="${1:-$(flight_recorder_file)}"
    local now="${2:-$(flight_recorder_now)}"

    [ -f "$file" ] || return 0

    valid_flight_history "$file" | awk -F '\t' -v now="$now" '
        function keep(target, label,   age, diff) {
            age = now - $1
            if (age < target) return

            diff = age - target
            if (!(label in best_diff) || diff < best_diff[label]) {
                best_diff[label] = diff
                best[label] = $0
            }
        }
        {
            latest = $0
            keep(60, "1m ago")
            keep(300, "5m ago")
            keep(900, "15m ago")
        }
        END {
            if (latest != "") print "now\t" latest
            if (best["1m ago"] != "" && best["1m ago"] != latest) print "1m ago\t" best["1m ago"]
            if (best["5m ago"] != "" && best["5m ago"] != latest && best["5m ago"] != best["1m ago"]) print "5m ago\t" best["5m ago"]
            if (best["15m ago"] != "" && best["15m ago"] != latest && best["15m ago"] != best["1m ago"] && best["15m ago"] != best["5m ago"]) print "15m ago\t" best["15m ago"]
        }'
}

detect_incident_cause() {
    local file="${1:-$(flight_recorder_file)}"

    [ -f "$file" ] || { printf 'Learning recent activity. First cause after the next refresh.'; return 0; }

    flight_checkpoint_rows "$file" | awk -F '\t' -v high_cpu="$HIGH_CPU_THRESHOLD" -v load_warn="$LOAD_WARN" -v low_disk_warn="$LOW_DISK_WARN_GB" '
        function num(value) { return value ~ /^-?[0-9]+([.][0-9]+)?$/ }
        function is_spotlight(app, app_lc) {
            app_lc = tolower(app)
            return app_lc ~ /(mds|mdworker|corespotlight|spotlight)/
        }
        function set_best(score, message) {
            if (score > best_score) {
                best_score = score
                best_message = message
            }
        }
        {
            if ($1 == "now") {
                last_ts = $2; last_state = $3; last_issue = $4; last_load = $5; last_mem = $7; last_disk = $8; last_cpu_app = $10; last_cpu_pct = $11
                next
            }

            first_ts = $2; first_state = $3; first_issue = $4; first_load = $5; first_mem = $7; first_disk = $8; first_cpu_app = $10; first_cpu_pct = $11
        }
        END {
            if (!last_ts || !first_ts) {
                print "Learning recent activity. First cause after the next refresh."
                exit
            }

            minutes = int((last_ts - first_ts) / 60)
            if (minutes < 1) minutes = 1
            cpu_delta = 0
            mem_delta = 0
            disk_drop = 0
            load_delta = 0

            if (num(first_cpu_pct) && num(last_cpu_pct)) cpu_delta = last_cpu_pct - first_cpu_pct
            if (num(first_mem) && num(last_mem)) mem_delta = last_mem - first_mem
            if (num(first_disk) && num(last_disk)) disk_drop = first_disk - last_disk
            if (num(first_load) && num(last_load)) load_delta = last_load - first_load

            if (is_spotlight(last_cpu_app) && num(last_cpu_pct) && (last_cpu_pct >= 40 || load_delta >= 2 || last_state != "healthy")) {
                set_best(260 + last_cpu_pct, sprintf("Spotlight indexing is now driving load (%s %.1f%% CPU) in %dm", last_cpu_app, last_cpu_pct, minutes))
            }

            if (!is_spotlight(last_cpu_app) && num(last_cpu_pct) && (last_cpu_pct >= high_cpu || cpu_delta >= 40 || (last_state == "critical" && last_cpu_pct >= 60))) {
                if (first_cpu_app == last_cpu_app && num(first_cpu_pct)) {
                    set_best(220 + cpu_delta, sprintf("%s jumped from %.1f%% to %.1f%% CPU in %dm", last_cpu_app, first_cpu_pct, last_cpu_pct, minutes))
                } else {
                    set_best(200 + last_cpu_pct + cpu_delta, sprintf("%s is now top CPU at %.1f%% after %s in %dm", last_cpu_app, last_cpu_pct, first_cpu_app, minutes))
                }
            }

            if (mem_delta >= 15 && num(last_mem) && last_mem >= 70) {
                set_best(170 + mem_delta, sprintf("Memory pressure rose from %.0f%% to %.0f%% in %dm", first_mem, last_mem, minutes))
            }

            if (disk_drop >= 4 || (num(last_disk) && last_disk < low_disk_warn && disk_drop >= 2)) {
                set_best(150 + disk_drop, sprintf("Disk free dropped by %.1fGB in %dm", disk_drop, minutes))
            }

            if (load_delta >= load_warn) {
                set_best(120 + load_delta, sprintf("Load rose from %.1f to %.1f in %dm", first_load, last_load, minutes))
            }

            if (first_state == "healthy" && last_state != "healthy") {
                set_best(80, sprintf("Health changed from healthy to %s: %s", last_state, last_issue))
            }

            if (best_message != "") printf "%s", best_message
            else printf "No clear change in the last %dm. Watching for a stronger trend.", minutes
        }'
}

battery_line() {
    pmset -g batt 2>/dev/null | grep -E 'InternalBattery|Battery Power|AC Power' | tail -1
}

battery_percent() {
    battery_line | grep -Eo '[0-9]+%' | head -1 | tr -d '%'
}

battery_state() {
    battery_line | grep -Eo 'discharging|charging|charged' | head -1
}

battery_remaining() {
    battery_line | grep -Eo '[0-9]+:[0-9]+ remaining' | head -1 | sed 's/ remaining//'
}

cpu_temperature() {
    if command_exists osx-cpu-temp; then
        osx-cpu-temp -c 2>/dev/null | grep -Eo '[0-9.]+' | head -1
    fi
}

top_issue() {
    local load_int="$1"
    local high_cpu="$2"
    local disk_gb="$3"
    local battery_pct="$4"
    local temp="$5"
    local temp_int

    temp_int="$(integer_part "$temp")"

    if [ "$high_cpu" -gt 0 ]; then
        printf 'Busy app using too much CPU'
    elif [ "$load_int" -ge "$LOAD_CRIT" ]; then
        printf 'System load is very high'
    elif is_number "$disk_gb" && [ "$disk_gb" -lt "$LOW_DISK_WARN_GB" ]; then
        printf 'Low disk space'
    elif is_number "$battery_pct" && [ "$battery_pct" -lt 20 ]; then
        printf 'Low battery'
    elif is_number "$temp_int" && [ "$temp_int" -gt 85 ]; then
        printf 'CPU temperature is high'
    elif [ "$load_int" -ge "$LOAD_WARN" ]; then
        printf 'System load is rising'
    else
        printf 'No urgent issue'
    fi
}

health_state() {
    local load_int="$1"
    local high_cpu="$2"
    local disk_gb="$3"
    local battery_pct="$4"
    local temp="$5"
    local temp_int

    temp_int="$(integer_part "$temp")"

    if [ "$high_cpu" -gt 0 ] || [ "$load_int" -ge "$LOAD_CRIT" ]; then
        printf 'critical'
    elif is_number "$temp_int" && [ "$temp_int" -gt 85 ]; then
        printf 'critical'
    elif is_number "$disk_gb" && [ "$disk_gb" -lt "$LOW_DISK_WARN_GB" ]; then
        printf 'warning'
    elif is_number "$battery_pct" && [ "$battery_pct" -lt 20 ]; then
        printf 'warning'
    elif [ "$load_int" -ge "$LOAD_WARN" ]; then
        printf 'warning'
    else
        printf 'healthy'
    fi
}

state_icon() {
    case "$1" in
        critical) printf '🔥' ;;
        warning) printf '⚡' ;;
        *) printf '✅' ;;
    esac
}

state_color() {
    case "$1" in
        critical) critical_color ;;
        warning) warning_color ;;
        *) healthy_color ;;
    esac
}

menu_animation_frame() {
    local frame_index

    frame_index=$(( ($(flight_recorder_now) / 5) % 6 ))

    case "$frame_index" in
        0) printf '·' ;;
        1) printf '◦' ;;
        2) printf '○' ;;
        3) printf '◉' ;;
        4) printf '○' ;;
        *) printf '◦' ;;
    esac
}

menu_title() {
    local state="$1"
    local load="$2"
    local high_cpu="$3"
    local icon

    icon="$(state_icon "$state")"

    if [ "$high_cpu" -gt 0 ]; then
        printf '%s %s' "$icon" "$high_cpu"
    elif [ "$state" = "healthy" ]; then
        if is_true "$ANIMATE_TITLE"; then
            menu_animation_frame
        else
            printf 'SM'
        fi
    else
        printf '%s %.1f' "$icon" "$load"
    fi
}

truncate_label() {
    local value="$1"
    local max="${2:-40}"

    if [ "${#value}" -gt "$max" ]; then
        printf '%s...' "${value:0:$((max - 3))}"
    else
        printf '%s' "$value"
    fi
}

print_process_list() {
    local title="$1"
    local sort_key="$2"
    local metric_label="$3"
    local metric_index="$4"
    local indent="${5:---}"
    local awk_script

    echo "$title"
    awk_script="$(process_awk_helpers)
{
    pid = \$2
    metric = \$metric_index
    cmd = join_fields(11, NF)
    app_name = app_name_from_cmd(cmd)

    printf \"%s%s (%s %.1f%%) | font=Menlo size=11\\n\", indent, app_name, metric_label, metric
    printf \"%s--PID: %s | font=Menlo size=10 color=gray\\n\", indent, pid
}"
    printf '%s\n' "$PROCESS_SNAPSHOT" |
        tail -n +2 |
        sort -nrk "$sort_key" |
        head -6 |
        awk -v metric_index="$metric_index" -v metric_label="$metric_label" -v indent="$indent" "$awk_script"
}

print_high_cpu_processes() {
    local awk_script

    echo "Busy Apps"
    awk_script="$(process_awk_helpers)
NR > 1 && \$3 > threshold {
    user = \$1
    pid = \$2
    cpu = \$3
    cmd = join_fields(11, NF)
    app_name = app_name_from_cmd(cmd)

    printf \"--%s (%.1f%%) | color=red font=Menlo size=11\\n\", app_name, cpu
    printf \"----PID: %s | font=Menlo size=10 color=gray\\n\", pid
    if (user == current_user) {
        printf \"----Process Actions\\n\"
        printf \"------Stop Process | bash=\\\"/bin/kill\\\" param1=\\\"%s\\\" terminal=false refresh=true color=red\\n\", pid
        printf \"------Potentially Disruptive\\n\"
        printf \"--------Force Kill (Immediate) | bash=\\\"/bin/kill\\\" param1=\\\"-9\\\" param2=\\\"%s\\\" terminal=true refresh=true color=red\\n\", pid
    } else {
        printf \"----Protected system process | color=gray\\n\"
        printf \"----Open Activity Monitor | bash=\\\"%s\\\" param1=\\\"open-activity-monitor\\\" terminal=false\\n\", plugin_path
    }
    found = 1
}
END {
    if (!found) {
        printf \"--No busy apps detected | color=green\\n\"
    }
}"
    printf '%s\n' "$PROCESS_SNAPSHOT" |
        awk -v threshold="$HIGH_CPU_THRESHOLD" -v plugin_path="$PLUGIN_PATH" -v current_user="$USER" "$awk_script"
}

health_label() {
    case "$1" in
        critical) printf 'Critical' ;;
        warning) printf 'Needs attention' ;;
        *) printf 'Good' ;;
    esac
}

print_mac_health_summary() {
    local state="$1"
    local issue="$2"
    local color="$3"
    local model_name os_version uptime_info subtle

    model_name="$(hardware_name)"
    os_version="$(macos_version)"
    uptime_info="$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')"
    subtle="$(secondary_color)"

    echo "Mac Health: $(health_label "$state") | color=$color"
    echo "--${model_name} · macOS ${os_version} | color=$subtle"
    echo "--Uptime: ${uptime_info} | color=$subtle"
    echo "--Current issue: ${issue} | color=$color"
}

print_recommendation() {
    local load_int="$1"
    local high_cpu="$2"
    local disk_gb="$3"
    local battery_pct="$4"
    local temp="$5"
    local temp_int

    temp_int="$(integer_part "$temp")"

    echo "---"
    echo "Today's Recommendation"
    if [ "$high_cpu" -gt 0 ]; then
        echo "--Stop one confirmed busy app below | color=red"
        echo "----Open Activity Monitor | bash=\"$PLUGIN_PATH\" param1=\"open-activity-monitor\" terminal=false"
    elif [ "$load_int" -ge "$LOAD_CRIT" ]; then
        echo "--Check CPU before killing anything | color=red"
        echo "----Open Activity Monitor | bash=\"$PLUGIN_PATH\" param1=\"open-activity-monitor\" terminal=false"
    elif is_number "$disk_gb" && [ "$disk_gb" -lt "$LOW_DISK_WARN_GB" ]; then
        echo "--Free disk space | color=orange"
        echo "----Empty Trash | bash=\"$PLUGIN_PATH\" param1=\"empty-trash\" terminal=false refresh=true"
    elif is_number "$battery_pct" && [ "$battery_pct" -lt 20 ]; then
        echo "--Connect power soon | color=orange"
    elif is_number "$temp_int" && [ "$temp_int" -gt 85 ]; then
        echo "--Let the Mac cool down | color=red"
        echo "----Open Activity Monitor | bash=\"$PLUGIN_PATH\" param1=\"open-activity-monitor\" terminal=false"
    elif [ "$load_int" -ge "$LOAD_WARN" ]; then
        echo "--Watch the trend | color=orange"
        echo "----Open Activity Monitor | bash=\"$PLUGIN_PATH\" param1=\"open-activity-monitor\" terminal=false"
    else
        echo "--No urgent action | color=green"
    fi
}

print_flight_checkpoints() {
    local lines subtle checkpoint_count

    subtle="$(secondary_color)"
    lines="$(flight_checkpoint_rows)"

    if [ -z "$lines" ]; then
        echo "--Recent activity | color=$subtle"
        echo "----Confidence improves over 15 minutes | color=$subtle"
        return 0
    fi

    checkpoint_count="$(printf '%s\n' "$lines" | awk 'END { print NR + 0 }')"

    echo "--Recent activity | color=$subtle"
    printf '%s\n' "$lines" |
        awk -F '\t' -v subtle="$subtle" '{
            printf "----%s: %s, load %s, CPU %s %.1f%% | font=Menlo size=11 color=%s\n", $1, $3, $5, $10, $11, subtle
        }'

    if [ "$checkpoint_count" -lt 4 ]; then
        echo "----Confidence improves over 15 minutes | color=$subtle"
    fi
}

print_next_step() {
    local load_int="$1"
    local high_cpu="$2"
    local disk_gb="$3"
    local battery_pct="$4"
    local temp="$5"
    local temp_int

    temp_int="$(integer_part "$temp")"

    if [ "$high_cpu" -gt 0 ] || [ "$load_int" -ge "$LOAD_CRIT" ]; then
        echo "--Next step: Open Activity Monitor | bash=\"$PLUGIN_PATH\" param1=\"open-activity-monitor\" terminal=false"
    elif is_number "$temp_int" && [ "$temp_int" -gt 85 ]; then
        echo "--Next step: Open Activity Monitor | bash=\"$PLUGIN_PATH\" param1=\"open-activity-monitor\" terminal=false"
    elif is_number "$disk_gb" && [ "$disk_gb" -lt "$LOW_DISK_WARN_GB" ]; then
        echo "--Next step: Review disk usage and free space | color=$(warning_color)"
    elif is_number "$battery_pct" && [ "$battery_pct" -lt 20 ]; then
        echo "--Next step: Connect power soon | color=$(warning_color)"
    elif [ "$load_int" -ge "$LOAD_WARN" ]; then
        echo "--Next step: Monitor CPU trend | bash=\"$PLUGIN_PATH\" param1=\"open-activity-monitor\" terminal=false"
    else
        echo "--Next step: No urgent action | color=$(healthy_color)"
    fi
}

print_alert_rules() {
    local subtle

    subtle="$(secondary_color)"

    echo "--How alerts work | color=$subtle"
    echo "----Busy app: >=${HIGH_CPU_THRESHOLD}% CPU | color=$subtle"
    echo "----Load: warning >=${LOAD_WARN}, critical >=${LOAD_CRIT} | color=$subtle"
    echo "----Disk: warning <${LOW_DISK_WARN_GB}GB free | color=$subtle"
    echo "----Battery: warning <20% | color=$subtle"
    echo "----Temperature: critical >85°C | color=$subtle"
}

print_triage_summary() {
    local state="$1"
    local issue="$2"
    local color="$3"
    local load_int="$4"
    local high_cpu="$5"
    local disk_gb="$6"
    local battery_pct="$7"
    local temp="$8"
    local cause

    cause="$(detect_incident_cause)"

    echo "---"
    echo "Triage"
    echo "--Status: $(health_label "$state") - ${issue} | color=$color"
    echo "--Likely cause: ${cause}"
    print_next_step "$load_int" "$high_cpu" "$disk_gb" "$battery_pct" "$temp"
    echo "--Copy Incident Report | bash=\"$PLUGIN_PATH\" param1=\"diagnostic\" terminal=false refresh=false"
    print_alert_rules
    print_flight_checkpoints
}

print_flight_report() {
    local now lines

    now="$(flight_recorder_now)"
    lines="$(valid_flight_history | tail -10)"

    echo
    echo "Flight Recorder:"
    echo "Detected cause: $(detect_incident_cause)"

    if [ -z "$lines" ]; then
        echo "History: learning recent activity"
        return 0
    fi

    echo "Recent snapshots:"
    printf '%s\n' "$lines" |
        awk -F '\t' -v now="$now" '{
            age = now - $1
            if (age < 60) label = "now"
            else label = int(age / 60) "m ago"

            printf "  - %s | %s | load %s | mem %s%% | disk %sGB | CPU %s %.1f%%\n", label, $2, $4, $6, $7, $9, $10
        }'
}

print_resource_overview() {
    local load1="$1"
    local high_cpu="$2"
    local mem_gb="$3"
    local disk_human="$4"
    local disk_gb="$5"
    local batt_pct="$6"
    local temp="$7"
    local mem_pressure batt_state batt_remaining net_rates disk_color batt_color temp_int wifi_details wifi_ssid wifi_channel wifi_security wifi_signal wifi_rate wifi_mode wifi_type wifi_ip wifi_router vpn_state subtle

    mem_pressure="$(memory_pressure_percent)"
    batt_state="$(battery_state)"
    batt_remaining="$(battery_remaining)"
    net_rates="$(network_rates)"
    wifi_details="$(wifi_current_details 2>/dev/null || true)"
    IFS='|' read -r wifi_ssid wifi_channel wifi_security wifi_signal wifi_rate wifi_mode wifi_type wifi_endpoint <<EOF
$wifi_details
EOF
    wifi_ip="${wifi_endpoint%%|*}"
    wifi_router="${wifi_endpoint##*|}"
    vpn_state="$(vpn_summary)"
    subtle="$(secondary_color)"
    temp_int="$(integer_part "$temp")"

    echo "---"
    echo "CPU"
    echo "--Load: ${load1}"
    echo "--Busy apps: ${high_cpu}"
    if is_number "$temp_int" && [ "$temp_int" -gt 0 ]; then
        echo "--Temperature: ${temp}°C"
    else
        echo "--Temperature: Not available | color=$subtle"
    fi
    echo "--Open Activity Monitor | bash=\"$PLUGIN_PATH\" param1=\"open-activity-monitor\" terminal=false"

    echo "---"
    echo "Memory"
    if is_number "$mem_pressure"; then
        echo "--Pressure: ${mem_pressure}%"
    else
        echo "--Pressure: Not available | color=$subtle"
    fi
    echo "--Compressed: ${mem_gb}GB"

    echo "---"
    echo "Disk"
    disk_color="green"
    if is_number "$disk_gb" && [ "$disk_gb" -lt "$LOW_DISK_WARN_GB" ]; then
        disk_color="orange"
    fi
    echo "--Free: ${disk_human} | color=$disk_color"

    echo "---"
    echo "Battery"
    if is_number "$batt_pct"; then
        batt_color="green"
        [ "$batt_pct" -lt 50 ] && batt_color="orange"
        [ "$batt_pct" -lt 20 ] && batt_color="red"
        echo "--Charge: ${batt_pct}% ${batt_state} | color=$batt_color"
        [ -n "$batt_remaining" ] && echo "--Remaining: ${batt_remaining}"
    else
        echo "--Desktop power | color=$subtle"
    fi

    echo "---"
    echo "Network"
    if wifi_connected; then
        echo "--Wi-Fi: connected"
        echo "----SSID: ${wifi_ssid}"
        echo "----Channel: ${wifi_channel}"
        echo "----Security: ${wifi_security}"
        echo "----Signal: ${wifi_signal}"
        echo "----Rate: ${wifi_rate} Mbps"
        echo "----Mode: ${wifi_mode}"
        echo "----Type: ${wifi_type}"
        echo "----IP: ${wifi_ip}"
        echo "----Router: ${wifi_router}"
    else
        echo "--Wi-Fi: not connected | color=$subtle"
    fi
    echo "--VPN: ${vpn_state}"
    echo "--Throughput: ${net_rates}"
    echo "--Open Speed Test | bash=\"/usr/bin/open\" param1=\"https://fast.com\" terminal=false"

    echo "---"
    echo "Devices"
    if is_true "$SHOW_DEVICES"; then
        echo "--Full device details below"
    else
        echo "--Details off for speed | color=$subtle"
    fi
}

print_energy_impact() {
    local status
    local awk_script
    status="$(battery_state)"

    if [ "$status" = "discharging" ] && is_true "$SHOW_ENERGY"; then
        echo "---"
        echo "Energy Impact (Top 5)"
        awk_script="$(process_awk_helpers)
NR > 1 {
    pid = \$1
    power = \$NF
    cmd = join_fields(2, NF - 1)
    app_name = app_name_from_cmd(cmd)

    power_int = int(power)
    if (power_int > 50) color = \"red\"
    else if (power_int > 20) color = \"orange\"
    else if (power_int > 5) color = \"yellow\"
    else color = \"green\"

    printf \"--%s (%.1f) | font=Menlo size=11 color=%s\\n\", app_name, power, color
    printf \"----PID: %s | font=Menlo size=10 color=gray\\n\", pid
    printf \"----Open Activity Monitor | bash=\\\"%s\\\" param1=\\\"open-activity-monitor\\\" terminal=false\\n\", plugin_path
}"
        top -l 2 -o power -stats pid,command,power -n 6 2>/dev/null |
            tail -6 |
        awk -v plugin_path="$PLUGIN_PATH" "$awk_script"
    fi
}

print_health_section() {
    local temp temp_int batt_pct batt_state batt_remaining fan_speed uptime_info subtle

    subtle="$(secondary_color)"

    echo "Health"

    temp="$(cpu_temperature)"
    temp_int="$(integer_part "$temp")"
    if is_number "$temp_int" && [ "$temp_int" -gt 0 ]; then
        if [ "$temp_int" -gt 85 ]; then
            echo "--CPU Temp: ${temp}°C | color=red"
        elif [ "$temp_int" -gt 70 ]; then
            echo "--CPU Temp: ${temp}°C | color=orange"
        else
            echo "--CPU Temp: ${temp}°C | color=green"
        fi
    else
        echo "--CPU Temp: Not available | color=$subtle"
    fi

    batt_pct="$(battery_percent)"
    batt_state="$(battery_state)"
    batt_remaining="$(battery_remaining)"
    if is_number "$batt_pct"; then
        if [ "$batt_state" = "charging" ]; then
            echo "--Battery: ${batt_pct}% (Charging)"
        elif [ "$batt_state" = "charged" ]; then
            echo "--Battery: ${batt_pct}% (Charged)"
        elif [ -n "$batt_remaining" ]; then
            echo "--Battery: ${batt_pct}% (${batt_remaining} left)"
        elif [ "$batt_pct" -lt 20 ]; then
            echo "--Battery: ${batt_pct}% | color=red"
        elif [ "$batt_pct" -lt 50 ]; then
            echo "--Battery: ${batt_pct}% | color=orange"
        else
            echo "--Battery: ${batt_pct}% | color=green"
        fi
    else
        echo "--Battery: Desktop (No battery) | color=$subtle"
    fi

    if command_exists istats; then
        fan_speed="$(istats fan speed 2>/dev/null | grep -Eo '[0-9]+ RPM' | head -1)"
        [ -n "$fan_speed" ] && echo "--Fan: $fan_speed | color=$subtle"
    fi

    uptime_info="$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')"
    echo "--Uptime: $uptime_info | color=$subtle"
}

print_devices_section() {
    local displays display_lines usb_devices bt_devices network_list device battery_pct battery_color ip_addr subtle

    is_true "$SHOW_DEVICES" || return 0

    subtle="$(secondary_color)"

    echo "---"
    echo "Devices"
    echo "--Displays:"

    displays="$(cached_command displays "$SLOW_CACHE_TTL_SECONDS" /usr/sbin/system_profiler SPDisplaysDataType)"
    display_lines="$(printf '%s\n' "$displays" | awk '
        /^[[:space:]]+[A-Za-z].*:$/ && !/Displays:|GPU|Chipset|Type:|Bus:|Cores:|Vendor:|Metal|Mirror:|Online:|Rotation:|Automatically|Connection Type:|UI Looks/ {
            display_name = $0
            gsub(/^[[:space:]]+/, "", display_name)
            gsub(/:$/, "", display_name)
            getline
            if (/Resolution:/) {
                resolution = $0
                gsub(/^[[:space:]]+Resolution:[[:space:]]*/, "", resolution)
                is_builtin = 0
                while (getline > 0) {
                    if (/Connection Type: Internal/ || /Display Type:.*Built-in/) is_builtin = 1
                    if (/^[[:space:]]+[A-Za-z].*:$/ && !/Mirror:|Online:|Rotation:|Automatically|Connection Type:|UI Looks|Main Display/) break
                }
                type = is_builtin ? "Built-in" : "External"
                printf "----%s (%s): %s | font=Menlo size=10\n", display_name, type, resolution
            }
        }')"
    if [ -n "$display_lines" ]; then
        printf '%s\n' "$display_lines"
    else
        echo "----No display details available | font=Menlo size=10 color=$subtle"
    fi

    echo "--USB Devices:"
    usb_devices="$(cached_command usb "$SLOW_CACHE_TTL_SECONDS" /usr/sbin/system_profiler SPUSBDataType |
        grep -v 'Apple\|Bluetooth\|Hub\|Host Controller' |
        grep 'Product ID:' -B 1 |
        grep -v 'Product ID\|--' |
        sed 's/^[[:space:]]*//' |
        head -5)"

    if [ -n "$usb_devices" ]; then
        printf '%s\n' "$usb_devices" | while IFS= read -r device; do
            echo "----${device} | font=Menlo size=10"
        done
    else
        echo "----None detected | font=Menlo size=10 color=$subtle"
    fi

    echo "--Bluetooth:"
    bt_devices="$(cached_command bluetooth "$SLOW_CACHE_TTL_SECONDS" /usr/sbin/system_profiler SPBluetoothDataType |
        awk '
            /^[[:space:]]+Connected:[[:space:]]*$/ { in_connected = 1; next }
            /^[[:space:]]+Not Connected:[[:space:]]*$/ { in_connected = 0; next }
            in_connected && /^[[:space:]]+[A-Za-z0-9]/ && /:$/ {
                gsub(/^[[:space:]]+/, "")
                gsub(/:$/, "")
                print
            }' |
        head -5)"

    if [ -n "$bt_devices" ]; then
        printf '%s\n' "$bt_devices" | while IFS= read -r device; do
            battery_pct="$(ioreg -r -l 2>/dev/null | grep -A 20 "\"$device\"" | grep -Ei 'BatteryPercent|batterylevel' | head -1 | grep -Eo '[0-9]+' | head -1)"
            if is_number "$battery_pct"; then
                if [ "$battery_pct" -lt 20 ]; then
                    battery_color="red"
                elif [ "$battery_pct" -lt 50 ]; then
                    battery_color="orange"
                else
                    battery_color="green"
                fi
                echo "----${device} (Battery ${battery_pct}%) | font=Menlo size=10 color=$battery_color"
            else
                echo "----${device} | font=Menlo size=10"
            fi
        done
    else
        echo "----No devices connected | font=Menlo size=10 color=$subtle"
    fi

    echo "--Network:"
    network_list="$(ifconfig -a 2>/dev/null | awk '/inet / && $2 != "127.0.0.1" {print $2}')"
    if [ -n "$network_list" ]; then
        printf '%s\n' "$network_list" | while IFS= read -r ip_addr; do
            echo "----IP: ${ip_addr} | font=Menlo size=10"
        done
    else
        echo "----No active connections | font=Menlo size=10 color=$subtle"
    fi
}

print_system_alerts() {
    local updates_available app_store_running icloud_drive mds_active

    is_true "$SHOW_SYSTEM_ALERTS" || return 0

    echo "---"
    echo "Signals"

    if is_true "$CHECK_SOFTWARE_UPDATES"; then
        updates_available="$(cached_command softwareupdate 3600 /usr/sbin/softwareupdate -l | grep -c '^\*' || true)"
        if [ "$updates_available" -gt 0 ]; then
            echo "--System Updates: ${updates_available} available | color=orange"
            echo "----Open Software Update | bash=\"/usr/bin/open\" param1=\"x-apple.systempreferences:com.apple.preferences.softwareupdate\" terminal=false"
        else
            echo "--System Updates: Up to date | color=green"
        fi
    else
        :
    fi

    app_store_running="$(pgrep -fl 'Software Update' 2>/dev/null | wc -l | tr -d '[:space:]')"
    [ "$app_store_running" -gt 0 ] && echo "--Background updates in progress | color=blue"

    if pgrep -x bird >/dev/null 2>&1; then
        icloud_drive="Active"
        echo "--iCloud Drive: $icloud_drive | color=green"
    else
        icloud_drive="Inactive"
        echo "--iCloud Drive: $icloud_drive | color=gray"
    fi

    mds_active="$(printf '%s\n' "$PROCESS_SNAPSHOT" | awk '$11 ~ /mds_stores/ && $3 > 10 { count++ } END { print count + 0 }')"
    [ "$mds_active" -gt 0 ] && echo "--Spotlight: Indexing active | color=orange"
}

print_docker_section() {
    local running_containers stopped_containers stats cpu mem display_name name

    is_true "$SHOW_DOCKER" || return 0
    pgrep -x OrbStack >/dev/null 2>&1 || return 0

    echo "---"
    echo "Containers (OrbStack)"

    if ! command_exists docker || ! docker info >/dev/null 2>&1; then
        echo "--Docker not available | color=gray"
        return 0
    fi

    running_containers="$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l | tr -d '[:space:]')"
    if [ "$running_containers" -gt 0 ]; then
        echo "--Running: ${running_containers} containers | color=green"
        docker ps --format '{{.Names}}' 2>/dev/null | head -5 | while IFS= read -r name; do
            display_name="$(truncate_label "$name" 25)"

            echo "----${display_name} | font=Menlo size=10"
            if is_true "$SHOW_DOCKER_STATS"; then
                stats="$(docker stats "$name" --no-stream --format '{{.CPUPerc}} {{.MemUsage}}' 2>/dev/null || true)"
                cpu="$(printf '%s' "$stats" | awk '{print $1}')"
                mem="$(printf '%s' "$stats" | awk '{print $2}')"
                [ -n "$cpu" ] && echo "------CPU: ${cpu}, Mem: ${mem} | font=Menlo size=9 color=gray"
            fi
            echo "------Stop | bash=\"$(command -v docker)\" param1=\"stop\" param2=\"$name\" terminal=false refresh=true"
            echo "------Restart | bash=\"$(command -v docker)\" param1=\"restart\" param2=\"$name\" terminal=false refresh=true"
            echo "------Logs | bash=\"$(command -v docker)\" param1=\"logs\" param2=\"$name\" param3=\"--tail\" param4=\"50\" terminal=true"
        done
    else
        echo "--No containers running | color=gray"
    fi

    stopped_containers="$(docker ps -a --filter status=exited --format '{{.Names}}' 2>/dev/null | wc -l | tr -d '[:space:]')"
    [ "$stopped_containers" -gt 0 ] && echo "--Stopped: ${stopped_containers} containers | color=gray"
    echo "--Cleanup actions moved to Actions > Potentially Disruptive | color=gray"
}

print_safe_action_center() {
    echo "---"
    echo "Actions"
    echo "--Version: $PLUGIN_VERSION | color=gray"
    echo "--Quick Actions"
    echo "----Open Activity Monitor | bash=\"$PLUGIN_PATH\" param1=\"open-activity-monitor\" terminal=false"
    echo "----Copy Diagnostic Report | bash=\"$PLUGIN_PATH\" param1=\"diagnostic\" terminal=false refresh=false"
    echo "----Open Console (Logs) | bash=\"$PLUGIN_PATH\" param1=\"open-console\" terminal=false"
    echo "----Open System Settings | bash=\"$PLUGIN_PATH\" param1=\"open-system-settings\" terminal=false"
    echo "--Potentially Disruptive | color=orange"
    echo "----Empty Trash (Permanent) | bash=\"$PLUGIN_PATH\" param1=\"empty-trash\" terminal=false refresh=true color=orange"
    echo "----Clear Memory Cache (Requires sudo) | bash=\"$PLUGIN_PATH\" param1=\"purge-memory\" terminal=true refresh=true color=orange"
    echo "----Restart Spotlight Index (Rebuilds search index) | bash=\"$PLUGIN_PATH\" param1=\"restart-spotlight\" terminal=true refresh=true color=orange"
    if command_exists docker; then
        echo "----Prune Docker System (Removes unused images and volumes) | bash=\"$(command -v docker)\" param1=\"system\" param2=\"prune\" param3=\"-af\" param4=\"--volumes\" terminal=true refresh=true color=red"
    fi
    echo "---"
    echo "About"
    echo "--System Monitor v$PLUGIN_VERSION | color=gray"
    print_plugin_update_notice
    print_update_status_line
    echo "----Update from GitHub | bash=\"$PLUGIN_PATH\" param1=\"update-from-github\" terminal=false refresh=false"
    echo "--Repository: @$AUTHOR_GITHUB/swiftbar-plugins | href=\"$REPO_URL\""
    echo "---"
    echo "Refresh | refresh=true"
}

open_app() {
    /usr/bin/open -a "$1" >/dev/null 2>&1
}

empty_trash() {
    /usr/bin/osascript -e 'tell application "Finder" to delete every item of trash' >/dev/null 2>&1
}

purge_memory() {
    /usr/bin/sudo /usr/sbin/purge
}

restart_spotlight() {
    /usr/bin/sudo /usr/bin/mdutil -E /
}

update_plugin_from_github() {
    local checkout_dir tmp url new_version

    if checkout_dir="$(official_checkout_dir)"; then
        if ! git -C "$checkout_dir" pull --ff-only; then
            write_plugin_update_status "failure" "" "Git update failed. Resolve local checkout state and try again."
            printf 'Git update failed. Resolve local checkout state and try again.\n' >&2
            return 1
        fi

        new_version="$(installed_plugin_version)"
        write_plugin_update_status "success" "${new_version:-latest}" "Updated to v${new_version:-latest} from GitHub."
        printf 'Updated System Monitor to %s from GitHub.\n' "${new_version:-latest}"
        return 0
    fi

    if ! command_exists curl; then
        write_plugin_update_status "failure" "" "curl is required to update this plugin from GitHub."
        printf 'curl is required to update this plugin from GitHub.\n' >&2
        return 1
    fi

    url="$(plugin_update_url)"
    tmp="$(mktemp "${TMPDIR:-/tmp}/swiftbar-system-monitor-update.XXXXXX")" || return 1

    if ! download_plugin_update "$url" "$tmp"; then
        rm -f "$tmp"
        write_plugin_update_status "failure" "" "Failed to download the latest plugin from GitHub."
        printf 'Failed to download the latest plugin from GitHub.\n' >&2
        return 1
    fi

    if ! validate_downloaded_plugin "$tmp"; then
        rm -f "$tmp"
        write_plugin_update_status "failure" "" "Downloaded file did not look like a valid System Monitor plugin."
        printf 'Downloaded file did not look like a valid System Monitor plugin.\n' >&2
        return 1
    fi

    if ! chmod +x "$tmp"; then
        rm -f "$tmp"
        write_plugin_update_status "failure" "" "Failed to mark the downloaded plugin as executable."
        printf 'Failed to mark the downloaded plugin as executable.\n' >&2
        return 1
    fi

    if ! mv "$tmp" "$PLUGIN_PATH"; then
        rm -f "$tmp"
        write_plugin_update_status "failure" "" "Failed to install the updated plugin."
        printf 'Failed to install the updated plugin at %s.\n' "$PLUGIN_PATH" >&2
        return 1
    fi

    new_version="$(installed_plugin_version)"
    write_plugin_update_status "success" "${new_version:-latest}" "Updated to v${new_version:-latest} from GitHub."
    printf 'Updated System Monitor to %s from GitHub.\n' "${new_version:-latest}"
}

perform_background_update_from_github() {
    local output message

    if output="$(update_plugin_from_github 2>&1)"; then
        message="$(printf '%s' "$output" | tail -1)"
        [ -n "$message" ] || message="Updated from GitHub."
        notify_update_result "System Monitor Updated" "$message"
    else
        message="$(printf '%s' "$output" | tail -1)"
        [ -n "$message" ] || message="Update failed."
        notify_update_result "System Monitor Update Failed" "$message"
    fi

    refresh_plugin_menu
}

queue_background_update_from_github() {
    write_plugin_update_status "pending" "$PLUGIN_VERSION" "Updating from GitHub in the background..."
    refresh_plugin_menu
    nohup "$PLUGIN_PATH" perform-update-from-github >/dev/null 2>&1 &
}

copy_diagnostic_report() {
    local report
    report="$(mktemp "${TMPDIR:-/tmp}/swiftbar-system-monitor.XXXXXX")"

    {
        echo "SwiftBar System Monitor Diagnostic"
        echo "Version: $PLUGIN_VERSION"
        echo "Author GitHub: @$AUTHOR_GITHUB"
        echo "Repository: $REPO_URL"
        echo "Generated: $(date)"
        echo "Host: $(hostname)"
        echo "macOS: $(sw_vers -productVersion 2>/dev/null || echo unknown)"
        echo "Load: $(load_average)"
        echo "Busy apps: $(high_cpu_count)"
        echo "Memory compressed: $(memory_compressed_gb)GB"
        echo "Disk available: $(disk_available_human)"
        echo "Battery: $(battery_percent 2>/dev/null || echo desktop)% $(battery_state 2>/dev/null || true)"
        print_flight_report
        echo
        echo "Top CPU:"
        ps aux | sort -nrk 3 | head -6
        echo
        echo "Top Memory:"
        ps aux | sort -nrk 4 | head -6
    } >"$report"

    if command_exists pbcopy; then
        pbcopy <"$report"
    fi

    open -R "$report" >/dev/null 2>&1 || true
}

render_menu() {
    local load1 load_int mem_gb disk_human disk_gb high_cpu batt_pct temp state issue color title_color

    load1="$(load_average)"
    PROCESS_SNAPSHOT="$(ps aux)"
    load_int="$(integer_part "$load1")"
    is_number "$load_int" || load_int="0"
    mem_gb="$(memory_compressed_gb)"
    disk_human="$(disk_available_human)"
    disk_gb="$(disk_available_gb)"
    high_cpu="$(high_cpu_count)"
    batt_pct="$(battery_percent)"
    temp="$(cpu_temperature)"
    state="$(health_state "$load_int" "$high_cpu" "$disk_gb" "$batt_pct" "$temp")"
    issue="$(top_issue "$load_int" "$high_cpu" "$disk_gb" "$batt_pct" "$temp")"
    color="$(state_color "$state")"
    title_color="$color"
    if [ "$state" = "healthy" ] && [ "$high_cpu" -eq 0 ] && ! is_true "$ANIMATE_TITLE"; then
        title_color="$(secondary_color)"
    fi
    record_flight_snapshot "$state" "$issue" "$load1" "$high_cpu" "$disk_gb" "$batt_pct"

    echo "$(menu_title "$state" "$load1" "$high_cpu") | color=$title_color tooltip=\"$issue. Load: $load1. Busy apps: $high_cpu.\""
    print_triage_summary "$state" "$issue" "$color" "$load_int" "$high_cpu" "$disk_gb" "$batt_pct" "$temp"
    print_resource_overview "$load1" "$high_cpu" "$mem_gb" "$disk_human" "$disk_gb" "$batt_pct" "$temp"
    print_high_cpu_processes
    print_energy_impact
    echo "---"
    print_health_section
    print_devices_section
    print_system_alerts
    print_docker_section
    echo "---"
    echo "Advanced"
    print_process_list "--Top CPU" "3" "CPU" "3" "----"
    print_process_list "--Top Memory" "4" "MEM" "4" "----"
    print_safe_action_center
}

main() {
    load_config

    case "${1:-}" in
        version|--version|-v)
            echo "$PLUGIN_VERSION"
            ;;
        diagnostic)
            copy_diagnostic_report
            ;;
        open-activity-monitor)
            open_app "Activity Monitor"
            ;;
        open-console)
            open_app "Console"
            ;;
        open-system-settings)
            open_app "System Settings"
            ;;
        update-from-github)
            queue_background_update_from_github
            ;;
        perform-update-from-github)
            perform_background_update_from_github
            ;;
        empty-trash)
            empty_trash
            ;;
        purge-memory)
            purge_memory
            ;;
        restart-spotlight)
            restart_spotlight
            ;;
        *)
            render_menu
            ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
