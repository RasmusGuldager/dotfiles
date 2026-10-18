#!/usr/bin/env bash
# =============================================================================
# Plugin: cpu_precise
# Description: Display CPU usage percentage with one decimal (e.g. 34.7%)
# Type: conditional (can hide when load is normal)
# Dependencies: None (uses /proc/stat, Linux only)
# =============================================================================
#
# Local variant of the upstream cpu plugin. Same measurement approach
# (cross-cycle /proc/stat delta, pure bash), but keeps tenths of a percent.
#
# CONTRACT IMPLEMENTATION:
#
# State:
#   - active: CPU metrics are available and readable
#   - inactive: Unable to read CPU metrics (or not Linux)
#
# Health:
#   - ok: CPU usage is below warning threshold
#   - warning: CPU usage is above warning but below critical
#   - error: CPU usage is above critical threshold
#
# Context:
#   - cpu_load_ok, cpu_load_warning, cpu_load_error
#
# =============================================================================

POWERKIT_ROOT="${POWERKIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
. "${POWERKIT_ROOT}/src/contract/plugin_contract.sh"

# =============================================================================
# Plugin Contract: Metadata
# =============================================================================

plugin_get_metadata() {
    metadata_set "id" "cpu_precise"
    metadata_set "name" "CPU (precise)"
    metadata_set "description" "Display CPU usage percentage with one decimal"
}

# =============================================================================
# Plugin Contract: Dependencies
# =============================================================================

plugin_check_dependencies() {
    is_linux || return 1
    [[ -r /proc/stat ]] || return 1
    return 0
}

# =============================================================================
# Plugin Contract: Options
# =============================================================================

plugin_declare_options() {
    # Icons
    declare_option "icon" "icon" $'\U0000f4bc' "Plugin icon (nf-mdi-chip)"
    declare_option "icon_warning" "icon" "" "Icon when warning (empty = use default)"
    declare_option "icon_critical" "icon" "" "Icon when critical (empty = use default)"

    # Thresholds (higher = worse)
    declare_option "warning_threshold" "number" "70" "Warning threshold percentage"
    declare_option "critical_threshold" "number" "90" "Critical threshold percentage"

    # Sampling (for fallback when cross-cycle data unavailable)
    declare_option "sample_interval" "number" "0.5" "Fallback sampling interval in seconds"
    declare_option "max_cache_age" "number" "60" "Maximum age of cached CPU readings in seconds"

    # Cache
    declare_option "cache_ttl" "number" "5" "Cache duration in seconds"
}

# =============================================================================
# Linux CPU Detection
# =============================================================================

# Read aggregate idle and total jiffies from /proc/stat
# Usage: _read_proc_stat idle_var total_var
_read_proc_stat() {
    local -n _idle_ref="$1" _total_ref="$2"
    local line v
    local -a vals

    read -r line </proc/stat 2>/dev/null
    [[ -n "$line" && "$line" == cpu* ]] || return 1
    read -ra vals <<<"${line#cpu }"

    _idle_ref=$((vals[3] + vals[4]))
    _total_ref=0
    for v in "${vals[@]}"; do
        _total_ref=$((_total_ref + v))
    done
}

