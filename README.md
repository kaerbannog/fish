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
| `enum4linux-ng` | `enum4linux-ng [options]` | Installe si nécessaire dans `~/tools`, puis lance enum4linux-ng. |
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

`update` examine APT, Snap, Flatpak, pip utilisateur et npm global. `Y`, `y` ou Entrée confirment ; toute autre réponse annule. Une entrée fermée (EOF) annule aussi.

Sur une nouvelle machine APT, la fonction ajoute d’abord les dépôts officiels VS Code et Chrome manquants, avec leurs clés GPG dédiées et `Signed-By`, puis actualise les index. Les configurations actives `.list` et `.sources` existantes sont conservées ; les fichiers de sauvegarde et les entrées désactivées ne comptent pas comme des dépôts actifs. Chrome est ajouté uniquement sur `amd64`. Cela ne déclenche pas l’installation de Chrome ou VS Code. Cette préparation a lieu avant la confirmation des mises à jour.

Pour APT, une installation réussie est suivie de `autoremove` et `clean`. pip utilise une liste JSON des paquets utilisateur obsolètes ; il est ignoré lorsqu’un environnement virtuel Python/Conda est actif. Le marqueur `EXTERNALLY-MANAGED` (PEP 668) est détecté avant toute tentative : pip utilisateur est alors ignoré avec un message explicite. Ces paquets restent non mis à jour ; utiliser des environnements virtuels ou pipx pour ces outils. Aucun `--break-system-packages` n’est ajouté. npm met à jour uniquement les paquets globaux vers les versions `latest` affichées, sans modifier les projets locaux. Si les dossiers du préfixe global ne sont pas accessibles en écriture, le recours à `sudo` est annoncé avant confirmation ; le chemin de Node et le préfixe sont conservés explicitement. Un préfixe utilisateur accessible reste mis à jour sans `sudo`.

Les vérifications et installations échouées sont signalées et entraînent un code de retour non nul. Conserver le dossier `helpers/` avec `update.fish`.

`update` vérifie aussi l’installateur **Obsidian installé en `.deb`** et **Burp installé nativement**. Après confirmation, il télécharge les versions officielles et vérifie leur SHA-256 : installation du `.deb` Obsidian via APT, ou lancement de l’assistant Burp (conserver le dossier existant). Une application ouverte est laissée intacte et sa mise à jour est signalée comme non appliquée. Les versions stables de Burp sont utilisées, pas les Early Adopter.

Burp est recherché dans `~/BurpSuitePro`, `~/BurpSuite` et `~/BurpSuiteCommunity`. Pour un autre emplacement, définir `set -gx BURP_HOME /chemin/vers/BurpSuite`. Les installations Obsidian AppImage ne sont pas gérées ; celles sous Snap/Flatpak passent par leur gestionnaire habituel. Les logiciels absents ne sont pas installés.

Sources officielles : [dépôt VS Code](https://code.visualstudio.com/docs/setup/linux), [clés Google](https://www.google.com/linuxrepositories/), [versions Obsidian](https://github.com/obsidianmd/obsidian-releases/releases), [installateurs Burp](https://portswigger.net/burp/downloads).

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
| `update` | `python3`, les gestionnaires à utiliser, `sudo` pour APT/Snap ; `gpg` et les certificats CA pour ajouter les dépôts |

Les wordlists sont attendues ici :

```text
~/tools/SecLists/Discovery/DNS/subdomains-top1million-20000.txt
~/tools/SecLists/Discovery/Web-Content/
```

`enum4linux-ng` clone le [dépôt officiel](https://github.com/cddmp/enum4linux-ng) dans `~/tools/enum4linux-ng` s’il manque, crée un environnement Python `venv/` et y installe les dépendances. Sur Debian/Ubuntu, les dépendances système manquantes sont installées avec `sudo apt-get` (`git`, `python3`, `python3-venv`, `smbclient`, `samba-common-bin`). Une installation fonctionnelle est réutilisée. Au maximum une fois par jour, la fonction vérifie la dernière révision du dépôt officiel (délai réseau maximal de 8 secondes). Si elle est plus récente, `Y`, `y` ou Entrée acceptent la mise à jour ; les autres réponses conservent la version locale. La mise à jour utilise uniquement une avance rapide Git (`--ff-only`), puis actualise les dépendances du venv. Les modifications locales suivies ou un historique divergent empêchent cette mise à jour. Hors ligne, l’outil démarre avec sa version locale. Cette vérification compare les commits, ce qui détecte aussi les corrections sans changement du numéro de version. Le cache est stocké dans `.git/fish-version-check`.

Si l’outil ou ses dépendances manquent, la fonction propose l’installation : `Y`, `y` ou Entrée acceptent, toute autre réponse (ou EOF) annule. Après installation, la commande initiale est exécutée avec ses arguments. Aucun paramètre d’installation supplémentaire :

```fish
enum4linux-ng -A 10.129.247.123
```

## Mise à jour du dépôt

```fish
git -C ~/.config/fish/functions pull
```
