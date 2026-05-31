#!/usr/bin/env python3
"""
samba_ad_exporter.py — Prometheus exporter for Samba Active Directory metrics.

Exposes port 9101 (configurable via EXPORTER_PORT env var).
Runs as root — required by samba-tool subcommands.
Collection interval: 60 seconds (background thread; HTTP server never blocks).

Environment variables:
  EXPORTER_PORT       (default 9101)
  COLLECT_INTERVAL    (default 60, seconds)
  SMB_CONF            (default /etc/samba/smb.conf)
  SAMBA_DB_DIR        (default /var/lib/samba)
  TLS_CERT            (default /var/lib/samba/private/tls/cert.pem)
    AD_BASE_DN          (optional; auto-discovered if unset)
"""

import json
import logging
import os
import re
import socket
import subprocess
import threading
import time
from datetime import datetime, timezone

from prometheus_client import (
    Counter,
    Gauge,
    start_http_server,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
log = logging.getLogger("samba_ad_exporter")

LISTEN_PORT = int(os.environ.get("EXPORTER_PORT", "9101"))
COLLECT_INTERVAL = int(os.environ.get("COLLECT_INTERVAL", "60"))
SMB_CONF = os.environ.get("SMB_CONF", "/etc/samba/smb.conf")
SAMBA_DB_DIR = os.environ.get("SAMBA_DB_DIR", "/var/lib/samba")
TLS_CERT = os.environ.get("TLS_CERT", "/var/lib/samba/private/tls/cert.pem")
AD_BASE_DN = os.environ.get("AD_BASE_DN")

SAM_LDB = os.path.join(SAMBA_DB_DIR, "private", "sam.ldb")

# --------------------------------------------------------------------------- #
# Metric definitions                                                           #
# --------------------------------------------------------------------------- #

repl_last_success = Gauge(
    "samba_ad_replication_last_success_timestamp_seconds",
    "Unix timestamp of last successful AD replication",
    ["nc", "partner"],
)
repl_age = Gauge(
    "samba_ad_replication_age_seconds",
    "Seconds elapsed since last successful AD replication",
    ["nc", "partner"],
)
repl_failures = Gauge(
    "samba_ad_replication_consecutive_failures_total",
    "Consecutive AD replication failure count",
    ["nc", "partner"],
)
repl_status = Gauge(
    "samba_ad_replication_status",
    "AD replication health (1 = ok, 0 = failed)",
    ["nc", "partner"],
)

fsmo_local = Gauge(
    "samba_ad_fsmo_role_local",
    "Whether this DC holds the FSMO role (1 = local, 0 = remote)",
    ["role"],
)
fsmo_total = Gauge(
    "samba_ad_fsmo_roles_held_total",
    "Total number of FSMO roles held by this DC",
)

svc_running = Gauge(
    "samba_ad_service_running",
    "Whether samba-ad-dc systemd service is active (1 = yes, 0 = no)",
)
proc_rss = Gauge(
    "samba_ad_process_rss_bytes",
    "Total RSS memory of samba-ad-dc processes in bytes",
)
db_size = Gauge(
    "samba_ad_database_size_bytes",
    "Size of a Samba database file in bytes",
    ["db"],
)

ad_join_ok = Gauge(
    "samba_ad_join_ok",
    "Result of 'net ads testjoin' (1 = ok, 0 = failed)",
)
ldap_query_duration = Gauge(
    "samba_ad_ldap_query_duration_seconds",
    "Duration of a local ldbsearch query against sam.ldb",
)
tls_cert_expiry = Gauge(
    "samba_ad_tls_cert_expiry_seconds",
    "Seconds until the LDAPS TLS certificate expires",
)

dns_forwarder_reachable = Gauge(
    "samba_ad_dns_forwarder_reachable",
    "Whether a configured DNS forwarder is reachable on TCP/53 (1 = yes, 0 = no)",
    ["forwarder"],
)
time_offset = Gauge(
    "samba_ad_time_offset_seconds",
    "System time offset from NTP reference as reported by chronyc",
)

object_count = Gauge(
    "samba_ad_object_count",
    "Number of AD objects by type",
    ["type"],
)
accounts_locked = Gauge(
    "samba_ad_accounts_locked_total",
    "Number of user accounts with the LOCKOUT flag set in userAccountControl",
)

pwd_complexity_enabled = Gauge(
    "samba_ad_password_settings_complexity_enabled",
    "Whether password complexity is enabled in the domain policy (1 = yes, 0 = no)",
)
pwd_lockout_threshold = Gauge(
    "samba_ad_password_settings_lockout_threshold",
    "Account lockout threshold configured in the domain policy (0 = disabled)",
)

active_connections = Gauge(
    "samba_ad_active_connections",
    "Current established TCP connections to Samba AD services",
    ["service", "port"],
)

auth_events_total = Counter(
    "samba_ad_auth_events_total",
    "Cumulative authentication events by service and result",
    ["service", "result"],
)
kerberos_requests_total = Counter(
    "samba_ad_kerberos_requests_total",
    "Cumulative Kerberos requests by request type",
    ["request_type"],
)
auth_last_scan_ts = Gauge(
    "samba_ad_auth_last_scan_timestamp_seconds",
    "Unix timestamp of the last samba auth-log scan",
)

last_collection_ts = Gauge(
    "samba_ad_exporter_last_collection_timestamp_seconds",
    "Unix timestamp of the last completed metrics collection",
)
collection_duration = Gauge(
    "samba_ad_exporter_collection_duration_seconds",
    "Wall-clock time taken by the last full collection run",
)
collection_errors = Counter(
    "samba_ad_exporter_collection_errors_total",
    "Number of errors encountered during metrics collection, by collector",
    ["collector"],
)

# --------------------------------------------------------------------------- #
# Helpers                                                                      #
# --------------------------------------------------------------------------- #

FSMO_ROLES = [
    "SchemaMaster",
    "InfrastructureMaster",
    "RidAllocationMaster",
    "PdcEmulation",
    "DomainNamingMaster",
    "DomainDnsZonesMaster",
    "ForestDnsZonesMaster",
]

_SERVICE_PORTS = {
    "88": "kerberos",
    "389": "ldap",
    "445": "smb",
    "464": "kpasswd",
    "636": "ldaps",
    "3268": "gc_ldap",
    "3269": "gc_ldaps",
}

_auth_last_read = 0.0
_discovered_ad_base_dn = None


def _run(cmd, timeout=30):
    """Execute *cmd* and return (stdout: str, returncode: int)."""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return result.stdout, result.returncode
    except subprocess.TimeoutExpired:
        log.warning("Command timed out: %s", cmd)
        return "", -1
    except Exception as exc:
        log.warning("Command failed %s: %s", cmd, exc)
        return "", -1


def _parse_samba_datetime(raw):
    """
    Parse a samba-tool timestamp string such as
    'Tue May 27 00:01:00 2026 UTC' or 'Tue May  6 09:00:00 2026 UTC'.
    Returns a UTC float timestamp, or None on parse failure.
    """
    raw = raw.strip()
    for fmt in ("%a %b %d %H:%M:%S %Y UTC", "%a %b  %d %H:%M:%S %Y UTC"):
        try:
            dt = datetime.strptime(raw, fmt).replace(tzinfo=timezone.utc)
            return dt.timestamp()
        except ValueError:
            continue
    log.debug("Could not parse samba datetime: %r", raw)
    return None


def _resolve_ad_base_dn():
    """
    Resolve the AD base DN. If AD_BASE_DN env var is set, use it.
    Otherwise auto-discover via ldbsearch against local sam.ldb rootDSE.
    """
    global _discovered_ad_base_dn

    if AD_BASE_DN:
        return AD_BASE_DN

    if _discovered_ad_base_dn:
        return _discovered_ad_base_dn

    out, rc = _run(
        [
            "ldbsearch",
            "-H",
            SAM_LDB,
            "-b",
            "",
            "-s",
            "base",
            "defaultNamingContext",
            "namingContexts",
        ],
        timeout=15,
    )
    if rc != 0:
        collection_errors.labels(collector="ad_base_dn_discovery").inc()
        return None

    for line in out.splitlines():
        m = re.match(r"defaultNamingContext:\s*(.+)", line)
        if m:
            _discovered_ad_base_dn = m.group(1).strip()
            log.info("Auto-discovered AD base DN: %s", _discovered_ad_base_dn)
            return _discovered_ad_base_dn

    for line in out.splitlines():
        m = re.match(r"namingContexts:\s*(DC=.+)", line)
        if m:
            _discovered_ad_base_dn = m.group(1).strip()
            log.info("Auto-discovered AD base DN from namingContexts: %s", _discovered_ad_base_dn)
            return _discovered_ad_base_dn

    collection_errors.labels(collector="ad_base_dn_discovery").inc()
    log.warning("Could not auto-discover AD base DN from local LDAP rootDSE")
    return None


# --------------------------------------------------------------------------- #
# Collectors                                                                   #
# --------------------------------------------------------------------------- #


def collect_replication():
    out, rc = _run(["samba-tool", "drs", "showrepl"])
    if rc != 0:
        collection_errors.labels(collector="replication").inc()
        return

    now = time.time()
    current_nc = None
    current_partner = None

    for line in out.splitlines():
        stripped = line.strip()

        # Naming context header: starts with DC= or CN= (but not CN=NTDS)
        if re.match(r"^(DC=|CN=Configuration|CN=Schema)", stripped):
            current_nc = stripped.rstrip(",")
            current_partner = None
            continue

        # Partner line: "SiteName\ServerName via RPC"
        partner_match = re.match(r"^[\w-]+\\([\w-]+)\s+via\s+RPC", stripped)
        if partner_match and current_nc:
            current_partner = partner_match.group(1)
            continue

        if not (current_nc and current_partner):
            continue

        # "Last attempt @ <datetime> was successful."
        success_match = re.search(r"Last attempt @ (.+?) was successful", stripped)
        if success_match:
            ts = _parse_samba_datetime(success_match.group(1))
            if ts:
                repl_last_success.labels(nc=current_nc, partner=current_partner).set(ts)
                repl_age.labels(nc=current_nc, partner=current_partner).set(now - ts)
            repl_status.labels(nc=current_nc, partner=current_partner).set(1)

        # "<N> consecutive failure(s)."
        fail_match = re.search(r"(\d+) consecutive failure", stripped)
        if fail_match:
            n = int(fail_match.group(1))
            repl_failures.labels(nc=current_nc, partner=current_partner).set(n)
            if n > 0:
                repl_status.labels(nc=current_nc, partner=current_partner).set(0)

        # "Last success @ <datetime>"
        last_match = re.match(r"Last success @ (.+)", stripped)
        if last_match:
            ts = _parse_samba_datetime(last_match.group(1))
            if ts:
                repl_last_success.labels(nc=current_nc, partner=current_partner).set(ts)
                repl_age.labels(nc=current_nc, partner=current_partner).set(now - ts)


def collect_fsmo():
    hostname = socket.gethostname().upper()
    out, rc = _run(["samba-tool", "fsmo", "show"])
    if rc != 0:
        collection_errors.labels(collector="fsmo").inc()
        return

    count = 0
    for role in FSMO_ROLES:
        pattern = rf"{role}Role owner: CN=NTDS Settings,CN=([^,]+)"
        match = re.search(pattern, out, re.IGNORECASE)
        if match:
            owner = match.group(1).upper()
            is_local = 1 if owner == hostname else 0
            fsmo_local.labels(role=role).set(is_local)
            count += is_local

    fsmo_total.set(count)


def collect_service():
    out, _ = _run(["systemctl", "is-active", "samba-ad-dc"])
    svc_running.set(1 if out.strip() == "active" else 0)


def collect_process_rss():
    out, rc = _run(["pgrep", "-f", "samba"])
    if rc != 0:
        proc_rss.set(0)
        return

    total_kb = 0
    for pid in out.strip().splitlines():
        try:
            with open(f"/proc/{pid.strip()}/status") as fh:
                for status_line in fh:
                    if status_line.startswith("VmRSS:"):
                        total_kb += int(status_line.split()[1])
                        break
        except (OSError, ValueError):
            pass

    proc_rss.set(total_kb * 1024)


def collect_db_size():
    for db_name in ("sam.ldb", "idmap.ldb"):
        path = os.path.join(SAMBA_DB_DIR, "private", db_name)
        try:
            db_size.labels(db=db_name).set(os.path.getsize(path))
        except OSError:
            collection_errors.labels(collector="db_size").inc()


def collect_ad_join():
    _, rc = _run(["net", "ads", "testjoin"], timeout=15)
    ad_join_ok.set(1 if rc == 0 else 0)


def collect_ldap_duration():
    start = time.monotonic()
    _, rc = _run(
        ["ldbsearch", "-H", SAM_LDB, "-b", "", "-s", "base", "(objectClass=*)"],
        timeout=10,
    )
    elapsed = time.monotonic() - start
    if rc == 0:
        ldap_query_duration.set(elapsed)
    else:
        collection_errors.labels(collector="ldap").inc()


def collect_tls_expiry():
    if not os.path.exists(TLS_CERT):
        return
    out, rc = _run(["openssl", "x509", "-enddate", "-noout", "-in", TLS_CERT])
    if rc != 0:
        collection_errors.labels(collector="tls").inc()
        return

    # notAfter=Jun 20 00:00:00 2026 GMT
    match = re.search(r"notAfter=(.+)", out)
    if not match:
        return
    try:
        # strptime does not accept 'GMT' timezone; treat it as UTC
        raw = match.group(1).strip().replace(" GMT", "")
        dt = datetime.strptime(raw, "%b %d %H:%M:%S %Y").replace(tzinfo=timezone.utc)
        tls_cert_expiry.set(dt.timestamp() - time.time())
    except ValueError as exc:
        log.warning("TLS expiry parse error: %s", exc)


def collect_dns_forwarders():
    """Read 'dns forwarder' IPs from smb.conf, probe each on TCP/53."""
    forwarders = []
    try:
        with open(SMB_CONF) as fh:
            for line in fh:
                m = re.match(r"\s*dns\s+forwarder\s*=\s*(.+)", line)
                if m:
                    forwarders = m.group(1).strip().split()
                    break
    except OSError:
        collection_errors.labels(collector="dns_forwarders").inc()
        return

    for ip in forwarders:
        try:
            sock = socket.create_connection((ip, 53), timeout=3)
            sock.close()
            dns_forwarder_reachable.labels(forwarder=ip).set(1)
        except OSError:
            dns_forwarder_reachable.labels(forwarder=ip).set(0)


def collect_time_offset():
    out, rc = _run(["chronyc", "tracking"])
    if rc != 0:
        collection_errors.labels(collector="chrony").inc()
        return

    m = re.search(r"System time\s*:\s*([\d.]+)\s+seconds\s+(fast|slow)", out)
    if m:
        offset = float(m.group(1))
        if m.group(2) == "slow":
            offset = -offset
        time_offset.set(offset)


def collect_object_counts():
    for obj_type in ("user", "group", "computer"):
        out, rc = _run(["samba-tool", obj_type, "list"])
        if rc == 0:
            count = sum(1 for line in out.splitlines() if line.strip())
            object_count.labels(type=obj_type).set(count)
        else:
            collection_errors.labels(collector=f"object_count_{obj_type}").inc()


def collect_locked_accounts():
    """
    Count accounts that have userAccountControl bit 0x10 (LOCKOUT) set.
    Queries the local sam.ldb via ldbsearch and parses UAC values in Python
    to avoid relying on OID bitwise filters which vary by Samba version.
    """
    ad_base_dn = _resolve_ad_base_dn()
    if not ad_base_dn:
        collection_errors.labels(collector="locked_accounts_base_dn").inc()
        return

    out, rc = _run(
        [
            "ldbsearch",
            "-H",
            SAM_LDB,
            "-b",
            ad_base_dn,
            "(&(objectClass=user)(!(objectClass=computer)))",
            "userAccountControl",
        ],
        timeout=20,
    )
    if rc != 0:
        collection_errors.labels(collector="locked_accounts").inc()
        return

    locked = 0
    for line in out.splitlines():
        m = re.match(r"userAccountControl:\s*(\d+)", line)
        if m:
            uac = int(m.group(1))
            if uac & 0x10:  # LOCKOUT bit
                locked += 1

    accounts_locked.set(locked)


def collect_password_settings():
    out, rc = _run(["samba-tool", "domain", "passwordsettings", "show"])
    if rc != 0:
        collection_errors.labels(collector="password_settings").inc()
        return

    complexity = 0
    lockout = 0

    for line in out.splitlines():
        lower = line.lower()
        if "complexity" in lower:
            complexity = 1 if "on" in lower else 0
        lockout_match = re.search(r"lockout threshold\s*[:\-]\s*(\d+)", lower)
        if lockout_match:
            lockout = int(lockout_match.group(1))

    pwd_complexity_enabled.set(complexity)
    pwd_lockout_threshold.set(lockout)


def collect_active_connections():
    """
    Count current established TCP connections to key Samba AD service ports.
    """
    out, rc = _run(["ss", "-Hnt", "state", "established"], timeout=10)
    if rc != 0:
        collection_errors.labels(collector="active_connections").inc()
        return

    counts = {port: 0 for port in _SERVICE_PORTS}
    for line in out.splitlines():
        parts = line.split()
        if len(parts) < 4:
            continue
        local_addr = parts[3]
        if "]:" in local_addr:
            port = local_addr.split("]:")[1]
        else:
            port = local_addr.rsplit(":", 1)[-1]
        if port in counts:
            counts[port] += 1

    for port, service in _SERVICE_PORTS.items():
        active_connections.labels(service=service, port=port).set(counts[port])


def collect_auth_events():
    """
    Parse samba-ad-dc journal lines and increment auth success/failure counters.
    Best with 'log level = 1 auth_json_audit:3' enabled in smb.conf.
    """
    global _auth_last_read

    now = time.time()
    if _auth_last_read == 0.0:
        since_secs = COLLECT_INTERVAL + 5
    else:
        since_secs = max(int(now - _auth_last_read) + 5, 5)

    out, rc = _run(
        [
            "journalctl",
            "--unit=samba-ad-dc",
            "--since",
            f"{since_secs} seconds ago",
            "--no-pager",
            "--output=cat",
        ],
        timeout=20,
    )
    _auth_last_read = now
    auth_last_scan_ts.set(now)

    if rc != 0:
        collection_errors.labels(collector="auth_events").inc()
        return

    for line in out.splitlines():
        # JSON log format from auth_json_audit
        if '"Authentication"' in line:
            try:
                data = json.loads(line)
                auth = data.get("Authentication", {})
                service = str(auth.get("serviceDescription", "unknown")).lower().strip()
                status = str(auth.get("status", "")).strip()
                auth_type = str(
                    auth.get("authType") or auth.get("authtype") or ""
                ).upper().strip()
                result = "success" if status == "NT_STATUS_OK" else "failure"
                auth_events_total.labels(service=service, result=result).inc()
                if "kerberos" in service and auth_type in ("AS-REQ", "TGS-REQ"):
                    kerberos_requests_total.labels(request_type=auth_type).inc()
            except (json.JSONDecodeError, TypeError, ValueError):
                continue
            continue

        # Fallback for text audit format
        if "Authentication:" in line and "serviceDescription=" in line:
            svc_m = re.search(r"serviceDescription=([^,\s]+)", line)
            sta_m = re.search(r"status=([^,\s]+)", line)
            typ_m = re.search(r"authDescription=([^,\s]+)", line)
            if svc_m and sta_m:
                service = svc_m.group(1).lower()
                status = sta_m.group(1)
                result = "success" if "STATUS_OK" in status else "failure"
                auth_events_total.labels(service=service, result=result).inc()
                if "kerberos" in service and typ_m:
                    auth_type = typ_m.group(1).upper()
                    if auth_type in ("AS-REQ", "TGS-REQ"):
                        kerberos_requests_total.labels(request_type=auth_type).inc()


# --------------------------------------------------------------------------- #
# Collection loop                                                              #
# --------------------------------------------------------------------------- #

_COLLECTORS = [
    ("replication", collect_replication),
    ("fsmo", collect_fsmo),
    ("service", collect_service),
    ("process_rss", collect_process_rss),
    ("db_size", collect_db_size),
    ("ad_join", collect_ad_join),
    ("ldap_duration", collect_ldap_duration),
    ("tls_expiry", collect_tls_expiry),
    ("dns_forwarders", collect_dns_forwarders),
    ("time_offset", collect_time_offset),
    ("object_counts", collect_object_counts),
    ("locked_accounts", collect_locked_accounts),
    ("password_settings", collect_password_settings),
    ("active_connections", collect_active_connections),
    ("auth_events", collect_auth_events),
]


def collect_all():
    start = time.monotonic()
    for name, fn in _COLLECTORS:
        try:
            fn()
        except Exception:
            log.exception("Unhandled error in collector '%s'", name)
            collection_errors.labels(collector=name).inc()

    elapsed = time.monotonic() - start
    collection_duration.set(elapsed)
    last_collection_ts.set(time.time())
    log.info("Collection complete in %.2fs", elapsed)


def _background_loop():
    while True:
        time.sleep(COLLECT_INTERVAL)
        collect_all()


# --------------------------------------------------------------------------- #
# Entry point                                                                  #
# --------------------------------------------------------------------------- #

if __name__ == "__main__":
    log.info("Starting samba-ad-exporter on port %d", LISTEN_PORT)

    # Run an initial collection synchronously before opening the HTTP server
    collect_all()

    # Start background collection thread (daemon so it exits with the process)
    t = threading.Thread(target=_background_loop, daemon=True, name="collector")
    t.start()

    # Start the prometheus_client HTTP server
    start_http_server(LISTEN_PORT)
    log.info("Metrics available at http://0.0.0.0:%d/metrics", LISTEN_PORT)

    # Keep main thread alive
    while True:
        time.sleep(3600)
