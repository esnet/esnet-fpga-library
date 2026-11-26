#!/usr/bin/env python3
"""Write Make dependencies from regio-elaborate's loaded YAML paths."""
import argparse
import os
from pathlib import Path


def make_escape(value):
    return (str(value).replace('\\', '\\\\').replace('$', '$$')
            .replace('#', '\\#').replace(' ', '\\ ').replace(':', '\\:'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', required=True)
    parser.add_argument('--target-dir-variable', required=True)
    parser.add_argument('--paths', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    paths = sorted({os.path.relpath(Path(p).resolve()) for p in args.paths.read_text().splitlines() if p})
    # Empty rules let Make rebuild after an include is removed from the source.
    target = f'$({args.target_dir_variable})/{make_escape(Path(args.target).name)}'
    text = target + ': ' + ' '.join(map(make_escape, paths)) + '\n'
    text += ''.join(make_escape(path) + ':\n' for path in paths)
    temporary = args.output.with_suffix(args.output.suffix + '.tmp')
    temporary.write_text(text)
    temporary.replace(args.output)


if __name__ == '__main__':
    main()
