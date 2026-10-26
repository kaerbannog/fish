"""Résumé pip/npm sur stderr, versions à installer sur stdout."""
import json
import re
import sys


def packages(kind, data):
    if kind == "pip":
        if not isinstance(data, list):
            raise ValueError("réponse pip invalide")
        for item in data:
            name, old, new = item["name"], item["version"], item["latest_version"]
            if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", name):
                raise ValueError("nom de paquet pip invalide")
            yield name, old, new, f"{name}=={new}"
    else:
        if not isinstance(data, dict) or "error" in data:
            raise ValueError(f"réponse npm invalide : {data}")
        for name, item in data.items():
            old, new = item.get("current", "absent"), item["latest"]
            if not re.fullmatch(r"(?:@[\w.-]+/)?[\w.-]+", name) or name.startswith("-"):
                raise ValueError("nom de paquet npm invalide")
            if old != new:
                yield name, old, new, f"{name}@{new}"


if __name__ == "__main__":
    try:
        rows = list(packages(sys.argv[1], json.load(sys.stdin)))
        for name, old, new, target in rows:
            print(f"• {name} : {old} → {new}", file=sys.stderr)
            print(target)
    except (ValueError, KeyError, TypeError) as exc:
        print(f"[-] {exc}", file=sys.stderr)
        sys.exit(1)
