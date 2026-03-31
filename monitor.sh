#!/bin/bash

# ============================================================
#  system-monitor/monitor.sh
#  System health monitor — compatible with macOS & Linux
# ============================================================

# ---------- Configuration ----------
LOG_FILE="$(dirname "$0")/output.log"
ALERT_CPU=80
ALERT_MEM=80
ALERT_DISK=90

# ---------- Colors ----------
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ---------- Detect OS ----------
OS="$(uname -s)"

# ---------- CPU Usage ----------
if [[ "$OS" == "Darwin" ]]; then
  # macOS top requires -l for log mode; take 2 samples, use the second (accurate)
  CPU_IDLE=$(top -l 2 -n 0 | grep "CPU usage" | tail -1 | awk '{print $7}' | tr -d '%')
  CPU_USED=$(awk "BEGIN{printf \"%d\", 100 - ${CPU_IDLE:-0}}")
else
  CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | tr -d '%')
  CPU_USED=$(echo "100 - ${CPU_IDLE:-0}" | bc | awk '{printf "%d", $1}')
fi

# ---------- Memory Usage ----------
if [[ "$OS" == "Darwin" ]]; then
  PAGE_SIZE=$(pagesize 2>/dev/null || echo 4096)
  VM=$(vm_stat)
  PAGES_FREE=$(    echo "$VM" | awk '/Pages free/       {gsub(/\./,"",$3); print $3}')
  PAGES_ACTIVE=$(  echo "$VM" | awk '/Pages active/     {gsub(/\./,"",$3); print $3}')
  PAGES_INACTIVE=$(echo "$VM" | awk '/Pages inactive/   {gsub(/\./,"",$3); print $3}')
  PAGES_WIRED=$(   echo "$VM" | awk '/Pages wired down/ {gsub(/\./,"",$4); print $4}')
  PAGES_SPEC=$(    echo "$VM" | awk '/Pages speculative/{gsub(/\./,"",$3); print $3}')

  MEM_USED_PAGES=$(( PAGES_ACTIVE + PAGES_INACTIVE + PAGES_WIRED ))
  MEM_TOTAL_PAGES=$(( MEM_USED_PAGES + PAGES_FREE + ${PAGES_SPEC:-0} ))

  if (( MEM_TOTAL_PAGES > 0 )); then
    MEM_PCT=$(awk "BEGIN{printf \"%d\", ($MEM_USED_PAGES / $MEM_TOTAL_PAGES) * 100}")
  else
    MEM_PCT=0
  fi

  MEM_TOTAL_GB=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
  MEM_USED_GB=$(awk "BEGIN{printf \"%.1f\", ($MEM_USED_PAGES * $PAGE_SIZE) / 1024 / 1024 / 1024}")
else
  MEM_TOTAL=$(free -k | awk '/^Mem:/{print $2}')
  MEM_USED=$(free -k  | awk '/^Mem:/{print $3}')
  MEM_PCT=$(awk "BEGIN{printf \"%d\", ($MEM_USED/$MEM_TOTAL)*100}")
fi

# ---------- Disk Usage ----------
DISK_PCT=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')

# ---------- Top Process ----------
if [[ "$OS" == "Darwin" ]]; then
  TOP_PROC=$(ps -arceo comm,pcpu | awk 'NR>1 && $1 !~ /^\[/ {print $1; exit}')
else
  TOP_PROC=$(ps -eo comm,pcpu --sort=-pcpu | awk 'NR>1 && $1 !~ /^\[/ {print $1; exit}')
fi

# ---------- Helper ----------
print_metric() {
  local label="$1" value="$2" threshold="$3" unit="${4:-%}"
  local warn=$(( threshold * 75 / 100 ))
  if (( value >= threshold )); then
    echo -e "${RED}${BOLD}  ⚠  $label: ${value}${unit}  <- HIGH${RESET}"
  elif (( value >= warn )); then
    echo -e "${YELLOW}     $label: ${value}${unit}${RESET}"
  else
    echo -e "${GREEN}     $label: ${value}${unit}${RESET}"
  fi
}

# ---------- Timestamp ----------
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# ---------- Terminal output ----------
echo ""
echo -e "${CYAN}${BOLD}+==================================+${RESET}"
echo -e "${CYAN}${BOLD}|    System Health Monitor         |${RESET}"
echo -e "${CYAN}${BOLD}|    $TIMESTAMP    |${RESET}"
echo -e "${CYAN}${BOLD}+==================================+${RESET}"
echo ""

print_metric "CPU Usage  " "$CPU_USED"  "$ALERT_CPU"
print_metric "Memory     " "$MEM_PCT"   "$ALERT_MEM"
print_metric "Disk       " "$DISK_PCT"  "$ALERT_DISK"
echo -e "     ${BOLD}Top Process${RESET}: ${TOP_PROC}"

if [[ "$OS" == "Darwin" && -n "$MEM_TOTAL_GB" ]]; then
  echo -e "     ${BOLD}RAM         ${RESET}: ${MEM_USED_GB} GB used of ${MEM_TOTAL_GB} GB"
fi
echo ""

# ---------- Alerts ----------
ALERTS=()
(( CPU_USED  >= ALERT_CPU  )) && ALERTS+=("CPU at ${CPU_USED}%")
(( MEM_PCT   >= ALERT_MEM  )) && ALERTS+=("Memory at ${MEM_PCT}%")
(( DISK_PCT  >= ALERT_DISK )) && ALERTS+=("Disk at ${DISK_PCT}%")

if (( ${#ALERTS[@]} > 0 )); then
  echo -e "${RED}${BOLD}!! ALERT: ${ALERTS[*]}${RESET}"
  echo ""
fi

# ---------- Log ----------
{
  echo "[$TIMESTAMP]"
  echo "CPU Usage  : ${CPU_USED}%"
  echo "Memory     : ${MEM_PCT}%"
  echo "Disk       : ${DISK_PCT}%"
  echo "Top Process: ${TOP_PROC}"
  [[ "$OS" == "Darwin" && -n "$MEM_TOTAL_GB" ]] && echo "RAM        : ${MEM_USED_GB} GB / ${MEM_TOTAL_GB} GB"
  (( ${#ALERTS[@]} > 0 )) && echo "ALERT: ${ALERTS[*]}"
  echo "---"
} >> "$LOG_FILE"

echo -e "${CYAN}Output saved to:${RESET} $LOG_FILE"
echo ""
