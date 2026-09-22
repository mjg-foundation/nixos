#!/usr/bin/env python3
"""Compare music libraries using paths and sizes; Python standard library only."""

import argparse
from collections import defaultdict
import json
import os
from pathlib import Path
import sys
import unicodedata
from urllib.parse import unquote, urlsplit


AUDIO = {'.aac', '.aiff', '.aif', '.alac', '.ape', '.flac', '.m4a', '.mp3',
         '.ogg', '.opus', '.wav', '.wma', '.dsf', '.dff', '.m4b'}
METADATA = {'.git', '.agents', '.codex', '__pycache__'}


def normalized(value):
    return unicodedata.normalize('NFC', value).casefold()


def resolve_location(value, gvfs_root=None):
    """Translate an already-mounted Linux GVfs MTP URI into a filesystem path."""
    if value.startswith('file://'):
        uri = urlsplit(value)
        if uri.netloc not in ('', 'localhost'):
            raise ValueError('Only local file:// URLs are supported.')
        return Path(unquote(uri.path)).resolve()
    if value.startswith('mtp://'):
        uri = urlsplit(value)
        runtime = os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')
        base = Path(gvfs_root) if gvfs_root else Path(runtime) / 'gvfs'
        target = normalized(unquote(uri.netloc))
        try:
            mounts = [p for p in base.iterdir()
                      if p.name.startswith('mtp:host=')
                      and normalized(unquote(p.name[len('mtp:host='):])) == target]
        except OSError as exc:
            raise ValueError(f'Cannot access GVfs mounts at {base}: {exc}') from exc
        if len(mounts) != 1:
            raise ValueError('MTP device is not uniquely mounted in GVfs. Unlock the '
                             'phone, enable file transfer, and open it in your file '
                             'manager, or supply its mounted filesystem path.')
        return mounts[0] / unquote(uri.path).lstrip('/')
    if '://' in value:
        raise ValueError('Supported locations: local paths, file:// URLs, mtp:// URLs.')
    return Path(value).expanduser().resolve()


def scan(root, excluded_names, excluded_paths):
    if not root.is_dir():
        raise ValueError(f'Not an accessible directory: {root}')
    files, errors = {}, []
    directories = 0

    def onerror(exc):
        errors.append(str(exc))

    for base, dirs, names in os.walk(root, onerror=onerror, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in excluded_names)
        directories += 1
        for name in sorted(names):
            path = Path(base) / name
            if name in excluded_names or path.resolve() in excluded_paths:
                continue
            try:
                # Do not follow symlinks outside the selected library.
                if path.is_symlink():
                    errors.append(f'Skipped symbolic link: {path}')
                elif path.is_file():
                    files[path.relative_to(root).as_posix()] = path.stat().st_size
            except OSError as exc:
                errors.append(str(exc))
        for name in dirs:
            if (Path(base) / name).is_symlink():
                errors.append(f'Skipped directory symbolic link: {Path(base) / name}')
        if directories % 100 == 0:
            print(f'  {directories} directories, {len(files)} files scanned', file=sys.stderr)
    return files, errors


def compare(left, right):
    common = left.keys() & right.keys()
    remaining_left = set(left) - common
    remaining_right = set(right) - common
    result = {
        'same_path_same_size': sum(left[p] == right[p] for p in common),
        'size_mismatches': [{'path': p, 'left_size': left[p], 'right_size': right[p]}
                            for p in sorted(common) if left[p] != right[p]],
        'path_variants': [], 'likely_moves': [],
    }

    def pair_unique(key, category):
        li, ri = defaultdict(list), defaultdict(list)
        for p in sorted(remaining_left):
            li[key(p, left)].append(p)
        for p in sorted(remaining_right):
            ri[key(p, right)].append(p)
        for k in sorted(li.keys() & ri.keys()):
            if len(li[k]) == len(ri[k]) == 1:
                p, q = li[k][0], ri[k][0]
                result[category].append({'left': p, 'right': q, 'size': left[p]})
                remaining_left.remove(p)
                remaining_right.remove(q)

    pair_unique(lambda p, fs: (normalized(p), fs[p]), 'path_variants')
    signature = lambda p, fs: (normalized(Path(p).name), fs[p])
    pair_unique(signature, 'likely_moves')

    # Search the entire other library, including files already matched above.
    # This identifies extra copies instead of incorrectly calling them missing songs.
    for side, remaining, own, other in (
        ('left', remaining_left, left, right),
        ('right', remaining_right, right, left),
    ):
        index = defaultdict(list)
        for p in sorted(other):
            index[signature(p, other)].append(p)
        extras, only = [], []
        for p in sorted(remaining):
            matches = index.get(signature(p, own), [])
            if matches:
                extras.append({'path': p, 'matches_in_other_library': matches})
            else:
                only.append(p)
        result[f'{side}_extra_copies'] = extras
        result[f'{side}_only'] = only
    result['exact_path_left_only'] = sorted(set(left) - set(right))
    result['exact_path_right_only'] = sorted(set(right) - set(left))
    return result


