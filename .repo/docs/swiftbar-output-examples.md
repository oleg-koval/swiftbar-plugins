# SwiftBar Output Examples

These examples document representative output states for review and manual testing.

## Healthy

```text
SM | color=green tooltip="No urgent issue. Load: 2.14. Busy apps: 0."
---
Mac Health: Good | color=green
--MacBook Pro · macOS 15.5
--Uptime: 2 days
--Current issue: No urgent issue | color=green
---
Today's Recommendation
--No urgent action | color=green
---
CPU
--Load: 2.14
--Busy apps: 0
---
Memory
--Pressure: 32%
--Compressed: 1.2GB
---
Disk
--Free: 120 GB | color=green
```

## Warning

```text
⚡ 6.2 | color=orange tooltip="System load is rising. Load: 6.24. Busy apps: 0."
---
Mac Health: Needs attention | color=orange
--MacBook Pro · macOS 15.5
--Current issue: System load is rising | color=orange
---
Today's Recommendation
--Watch the trend | color=orange
```

## Critical

```text
🔥 1 | color=red tooltip="Busy app using too much CPU. Load: 9.42. Busy apps: 1."
---
Mac Health: Critical | color=red
--MacBook Pro · macOS 15.5
--Current issue: Busy app using too much CPU | color=red
---
Today's Recommendation
--Stop one confirmed busy app below | color=red
---
Triage
🔥 Busy Apps
```
