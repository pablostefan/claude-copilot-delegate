#!/usr/bin/env python3
"""Mescla um JSON de configurações no settings.json do Claude Code sem apagar nada.

- dicionários: mesclados recursivamente
- listas: união, mantendo a ordem (nada é removido)
- valores simples: o novo vence, e a troca é mostrada
Uso: merge_settings.py <destino settings.json> <trecho.json> [--dry-run]
"""
import json
import shutil
import sys
import time
from pathlib import Path


def merge(dst, src, path, changes):
    for key, value in src.items():
        here = f"{path}.{key}" if path else key
        if key not in dst:
            dst[key] = value
            changes.append(f"+ {here} = {json.dumps(value, ensure_ascii=False)}")
        elif isinstance(dst[key], dict) and isinstance(value, dict):
            merge(dst[key], value, here, changes)
        elif isinstance(dst[key], list) and isinstance(value, list):
            added = [v for v in value if v not in dst[key]]
            dst[key].extend(added)
            changes.extend(f"+ {here}[] {json.dumps(v, ensure_ascii=False)}" for v in added)
        elif dst[key] != value:
            changes.append(f"~ {here}: {json.dumps(dst[key])} -> {json.dumps(value)}")
            dst[key] = value


def main():
    args = [a for a in sys.argv[1:] if a != "--dry-run"]
    dry = "--dry-run" in sys.argv
    if len(args) != 2:
        sys.exit(__doc__)
    target, snippet = Path(args[0]).expanduser(), Path(args[1])
    current = json.loads(target.read_text()) if target.exists() else {}
    changes = []
    merge(current, json.loads(snippet.read_text()), "", changes)
    print("\n".join(changes) if changes else "nada a mudar")
    if dry or not changes:
        return
    if target.exists():
        backup = target.with_name(f"{target.name}.bak-{time.strftime('%Y%m%d-%H%M%S')}")
        shutil.copy2(target, backup)
        print(f"backup: {backup}")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(current, indent=2, ensure_ascii=False) + "\n")
    print(f"gravado: {target}")


if __name__ == "__main__":
    main()
