#!/usr/bin/env bash

set -euo pipefail

probe_host="1.1.1.1"

nm_get() {
  LC_ALL=C nmcli -e no -g "$@" 2>/dev/null
}

active_interface() {
  ip -4 route get "$probe_host" 2>/dev/null |
    awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }'
}

main_default_interface() {
  ip -4 route show table main 2>/dev/null |
    awk '$1 == "default" { for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }'
}

target_interface() {
  local iface type

  # Prefer the physical/default connection in the main table. Policy-routed
  # tunnels such as singbox_tun are the effective egress, but their peer
  # address is not the LAN gateway the user can sensibly configure here.
  iface=$(main_default_interface || true)
  if [[ -n $iface ]]; then
    printf '%s\n' "$iface"
    return 0
  fi

  iface=$(active_interface || true)
  [[ -n $iface ]] || return 1
  type=$(nm_get GENERAL.TYPE device show "$iface" | head -n 1 || true)
  [[ $type != "tun" && $type != "wireguard" ]] || return 1
  printf '%s\n' "$iface"
}

active_profile() {
  local iface=$1
  nm_get GENERAL.CONNECTION device show "$iface" | head -n 1
}

connection_value() {
  local field=$1
  nm_get "$field" connection show "$profile" | head -n 1
}

live_gateway() {
  ip -4 route get "$probe_host" 2>/dev/null |
    awk '{ for (i = 1; i <= NF; i++) if ($i == "via") { print $(i + 1); exit } }'
}

main_route_gateway() {
  local iface=$1
  [[ -n $iface ]] || return 1

  ip -4 route show table main dev "$iface" 2>/dev/null |
    awk '$1 == "default" { for (i = 1; i <= NF; i++) if ($i == "via") { print $(i + 1); exit } }'
}

default_route_gateway() {
  local routes=$1
  local route destination gateway metric

  while IFS= read -r route; do
    read -r destination gateway metric <<<"$route"
    if [[ $destination == "0.0.0.0/0" && -n ${gateway:-} ]]; then
      printf '%s\n' "$gateway"
      return 0
    fi
  done < <(printf '%s\n' "$routes" | tr ',' '\n')
}

