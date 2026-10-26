"""Inspect local static artifacts only; never uploads or provisions hosting."""
from pathlib import Path
import argparse

APPLICATION_ROUTES = {
    '/login', '/register', '/home', '/converts', '/pending', '/admin', '/auth/callback',
    '/ministry', '/ministry/team', '/ministry/students',
    '/ministry/students/register', '/ministry/classes', '/ministry/attendance',
    '/ministry/handoff',
}


def inspect(root):
    root = Path(root)
    issues = []
    for required in ('index.html', '_redirects'):
        if not (root / required).is_file():
            issues.append(f'Missing {required}; build the web artifact first.')
    redirects = root / '_redirects'
    if redirects.is_file():
        rules = [line.split() for line in redirects.read_text().splitlines()
                 if line.strip() and not line.lstrip().startswith('#')]
        expected = [[route, '/', '200'] for route in APPLICATION_ROUTES]
        if sorted(rules) != sorted(expected):
            issues.append('Use only exact application-route proxies to / 200: '
                          + ', '.join(sorted(APPLICATION_ROUTES))
                          + '. Wildcard proxies can replace JS/WASM/assets with HTML.')
    files = list(root.rglob('*')) if root.is_dir() else []
    count = 0
    for file in files:
        if file.is_symlink():
            issues.append(f'Symlink not accepted: {file.relative_to(root)}')
        elif file.is_file():
            count += 1
            size = file.stat().st_size
            if size > 25 * 1024 * 1024:
                issues.append(f'{file.relative_to(root)}: {size} bytes exceeds 25 MiB. '
                              'Remove unused assets or rebuild smaller; do not enable paid storage.')
    if count > 20000:
        issues.append(f'{count} files exceeds the Free limit of 20000; reduce artifact files.')
    return issues


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', nargs='?', default='build/web')
    issues = inspect(parser.parse_args().directory)
    print('\n'.join(issues) if issues else 'Static artifact size/routing preflight passed (local only).')
    raise SystemExit(1 if issues else 0)
