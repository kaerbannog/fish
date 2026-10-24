function ip_recon
    if test (count $argv) -ne 1
        echo "Usage: ip_recon <IP>"
        return 1
    end
    
    set -l ip $argv[1]
    set -l final_url ""
    set -l domain ""
    
    # ─────────────────────────────────────────────
    # 1. Recherche du domaine via HTTP / HTTPS
    # ─────────────────────────────────────────────
    
    for proto in http https
        echo "[*] Test de $proto://$ip"
        
        set -l result (curl -k -L -sS \
                            --connect-timeout 5 \
                            --max-time 10 \
                            -o /dev/null \
                            -w '%{url_effective}' \
                            "$proto://$ip" 2>/dev/null)
        
        if test -n "$result"
            set -l host (string replace -r '^https?://([^/:]+).*' '$1' "$result")
            
            if test -n "$host"; and test "$host" != "$ip"
                set final_url "$result"
                set domain "$host"
                break
            end
        end
    end
    
    if test -z "$domain"
        echo "[-] Aucune redirection vers un domaine détectée."
        return 1
    end
    
    set -l proto (string replace -r '^(https?)://.*' '$1' "$final_url")
    set -l base_url "$proto://$domain"
    
    echo
    echo "[+] Redirection détectée : $final_url"
    echo "[+] Domaine             : $domain"
    echo "[+] URL                  : $base_url"
    echo
    
    # ─────────────────────────────────────────────
    # 2. Fonction de mise à jour de /etc/hosts
    # ─────────────────────────────────────────────
    
    function __ip_recon_update_hosts --no-scope-shadowing
        set -l new_hosts $argv
        set -l existing_hosts
        
        while read -l line
            set -l normalized (string replace -ar '\s+' ' ' (string trim "$line"))
            set -l fields (string split ' ' "$normalized")
            
            if test (count $fields) -ge 2
                if test "$fields[1]" = "$ip"
                    
                    for host in $fields[2..-1]
                    
                        if string match -q '#*' "$host"
                            break
                        end
                        
                        if test -n "$host"
                            if not contains -- "$host" $existing_hosts
                                set -a existing_hosts "$host"
                            end
                        end
                    end
                end
            end
        end < /etc/hosts
        
        # Ajoute les nouveaux domaines
        for host in $new_hosts
            if test -n "$host"
                if not contains -- "$host" $existing_hosts
                    set -a existing_hosts "$host"
                end
            end
        end
        
        set -l host_line "$ip "(string join ' ' $existing_hosts)
        
        # Reconstruit /etc/hosts sans les anciennes lignes de cette IP
        set -l tmpfile (mktemp)
        
        while read -l line
            set -l normalized (string replace -ar '\s+' ' ' (string trim "$line"))
            set -l fields (string split ' ' "$normalized")
            
            if test (count $fields) -ge 1
                if test "$fields[1]" = "$ip"
                    continue
                end
            end
            
            echo "$line" >> "$tmpfile"
            
        end < /etc/hosts
        
        echo "$host_line" >> "$tmpfile"
        
        sudo cp "$tmpfile" /etc/hosts
        set -l cp_status $status
        
        rm -f "$tmpfile"
        
        if test $cp_status -ne 0
            echo "[-] Impossible de modifier /etc/hosts."
            return 1
        end
        
        echo "[+] /etc/hosts :"
        echo "    $host_line"
    end
    
    # ─────────────────────────────────────────────
    # 3. Ajout du domaine principal
    # ─────────────────────────────────────────────
    
    read -l -P "Ajouter '$ip $domain' à /etc/hosts ? [y/N] " answer
    
    if string match -qr '^[yY]$' "$answer"
        
        __ip_recon_update_hosts "$domain"
        
        if test $status -ne 0
            functions -e __ip_recon_update_hosts
            return 1
        end
        
    else
        echo "[*] Domaine principal non ajouté."
    end
    
    # ─────────────────────────────────────────────
    # 4. Recherche des VHOST
    # ─────────────────────────────────────────────
    
    echo
    echo "[*] Lancement :"
    echo "    ffuf_subfinder $base_url -ac -s"
    echo
    
    set -l results (ffuf_subfinder "$base_url" -ac -s)
    
    if test (count $results) -eq 0
        echo "[-] Aucun sous-domaine trouvé."
        functions -e __ip_recon_update_hosts
        return 0
    end
    
    # ─────────────────────────────────────────────
    # 5. staging → staging.silentium.htb
    # ─────────────────────────────────────────────
    
    set -l subs
    
    for name in $results
    
        set name (string trim "$name")
        
        if test -z "$name"
            continue
        end
        
        # ffuf_subfinder renvoie par exemple "staging"
        set -l fqdn "$name.$domain"
        
        if not contains -- "$fqdn" $subs
            set -a subs "$fqdn"
        end
    end
    
    if test (count $subs) -eq 0
        echo "[-] Aucun sous-domaine exploitable."
        functions -e __ip_recon_update_hosts
        return 0
    end
    
    # ─────────────────────────────────────────────
    # 6. Affichage
    # ─────────────────────────────────────────────
    
    echo
    echo "[+] Sous-domaines trouvés :"
    
    for sub in $subs
        echo "    $sub"
    end
    
    echo
    
    # ─────────────────────────────────────────────
    # 7. Ajout groupé dans /etc/hosts
    # ─────────────────────────────────────────────
    
    read -l -P "Ajouter ces sous-domaines à /etc/hosts ? [y/N] " answer
    
    if string match -qr '^[yY]$' "$answer"
        
        __ip_recon_update_hosts "$domain" $subs
        
        if test $status -eq 0
            echo
            echo "[+] Terminé."
        end
        
    else
        echo "[*] Sous-domaines non ajoutés."
    end
    
    functions -e __ip_recon_update_hosts
end
