# Fonctions Fish

Fonctions personnelles pour la reconnaissance réseau et web, les environnements Python et les mises à jour système.

## Installation

Cloner le dépôt directement dans le dossier des fonctions Fish :

```fish
mkdir -p ~/.config/fish
git clone git@github.com:kaerbannog/fish.git ~/.config/fish/functions
```

Le dossier cible doit être absent ou vide. S’il contient déjà des fonctions, le sauvegarder avant de cloner :

```fish
mv ~/.config/fish/functions ~/.config/fish/functions.backup.(date +%Y%m%d-%H%M%S)
git clone git@github.com:kaerbannog/fish.git ~/.config/fish/functions
```

Fish charge automatiquement les fonctions à leur premier appel. Pour recharger une fonction déjà utilisée dans le terminal courant :

```fish
source ~/.config/fish/functions/ip_recon.fish
source ~/.config/fish/functions/ip_nmap.fish
```

## Fonctions disponibles

| Fonction | Utilisation | Rôle |
| --- | --- | --- |
| `ip_nmap` | `ip_nmap <IP>` | Scan TCP complet, services, ports ouverts et rapports XML/HTML. |
| `ip_recon` | `ip_recon <IP>` | Détection du domaine web, recherche de vhosts et ajout interactif à `/etc/hosts`. |
| `ffuf_subfinder` | `ffuf_subfinder <URL> [options ffuf]` | Recherche de vhosts par l’en-tête HTTP `Host`. |
| `ferox` | `ferox <URL> [options feroxbuster]` | Recherche de chemins web avec sélection de wordlist via `fzf`. |
| `enum4linux-ng` | `enum4linux-ng [options]` | Lance l’installation locale d’enum4linux-ng. |
| `autoenv` | `autoenv` | Crée si nécessaire un environnement Python `.env` dans le dossier courant et l’active. |
| `update` | `update` | Vérifie les mises à jour disponibles et propose leur installation. |

### Scan réseau : `ip_nmap`

```fish
ip_nmap 10.129.247.123
```

La fonction lance au premier plan :

1. La découverte des 65 535 ports TCP avec `-sT -p- -Pn -n -T4 --open`, sans besoin de `sudo`.
2. La détection des services et les scripts Nmap par défaut (`-sV -sC`) sur les ports ouverts uniquement.
3. La conversion du XML en HTML avec `xsltproc` et la feuille XSL locale de Nmap.

Les résultats Nmap et la liste des ports ouverts s’affichent dans le terminal. Chaque appel lance un nouveau scan ; aucun scan UDP n’est effectué. L’argument est une IP seule, sans port.

Les rapports sont enregistrés relativement au **dossier depuis lequel la commande est lancée** :

```text
recon/<IP>/<date-heure>-<suffixe>/
├── discovery.nmap / discovery.gnmap / discovery.xml
├── services.nmap / services.gnmap / services.xml
├── report.html
└── scan.log
```

Si aucun port ouvert n’est détecté, les fichiers `services.*` ne sont pas créés et le HTML est produit à partir de `discovery.xml`.

### Reconnaissance web : `ip_recon`

```fish
ip_recon 10.129.247.123
```

Teste HTTP puis HTTPS sur leurs ports standards pour trouver une redirection vers un domaine. Propose ensuite son ajout à `/etc/hosts`, lance `ffuf_subfinder` avec `-ac -s`, puis propose l’ajout des vhosts trouvés. L’écriture dans `/etc/hosts` utilise `sudo` après confirmation.

Sans redirection vers un domaine, la fonction s’arrête. Cette version attend une IP seule et ne gère pas `IP:port`. Elle ne lance pas Nmap : les deux fonctions sont indépendantes.

Pour cibler directement un service web sur un autre port avec un domaine connu et résolu :

```fish
ffuf_subfinder http://machine.htb:8080 -ac -s
```

`ffuf_subfinder` fait du fuzzing de vhosts HTTP ; il n’utilise pas l’outil Subfinder.

### Autres exemples

```fish
ferox http://machine.htb
enum4linux-ng -A 10.129.247.123
autoenv
deactivate
update
```

`ferox` utilise les extensions `php,html,js,json,txt,log`, 50 threads, exclut `/cgi-bin/` et active `--burp-replay` : prévoir le proxy Burp correspondant. Si la sélection de wordlist est annulée, il utilise `big.txt`.

`update` examine les gestionnaires présents parmi APT, Snap, Flatpak et pip utilisateur. La confirmation accepte par défaut avec Entrée. Pour APT, l’installation est suivie d’un nettoyage (`autoremove`, `autoclean`, `clean`).

## Dépendances et chemins locaux

Installer les outils correspondant aux fonctions utilisées :

| Fonction | Dépendances |
| --- | --- |
| `ip_nmap` | `nmap`, sa feuille `nmap.xsl`, `xsltproc`, `awk`, `tee`, `mktemp` |
| `ip_recon` | `curl`, `ffuf`, SecLists, `sudo` pour modifier `/etc/hosts` |
| `ffuf_subfinder` | `ffuf`, SecLists |
| `ferox` | `feroxbuster`, `fzf`, SecLists, proxy Burp pour le replay |
| `enum4linux-ng` | Installation locale d’enum4linux-ng et son environnement Python |
| `autoenv` | `python3` avec le module `venv` |
| `update` | Les gestionnaires de paquets à utiliser, `sudo` pour APT/Snap |

Les wordlists sont attendues ici :

```text
~/tools/SecLists/Discovery/DNS/subdomains-top1million-20000.txt
~/tools/SecLists/Discovery/Web-Content/
```

Le wrapper `enum4linux-ng.fish` contient des chemins absolus à adapter sur une autre machine :

```text
/home/grut/tools/enum4linux-ng/venv/bin/python
/home/grut/tools/enum4linux-ng/enum4linux-ng.py
```

## Mise à jour du dépôt

```fish
git -C ~/.config/fish/functions pull
```
