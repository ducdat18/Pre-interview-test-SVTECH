#!/usr/bin/env bash
#
# k8s-node-validate — verify a node satisfies Kubernetes prerequisites.
#
# Checks that every required kernel parameter, module, swap state, container
# runtime setting, and package is correctly applied after provisioning.
#
# Exit code:
#   0  all checks passed
#   1  one or more checks FAILED (details printed, failing checks summarised)
#
# Usage: sudo ./validate.sh [--quiet]
#
set -uo pipefail

QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

PASS=0
FAIL=0
declare -a FAILURES=()

# --- expected values --------------------------------------------------------
PAUSE_IMAGE_EXPECTED="${PAUSE_IMAGE_EXPECTED:-registry.k8s.io/pause:3.10}"
COMMAND_LOG="${COMMAND_LOG:-/var/log/commands.log}"

# Required sysctl parameters -> expected value
declare -A SYSCTLS=(
  ["net.ipv4.ip_forward"]="1"
  ["net.bridge.bridge-nf-call-iptables"]="1"
  ["net.bridge.bridge-nf-call-ip6tables"]="1"
)

REQUIRED_MODULES=(overlay br_netfilter)
REQUIRED_BINS=(kubelet kubeadm kubectl containerd runc)

# --- pretty printing --------------------------------------------------------
C_GREEN=$'\e[32m'; C_RED=$'\e[31m'; C_YELLOW=$'\e[33m'; C_RESET=$'\e[0m'
[[ -t 1 ]] || { C_GREEN=""; C_RED=""; C_YELLOW=""; C_RESET=""; }

log()  { [[ $QUIET -eq 1 ]] || echo -e "$@"; }
ok()   { PASS=$((PASS+1)); log "  ${C_GREEN}[PASS]${C_RESET} $1"; }
bad()  { FAIL=$((FAIL+1)); FAILURES+=("$1"); log "  ${C_RED}[FAIL]${C_RESET} $1"; }
note() { log "  ${C_YELLOW}[INFO]${C_RESET} $1"; }
section() { log "\n${C_YELLOW}== $1 ==${C_RESET}"; }

# check "description" "actual" "expected"
check_eq() {
  local desc="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    ok "$desc (=$expected)"
  else
    bad "$desc — expected '$expected', got '${actual:-<empty>}'"
  fi
}

# A module counts as present if loaded (lsmod), built-in (/sys/module or
# /proc/filesystems). Kernels vary: overlay is often built-in, not an LKM.
module_present() {
  local m="$1"
  lsmod 2>/dev/null | awk '{print $1}' | grep -qx "$m" && return 0
  [[ -d "/sys/module/$m" ]] && return 0
  grep -qw "$m" /proc/filesystems 2>/dev/null && return 0
  return 1
}

# =============================================================================
section "Swap"
if swapon --noheadings --show 2>/dev/null | grep -q .; then
  bad "swap is enabled (must be off for kubelet)"
else
  ok "swap is disabled"
fi
swap_total=$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
check_eq "SwapTotal in /proc/meminfo" "${swap_total:-0}" "0"

# =============================================================================
section "Kernel modules"
for m in "${REQUIRED_MODULES[@]}"; do
  if module_present "$m"; then
    ok "module '$m' is available (loaded or built-in)"
  else
    bad "module '$m' is NOT available"
  fi
done

# =============================================================================
section "Kernel parameters (sysctl)"
for key in "${!SYSCTLS[@]}"; do
  want="${SYSCTLS[$key]}"
  got=$(sysctl -n "$key" 2>/dev/null || echo "")
  check_eq "$key" "${got// /}" "$want"
done

# Confirm the params are persisted (survive reboot), not just live.
if [[ -f /etc/sysctl.d/99-kubernetes-cri.conf ]]; then
  ok "persistent sysctl file /etc/sysctl.d/99-kubernetes-cri.conf present"
else
  bad "persistent sysctl file /etc/sysctl.d/99-kubernetes-cri.conf missing"
fi
if [[ -f /etc/modules-load.d/k8s.conf ]]; then
  ok "persistent modules file /etc/modules-load.d/k8s.conf present"
else
  bad "persistent modules file /etc/modules-load.d/k8s.conf missing"
fi

# =============================================================================
section "containerd"
if command -v containerd >/dev/null 2>&1; then
  ok "containerd binary present"
else
  bad "containerd binary missing"
fi
if systemctl is-active --quiet containerd 2>/dev/null; then
  ok "containerd service is active"
else
  bad "containerd service is not active"
fi

CFG=/etc/containerd/config.toml
if [[ -f "$CFG" ]]; then
  ok "config.toml present"
  if grep -qE '^\s*SystemdCgroup\s*=\s*true' "$CFG"; then
    ok "SystemdCgroup = true (systemd cgroup driver)"
  else
    bad "SystemdCgroup is not set to true"
  fi
  # Version-agnostic: containerd v1 config uses  sandbox_image = "..."
  # while v2/v3 config uses  sandbox = '...'  under pinned_images.
  if grep -qF "$PAUSE_IMAGE_EXPECTED" "$CFG"; then
    ok "pause/sandbox image pinned to $PAUSE_IMAGE_EXPECTED"
  else
    bad "pause/sandbox image not pinned to $PAUSE_IMAGE_EXPECTED"
  fi
else
  bad "config.toml missing"
fi

# =============================================================================
section "Kubernetes tooling"
for b in "${REQUIRED_BINS[@]}"; do
  if command -v "$b" >/dev/null 2>&1; then
    ok "$b in PATH ($(command -v "$b"))"
  else
    bad "$b not found in PATH"
  fi
done

# =============================================================================
section "Command audit logging"
if [[ -f "$COMMAND_LOG" ]]; then
  ok "dedicated command log exists: $COMMAND_LOG"
else
  bad "dedicated command log missing: $COMMAND_LOG"
fi
if [[ -f /etc/ld.so.preload ]] && grep -q 'libsnoopy' /etc/ld.so.preload; then
  ok "snoopy active in /etc/ld.so.preload"
else
  bad "snoopy not enabled in /etc/ld.so.preload"
fi
if systemctl is-active --quiet auditd 2>/dev/null; then
  ok "auditd service is active"
else
  note "auditd not active (secondary mechanism)"
fi

# =============================================================================
section "Summary"
TOTAL=$((PASS+FAIL))
log "  Passed: ${C_GREEN}${PASS}${C_RESET} / ${TOTAL}"
if [[ $FAIL -gt 0 ]]; then
  # Always surface failures (even with --quiet) so CI logs show the cause.
  echo "k8s-node-validate: ${FAIL}/${TOTAL} checks FAILED:" >&2
  for f in "${FAILURES[@]}"; do
    echo "    - $f" >&2
  done
  exit 1
fi
log "\n${C_GREEN}All ${TOTAL} checks passed — node is Kubernetes-ready.${C_RESET}"
exit 0
