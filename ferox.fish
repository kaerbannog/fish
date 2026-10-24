function ferox
    if test (count $argv) -lt 1
        echo "Usage: ferox <url> [extra feroxbuster args]"
        return 1
    end
    
    set url $argv[1]
    set extra_args $argv[2..-1]
    
    set seclists_dir ~/tools/SecLists/Discovery/Web-Content
    
    if not test -d $seclists_dir
        echo "SecLists directory not found: $seclists_dir"
        return 1
    end
    
    set wordlist (find $seclists_dir -type f | fzf \
                    --prompt="Wordlist > " \
                    --height=40% \
                    --reverse)
    
    if test -z "$wordlist"
        echo "No wordlist selected, using default: big.txt"
        set wordlist "$seclists_dir/big.txt"
    end
    
    feroxbuster \
                --burp-replay \
                -x php,html,js,json,txt,log \
                -t 50 \
                -w "$wordlist" \
                -u "$url" \
                --dont-scan "$url/cgi-bin/" \
                $extra_args
end
