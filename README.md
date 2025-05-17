# NUMA Performance Test Framework

This repository provides an Bash script (`numa_test.sh`) to automate NUMA policy benchmarking on Linux systems. The script iterates over CPU binding, memory binding, and interleaving configurations, runs real-world workloads under each policy, and captures comprehensive logs for post-analysis.

---

## Features

* **Automatic NUMA Discovery**: Detects and prints available NUMA nodes using `numactl --hardware`.
* **Policy Types**: Supports three NUMA policies:

  * **cpu\_bind**: Bind processes to specific physical CPUs (`--physcpubind`).
  * **mem\_bind**: Allocate memory exclusively from specified NUMA nodes (`--membind`).
  * **interleave**: Distribute memory pages round-robin across nodes (`--interleave`).
* **Real-World Workloads**: Predefined workloads include:

  * **STREAM**: Memory bandwidth microbenchmark.
  * **Sysbench Memory**: Random memory read/write tests.
  * **FIO Random Read**: Filesystem + page cache I/O stress.
  * **Memcached + Memtier**: In-memory cache server with client load.
* **Extensible**: Easily add or override workloads via the associative `WORKLOADS` array.
* **CLI Options**:

  * Override default policies (`-p, --policies`).
  * Select specific workloads (`-w, --workloads`).
  * Configure output directory (`-o, --outdir`).
  * Choose serial (`-s, --serial`) vs. parallel execution.
  * Dry-run mode (`-d, --dry-run`) to preview commands.
* **Robust Logging**: Captures stdout and stderr per policy/workload into timestamped log files.

---

## Prerequisites

* **Linux** with `numactl` installed.
* Bash shell (version ≥ 4.2) supporting associative arrays.
* Workload binaries/tools installed and in `PATH` or current directory:

  * [STREAM](https://www.cs.virginia.edu/stream/)
  * `sysbench` (e.g., `sudo apt install sysbench`)
  * `fio` (e.g., `sudo apt install fio`)
  * `memcached` + `memtier_benchmark` (e.g., `sudo apt install memcached && pip install memtier_benchmark`)

---

## Usage

1. **Clone this repository** and make the script executable:

   ```bash
   git clone git@github.com:Lorickh/NUMA_autotest.git
   cd git@github.com:Lorickh/NUMA_autotest.git
   chmod +x numa_test.sh
   ```

2. **Run with defaults**:

   ```bash
   ./numa_test.sh
   ```

3. **Customize policies and workloads**:

   ```bash
   # Override policies and select specific workloads
   ./numa_test.sh \
     --policies "cpu_bind:0,mem_bind:1,interleave:all" \
     --workloads "stream,fio_randread" \
     --outdir "my_results" \
     --serial
   ```

4. **Dry-run** (preview commands without executing):

   ```bash
   ./numa_test.sh --dry-run
   ```

Logs will be saved under the specified output directory (default: `numa_results/`), organized by policy and workload.

---

## Adding New Workloads

1. Open `numa_test.sh` and locate the `WORKLOADS` associative array.
2. Add a new key-value pair:

   ```bash
   WORKLOADS[my_workload]="<your_command_here>"
   ```
3. Optionally include it via CLI:

   ```bash
   ./numa_test.sh --workloads "my_workload"
   ```

---

## Extending Capabilities

* **Background Load**: Integrate `stress-ng` or other tools before each run by inserting a pre-run hook in the main loop.
* **Reporting**: Parse logs and generate JSON/HTML summaries or visualize with Grafana.
* **Concurrency Control**: Limit parallel jobs with `wait -n` or incorporate job queue logic.

---

## Support & Contributions

Feel free to open issues or submit pull requests to extend workloads, improve logging, or integrate new reporting features.

---

© 2025 NUMA Test Framework Contributors
