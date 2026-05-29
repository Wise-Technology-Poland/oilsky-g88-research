#!/system/bin/sh

LOG=/data/adb/oilsky-charge-limit.log
LIMIT_UA=2000000

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"
}

write_limit() {
  node="$1"

  [ -e "$node" ] || return 0
  [ -w "$node" ] || {
    log "skip not writable: $node"
    return 0
  }

  current="$(cat "$node" 2>/dev/null | tr -d '\r\n')"
  [ -n "$current" ] || {
    log "skip unreadable: $node"
    return 0
  }

  echo "$LIMIT_UA" > "$node" 2>/dev/null
  after="$(cat "$node" 2>/dev/null | tr -d '\r\n')"
  log "set $node from $current to $after requested=$LIMIT_UA unit=uA"
}

(
  sleep 20
  log "Oilsky Charge Limit 2A starting"

  for node in \
    /sys/class/power_supply/battery/constant_charge_current_max \
    /sys/class/power_supply/battery/input_current_limit \
    /sys/class/power_supply/battery/current_max \
    /sys/class/power_supply/usb/input_current_limit \
    /sys/class/power_supply/usb/current_max \
    /sys/class/power_supply/charger/input_current_limit \
    /sys/class/power_supply/charger/constant_charge_current_max \
    /sys/class/power_supply/charger/current_max \
    /sys/class/power_supply/eta696x/input_current_limit \
    /sys/class/power_supply/eta696x/constant_charge_current_max \
    /sys/class/power_supply/eta696x/current_max \
    /sys/class/power_supply/mtk-master-charger/input_current_limit \
    /sys/class/power_supply/mtk-master-charger/constant_charge_current_max \
    /sys/class/power_supply/mtk-master-charger/current_max \
    /sys/class/power_supply/mtk-slave-charger/input_current_limit \
    /sys/class/power_supply/mtk-slave-charger/constant_charge_current_max \
    /sys/class/power_supply/mtk-slave-charger/current_max \
    /sys/class/power_supply/main/input_current_limit \
    /sys/class/power_supply/main/constant_charge_current_max \
    /sys/class/power_supply/main/current_max \
    /sys/class/power_supply/primary_chg/input_current_limit \
    /sys/class/power_supply/primary_chg/constant_charge_current_max \
    /sys/class/power_supply/primary_chg/current_max
  do
    write_limit "$node"
  done

  log "Oilsky Charge Limit 2A finished"
) &
