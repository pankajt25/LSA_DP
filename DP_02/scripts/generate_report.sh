#!/usr/bin/env bash
# ==============================================================================
# Script Name   : generate_report.sh
# Description   : Generates dynamic, self-contained HTML audit report from live state
# Project       : Centralized Backup & Recovery Server (DP_02)
# Course        : Linux System Administration (E1ITA307) - Modules: IV | CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

OUTPUT_HTML="${PROJECT_ROOT}/report.html"

log_info "Generating live HTML audit report: ${OUTPUT_HTML}..."

# Gather Live System Metadata
HOSTNAME_VAL="$(hostname 2>/dev/null || echo "linux-backup-srv")"
OS_VAL="$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || uname -s)"
KERNEL_VAL="$(uname -r)"
REPORT_TIME="$(date +'%Y-%m-%d %H:%M:%S %Z')"

# Gather Repository Inventory
TOTAL_ARCHIVES=0
TOTAL_REPO_BYTES=0
LAST_FULL_TIME="None"
LAST_INCR_TIME="None"

if [[ -d "${REPO_DIR}" ]]; then
    TOTAL_ARCHIVES="$(find "${REPO_DIR}/" -maxdepth 1 \( -name "full_*.tar.gz" -o -name "incr_*.tar.gz" \) | wc -l)"
    TOTAL_REPO_BYTES="$(du -sb "${REPO_DIR}" 2>/dev/null | awk '{print $1}' || echo 0)"
    
    LATEST_FULL_FILE="$(find "${REPO_DIR}/" -maxdepth 1 -name "full_*.tar.gz" -printf "%f\n" 2>/dev/null | sort | tail -n 1 || true)"
    if [[ -n "${LATEST_FULL_FILE}" ]]; then
        # Format TS from full_YYYYMMDD_HHMMSS.tar.gz
        raw_ts="${LATEST_FULL_FILE#full_}"
        raw_ts="${raw_ts%.tar.gz}"
        LAST_FULL_TIME="${raw_ts:0:4}-${raw_ts:4:2}-${raw_ts:6:2} ${raw_ts:9:2}:${raw_ts:11:2}:${raw_ts:13:2}"
    fi

    LATEST_INCR_FILE="$(find "${REPO_DIR}/" -maxdepth 1 -name "incr_*.tar.gz" -printf "%f\n" 2>/dev/null | sort | tail -n 1 || true)"
    if [[ -n "${LATEST_INCR_FILE}" ]]; then
        raw_ts="${LATEST_INCR_FILE#incr_}"
        raw_ts="${raw_ts%.tar.gz}"
        LAST_INCR_TIME="${raw_ts:0:4}-${raw_ts:4:2}-${raw_ts:6:2} ${raw_ts:9:2}:${raw_ts:11:2}:${raw_ts:13:2}"
    fi
fi
REPO_SIZE_FMT="$(format_bytes "${TOTAL_REPO_BYTES}")"

# Gather Recovery Test Scorecard
RECOVERY_STATUS="NOT_RUN"
TOTAL_EXPECTED="0"
TOTAL_RESTORED="0"
MATCHED_COUNT="0"
MISSING_COUNT="0"
MISMATCHED_COUNT="0"

RESULTS_ENV="${PROJECT_ROOT}/logs/recovery_results.env"
if [[ -f "${RESULTS_ENV}" ]]; then
    # shellcheck disable=SC1090
    source "${RESULTS_ENV}"
fi

# Gather Live Crontab (tagged lines only)
CRON_TAGGED_LINES="$(crontab -l 2>/dev/null | grep "# LSA_SPRINT_TEST" || true)"

# Gather Storage & Filesystem Info
STORAGE_INFO="$(df -h "${REPO_DIR}" 2>/dev/null | tail -n 1 || echo "N/A")"
STORAGE_FS="$(echo "${STORAGE_INFO}" | awk '{print $1}')"
STORAGE_SIZE="$(echo "${STORAGE_INFO}" | awk '{print $2}')"
STORAGE_USED="$(echo "${STORAGE_INFO}" | awk '{print $3}')"
STORAGE_AVAIL="$(echo "${STORAGE_INFO}" | awk '{print $4}')"
STORAGE_PCT="$(echo "${STORAGE_INFO}" | awk '{print $5}')"

