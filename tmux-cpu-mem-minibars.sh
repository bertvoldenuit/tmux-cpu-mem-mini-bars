#!/bin/sh
# tmux-cpu-mem-minibars: CPU and RAM as colored mini-bars for the tmux status line.
# Prints one line containing tmux style codes (#[fg=...]), so it is meant to be
# called from tmux with #(...), not run in a plain shell.
# Linux only (reads /proc). POSIX sh, no dependencies besides awk.

# --- CPU: usage since the previous call (state kept in /tmp) ---
f=/tmp/.tmux-cpu-mem-minibars-cpu-$(id -u)
read -r _ u n s i w q sq st _ < /proc/stat
total=$((u+n+s+i+w+q+sq+st)); idle=$((i+w))
if [ -f "$f" ]; then read -r pt pi < "$f"; else pt=$total; pi=$idle; fi
echo "$total $idle" > "$f"
dt=$((total-pt)); di=$((idle-pi))
if [ "$dt" -gt 0 ]; then cpu=$((100*(dt-di)/dt)); else cpu=0; fi

# --- RAM: percent, used and total in GiB (MemTotal - MemAvailable) ---
set -- $(LC_ALL=C awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%d %.1f %.1f", (t-a)*100/t, (t-a)/1048576, t/1048576}' /proc/meminfo)
mem=$1; used=$2; tot=$3

# --- rendering ---
bar() { n=$(($1*8/100)); k=0; o=""
  while [ $k -lt 8 ]; do
    if [ $k -lt $n ]; then o="$o█"; else o="$o░"; fi; k=$((k+1)); done
  printf "%s" "$o"; }
col() { if [ "$1" -ge 80 ]; then printf '#[fg=red]'
  elif [ "$1" -ge 50 ]; then printf '#[fg=yellow]'
  else printf '#[fg=green]'; fi; }

printf "%sCPU %s %3d%%#[default]  %sRAM %s %s/%sG#[default]" \
  "$(col $cpu)" "$(bar $cpu)" "$cpu" "$(col $mem)" "$(bar $mem)" "$used" "$tot"
