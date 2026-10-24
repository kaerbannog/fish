function update
    set_color yellow
    echo "=== Vérification des mises à jour disponibles ==="
    set_color normal
    
    set updates ""
    
    # apt
    if type -q apt
        echo "--- apt ---"
        sudo apt update -qq > /dev/null
        set apt_list (apt list --upgradable 2>/dev/null | grep -v "Listing...")
        if test (count $apt_list) -gt 0
            set_color cyan
            echo $apt_list | awk -F' ' '{print "• " $1 " → " $2 " (actuel: " $4 ")"}'
            set_color normal
            set updates "$updates apt"
        else
            set_color green; echo "✅ Aucune mise à jour apt."; set_color normal
        end
        echo
    end
    
    # snap
    if type -q snap
        echo "--- snap ---"
        set snap_list (snap refresh --list 2>/dev/null | tail -n +2)
        if test (count $snap_list) -gt 0
            set_color cyan
            echo $snap_list | awk '{print "• " $1 " → " $2}'
            set_color normal
            set updates "$updates snap"
        else
            set_color green; echo "✅ Aucune mise à jour snap."; set_color normal
        end
        echo
    end
    
    # flatpak
    if type -q flatpak
        echo "--- flatpak ---"
        set flatpak_list (flatpak remote-ls --updates 2>/dev/null)
        if test (count $flatpak_list) -gt 0
            set_color cyan
            echo $flatpak_list | awk '{print "• " $1 " → " $2}'
            set_color normal
            set updates "$updates flatpak"
        else
            set_color green; echo "✅ Aucune mise à jour flatpak."; set_color normal
        end
        echo
    end
    
    # pip (utilisateur)
    if type -q pip3
        echo "--- pip3 (user) ---"
        set pip_list (pip3 list --outdated --user --format=columns 2>/dev/null)
        if test (count $pip_list) -gt 1
            set_color cyan
            echo $pip_list | tail -n +3 | awk '{print "• " $1 " → " $3 " (actuel: " $2 ")"}'
            set_color normal
            set updates "$updates pip3"
        else
            set_color green; echo "✅ Aucune mise à jour pip3 (user)."; set_color normal
        end
        echo
    end
    
    if test -z "$updates"
        set_color green
        echo "✅ Tout est déjà à jour."
        set_color normal
        return 0
    end
    
    set_color yellow
    echo "Résumé : mises à jour dispo pour → $updates"
    set_color normal
    
    read -l -P "Voulez-vous lancer la mise à jour ? (Y/n) " reponse
    
    if test -z "$reponse"; or test (string match -iq "y*" $reponse)
        set_color yellow; echo "=== Lancement des mises à jour ==="; set_color normal
        if string match -q "*apt*" $updates
            sudo apt upgrade -y
            sudo apt autoremove -y
            sudo apt autoclean -y
            sudo apt clean -y
        end
        if string match -q "*snap*" $updates
            sudo snap refresh
        end
        if string match -q "*flatpak*" $updates
            flatpak update -y
        end
        if string match -q "*pip3*" $updates
            pip3 list --outdated --user --format=freeze | cut -d = -f 1 | xargs -n1 pip3 install --user -U
        end
        set_color green; echo "✅ Mise à jour + nettoyage terminés."; set_color normal
    else
        set_color red; echo "❌ Mise à jour annulée."; set_color normal
    end
end
