function enum4linux-ng --description 'Installe si nécessaire et lance enum4linux-ng depuis ~/tools'
    set -l tool_dir "$HOME/tools/enum4linux-ng"
    set -l python "$tool_dir/venv/bin/python"
    set -l script "$tool_dir/enum4linux-ng.py"

    set -l packages
    if not command -q git
        set -a packages git
    end
    if not command -q python3
        set -a packages python3 python3-venv
    else if not command python3 -c 'import venv, ensurepip' 2>/dev/null
        set -a packages python3-venv
    end
    if not command -q smbclient; or not command -q rpcclient
        set -a packages smbclient
    end
    if not command -q net; or not command -q nmblookup
        set -a packages samba-common-bin
    end
    set -l needs_install 0
    if test (count $packages) -gt 0; or not test -f "$script"; or not test -x "$python"
        set needs_install 1
    else if not command "$python" "$script" --help >/dev/null 2>&1
        set needs_install 1
    end
    if test $needs_install -eq 1
        read -l -P "enum4linux-ng absent ou incomplet. Installer dans $tool_dir ? [Y/n] " answer
        if test $status -ne 0
            echo '[*] Installation annulée.' >&2
            return 1
        end
        if not string match -qr '^[yY]?$' -- "$answer"
            echo '[*] Installation annulée.' >&2
            return 1
        end
    end
    if test (count $packages) -gt 0
        if not command -q apt-get
            echo "[-] Installer les dépendances système : "(string join ', ' $packages) >&2
            return 1
        end
        echo "[*] Installation des dépendances système : "(string join ', ' $packages) >&2
        command sudo apt-get update --error-on=any; or return 1
        command sudo apt-get install -y $packages; or return 1
    end

    if not test -f "$script"
        if test -e "$tool_dir"
            echo "[-] $tool_dir existe mais ne contient pas enum4linux-ng.py ; vérifier ce dossier." >&2
            return 1
        end
        command mkdir -p "$HOME/tools"; or return 1
        command git clone https://github.com/cddmp/enum4linux-ng.git "$tool_dir"; or return 1
    end
    if not test -x "$python"
        command python3 -m venv "$tool_dir/venv"; or return 1
    end
    if test -f "$tool_dir/venv/.requirements-pending"; or not command "$python" "$script" --help >/dev/null 2>&1
        command "$python" -m pip install -r "$tool_dir/requirements.txt"; or return 1
        command "$python" "$script" --help >/dev/null; or return 1
        command rm -f "$tool_dir/venv/.requirements-pending"
    end
    # Vérification quotidienne, sans bloquer l’usage hors ligne.
    if test -d "$tool_dir/.git"; and command -q timeout
        set -l checked "$tool_dir/.git/fish-version-check"
        set -l now (date +%s)
        set -l last 0
        if test -f "$checked"
            set -l saved (string trim < "$checked")
            if string match -qr '^[0-9]{1,12}$' -- "$saved"
                set last "$saved"
            end
        end
        if test (math "$now - $last") -ge 86400
            set -l origin (command git -C "$tool_dir" remote get-url origin 2>/dev/null)
            if contains -- "$origin" https://github.com/cddmp/enum4linux-ng https://github.com/cddmp/enum4linux-ng.git
                echo '[*] Vérification de la version officielle d’enum4linux-ng…' >&2
                # Limite aussi les tentatives hors ligne à une par jour.
                echo "$now" > "$checked"
                if command timeout 8s git -C "$tool_dir" -c credential.helper= -c core.askPass=true fetch --quiet https://github.com/cddmp/enum4linux-ng.git HEAD 2>/dev/null
                    set -l current (command git -C "$tool_dir" rev-parse HEAD)
                    set -l latest (command git -C "$tool_dir" rev-parse FETCH_HEAD)
                    if test "$current" != "$latest"
                        set -l changes (command git -C "$tool_dir" status --porcelain --untracked-files=no)
                        set -l status_ok $status
                        if test $status_ok -ne 0; or test (count $changes) -gt 0
                            echo '[*] Modifications locales : mise à jour automatique ignorée.' >&2
                        else if not command git -C "$tool_dir" merge-base --is-ancestor "$current" "$latest"
                            echo '[*] Historique local différent : mise à jour automatique ignorée.' >&2
                        else
                            echo "[+] Nouvelle révision : "(string sub -l 8 "$current")" → "(string sub -l 8 "$latest") >&2
                            read -l -P 'Mettre à jour enum4linux-ng ? [Y/n] ' answer
                            set -l answer_status $status
                            if test $answer_status -eq 0; and string match -qr '^[yY]?$' -- "$answer"
                                command git -C "$tool_dir" merge --ff-only "$latest"; or return 1
                                command touch "$tool_dir/venv/.requirements-pending"; or return 1
                                command "$python" -m pip install -r "$tool_dir/requirements.txt"
                                if test $status -ne 0
                                    # Permet de retenter la préparation au prochain appel.
                                    command rm -f "$checked"
                                    return 1
                                end
                                command "$python" "$script" --help >/dev/null; or return 1
                                command rm -f "$tool_dir/venv/.requirements-pending"
                            else
                                echo '[*] Version actuelle conservée.' >&2
                            end
                        end
                    else
                        echo '[+] enum4linux-ng est à jour.' >&2
                    end
                else
                    echo '[*] Vérification indisponible ; utilisation de la version locale.' >&2
                end
            end
        end
    end
    command "$python" "$script" $argv
end