# CPU usage in tenths of a percent (347 = 34.7%), using the delta since the
# previous render cycle. Falls back to a short sleep-based sample when there is
# no usable previous snapshot.
_get_cpu_tenths() {
    local idle total
    _read_proc_stat idle total || return 1

    local current_time="${EPOCHSECONDS}"

    # Previous snapshot (24h TTL - only invalid on reboot)
    local prev_idle prev_total prev_timestamp
    prev_idle=$(cache_get "cpu_precise_prev_idle" "86400")
    prev_total=$(cache_get "cpu_precise_prev_total" "86400")
    prev_timestamp=$(cache_get "cpu_precise_prev_timestamp" "86400")

    cache_set "cpu_precise_prev_idle" "$idle"
    cache_set "cpu_precise_prev_total" "$total"
    cache_set "cpu_precise_prev_timestamp" "$current_time"

    local need_fallback=0
    local max_age
    max_age=$(get_option "max_cache_age")
    max_age="${max_age:-60}"

    if [[ -z "$prev_idle" || -z "$prev_total" || -z "$prev_timestamp" ]]; then
        need_fallback=1
    else
        local age=$((current_time - prev_timestamp))
        # Too old (suspend/resume) or too close together (rapid refresh)
        ((age > max_age || age < 1)) && need_fallback=1
    fi

    if ((need_fallback)); then
        local sample_interval
        sample_interval=$(get_option "sample_interval")
        prev_idle=$idle
        prev_total=$total
        sleep "${sample_interval:-0.5}"
        _read_proc_stat idle total || return 1
    fi

    local delta_idle=$((idle - prev_idle))
    local delta_total=$((total - prev_total))

    if ((delta_total > 0)); then
        # Rounded to nearest tenth
        local tenths=$((((delta_total - delta_idle) * 1000 + delta_total / 2) / delta_total))
        ((tenths > 1000)) && tenths=1000
        ((tenths < 0)) && tenths=0
        printf '%d' "$tenths"
    else
        printf '0'
    fi
}

# =============================================================================
# Plugin Contract: Data Collection
# =============================================================================

plugin_collect() {
    local tenths
    tenths=$(_get_cpu_tenths) || return 1
    [[ -z "$tenths" ]] && return 1

    # Integer percent for thresholds/icon, tenths for display
    plugin_data_set "percent" "$((tenths / 10))"
    plugin_data_set "tenths" "$tenths"
    plugin_data_set "available" "1"
}

# =============================================================================
# Plugin Contract: Type and Presence
# =============================================================================

plugin_get_content_type() {
    printf 'dynamic'
}

plugin_get_presence() {
    printf 'conditional'
}

# =============================================================================
# Plugin Contract: State
# =============================================================================

plugin_get_state() {
    local available
    available=$(plugin_data_get "available")
    [[ "$available" == "1" ]] && printf 'active' || printf 'inactive'
}

# =============================================================================
# Plugin Contract: Health
# =============================================================================

plugin_get_health() {
    local percent warn_th crit_th
    percent=$(plugin_data_get "percent")
    warn_th=$(get_option "warning_threshold")
    crit_th=$(get_option "critical_threshold")

    evaluate_threshold_health "${percent:-0}" "${warn_th:-70}" "${crit_th:-90}"
}

# =============================================================================
# Plugin Contract: Context
# =============================================================================

plugin_get_context() {
    plugin_context_from_health "$(plugin_get_health)" "cpu_load"
}

# =============================================================================
# Plugin Contract: Icon
# =============================================================================

plugin_get_icon() {
    local percent warn_th crit_th
    percent=$(plugin_data_get "percent")
    warn_th=$(get_option "warning_threshold")
    crit_th=$(get_option "critical_threshold")

    # Data-based icon selection (contract: icon must not call plugin_get_health)
    if ((${percent:-0} >= ${crit_th:-90})); then
        local icon_crit
        icon_crit=$(get_option "icon_critical")
        [[ -n "$icon_crit" ]] && printf '%s' "$icon_crit" || get_option "icon"
    elif ((${percent:-0} >= ${warn_th:-70})); then
        local icon_warn
        icon_warn=$(get_option "icon_warning")
        [[ -n "$icon_warn" ]] && printf '%s' "$icon_warn" || get_option "icon"
    else
        get_option "icon"
    fi
}

# =============================================================================
# Plugin Contract: Render
# =============================================================================

plugin_render() {
    local tenths
    tenths=$(plugin_data_get "tenths")
    tenths="${tenths:-0}"

    # Padded for alignment: " 7.3%", "34.7%", "100.0%"
    printf '%3d.%d%%' "$((tenths / 10))" "$((tenths % 10))"
}
