#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Fix double 'let' statements after with lib replacement
#

set -euo pipefail

find modules -name "*.nix" -type f | while read -r file; do
    # Check if file has consecutive let statements
    if grep -A1 "^in$" "$file" | grep -q "^let$"; then
        echo "Fixing double let in: $file"
        
        # Fix pattern:
        # let
        #   inherit...
        # in
        # let
        #   cfg = ...
        
        # Merge the two let blocks
        awk '
            /^let$/ && !in_let { in_let=1; print; next }
            /^in$/ && in_let { 
                # Check if next line is another let
                getline nextline
                if (nextline == "let") {
                    # Skip the "in" and the second "let"
                    in_let=1
                } else {
                    print "in"
                    print nextline
                    in_let=0
                }
                next
            }
            { print }
        ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    fi
done

echo "Fixed double let statements"