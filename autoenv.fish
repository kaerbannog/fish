function autoenv
    # If the env already exists, just activate it
    if test -f .env/bin/activate.fish
        source .env/bin/activate.fish
    else
        # Check that python3 is available
        if not type -q python3
            echo "python3 not found" 1>&2
            return 1
        end
        # Create venv and activate
        python3 -m venv .env
        source .env/bin/activate.fish
    end
end
