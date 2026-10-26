function ip_nmap --description 'Scan TCP complet, services, XML et HTML'
    if test (count $argv) -ne 1
        echo "Usage: ip_nmap <IP>"
        return 1
    end
    set -l ip $argv[1]
    set -l family
    if string match -qr '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' -- "$ip"
        for octet in (string split . "$ip")
            if test "$octet" -gt 255
                echo "[-] Adresse IPv4 invalide."
                return 1
            end
        end
    else if string match -qr '^[0-9a-fA-F]*:[0-9a-fA-F:]*:[0-9a-fA-F]*$' -- "$ip"
        set family -6
    else
        echo "[-] Fournir une adresse IP seule, sans port."
        return 1
    end
    for dependency in nmap xsltproc
        if not command -q "$dependency"
            echo "[-] Commande manquante : $dependency"
            return 1
        end
    end

    set -l root "$PWD/recon/$ip"
    command mkdir -p -- "$root"; or return 1
    set -l output (command mktemp -d "$root/"(date +%Y%m%d-%H%M%S)"-XXXXXX")
    if test -z "$output"
        return 1
    end
    echo "[*] Rapports : $output"
    echo "[*] Découverte des 65535 ports TCP de $ip…"
    # TCP connect : pas de sudo nécessaire. Sortie visible et journal conservé.
    command nmap $family -sT -p- -Pn -n -T4 --open -oA "$output/discovery" "$ip" 2>&1 | command tee "$output/scan.log"
    if test $pipestatus[1] -ne 0
        echo "[-] Échec de la découverte ; voir $output/scan.log"
        return 1
    end

    set -l ports (command awk '/Ports: / { sub(/^.*Ports: /, ""); n=split($0,a,","); for(i=1;i<=n;i++) { split(a[i],p,"/"); if(p[2]=="open" && p[3]=="tcp") { gsub(/^[ \t]+/,"",p[1]); print p[1] } } }' "$output/discovery.gnmap")
    set -l report "$output/discovery.xml"
    if test (count $ports) -gt 0
        echo "[+] Ports TCP ouverts : "(string join , $ports)
        echo "[*] Analyse des services et scripts par défaut…"
        command nmap $family -sT -Pn -n -T4 -sV -sC -p (string join , $ports) -oA "$output/services" "$ip" 2>&1 | command tee -a "$output/scan.log"
        if test $pipestatus[1] -ne 0
            echo "[-] Échec de l’analyse des services ; voir $output/scan.log"
            return 1
        end
        set report "$output/services.xml"
    else
        echo "[*] Aucun port TCP ouvert détecté."
    end

    echo "[+] XML : $report"
    command xsltproc --nonet -o "$output/report.html" "$report" 2>> "$output/scan.log"
    if test $status -ne 0; or not test -s "$output/report.html"
        echo "[-] Conversion HTML échouée ; XML conservé, voir $output/scan.log"
        return 1
    end
    if test (count $ports) -gt 0
        echo "[+] Ports TCP ouverts (découverte) : "(string join , $ports)
    end
    echo "[+] HTML : $output/report.html"
end