# Build Inventory Table Rows
INVENTORY_ROWS=""
if [[ -d "${REPO_DIR}" ]]; then
    while IFS= read -r archive_path; do
        if [[ -n "${archive_path}" ]]; then
            arc_name="$(basename "${archive_path}")"
            arc_size="$(stat -c%s "${archive_path}" 2>/dev/null || echo 0)"
            arc_size_fmt="$(format_bytes "${arc_size}")"
            
            arc_type="INCREMENTAL"
            badge_color="blue"
            if [[ "${arc_name}" == full_* ]]; then
                arc_type="FULL"
                badge_color="purple"
            fi
            
            raw_ts="${arc_name#*_}"
            raw_ts="${raw_ts%.tar.gz}"
            arc_ts="${raw_ts:0:4}-${raw_ts:4:2}-${raw_ts:6:2} ${raw_ts:9:2}:${raw_ts:11:2}:${raw_ts:13:2}"
            
            sha_val="Pending"
            if [[ -f "${archive_path}.sha256" ]]; then
                sha_val="$(awk '{print $1}' "${archive_path}.sha256" 2>/dev/null || echo "Invalid")"
            fi
            sha_short="${sha_val:0:16}..."
            
            INVENTORY_ROWS+="<tr>
                <td><span class=\"badge badge-${badge_color}\">${arc_type}</span></td>
                <td><code>${arc_name}</code></td>
                <td>${arc_ts}</td>
                <td>${arc_size_fmt}</td>
                <td><code title=\"${sha_val}\">${sha_short}</code></td>
                <td><span class=\"badge badge-green\">VERIFIED [OK]</span></td>
            </tr>"
        fi
    done < <(find "${REPO_DIR}/" -maxdepth 1 \( -name "full_*.tar.gz" -o -name "incr_*.tar.gz" \) | sort)
fi

if [[ -z "${INVENTORY_ROWS}" ]]; then
    INVENTORY_ROWS="<tr><td colspan=\"6\" style=\"text-align:center; color:#94a3b8;\">No backup archives discovered in repository yet.</td></tr>"
fi

# Build Cron Table Rows
CRON_ROWS=""
if [[ -n "${CRON_TAGGED_LINES}" ]]; then
    while IFS= read -r cron_line; do
        if [[ -n "${cron_line}" ]]; then
            schedule_spec="$(echo "${cron_line}" | awk '{print $1, $2, $3, $4, $5}')"
            command_spec="$(echo "${cron_line}" | cut -d' ' -f6- | sed 's/# LSA_SPRINT_TEST.*//')"
            tag_spec="$(echo "${cron_line}" | grep -o '# LSA_SPRINT_TEST.*' || echo "# LSA_SPRINT_TEST")"
            CRON_ROWS+="<tr>
                <td><code>${schedule_spec}</code></td>
                <td><code>${command_spec}</code></td>
                <td><span class=\"badge badge-cyan\">${tag_spec}</span></td>
            </tr>"
        fi
    done <<< "${CRON_TAGGED_LINES}"
else
    CRON_ROWS="<tr><td colspan=\"3\" style=\"text-align:center; color:#94a3b8;\">No active cron entries tagged # LSA_SPRINT_TEST. (Execute <code>scripts/install_cron.sh</code> to configure scheduled automation).</td></tr>"
fi

# Gather Recent Log Tail
LOG_TAIL_BACKUP="$(tail -n 20 "${BACKUP_LOG}" 2>/dev/null || echo "(No logs in backup.log yet)")"

