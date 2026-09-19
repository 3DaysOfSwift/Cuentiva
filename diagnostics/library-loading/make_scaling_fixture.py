#!/usr/bin/env python3
"""Repeat real stories to benchmark 500 records; this generates no new content."""
import importlib.util
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('library_builder', root / 'scripts/build_library_dat.py')
if spec is None or spec.loader is None: raise RuntimeError('Cannot load binary builder')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)
destination = Path(sys.argv[1])
destination.mkdir(parents=True, exist_ok=True)
source = json.loads((root / 'Cuentiva/3 - App Resources/Books.json').read_text())
books = [dict(source[i % len(source)], id=f'benchmark-{i}') for i in range(500)]
(destination / 'Books.json').write_text(json.dumps(books, ensure_ascii=False, indent=2))
(destination / 'Library.dat').write_bytes(builder.Builder(books).data)
