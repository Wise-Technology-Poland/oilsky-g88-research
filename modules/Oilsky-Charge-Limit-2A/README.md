# Oilsky Charge Limit 2A

Magisk module that caps supported Android/MTK charging current sysfs nodes at
2A during late boot.

The module is intentionally conservative:

- it only writes to known current-limit sysfs candidates if they exist;
- it skips nodes that are not writable;
- it writes `2000000`, because Android/Linux power_supply current limits are
  normally exposed in microamps;
- it logs actions to `/data/adb/oilsky-charge-limit.log`.

This module does not guarantee that every charger IC path is limited. Confirm on
the target device by checking the log and by measuring charging current.
