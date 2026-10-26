function update --description 'APT, Snap, Flatpak, pip utilisateur et npm global'
    set -l helpers (path dirname (status filename))/helpers
    set -l updates
    set -l errors
    set -l pip_packages
    set -l npm_packages
    set -l npm_prefix
    set -l npm_as_root 0
    set -l npm_node
    set -l npm_cli
    set -l desktop_updates
    if not command -q python3
        echo '[-] python3 est nécessaire pour lire les résultats pip/npm et les dépôts APT.'
        return 1
    end
    echo '=== Vérification des mises à jour ==='
    if command -q apt-get
        echo '--- APT et dépôts VS Code / Chrome ---'
        if command python3 "$helpers/update_repos.py"
            if command sudo apt-get update --error-on=any
                set -l listing (command env LC_ALL=C apt list --upgradable)
                if test $status -ne 0
                    set -a errors 'vérification APT'
                else
                    set -l packages (string match -r '^\S+/.*' -- $listing)
                    if test (count $packages) -gt 0
                        printf '%s\n' $packages
                        set -a updates apt
                    else
                        echo '[+] APT à jour.'
                    end
                end
            else
                set -a errors 'actualisation APT'
            end
        else
            set -a errors 'configuration des dépôts APT'
        end
    end
    if command -q snap
        echo '--- Snap ---'
        set -l listing (command env LC_ALL=C snap refresh --list)
        if test $status -ne 0
            set -a errors 'vérification Snap'
        else if test (count $listing) -gt 1
            printf '%s\n' $listing
            set -a updates snap
        else
            echo '[+] Snap à jour.'
        end
    end
    if command -q flatpak
        echo '--- Flatpak ---'
        set -l listing (command flatpak remote-ls --updates --columns=application,version)
        if test $status -ne 0
            set -a errors 'vérification Flatpak'
        else if test (count $listing) -gt 0
            printf '%s\n' $listing
            set -a updates flatpak
        else
            echo '[+] Flatpak à jour.'
        end
    end
    if command python3 -m pip --version >/dev/null 2>&1
        echo '--- pip (paquets utilisateur) ---'
        if set -q VIRTUAL_ENV; or set -q CONDA_PREFIX
            echo '[*] Environnement Python actif : pip utilisateur ignoré.'
        else if command python3 -c 'import pathlib,sys,sysconfig; sys.exit(not (sys.prefix == sys.base_prefix and (pathlib.Path(sysconfig.get_path("stdlib")) / "EXTERNALLY-MANAGED").is_file()))'
            echo '[*] pip utilisateur ignoré : Python est géré par le système (PEP 668).'
            echo '    Les paquets pip utilisateur ne seront pas mis à jour ; utiliser des environnements virtuels ou pipx pour ces outils.'
        else
            set -l listing (command python3 -m pip list --outdated --user --format=json --disable-pip-version-check)
            if test $status -ne 0
                set -a errors 'vérification pip'
            else
                set pip_packages (printf '%s\n' $listing | command python3 "$helpers/update_packages.py" pip)
                if test $status -ne 0
                    set -a errors 'lecture des résultats pip'
                else if test (count $pip_packages) -gt 0
                    set -a updates pip
                else
                    echo '[+] pip utilisateur à jour.'
                end
            end
        end
    end
    if command -q npm
        echo '--- npm (paquets globaux, dernière version publiée) ---'
        set -l listing (command npm outdated --global --depth=0 --json)
        set -l npm_status $status
        # npm retourne 1 lorsque des mises à jour sont disponibles.
        if test $npm_status -gt 1
            set -a errors 'vérification npm'
        else
            set npm_packages (printf '%s\n' $listing | command python3 "$helpers/update_packages.py" npm)
            if test $status -ne 0
                set -a errors 'lecture des résultats npm'
            else if test (count $npm_packages) -gt 0
                set npm_prefix (command npm prefix --global)
                if test $status -ne 0; or not string match -q '/*' -- "$npm_prefix"
                    set -a errors 'lecture du préfixe npm'
                else
                    set npm_node (command -s node)
                    set npm_cli (path resolve (command -s npm))
                    if test -z "$npm_node"; or not test -f "$npm_cli"
                        set -a errors 'localisation de Node/npm'
                    else
                        for directory in "$npm_prefix" "$npm_prefix/lib" "$npm_prefix/lib/node_modules" "$npm_prefix/bin"
                            if test -d "$directory"; and not test -w "$directory"
                                set npm_as_root 1
                            end
                        end
                        if test $npm_as_root -eq 1
                            echo "[*] npm global nécessite sudo pour mettre à jour : $npm_prefix"
                        end
                        set -a updates npm
                    end
                end
            else
                echo '[+] npm global à jour.'
            end
        end
    end
    echo '--- Obsidian (.deb) / Burp (installation native) ---'
    set desktop_updates (command python3 "$helpers/update_desktop.py")
    if test $status -ne 0
        set -a errors 'vérification Obsidian/Burp'
    end
    if test (count $desktop_updates) -gt 0
        set -a updates desktop
    end
    if test (count $errors) -gt 0
        echo '[-] Vérifications incomplètes : '(string join ', ' $errors)
    end
    if test (count $updates) -eq 0
        if test (count $errors) -gt 0
            return 1
        end
        echo '[+] Tout est à jour.'
        return 0
    end
    echo 'Mises à jour disponibles : '(string join ', ' $updates)
    read -l -P 'Installer les mises à jour ? [Y/n] ' answer
    if test $status -ne 0
        echo '[*] Mise à jour annulée.'
        return 1
    end
    if not string match -qr '^[yY]?$' -- "$answer"
        echo '[*] Mise à jour annulée.'
        return 0
    end
    for manager in $updates
        switch $manager
            case apt
                # Ne pas nettoyer après un échec d’installation.
                command sudo apt-get upgrade -y
                and command sudo apt-get autoremove -y
                and command sudo apt-get clean
                or set -a errors 'mise à jour/nettoyage APT'
            case snap
                command sudo snap refresh; or set -a errors 'mise à jour Snap'
            case flatpak
                command flatpak update -y; or set -a errors 'mise à jour Flatpak'
            case pip
                # Pas de sudo ni de contournement de la protection Python système.
                command python3 -m pip install --user --upgrade $pip_packages
                or set -a errors 'mise à jour pip'
            case npm
                if test $npm_as_root -eq 1
                    # Conserver le Node et le préfixe de l’utilisateur sous sudo.
                    command sudo env "PATH="(path dirname "$npm_node")":/usr/local/bin:/usr/bin:/bin" "$npm_node" "$npm_cli" install --global --prefix "$npm_prefix" $npm_packages
                    or set -a errors 'mise à jour npm'
                else
                    command npm install --global --prefix "$npm_prefix" $npm_packages
                    or set -a errors 'mise à jour npm'
                end
            case desktop
                for item in $desktop_updates
                    command python3 "$helpers/update_desktop.py" --install "$item"
                    or set -a errors 'mise à jour Obsidian/Burp'
                end
        end
    end
    if test (count $errors) -gt 0
        echo '[-] Terminé avec erreurs : '(string join ', ' $errors)
        return 1
    end
    echo '[+] Mises à jour terminées.'
end
