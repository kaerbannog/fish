"""Mises à jour officielles des installations .deb Obsidian et natives Burp."""
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import tempfile
from urllib.parse import urlencode
from urllib.request import Request, urlopen
import xml.etree.ElementTree as ET


def fetch(url):
    return json.load(urlopen(Request(url, headers={'User-Agent': 'fish-update'}), timeout=30))


def version(value):
    if not re.fullmatch(r'\d+(?:\.\d+)*', value):
        raise ValueError(f'Version non reconnue : {value}')
    return tuple(map(int, value.split('.')))


def installed_obsidian():
    try:
        p = subprocess.run(['dpkg-query', '-W', '-f=${Status}\t${Version}', 'obsidian'],
                           capture_output=True, text=True)
    except FileNotFoundError:
        return None
    if p.returncode == 0 and p.stdout.startswith('install ok installed\t'):
        return p.stdout.split('\t')[1].strip()
    return None


def burp_version(directory):
    return ET.parse(Path(directory) / '.install4j/i4jparams.conf').getroot().find('general').get('applicationVersion')


def check():
    old = installed_obsidian()
    if old:
        data = fetch('https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest')
        new = data['tag_name'].removeprefix('v')
        # dpkg handles Debian version suffixes correctly.
        if subprocess.run(['dpkg', '--compare-versions', old, 'lt', new]).returncode == 0:
            arch = subprocess.check_output(['dpkg', '--print-architecture'], text=True).strip()
            asset = next(a for a in data['assets'] if a['name'] == f'obsidian_{new}_{arch}.deb')
            digest = asset.get('digest', '')
            if not digest.startswith('sha256:'):
                raise ValueError('Empreinte SHA-256 Obsidian absente')
            yield dict(app='Obsidian', old=old, new=new, url=asset['browser_download_url'],
                       sha256=digest.split(':')[1])
        else:
            print('[+] Installateur Obsidian à jour.', file=sys.stderr)
    candidates = [Path(os.environ['BURP_HOME'])] if os.environ.get('BURP_HOME') else [
        Path.home() / 'BurpSuitePro', Path.home() / 'BurpSuite', Path.home() / 'BurpSuiteCommunity']
    for directory in candidates:
        if not (directory / '.install4j/i4jparams.conf').is_file():
            continue
        old = burp_version(directory)
        target = {'x86_64': 'Linux', 'aarch64': 'LinuxArm64'}[platform.machine()]
        data = fetch('https://portswigger.net/burp/releases/data?previousLastId=-1&lastId=-1&pageSize=20')
        builds = [b for r in data['ResultSet']['Results'] if 'Stable' in r['releaseChannels']
                  for b in r['builds'] if b['BuildCategoryId'] == 'desktop' and b['BuildCategoryPlatform'] == target]
        build = max(builds, key=lambda b: version(b['Version']))
        new = build['Version']
        if version(new) > version(old):
            url = 'https://portswigger.net/burp/releases/download?' + urlencode(dict(product='desktop', type=target, version=new))
            yield dict(app='Burp', old=old, new=new, url=url, sha256=build['Sha256Checksum'], directory=str(directory))
        else:
            print('[+] Burp stable à jour.', file=sys.stderr)


def install(item):
    app = item['app']
    # APT peut avoir déjà mis à jour Obsidian depuis la phase de vérification.
    if app == 'Obsidian':
        current = installed_obsidian()
        if current and subprocess.run(['dpkg', '--compare-versions', current, 'ge', item['new']]).returncode == 0:
            print('[+] Obsidian déjà à jour.', flush=True)
            return
    elif version(burp_version(item['directory'])) >= version(item['new']):
        print('[+] Burp déjà à jour.', flush=True)
        return
    # Ne pas fermer de force une application ou un projet ouvert.
    if app == 'Obsidian':
        processes = subprocess.check_output(['ps', '-eo', 'comm='], text=True).lower().splitlines()
        running = any(p.strip() == 'obsidian' for p in processes)
    else:
        processes = subprocess.check_output(['ps', '-eo', 'args='], text=True).splitlines()
        running = any(item['directory'] in p and ('burpsuite.jar' in p or '/BurpSuite' in p)
                      for p in processes if 'update_desktop.py' not in p)
    if running:
        raise RuntimeError(f'Fermer {app}, puis relancer update pour appliquer sa mise à jour.')
    print(f'[*] Téléchargement de {app} {item["new"]}…', flush=True)
    with tempfile.TemporaryDirectory(prefix='fish-desktop-update-') as tmp:
        destination = Path(tmp) / ('obsidian.deb' if app == 'Obsidian' else 'burp.sh')
        digest = hashlib.sha256()
        with urlopen(item['url'], timeout=60) as source, destination.open('wb') as output:
            while chunk := source.read(1024 * 1024):
                digest.update(chunk)
                output.write(chunk)
        if digest.hexdigest().lower() != item['sha256'].lower():
            raise RuntimeError(f'Empreinte SHA-256 incorrecte pour {app}')
        if app == 'Obsidian':
            subprocess.run(['sudo', 'apt-get', 'install', '-y', str(destination)], check=True)
            if installed_obsidian() != item['new']:
                raise RuntimeError('Version Obsidian attendue non installée')
        else:
            print(f'[*] Dans l’assistant Burp, conserver le dossier : {item["directory"]}', flush=True)
            subprocess.run(['sh', str(destination)], check=True)
            if burp_version(item['directory']) != item['new']:
                raise RuntimeError('Version Burp attendue non installée (assistant annulé ou autre dossier).')
        print(f'[+] {app} {item["new"]} installé.', flush=True)


if __name__ == '__main__':
    try:
        if len(sys.argv) == 3 and sys.argv[1] == '--install':
            install(json.loads(sys.argv[2]))
        else:
            for item in check():
                print(f'• {item["app"]} : {item["old"]} → {item["new"]}', file=sys.stderr)
                print(json.dumps(item))
    except (OSError, ValueError, KeyError, TypeError, AttributeError, StopIteration,
            RuntimeError, ET.ParseError, subprocess.SubprocessError) as exc:
        print(f'[-] Mise à jour des applications : {exc}', file=sys.stderr)
        sys.exit(1)
