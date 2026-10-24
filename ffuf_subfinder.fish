function ffuf_subfinder
    if test (count $argv) -lt 1
        echo "Usage: ffuf_subfinder <url> [ffuf options]"
        echo "Ex: ffuf_subfinder http://site.com -mc 200"
        return 1
    end
    
    set url $argv[1]
    set args $argv[2..-1]
    
    # Récupère juste le host (sans protocole, ni chemin)
    set domain (string replace -r '^[^/]+://' '' $url)  # enlève http:// ou https://
    set domain (string split '/' $domain)[1]           # enlève éventuel chemin
    
    ffuf -u "$url" \
                -H "Host: FUZZ.$domain" \
                -w ~/tools/SecLists/Discovery/DNS/subdomains-top1million-20000.txt \
                $args
end