def render(report):
    result = report['differences']
    lines = ['Music library comparison', '']
    for side in ('left', 'right'):
        item = report[side]
        lines.append(f"{side.title()}: {item['root']}")
        lines.append(f"  {item['file_count']} files; {item['audio_count']} audio files")
    lines += ['', 'Compared paths and byte sizes, not file contents or audio tags.',
              'Moves, name variants, and extra copies are candidates, not hash-verified matches.',
              'Hidden files are included. Excluded names: ' + ', '.join(report['excluded_names']),
              'The script itself and explicitly selected report outputs are excluded.',
              '', f"Same path and size: {result['same_path_same_size']} files"]
    if report['errors']:
        lines += ['', 'INCOMPLETE SCAN — results may contain false differences:']
        lines += ['  ' + error for error in report['errors']]

    for side in ('left', 'right'):
        paths = result[f'{side}_only']
        lines += ['', f'Only on {side}: {len(paths)} files '
                  f'({sum(Path(p).suffix.lower() in AUDIO for p in paths)} audio)']
        groups = defaultdict(list)
        for p in paths:
            groups[str(Path(p).parent)].append(Path(p).name)
        for folder, names in sorted(groups.items()):
            lines.append(f'  {folder}/ — {len(names)} files')
            lines.extend('    ' + name for name in names)

        extras = result[f'{side}_extra_copies']
        lines += ['', f'Likely extra copies on {side}: {len(extras)} files']
        for item in extras:
            lines += ['  ' + item['path']]
            lines += ['    matches other library: ' + p for p in item['matches_in_other_library']]

    for key, title in [('path_variants', 'Case/Unicode path differences'),
                       ('likely_moves', 'Likely moved files')]:
        lines += ['', f'{title}: {len(result[key])} files (left -> right)']
        lines += [f"  {p['left']} -> {p['right']}" for p in result[key]]
    lines += ['', f"Same path, different size: {len(result['size_mismatches'])} files"]
    for item in result['size_mismatches']:
        lines.append(f"  {item['path']} — left {item['left_size']} bytes; right {item['right_size']} bytes")
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(prog="compare-music", description=__doc__, epilog=(
        'MTP URLs require an existing GVfs mount. Select the Music folder itself. '
        'Read-only scan; exit 0 on success (even with differences), 2 on errors.'))
    parser.add_argument('left', help='First library directory or mounted MTP URL')
    parser.add_argument('right', help='Second library directory or mounted MTP URL')
    parser.add_argument('-o', '--output', type=Path, help='Write text report here instead of stdout')
    parser.add_argument('--json', dest='json_output', type=Path, help='Also write detailed JSON')
    parser.add_argument('--exclude', action='append', default=[], metavar='NAME',
                        help='Exclude a file/directory basename at any depth; repeatable')
    args = parser.parse_args()
    try:
        left_root, right_root = resolve_location(args.left), resolve_location(args.right)
        excluded_names = METADATA | set(args.exclude)
        outputs = [p.resolve() for p in (args.output, args.json_output) if p]
        if len(set(outputs)) != len(outputs):
            raise ValueError('Text and JSON output paths must differ.')
        if Path(__file__).resolve() in outputs:
            raise ValueError('Report output must not overwrite this script.')
        # Avoid overwriting any existing library file, even when explicitly excluded.
        for p in outputs:
            if p.exists() and any(p.is_relative_to(root.resolve()) for root in (left_root, right_root)):
                raise ValueError(f'Refusing to overwrite an existing file inside a library: {p}')
        excluded_paths = {Path(__file__).resolve(), *outputs}
        report = {'excluded_names': sorted(excluded_names), 'errors': []}
        inventories = []
        for side, root in [('left', left_root), ('right', right_root)]:
            print(f'Scanning {side}: {root}', file=sys.stderr)
            files, errors = scan(root, excluded_names, excluded_paths)
            inventories.append(files)
            report[side] = {'root': str(root), 'file_count': len(files),
                            'audio_count': sum(Path(p).suffix.lower() in AUDIO for p in files)}
            report['errors'].extend(errors)
        report['differences'] = compare(*inventories)
        output = render(report)
        if args.output:
            args.output.write_text(output, encoding='utf-8')
            print(f'Text report: {args.output}', file=sys.stderr)
        else:
            print(output, end='')
        if args.json_output:
            args.json_output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n',
                                       encoding='utf-8')
            print(f'JSON report: {args.json_output}', file=sys.stderr)
        return 2 if report['errors'] else 0
    except (OSError, ValueError) as exc:
        print(f'Error: {exc}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
