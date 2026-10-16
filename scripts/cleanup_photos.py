"""Explicit operator cleanup: Storage HTTP deletion precedes SQL metadata purge.

No scheduler; dry-run by default. Never print the service key or object paths.
"""
import argparse
import datetime
import json
import os
import urllib.error
import urllib.parse
import urllib.request


def cleanup(url, key, execute=False):
    if not url or not url.strip() or not key or not key.strip():
        raise ValueError("Missing operator configuration")
    endpoint = urllib.parse.urlparse(url)
    if endpoint.scheme != "https" and not (
        endpoint.scheme == "http" and endpoint.hostname in ("localhost", "127.0.0.1", "::1")
    ):
        raise ValueError("Use HTTPS or a loopback HTTP service")
    if endpoint.username or endpoint.password or endpoint.query or endpoint.fragment:
        raise ValueError("Invalid service URL")
    base = url.rstrip("/")

    def request(method, path, body=None):
        data = None if body is None else json.dumps(body).encode("utf-8")
        req = urllib.request.Request(base + path, data=data, method=method, headers={
            "apikey": key, "Authorization": "Bearer " + key,
            "Content-Type": "application/json",
        })
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read()
            return json.loads(raw) if raw else None

    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    query = urllib.parse.urlencode({
        "select": "id,path", "order": "id.asc", "limit": "100",
        "or": f"(status.eq.detached,and(status.eq.pending,expires_at.lte.{now}))",
    })
    rows = request("GET", "/rest/v1/photo_assets?" + query)
    if not isinstance(rows, list):
        raise ValueError("Invalid cleanup response")
    print(json.dumps({"eligible_ids": [row["id"] for row in rows], "count": len(rows)}))
    removed = 0
    for row in rows:
        if execute:
            request("DELETE", "/storage/v1/object/convert-photos", {"prefixes": [row["path"]]})
            request("POST", "/rest/v1/rpc/ieadpe_purge_photo_asset", {"asset_id": row["id"]})
            removed += 1
    return len(rows), removed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    try:
        found, removed = cleanup(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SERVICE_ROLE_KEY"], args.execute)
        print(f"Eligible batch: {found}; removed: {removed}. Repeat for further batches.")
    except (KeyError, ValueError, urllib.error.URLError):
        raise SystemExit("Cleanup failed. Verify operator configuration and service status; metadata is retained when Storage removal fails.") from None


if __name__ == "__main__":
    main()
