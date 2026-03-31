# System Health Monitor

A simple Bash script that snapshots your system's health in seconds — CPU, memory, disk, and the top-hungry process — with color-coded output and automatic alerts.

---

## Project Structure

```
system-monitor/
├── monitor.sh    
├── output.log     
└── README.md     
```

---

## Quick Start

```bash
# 1. Clone or copy the project
cd system-monitor

# 2. Make the script executable (one-time step)
chmod +x monitor.sh

# 3. Run it
./monitor.sh
```

---

## Sample Output

```
╔══════════════════════════════════╗
║    System Health Monitor         ║
║    2024-06-01 14:32:10           ║
╚══════════════════════════════════╝

   CPU Usage  : 23%
   Memory     : 45%
   Disk       : 60%
   Top Process: chrome

Output saved to: ./output.log
```

If a metric is **high**, you'll see a red alert:

```
CPU Usage  : 85%  

ALERT: CPU at 85%
```

---

## Configuration

Edit these variables at the top of `monitor.sh`:

| Variable     | Default | Meaning                        |
|--------------|---------|--------------------------------|
| `ALERT_CPU`  | `80`    | CPU % that triggers an alert   |
| `ALERT_MEM`  | `80`    | Memory % that triggers alert   |
| `ALERT_DISK` | `90`    | Disk % that triggers an alert  |
| `LOG_FILE`   | `./output.log` | Where logs are saved    |

---


## How Each Metric Is Collected

| Metric       | Tool Used | Notes                                      |
|--------------|-----------|--------------------------------------------|
| CPU Usage    | `top`     | Samples idle %, subtracts from 100         |
| Memory       | `free`    | `used / total * 100`                       |
| Disk         | `df`      | Checks the root `/` filesystem             |
| Top Process  | `ps`      | Sorted by CPU %, skips kernel threads      |

---

## Requirements

- Bash 4+
- Standard Unix tools: `top`, `free`, `df`, `ps`, `awk`, `bc`
- Works on: **Linux**, **macOS** (minor `top` flag differences may apply)

---

## Log Format (`output.log`)

Each run appends a block like:

```
[2024-06-01 14:32:10]
CPU Usage  : 23%
Memory     : 45%
Disk       : 60%
Top Process: chrome
---
```

If thresholds are breached, an `ALERT:` line is added before `---`.