valid_ipv4() {
  local value=$1
  local octet
  local -a octets

  [[ $value =~ ^[0-9]+(\.[0-9]+){3}$ ]] || return 1
  IFS=. read -r -a octets <<<"$value"
  [[ ${#octets[@]} -eq 4 ]] || return 1

  for octet in "${octets[@]}"; do
    [[ $octet =~ ^[0-9]{1,3}$ ]] || return 1
    ((10#$octet <= 255)) || return 1
  done

  [[ $value != "0.0.0.0" && $value != "255.255.255.255" ]]
}

require_active_profile() {
  iface=$(target_interface || true)
  [[ -n $iface ]] || { echo "No editable NetworkManager uplink." >&2; return 1; }

  profile=$(active_profile "$iface" || true)
  [[ -n $profile && $profile != "--" ]] || {
    echo "No active NetworkManager connection profile." >&2
    return 1
  }
}

capture_profile() {
  old_method=$(connection_value ipv4.method)
  old_gateway=$(connection_value ipv4.gateway)
  old_routes=$(connection_value ipv4.routes)
  old_ignore_auto_routes=$(connection_value ipv4.ignore-auto-routes)
  old_never_default=$(connection_value ipv4.never-default)
}

restore_profile() {
  nmcli connection modify "$profile" \
    ipv4.method "$old_method" \
    ipv4.gateway "$old_gateway" \
    ipv4.routes "$old_routes" \
    ipv4.ignore-auto-routes "$old_ignore_auto_routes" \
    ipv4.never-default "$old_never_default" >/dev/null
}

reconnect_or_rollback() {
  local expected_gateway=${1:-}
  local actual_gateway

  if nmcli connection up "$profile" >/dev/null 2>&1; then
    if [[ -z $expected_gateway ]]; then
      return 0
    fi

    actual_gateway=$(main_route_gateway "$iface" || true)
    if [[ $actual_gateway == "$expected_gateway" ]]; then
      return 0
    fi
  fi

  restore_profile >/dev/null 2>&1 || true
  nmcli connection up "$profile" >/dev/null 2>&1 || true
  echo "Gateway change failed; previous settings were restored." >&2
  return 1
}

show_status() {
  local active_iface iface profile method gateway routes ignore_auto_routes mode configured_gateway target_gateway

  active_iface=$(active_interface || true)
  iface=$(target_interface || true)
  if [[ -z $iface ]]; then
    printf 'mode\tdisconnected\n'
    printf 'live_gateway\t%s\n' "$(live_gateway || true)"
    exit 0
  fi

  profile=$(active_profile "$iface" || true)
  if [[ -z $profile || $profile == "--" ]]; then
    printf 'mode\tunavailable\n'
    printf 'live_gateway\t%s\n' "$(live_gateway || true)"
    printf 'target_interface\t%s\n' "$iface"
    exit 0
  fi

  method=$(nm_get ipv4.method connection show "$profile" | head -n 1 || true)
  gateway=$(nm_get ipv4.gateway connection show "$profile" | head -n 1 || true)
  routes=$(nm_get ipv4.routes connection show "$profile" | head -n 1 || true)
  ignore_auto_routes=$(nm_get ipv4.ignore-auto-routes connection show "$profile" | head -n 1 || true)
  mode="auto"
  configured_gateway=""

  if [[ $ignore_auto_routes == "yes" ]]; then
    configured_gateway=$(default_route_gateway "$routes" || true)
    [[ -n $configured_gateway ]] && mode="manual"
  elif [[ $method == "manual" && -n $gateway ]]; then
    configured_gateway=$gateway
    mode="manual"
  fi

  target_gateway=$(main_route_gateway "$iface" || true)
  printf 'mode\t%s\n' "$mode"
  printf 'configured_gateway\t%s\n' "$configured_gateway"
  printf 'target_gateway\t%s\n' "$target_gateway"
  printf 'live_gateway\t%s\n' "$(live_gateway || true)"
  printf 'target_interface\t%s\n' "$iface"
  printf 'target_profile\t%s\n' "$profile"
}

set_manual() {
  local requested_gateway=$1

  valid_ipv4 "$requested_gateway" || {
    echo "Enter a valid IPv4 gateway." >&2
    return 1
  }

  require_active_profile
  capture_profile

  if ! nmcli connection modify "$profile" \
    ipv4.method "$old_method" \
    ipv4.gateway "" \
    ipv4.routes "0.0.0.0/0 $requested_gateway 50" \
    ipv4.ignore-auto-routes yes \
    ipv4.never-default no >/dev/null; then
    echo "Could not save the gateway settings." >&2
    return 1
  fi

  reconnect_or_rollback "$requested_gateway"
}

set_auto() {
  require_active_profile
  capture_profile

  if ! nmcli connection modify "$profile" \
    ipv4.method "$old_method" \
    ipv4.gateway "" \
    ipv4.routes "" \
    ipv4.ignore-auto-routes no \
    ipv4.never-default no >/dev/null; then
    echo "Could not restore automatic gateway settings." >&2
    return 1
  fi

  reconnect_or_rollback
}

command=${1:-status}
case "$command" in
  status)
    show_status
    ;;
  set)
    [[ $# -eq 2 ]] || { echo "Usage: gateway.sh set <ipv4-gateway>" >&2; exit 2; }
    set_manual "$2"
    ;;
  auto)
    [[ $# -eq 1 ]] || { echo "Usage: gateway.sh auto" >&2; exit 2; }
    set_auto
    ;;
  *)
    echo "Usage: gateway.sh [status|set <ipv4-gateway>|auto]" >&2
    exit 2
    ;;
esac
