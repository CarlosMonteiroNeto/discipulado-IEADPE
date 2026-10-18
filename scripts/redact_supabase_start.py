#!/usr/bin/env python3
"""Redact credentials from line-oriented Supabase CLI startup output."""

from __future__ import annotations

import re
import sys


_SECRET_FIELD = re.compile(
    r"(?i)(?P<prefix>\b(?:supabase_)?(?:anon(?:ymous)?[ _-]*key|"
    r"service[ _-]*role[ _-]*key|jwt[ _-]*secret|secret[ _-]*key)[\"']?\s*[:=]\s*)"
    r"(?P<value>[^\r\n]*)"
)
_POSTGRES_URL_PASSWORD = re.compile(
    r"(?i)(?P<prefix>\bpostgres(?:ql)?://[^:/@\s?#]+:)"
    r"(?P<password>[^@\s/?#]+)(?P<suffix>@)"
)
_JWT_TOKEN = re.compile(
    r"(?<![A-Za-z0-9_-])eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+"
    r"(?![A-Za-z0-9_-])"
)
_SUPABASE_KEY_TOKEN = re.compile(r"(?i)\bsb_(?:secret|publishable)_[a-z0-9_-]+")


def redact_line(line: str) -> str:
    line = _SECRET_FIELD.sub(r"\g<prefix>[redacted]", line)
    line = _POSTGRES_URL_PASSWORD.sub(r"\g<prefix>[redacted]\g<suffix>", line)
    line = _JWT_TOKEN.sub("[redacted]", line)
    return _SUPABASE_KEY_TOKEN.sub("[redacted]", line)


def main() -> None:
    for line in sys.stdin:
        sys.stdout.write(redact_line(line))


if __name__ == "__main__":
    main()
