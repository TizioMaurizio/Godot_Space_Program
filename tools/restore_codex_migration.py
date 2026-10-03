"""Verify/import a project-scoped Codex migration into a NEW Codex home.

Python 3.11+, standard library only. Never imports authentication/configuration.
Close Codex clients using the destination home before importing.
"""
import argparse
import hashlib
import json
import shutil
import sqlite3
from pathlib import Path


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def inside(root, relative):
    target = (root / relative).resolve()
    if not target.is_relative_to(root.resolve()):
        raise ValueError(f'Unsafe package path: {relative}')
    return target


def verify(package):
    manifest = json.loads((package / 'manifest.json').read_text(encoding='utf-8'))
    expected = manifest['files']
    actual = {p.relative_to(package).as_posix() for p in package.rglob('*') if p.is_file()}
    if actual != set(expected) | {'manifest.json'}:
        raise ValueError('Package has missing or unexpected files')
    for name, info in expected.items():
        path = inside(package, name)
        if path.stat().st_size != info['bytes'] or digest(path) != info['sha256']:
            raise ValueError(f'Checksum mismatch: {name}')
    return manifest


def remap_offsets(database, mappings):
    connection = sqlite3.connect(database)
    for table, columns in [('thread_turns', ['rollout_byte_offset', 'rollout_end_byte_offset']),
                           ('thread_history_projection_state', ['next_rollout_byte_offset'])]:
        for tid, mapping in mappings.items():
            for column in columns:
                rows = connection.execute(f'SELECT rowid,{column} FROM {table} WHERE thread_id=?', (tid,)).fetchall()
                for rowid, offset in rows:
                    if offset is None:
                        continue
                    if offset not in mapping:
                        raise ValueError(f'History offset does not match transcript: {table}/{tid}')
                    connection.execute(f'UPDATE {table} SET {column}=? WHERE rowid=?', (mapping[offset], rowid))
    connection.commit()
    connection.close()


def import_history(package, manifest, repo, destination):
    destination = destination.resolve()
    # Existing fresh login files are allowed, but never read, copied, or changed.
    protected = ['sessions', 'archived_sessions', 'session_index.jsonl', 'state_5.sqlite',
                 'thread_history_1.sqlite', 'goals_1.sqlite', 'memories_1.sqlite']
    if any((destination / name).exists() for name in protected):
        raise ValueError('Destination already has Codex history. Use a NEW, dedicated --codex-home.')
    if destination == Path(manifest['old_codex_home']).resolve():
        raise ValueError('Refusing to write to the original Codex home')
    destination.mkdir(parents=True, exist_ok=True)
    # Build in an isolated sibling directory; publish only after all validation passes.
    staging = destination.parent / (destination.name + '-migration-staging')
    staging.mkdir(exist_ok=False)
    shutil.copytree(package / 'codex', staging, dirs_exist_ok=True)
    mappings = {}
    for thread in manifest['threads']:
        path = inside(staging, thread['relative_rollout'])
        old_bytes = path.read_bytes()
        new_lines = []
        mapping = {0: 0}
        before = after = 0
        for line in old_bytes.splitlines(keepends=True):
            obj = json.loads(line)
            if obj.get('type') == 'session_meta':
                obj['payload']['cwd'] = str(repo)
                obj['payload']['runtime_workspace_roots'] = [str(repo)]
                obj['payload'].pop('git', None)
            new_line = (json.dumps(obj, ensure_ascii=False, separators=(',', ':')) + '\n').encode('utf-8')
            new_lines.append(new_line)
            before += len(line)
            after += len(new_line)
            mapping[before] = after
        path.write_bytes(b''.join(new_lines))
        mappings[thread['id']] = mapping
    history = staging / 'thread_history_1.sqlite'
    if history.exists():
        remap_offsets(history, mappings)
    connection = sqlite3.connect(staging / 'state_5.sqlite')
    for thread in manifest['threads']:
        connection.execute('UPDATE threads SET cwd=?,rollout_path=?,thread_section_id=NULL,project_id=NULL WHERE id=?',
                           (str(repo), str(inside(destination, thread['relative_rollout'])), thread['id']))
    connection.commit()
    connection.close()
    for path in staging.glob('*.sqlite'):
        connection = sqlite3.connect(path)
        try:
            if connection.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
                raise ValueError(f'Imported SQLite integrity failed: {path.name}')
        finally:
            connection.close()
    for source in staging.iterdir():
        target = destination / source.name
        if target.exists():
            raise ValueError(f'Refusing to overwrite {target}')
        shutil.move(str(source), str(target))
    staging.rmdir()
    print(f'Imported {len(manifest["threads"])} threads into {destination}')
    print(f'$env:CODEX_HOME = "{destination}"')
    print(f'codex resume {manifest["development_thread_id"]} --cd "{repo}"')


def restore_workspace(package, manifest, repo):
    # Only apply to the exact handoff commit and a clean checkout. Never overwrite user work.
    import subprocess
    def git(*args):
        return subprocess.check_output(['git', '-C', str(repo), *args], text=True).strip()
    if git('rev-parse', 'HEAD') != manifest['handoff_commit']:
        raise ValueError('Workspace restoration requires the exact handoff commit')
    if git('status', '--porcelain'):
        raise ValueError('Workspace restoration requires a clean checkout')
    for source in sorted((package / 'workspace').rglob('*')):
        if source.is_file():
            target = inside(repo, source.relative_to(package / 'workspace'))
            if '.git' in target.relative_to(repo).parts:
                raise ValueError('Refusing to write Git internals')
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
    print('Restored the captured source snapshot; implementation remains uncommitted.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', required=True, type=Path)
    parser.add_argument('--repo', type=Path)
    parser.add_argument('--codex-home', type=Path)
    parser.add_argument('--restore-workspace', action='store_true')
    parser.add_argument('--import-history', action='store_true')
    args = parser.parse_args()
    package = args.package.resolve()
    manifest = verify(package)
    print(f'All {len(manifest["files"])} payload hashes verified.')
    if args.restore_workspace or args.import_history:
        if not args.repo or not (args.repo / '.git').exists():
            parser.error('--repo must be a Git checkout')
        repo = args.repo.resolve()
        if args.restore_workspace:
            restore_workspace(package, manifest, repo)
        if args.import_history:
            if not args.codex_home:
                parser.error('--import-history requires a new dedicated --codex-home')
            import_history(package, manifest, repo, args.codex_home)


if __name__ == '__main__':
    main()
