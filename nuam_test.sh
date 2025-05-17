#!/usr/bin/env bash
# ============================================================================
# Industrial-Grade NUMA Performance Test Script
#
# This Bash script automates NUMA policy benchmarking by iterating over
# CPU binding, memory binding, and interleaving configurations. It launches
# real-world workloads under each policy, captures outputs, and organizes
# logs for post-analysis.
#
# Features:
#   - Auto-detects and prints NUMA topology for validation
#   - Supports cpu_bind, mem_bind, and interleave modes
#   - Predefined real-world workloads (STREAM, Sysbench, FIO, Memcached)
#   - Extensible workload definitions via associative array
#   - Configurable output directory and logging
#   - Placeholder for parallel vs. serial execution control
#   - Hooks for adding background CPU load or custom pre/post hooks
#
# Usage:
#   ./numa_test.sh [OPTIONS]
#
# OPTIONS:
#   -p, --policies    Comma-separated list of policy:type:nodes (overrides default)
#   -o, --outdir      Output directory for logs (default: "numa_results")
#   -w, --workloads   Comma-separated workload keys to run (default: all)
#   -s, --serial      Run workloads serially instead of in parallel
#   -d, --dry-run     Print commands without executing
#   -h, --help        Display this help and exit
#
# To extend:
#   - Add new policies to POLICIES array or via CLI
#   - Define additional workloads in WORKLOADS associative array
#   - Integrate stress-ng or other load generators before runs
#   - Customize logging format or add JSON/HTML reporting
# ============================================================================
set -euo pipefail

# ------------------------------
# 1. Print Help/Usage
# ------------------------------
function usage() {
    grep '^#' "$0" | sed 's/^# \{0,1\}//'
    exit 1
}

# ------------------------------
# 2. Parse Command-Line Options
# ------------------------------
OUTDIR="numa_results"
SERIAL=false
DRYRUN=false

# Default policies and workloads
declare -a POLICIES=(
  "cpu_bind:0,1"
  "mem_bind:2"
  "interleave:all"
)
declare -A WORKLOADS=(
  [stream]="./stream -M 64"
  [sysbench_mem]="sysbench memory --memory-oper=write --memory-block-size=1M --memory-total-size=1G run"
  [fio_randread]="fio --name=randread --ioengine=libaio --rw=randread --bs=4k --size=1G --numjobs=4 --runtime=60 --group_reporting"
  [memcached]="bash -c 'memcached -t4 -m1024 & sleep 2; memtier_benchmark --server=127.0.0.1 --port=11211 --protocol=memcache_text --threads=4 --test-time=30; kill \$!'"
)
SELECTED_WORKLOADS=()

while [[ "$#" -gt 0 ]]; do
    key="$1"
    case $key in
        -p|--policies)
            IFS="," read -r -a POLICIES <<< "$2"
            shift 2
            ;;
        -w|--workloads)
            IFS="," read -r -a SELECTED_WORKLOADS <<< "$2"
            shift 2
            ;;
        -o|--outdir)
            OUTDIR="$2"
            shift 2
            ;;
        -s|--serial)
            SERIAL=true
            shift
            ;;
        -d|--dry-run)
            DRYRUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# If specific workloads are requested, filter the associative array keys
if [[ ${#SELECTED_WORKLOADS[@]} -gt 0 ]]; then
    declare -A FILTERED=()
    for w in "${SELECTED_WORKLOADS[@]}"; do
        if [[ -n "${WORKLOADS[$w]:-}" ]]; then
            FILTERED[$w]="${WORKLOADS[$w]}"
        else
            echo "Warning: workload '$w' not defined, skipping."
        fi
    done
    WORKLOADS=()
    for k in "${!FILTERED[@]}"; do
        WORKLOADS[$k]="${FILTERED[$k]}"
    done
fi

# ------------------------------
# 3. Detect & Print NUMA Topology
# ------------------------------
function detect_numa_nodes() {
    echo "=== Detected NUMA Topology ==="
    numactl --hardware | awk '/available:/ {print; exit}'
    echo
}

detect_numa_nodes

# ------------------------------
# 4. Prepare Output Directory
# ------------------------------
mkdir -p "${OUTDIR}"

# ------------------------------
# 5. Main Execution Loop
# ------------------------------
for policy in "${POLICIES[@]}"; do
    IFS=":" read -r ptype pnodes <<< "${policy}"
    echo "--- Policy: ${ptype} on nodes ${pnodes} ---"

    # Build numactl command prefix based on policy type
    case "${ptype}" in
        cpu_bind)
            PREFIX=(numactl --physcpubind="${pnodes}")
            ;;  # Bind process to specified physical CPU nodes
        mem_bind)
            PREFIX=(numactl --membind="${pnodes}")
            ;;  # Allocate all memory from specified NUMA node
        interleave)
            PREFIX=(numactl --interleave="${pnodes}")
            ;;  # Distribute memory pages across specified nodes round-robin
        *)
            echo "Error: Unsupported policy type '${ptype}'"
            exit 1
            ;;
    esac

    # Iterate over each defined workload
    for wname in "${!WORKLOADS[@]}"; do
        cmd=${WORKLOADS[$wname]}
        logfile="${OUTDIR}/${ptype}_${pnodes}_${wname}.log"

        echo "[$(date +'%F %T')] Running workload: ${wname}" 1>&2
        echo "Command: ${PREFIX[*]} ${cmd}" 1>&2
        echo "Logfile: ${logfile}" 1>&2

        # Dry-run mode prints commands without execution
        if [[ "$DRYRUN" == true ]]; then
            continue
        fi

        # Execute workload (in background if not in serial mode)
        run_block() {
            {
                echo "=== Policy=${ptype}:${pnodes}, Workload=${wname} ==="
                echo
                "${PREFIX[@]}" ${cmd}
            } &> "${logfile}"
        }

        if [[ "$SERIAL" == true ]]; then
            run_block
        else
            run_block &
            # Optional: limit parallel jobs to avoid oversubscription
            # wait -n
        fi
    done

    # If parallel execution, wait for all workloads of this policy
    if [[ "$SERIAL" == false ]]; then
        wait
    fi

    echo
done

# ------------------------------
# 6. Completion Message
# ------------------------------
echo "All tests completed. Logs are available in '${OUTDIR}'."
# ============================================================================
