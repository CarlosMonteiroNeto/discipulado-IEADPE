"""Strict target parsing and HTTP transport for local-only Supabase checks."""

from __future__ import annotations

import ipaddress
import json
import re
from dataclasses import dataclass, field
from urllib.error import HTTPError
from urllib.parse import unquote, urlsplit
from urllib.request import HTTPRedirectHandler, ProxyHandler, Request, build_opener


class UnsafeSupabaseTarget(ValueError):
    """A configured target is not an unambiguous loopback endpoint."""


@dataclass(frozen=True)
class DatabaseTarget:
    host: str
    port: int
    database: str
    user: str
    password: str = field(repr=False)


def _is_loopback_host(host: str) -> bool:
    if host.lower() == "localhost":
        return True
    try:
        return ipaddress.ip_address(host).is_loopback
    except ValueError:
        return False


def require_loopback_url(value: str, *, label: str = "API URL") -> str:
    """Validate an HTTP(S) URL and return it without a trailing slash.

    Only localhost and literal loopback IP addresses are accepted. Keeping the
    accepted host literal prevents DNS names from selecting a remote target.
    """

    if not isinstance(value, str) or not value or value != value.strip():
        raise UnsafeSupabaseTarget(f"Unsafe local Supabase {label}.")
    try:
        parts = urlsplit(value)
        port = parts.port
    except ValueError as error:
        raise UnsafeSupabaseTarget(f"Unsafe local Supabase {label}.") from error

    hostname = parts.hostname
    decoded_path = unquote(parts.path)
    if (
        parts.scheme.lower() not in {"http", "https"}
        or not hostname
        or parts.username is not None
        or parts.password is not None
        or parts.query
        or parts.fragment
        or ("?" in value or "#" in value)
        or "\\" in decoded_path
        or any(segment in {".", ".."} for segment in decoded_path.split("/"))
        or (port is not None and not 1 <= port <= 65535)
        or not _is_loopback_host(hostname)
    ):
        raise UnsafeSupabaseTarget(f"Unsafe local Supabase {label}.")
    return value.rstrip("/")


def parse_database_url(value: str) -> DatabaseTarget:
    """Parse one loopback PostgreSQL URI, rejecting libpq overrides.

    No URI query or fragment is accepted. The database name is a bare SQL
    identifier because ``psql -d`` also accepts libpq conninfo; accepting a
    decoded `key=value` string there could override the validated ``-h``.
    This rejects `hostaddr`, service files, connection options and multi-host
    endpoints instead of maintaining a deny-list of connection overrides.
    """

    if not isinstance(value, str) or not value or value != value.strip():
        raise UnsafeSupabaseTarget("Unsafe local Supabase database URL.")
    try:
        parts = urlsplit(value)
        host = parts.hostname
        port = parts.port or 5432
    except ValueError as error:
        raise UnsafeSupabaseTarget("Unsafe local Supabase database URL.") from error

    database = unquote(parts.path[1:]) if parts.path.startswith("/") else ""
    if (
        parts.scheme.lower() not in {"postgres", "postgresql"}
        or not host
        or "," in host
        or not _is_loopback_host(host)
        or parts.username is None
        or parts.password is None
        or not parts.username
        or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", database)
        or "/" in database
        or "?" in value
        or "#" in value
        or parts.query
        or parts.fragment
        or not 1 <= port <= 65535
    ):
        raise UnsafeSupabaseTarget("Unsafe local Supabase database URL.")
    return DatabaseTarget(
        host=host,
        port=port,
        database=database,
        user=unquote(parts.username),
        password=unquote(parts.password),
    )


class _NoRedirectHandler(HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, new_url):
        return None


def request_json(
    url: str,
    *,
    method: str = "GET",
    headers: dict[str, str] | None = None,
    body: bytes | None = None,
    timeout: float = 10,
) -> object:
    """Send one bounded JSON request directly to a validated loopback URL.

    An empty proxy map ignores all ambient proxy variables. Redirect handling
    is disabled so a local endpoint cannot redirect this request to a hosted
    service. HTTP error bodies are deliberately never read or included here.
    """

    target = require_loopback_url(url)
    request_headers = {"Accept": "application/json"}
    if headers:
        request_headers.update(headers)
    if body is not None and not any(
        key.lower() == "content-type" for key in request_headers
    ):
        request_headers["Content-Type"] = "application/json"
    request = Request(
        target,
        data=body,
        headers=request_headers,
        method=method.upper(),
    )
    opener = build_opener(ProxyHandler({}), _NoRedirectHandler())
    try:
        with opener.open(request, timeout=timeout) as response:
            status = getattr(response, "status", response.getcode())
            if status < 200 or status >= 300:
                raise HTTPError(target, status, "local request failed", {}, None)
            raw = response.read(1024 * 1024 + 1)
    except HTTPError:
        raise
    if len(raw) > 1024 * 1024:
        raise ValueError("Local Supabase JSON response exceeded the size limit.")
    if not raw:
        return None
    try:
        return json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ValueError("Local Supabase returned invalid JSON.") from error
