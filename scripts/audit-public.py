# Silicon LogiX / SLX EchoBench
# Copyright (c) 2026 Marco Pezzullo (Silicon LogiX).
# License: Silicon LogiX Evaluation License 1.0. See LICENSE.
"""Audit the GitHub source allowlist, fixed binaries and optional pinned runtime."""
from pathlib import Path, PurePosixPath
import argparse, hashlib, json, re

ROOT = Path(__file__).resolve().parents[1]
PERSONAL = re.compile(rb'C:[/\\]Users[/\\][A-Za-z_]|/home/[A-Za-z_]|/mnt/c/Users/[A-Za-z_]')
SECRET = re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|ghp_[A-Za-z0-9]{30,}|sk-proj-[A-Za-z0-9_-]{30,}|github_pat_[A-Za-z0-9_]{40,}')


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def safe_name(name):
    path = PurePosixPath(name)
    return not (path.is_absolute() or '..' in path.parts or '\\' in name or ':' in name)


def audit(root=ROOT, require_runtime=False):
    root = Path(root).resolve()
    policy = json.loads((root / 'repository-policy.json').read_text(encoding='utf-8'))
    lock = json.loads((root / 'runtime-dependencies.lock.json').read_text(encoding='utf-8'))
    if policy['schema'] != 'slx.echobench.public-repository/v1' or lock['schema'] != 'slx.echobench.upstream-runtime/v1':
        raise RuntimeError('Unsupported public repository policy')
    allowed = set(policy['files'])
    upstream = lock['files']
    if len(allowed) != len(policy['files']) or any(not safe_name(n) for n in allowed | set(upstream)):
        raise RuntimeError('Invalid policy path or duplicate file')
    seen = set()
    runtime_seen = set()
    errors = []
    largest = 0
    for path in root.rglob('*'):
        relative = path.relative_to(root).as_posix()
        parts = PurePosixPath(relative).parts
        if parts[0] in ['.git', 'build', 'dist'] or relative.startswith('godot/.godot/') or '__pycache__' in parts:
            continue
        if path.is_symlink():
            errors.append('Symlink: ' + relative)
            continue
        if not path.is_file():
            continue
        if relative in upstream:
            runtime_seen.add(relative)
            if path.stat().st_size != upstream[relative]['size'] or digest(path) != upstream[relative]['sha256']:
                errors.append('Upstream runtime checksum: ' + relative)
            continue
        if path.suffix in ['.uid', '.import'] and relative not in allowed:
            continue
        if relative not in allowed:
            errors.append('Unexpected public file: ' + relative)
            continue
        seen.add(relative)
        largest = max(largest, path.stat().st_size)
        if path.stat().st_size >= 100 * 1024 * 1024:
            errors.append('GitHub file-size limit: ' + relative)
        if any(p.lower() in ['private', 'workspace', 'keys'] for p in parts):
            errors.append('Private path: ' + relative)
        if path.suffix.lower() in ['.cpp', '.hpp', '.h', '.c', '.sv', '.v', '.a', '.o', '.obj', '.pdb', '.debug', '.blend', '.pem', '.key'] and not relative.startswith('licenses/') and relative != 'adapters/nde_adapter.cpp':
            errors.append('Private source/symbol: ' + relative)
        if relative in policy['binary_sha256'] and digest(path) != policy['binary_sha256'][relative]:
            errors.append('Pinned binary/asset checksum: ' + relative)
        if not relative.startswith('licenses/'):
            if path.suffix.lower() in ['.exe', '.dll']:
                if PERSONAL.search(path.read_bytes()):
                    errors.append('Personal build path: ' + relative)
            elif path.suffix.lower() in ['.md', '.gd', '.py', '.json', '.yml', '.yaml', '.cfg', '.godot', '.tscn', '.ps1', '.cmd', '.txt', '.cpp', '.cs', '.repl']:
                data = path.read_bytes()
                if PERSONAL.search(data):
                    errors.append('Personal path: ' + relative)
                if SECRET.search(data):
                    errors.append('Secret marker: ' + relative)
    for name in allowed - seen:
        errors.append('Missing public file: ' + name)
    missing_runtime = set(upstream) - runtime_seen
    if require_runtime and missing_runtime:
        errors.append('Pinned runtime missing; run scripts/setup-runtime.py')
    if errors:
        raise RuntimeError('\n'.join(sorted(errors)))
    return {'passed': True, 'files': len(seen), 'largest_git_file_mib': round(largest / 1048576, 2),
            'renode_files_installed': len(runtime_seen), 'renode_files_expected': len(upstream),
            'runtime_complete': not missing_runtime, 'private_core_source': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--require-runtime', action='store_true')
    args = parser.parse_args()
    print(json.dumps(audit(require_runtime=args.require_runtime), indent=2))