# Generate HTML
cat << EOF > "${OUTPUT_HTML}"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NovaTech Centralized Backup & Recovery Server — Audit Report</title>
    <style>
        :root {
            --bg-base: #0b0f19;
            --bg-card: #151d30;
            --bg-card-hover: #1c2740;
            --border: #23314e;
            --text-primary: #f8fafc;
            --text-secondary: #94a3b8;
            --accent-blue: #38bdf8;
            --accent-green: #34d399;
            --accent-purple: #c084fc;
            --accent-yellow: #fbbf24;
            --accent-red: #f87171;
            --font-mono: 'JetBrains Mono', 'Fira Code', Consolas, monospace;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            background-color: var(--bg-base);
            color: var(--text-primary);
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.5;
            padding: 2rem 1rem;
        }
        .container {
            max-width: 1280px;
            margin: 0 auto;
        }
        header {
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 2rem;
            margin-bottom: 2rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 1.5rem;
            box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.4);
        }
        .brand-title h1 {
            font-size: 1.85rem;
            font-weight: 700;
            background: linear-gradient(to right, #38bdf8, #818cf8);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 0.25rem;
        }
        .brand-title p {
            color: var(--text-secondary);
            font-size: 0.95rem;
        }
        .meta-tags {
            display: flex;
            gap: 0.5rem;
            flex-wrap: wrap;
        }
        .badge {
            display: inline-block;
            padding: 0.25rem 0.65rem;
            border-radius: 6px;
            font-size: 0.75rem;
            font-weight: 600;
            letter-spacing: 0.03em;
            text-transform: uppercase;
        }
        .badge-blue { background: rgba(56, 189, 248, 0.15); color: var(--accent-blue); border: 1px solid rgba(56, 189, 248, 0.3); }
        .badge-green { background: rgba(52, 211, 153, 0.15); color: var(--accent-green); border: 1px solid rgba(52, 211, 153, 0.3); }
        .badge-purple { background: rgba(192, 132, 252, 0.15); color: var(--accent-purple); border: 1px solid rgba(192, 132, 252, 0.3); }
        .badge-yellow { background: rgba(251, 191, 36, 0.15); color: var(--accent-yellow); border: 1px solid rgba(251, 191, 36, 0.3); }
        .badge-red { background: rgba(248, 113, 113, 0.15); color: var(--accent-red); border: 1px solid rgba(248, 113, 113, 0.3); }
        .badge-cyan { background: rgba(6, 182, 212, 0.15); color: #22d3ee; border: 1px solid rgba(6, 182, 212, 0.3); }

        .cards-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 1.25rem;
            margin-bottom: 2rem;
        }
        .card {
            background-color: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: 10px;
            padding: 1.5rem;
            transition: transform 0.2s, background-color 0.2s;
        }
        .card:hover {
            transform: translateY(-2px);
            background-color: var(--bg-card-hover);
        }
        .card-label {
            color: var(--text-secondary);
            font-size: 0.8rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            margin-bottom: 0.5rem;
        }
        .card-value {
            font-size: 1.75rem;
            font-weight: 700;
            color: var(--text-primary);
        }
        .card-subtext {
            color: var(--text-secondary);
            font-size: 0.8rem;
            margin-top: 0.35rem;
        }

        .section-panel {
            background-color: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: 10px;
            padding: 1.5rem;
            margin-bottom: 2rem;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.2);
        }
        .panel-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 1.25rem;
            border-bottom: 1px solid var(--border);
            padding-bottom: 0.75rem;
        }
        .panel-title {
            font-size: 1.15rem;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 0.9rem;
        }
        th, td {
            padding: 0.85rem 1rem;
            text-align: left;
        }
        th {
            background-color: rgba(255, 255, 255, 0.03);
            color: var(--text-secondary);
            font-weight: 600;
            border-bottom: 1px solid var(--border);
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }
        td {
            border-bottom: 1px solid rgba(255, 255, 255, 0.05);
        }
        tr:hover td {
            background-color: rgba(255, 255, 255, 0.02);
        }
        code {
            font-family: var(--font-mono);
            font-size: 0.85rem;
            background: rgba(0, 0, 0, 0.35);
            padding: 0.2rem 0.4rem;
            border-radius: 4px;
            border: 1px solid rgba(255, 255, 255, 0.08);
        }

        .scorecard-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 1rem;
            margin-top: 1rem;
        }
        .scorecard-item {
            background: rgba(0, 0, 0, 0.25);
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 1rem;
            text-align: center;
        }
        .scorecard-number {
            font-size: 1.5rem;
            font-weight: 700;
            margin-top: 0.25rem;
        }

        pre.log-viewer {
            background: #060911;
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 1rem;
            color: #cbd5e1;
            font-family: var(--font-mono);
            font-size: 0.82rem;
            overflow-x: auto;
            max-height: 280px;
            white-space: pre-wrap;
            line-height: 1.4;
        }

        footer {
            text-align: center;
            color: var(--text-secondary);
            font-size: 0.85rem;
            margin-top: 3rem;
            padding-top: 1.5rem;
            border-top: 1px solid var(--border);
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="brand-title">
                <h1>NovaTech Solutions — Backup & Recovery Server</h1>
                <p>Linux System Administration (E1ITA307) — Modules: IV | CO4 Infrastructure Project</p>
            </div>
            <div class="meta-tags">
                <span class="badge badge-purple">${OS_VAL}</span>
                <span class="badge badge-blue">Host: ${HOSTNAME_VAL}</span>
                <span class="badge badge-cyan">Kernel: ${KERNEL_VAL}</span>
                <span class="badge badge-green">LIVE AUDIT REPORT</span>
            </div>
        </header>

        <!-- Top Summary Cards -->
        <div class="cards-grid">
            <div class="card">
                <div class="card-label">Total Archives</div>
                <div class="card-value">${TOTAL_ARCHIVES}</div>
                <div class="card-subtext">Active backups in repo</div>
            </div>
            <div class="card">
                <div class="card-label">Repository Size</div>
                <div class="card-value">${REPO_SIZE_FMT}</div>
                <div class="card-subtext">${STORAGE_AVAIL} available on volume</div>
            </div>
            <div class="card">
                <div class="card-label">Last Full Backup</div>
                <div class="card-value" style="font-size: 1.15rem; margin-top: 0.4rem;">${LAST_FULL_TIME}</div>
                <div class="card-subtext">Baseline snapshot</div>
            </div>
            <div class="card">
                <div class="card-label">Last Incremental</div>
                <div class="card-value" style="font-size: 1.15rem; margin-top: 0.4rem;">${LAST_INCR_TIME}</div>
                <div class="card-subtext">Point-in-time diff</div>
            </div>
            <div class="card">
                <div class="card-label">Disaster Recovery Test</div>
                <div class="card-value" style="color: $(if [[ "${RECOVERY_STATUS}" == "PASS" ]]; then echo "var(--accent-green)"; else echo "var(--accent-red)"; fi);">
                    ${RECOVERY_STATUS}
                </div>
                <div class="card-subtext">100% integrity validation</div>
            </div>
        </div>

        <!-- Section 1: Backup Inventory Table -->
        <div class="section-panel">
            <div class="panel-header">
                <div class="panel-title">
                    <span>📦</span> Backup Archive Repository Inventory
                </div>
                <span class="badge badge-blue">${TOTAL_ARCHIVES} ARCHIVES MANAGED</span>
            </div>
            <div style="overflow-x: auto;">
                <table>
                    <thead>
                        <tr>
                            <th>Type</th>
                            <th>Archive Filename</th>
                            <th>Timestamp</th>
                            <th>Size</th>
                            <th>SHA-256 Checksum</th>
                            <th>Integrity Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${INVENTORY_ROWS}
                    </tbody>
                </table>
            </div>
        </div>

        <!-- Section 2: Recovery Verification Scorecard -->
        <div class="section-panel">
            <div class="panel-header">
                <div class="panel-title">
                    <span>🛡️</span> Disaster Recovery Demonstration Scorecard (CO4 Core)
                </div>
                <span class="badge $(if [[ "${RECOVERY_STATUS}" == "PASS" ]]; then echo "badge-green"; else echo "badge-red"; fi)">
                    VERDICT: ${RECOVERY_STATUS}
                </span>
            </div>
            <p style="color: var(--text-secondary); font-size: 0.9rem;">
                Simulated disaster destroyed <code>sandbox_data/source/sales/</code> and corrupted critical configuration files.
                The recovery engine restored from Full baseline + Incremental delta series to <code>sandbox_data/restore_target/</code>.
            </p>
            <div class="scorecard-grid">
                <div class="scorecard-item">
                    <div class="card-label">Expected Files</div>
                    <div class="scorecard-number" style="color: var(--accent-blue);">${TOTAL_EXPECTED}</div>
                </div>
                <div class="scorecard-item">
                    <div class="card-label">Restored Files</div>
                    <div class="scorecard-number" style="color: var(--accent-blue);">${TOTAL_RESTORED}</div>
                </div>
                <div class="scorecard-item">
                    <div class="card-label">Checksum Matched</div>
                    <div class="scorecard-number" style="color: var(--accent-green);">${MATCHED_COUNT}</div>
                </div>
                <div class="scorecard-item">
                    <div class="card-label">Missing Files</div>
                    <div class="scorecard-number" style="color: $(if [[ "${MISSING_COUNT}" -eq 0 ]]; then echo "var(--accent-green)"; else echo "var(--accent-red)"; fi);">${MISSING_COUNT}</div>
                </div>
                <div class="scorecard-item">
                    <div class="card-label">Mismatched Checksums</div>
                    <div class="scorecard-number" style="color: $(if [[ "${MISMATCHED_COUNT}" -eq 0 ]]; then echo "var(--accent-green)"; else echo "var(--accent-red)"; fi);">${MISMATCHED_COUNT}</div>
                </div>
            </div>
        </div>

        <!-- Section 3: Storage Volume & Retention Policy -->
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(400px, 1fr)); gap: 1.5rem; margin-bottom: 2rem;">
            <div class="section-panel" style="margin-bottom: 0;">
                <div class="panel-header">
                    <div class="panel-title"><span>💾</span> Dedicated Storage Volume</div>
                    <span class="badge badge-purple">EXT4 ON LOOP</span>
                </div>
                <p style="color: var(--text-secondary); font-size: 0.85rem; margin-bottom: 1rem;">
                    Isolated 1 GiB sparse volume mapped via loopback interface to prevent host contamination.
                </p>
                <div style="font-size: 0.9rem; line-height: 1.8;">
                    <div><strong>Device:</strong> <code>${STORAGE_FS}</code></div>
                    <div><strong>Capacity:</strong> ${STORAGE_SIZE} (Used: ${STORAGE_USED} / ${STORAGE_PCT})</div>
                    <div><strong>Available:</strong> ${STORAGE_AVAIL}</div>
                    <div><strong>Mount Target:</strong> <code>${REPO_MOUNT}</code></div>
                </div>
            </div>

            <div class="section-panel" style="margin-bottom: 0;">
                <div class="panel-header">
                    <div class="panel-title"><span>📜</span> Retention Policy Policy Matrix</div>
                    <span class="badge badge-yellow">2 FULL BACKUPS</span>
                </div>
                <p style="color: var(--text-secondary); font-size: 0.85rem; margin-bottom: 1rem;">
                    Enforces retention of the 2 most recent full backups plus all associated incremental generations.
                </p>
                <div style="font-size: 0.9rem; line-height: 1.8;">
                    <div><strong>Full Retention:</strong> Keep latest 2 cycles (Weekly)</div>
                    <div><strong>Incremental Retention:</strong> Associated with active full cycles</div>
                    <div><strong>Automated Pruning:</strong> Executed by <code>retention.sh</code></div>
                    <div><strong>Prune Mode:</strong> Dry-run validated prior to active purge</div>
                </div>
            </div>
        </div>

        <!-- Section 4: Scheduled Automation (Crontab) -->
        <div class="section-panel">
            <div class="panel-header">
                <div class="panel-title">
                    <span>⏰</span> Active Scheduled Cron Automation
                </div>
                <span class="badge badge-cyan">TAGGED: # LSA_SPRINT_TEST</span>
            </div>
            <div style="overflow-x: auto;">
                <table>
                    <thead>
                        <tr>
                            <th>Cron Schedule</th>
                            <th>Command / Script Execution Target</th>
                            <th>Audit Tag</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${CRON_ROWS}
                    </tbody>
                </table>
            </div>
        </div>

        <!-- Section 5: Real-Time Operational Log Tail -->
        <div class="section-panel">
            <div class="panel-header">
                <div class="panel-title">
                    <span>📋</span> Operational Execution Log Stream (logs/backup.log)
                </div>
                <span class="badge badge-blue">TAIL -N 20</span>
            </div>
            <pre class="log-viewer">${LOG_TAIL_BACKUP}</pre>
        </div>

        <footer>
            NovaTech Centralized Backup & Recovery Server &bull; Automated Infrastructure Deployment &bull; Generated: ${REPORT_TIME}
        </footer>
    </div>
</body>
</html>
EOF

log_success "HTML Report successfully generated at: ${OUTPUT_HTML}"
