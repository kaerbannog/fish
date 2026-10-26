"""Ajoute les dépôts APT absents ; conserve les configurations existantes."""
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit
from urllib.request import urlopen


REPOS = (
    ("vscode", "https://packages.microsoft.com/repos/code",
     "https://packages.microsoft.com/keys/microsoft.asc", {"amd64", "arm64", "armhf"}),
    ("google-chrome", "https://dl.google.com/linux/chrome/deb/",
     "https://dl.google.com/linux/linux_signing_key.pub", {"amd64"}),
)


def active_uris(root):
    files = [root / "sources.list"]
    files += sorted((root / "sources.list.d").glob("*.list"))
    files += sorted((root / "sources.list.d").glob("*.sources"))
    for path in files:
        if not path.is_file():
            continue
        text = path.read_text()
        if path.suffix != ".sources":
            for line in text.splitlines():
                match = re.match(r"^\s*deb\s+(?:\[[^]]*\]\s+)?(\S+)", line)
                if match:
                    yield match[1]
        else:
            for stanza in re.split(r"\n\s*\n", text):
                fields = {}
                last = None
                for line in stanza.splitlines():
                    if line.lstrip().startswith("#"):
                        continue
                    if line[:1].isspace() and last:
                        fields[last] += " " + line.strip()
                    elif ":" in line:
                        key, value = line.split(":", 1)
                        last = key.lower()
                        fields[last] = value.strip()
                if fields.get("enabled", "yes").lower() == "no":
                    continue
                if "deb" in fields.get("types", "").split():
                    yield from fields.get("uris", "").split()


def matches(name, uri):
    url = urlsplit(uri)
    if name == "vscode":
        return url.hostname == "packages.microsoft.com" and url.path.rstrip("/") == "/repos/code"
    return url.hostname == "dl.google.com" and url.path.rstrip("/") in (
        "/linux/chrome/deb", "/linux/chrome-stable/deb")


def main(root=Path("/etc/apt")):
    existing = list(active_uris(root))
    arch = subprocess.check_output(["dpkg", "--print-architecture"], text=True).strip()
    for name, uri, key_url, architectures in REPOS:
        if any(matches(name, entry) for entry in existing):
            print(f"[+] Dépôt {name} déjà présent.", flush=True)
            continue
        if arch not in architectures:
            print(f"[*] Dépôt {name} ignoré : architecture {arch} non prise en charge.", flush=True)
            continue
        destination = root / "sources.list.d" / f"update-{name}.sources"
        if destination.exists():
            raise RuntimeError(f"{destination} existe mais n’est pas actif ; vérifier son contenu")
        keyring = root / "keyrings" / f"update-{name}.gpg"
        print(f"[*] Ajout du dépôt {name} et de sa clé de signature…", flush=True)
        with tempfile.TemporaryDirectory(prefix="fish-update-") as directory:
            tmp = Path(directory)
            with urlopen(key_url, timeout=30) as response:
                (tmp / "key.asc").write_bytes(response.read())
            subprocess.run(["gpg", "--batch", "--dearmor", "--output", str(tmp / "key.gpg"),
                            str(tmp / "key.asc")], check=True)
            (tmp / "repo.sources").write_text(
                f"Types: deb\nURIs: {uri}\nSuites: stable\nComponents: main\n"
                f"Architectures: {arch}\nSigned-By: {keyring}\n")
            subprocess.run(["sudo", "install", "-d", "-m", "0755", str(root / "keyrings"),
                            str(root / "sources.list.d")], check=True)
            subprocess.run(["sudo", "install", "-m", "0644", str(tmp / "key.gpg"), str(keyring)], check=True)
            subprocess.run(["sudo", "install", "-m", "0644", str(tmp / "repo.sources"), str(destination)], check=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
        print(f"[-] Configuration des dépôts : {exc}", file=sys.stderr)
        sys.exit(1)
