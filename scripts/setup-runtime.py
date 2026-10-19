# Silicon LogiX / SLX EchoBench
# Copyright (c) 2026 Marco Pezzullo (Silicon LogiX).
# License: Silicon LogiX Evaluation License 1.0. See LICENSE.
"""Install only the pinned upstream Renode files; never executes downloaded code."""
from pathlib import Path, PurePosixPath
import argparse, hashlib, json, os, shutil, tempfile, urllib.request, zipfile

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def destination(relative):
    name = PurePosixPath(relative)
    if name.is_absolute() or '..' in name.parts or '\\' in relative or ':' in relative:
        raise RuntimeError('Unsafe runtime path')
    if not relative.startswith('runtime/renode/'):
        raise RuntimeError('Runtime destination is outside Renode')
    path = ROOT.joinpath(*name.parts)
    if not path.resolve().is_relative_to(ROOT):
        raise RuntimeError('Runtime path escapes the checkout')
    current = path
    while current != ROOT:
        if current.is_symlink():
            raise RuntimeError('Runtime path contains a symlink')
        current = current.parent
    return path


def verify(lock):
    missing = []
    for relative, entry in lock['files'].items():
        path = destination(relative)
        if not path.is_file() or path.stat().st_size != entry['size'] or digest(path) != entry['sha256']:
            missing.append(relative)
    if missing:
        raise RuntimeError('Missing or changed pinned runtime file: ' + missing[0])
    return {'renode': lock['version'], 'verified_files': len(lock['files'])}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--archive', type=Path, help='Use an existing official ZIP instead of downloading')
    parser.add_argument('--verify-only', action='store_true')
    args = parser.parse_args()
    lock = json.loads((ROOT / 'runtime-dependencies.lock.json').read_text(encoding='utf-8'))
    if lock['schema'] != 'slx.echobench.upstream-runtime/v1':
        raise RuntimeError('Unsupported runtime lock')
    if args.verify_only:
        print(json.dumps(verify(lock)))
        return
    archive = args.archive
    if archive is None:
        cache = ROOT / 'build/downloads'
        cache.mkdir(parents=True, exist_ok=True)
        archive = cache / lock['archive_name']
        if not archive.exists():
            pending = archive.with_suffix('.download')
            try:
                count = 0
                with urllib.request.urlopen(lock['url'], timeout=120) as source, pending.open('wb') as output:
                    while block := source.read(1024 * 1024):
                        count += len(block)
                        if count > 160 * 1024 * 1024:
                            raise RuntimeError('Runtime download exceeds the declared limit')
                        output.write(block)
                if digest(pending) != lock['archive_sha256']:
                    raise RuntimeError('Runtime archive checksum mismatch')
                os.replace(pending, archive)
            finally:
                if pending.exists():
                    pending.unlink()
    if not archive.is_file() or digest(archive) != lock['archive_sha256']:
        raise RuntimeError('Runtime archive checksum mismatch; no runtime files were changed')
    build = ROOT / 'build'
    build.mkdir(exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix='renode-stage-', dir=build)).resolve()
    try:
        with zipfile.ZipFile(archive) as source:
            names = source.namelist()
            if len(names) != len(set(names)):
                raise RuntimeError('Duplicate runtime archive entries')
            for relative, entry in lock['files'].items():
                destination(relative)
                member = source.getinfo(entry['member'])
                if member.file_size != entry['size'] or member.file_size > 300 * 1024 * 1024:
                    raise RuntimeError('Runtime member size differs from the lock')
                if member.is_dir() or ((member.external_attr >> 16) & 0o170000) == 0o120000:
                    raise RuntimeError('Unexpected runtime member type')
                target = stage.joinpath(*PurePosixPath(relative).parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                with source.open(member) as src, target.open('wb') as dst:
                    shutil.copyfileobj(src, dst, 1024 * 1024)
                if digest(target) != entry['sha256']:
                    raise RuntimeError('Runtime member checksum mismatch')
        for relative in lock['files']:
            target = destination(relative)
            target.parent.mkdir(parents=True, exist_ok=True)
            os.replace(stage.joinpath(*PurePosixPath(relative).parts), target)
        print(json.dumps(verify(lock)))
    finally:
        if stage.parent != build.resolve() or not stage.name.startswith('renode-stage-'):
            raise RuntimeError('Unsafe staging cleanup target')
        shutil.rmtree(stage)


if __name__ == '__main__':
    main()
