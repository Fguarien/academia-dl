#!/bin/bash

# Script pour n8n - Extraction et téléchargement Academia.edu
# Usage: ./n8n_download.sh "URL"

URL="$1"
SCRIPT_DIR="/volume1/docker/academia-dl"

# Configuration pour n8n
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Fonction de log pour n8n (stderr pour les logs, stdout pour le résultat JSON)
log_json() {
    echo "{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"$1\",\"message\":\"$2\"}" >&2
}

# Validation et setup
if [ -z "$URL" ]; then
    echo '{"status":"error","error":"URL parameter missing","usage":"script.sh <academia.edu_url>"}'
    exit 1
fi

cd "$SCRIPT_DIR" || {
    echo '{"status":"error","error":"Cannot access directory '$SCRIPT_DIR'"}'
    exit 1
}

log_json "INFO" "Starting process for URL: $URL"
log_json "INFO" "Working directory: $(pwd)"

# Assurer que le répertoire downloads existe
mkdir -p downloads

# ÉTAPE 1: EXTRACTION OBLIGATOIRE pour les URLs keypass
BASE_URL="$URL"

if echo "$URL" | grep -q "keypass"; then
    log_json "INFO" "🔧 KEYPASS URL DETECTED - EXTRACTION REQUIRED"
    
    # Tentative d'extraction avec votre script run.sh
    log_json "INFO" "Running extraction command..."
    
    EXTRACT_OUTPUT=$(sudo ./run.sh extract "$URL" 2>&1)
    EXTRACT_STATUS=$?
    
    log_json "INFO" "Extract command exit status: $EXTRACT_STATUS"
    
    if [ $EXTRACT_STATUS -eq 0 ]; then
        # Cherche l'URL de base dans la sortie
        EXTRACTED_URL=$(echo "$EXTRACT_OUTPUT" | grep -o 'https://www.academia.edu/[0-9]\+/[^[:space:]]*' | head -1)
        
        if [ -n "$EXTRACTED_URL" ]; then
            BASE_URL="$EXTRACTED_URL"
            log_json "SUCCESS" "✅ Base URL successfully extracted: $BASE_URL"
        else
            log_json "WARNING" "⚠️ Could not find base URL in extract output, trying manual extraction..."
            
            # Extraction manuelle depuis l'URL keypass
            if echo "$URL" | grep -o "work/[0-9]\+/[^/?&]*" > /dev/null; then
                WORK_PATH=$(echo "$URL" | grep -o "work/[0-9]\+/[^/?&]*")
                BASE_URL="https://www.academia.edu/$WORK_PATH"
                log_json "SUCCESS" "✅ Manual extraction successful: $BASE_URL"
            else
                log_json "ERROR" "❌ All extraction methods failed"
                echo '{"status":"error","error":"Could not extract base URL from keypass URL","original_url":"'$URL'"}'
                exit 1
            fi
        fi
    else
        log_json "WARNING" "⚠️ Extract command failed, trying manual extraction..."
        
        # Extraction manuelle en cas d'échec
        if echo "$URL" | grep -o "work/[0-9]\+/[^/?&]*" > /dev/null; then
            WORK_PATH=$(echo "$URL" | grep -o "work/[0-9]\+/[^/?&]*")
            BASE_URL="https://www.academia.edu/$WORK_PATH"
            log_json "SUCCESS" "✅ Manual extraction successful: $BASE_URL"
        else
            log_json "ERROR" "❌ All extraction methods failed"
            echo '{"status":"error","error":"Could not extract base URL from keypass URL","original_url":"'$URL'"}'
            exit 1
        fi
    fi
else
    log_json "INFO" "ℹ️ Base URL format detected, no extraction needed"
fi

# VÉRIFICATION que nous avons une URL différente
if [ "$BASE_URL" = "$URL" ] && echo "$URL" | grep -q "keypass"; then
    log_json "ERROR" "❌ Extraction failed - base URL is same as keypass URL"
    echo '{"status":"error","error":"Extraction failed - would download from keypass URL","original_url":"'$URL'"}'
    exit 1
fi

# ÉTAPE 2: TÉLÉCHARGEMENT depuis l'URL de base
log_json "INFO" "🚀 Starting download from BASE URL: $BASE_URL"
log_json "INFO" "Original URL was: $URL"

# Compter les fichiers avant
FILES_BEFORE=$(find downloads/ -type f \( -name "*.pdf" -o -name "*.docx" -o -name "*.doc" -o -name "*.txt" \) 2>/dev/null | wc -l)

# Téléchargement
DOWNLOAD_OUTPUT=$(timeout 300 sudo ./run.sh download "$BASE_URL" 2>&1)
DOWNLOAD_STATUS=$?

if [ $DOWNLOAD_STATUS -eq 0 ]; then
    log_json "SUCCESS" "✅ Download command completed successfully"
    
    # Attendre que les fichiers soient écrits
    sleep 3
    
    # Chercher les nouveaux fichiers
    LATEST_FILE=""
    
    for ext in pdf docx doc txt; do
        RECENT=$(find downloads/ -name "*.$ext" -type f -newermt "2 minutes ago" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
        if [ -n "$RECENT" ] && [ -f "$RECENT" ]; then
            LATEST_FILE="$RECENT"
            break
        fi
    done
    
    FILES_AFTER=$(find downloads/ -type f \( -name "*.pdf" -o -name "*.docx" -o -name "*.doc" -o -name "*.txt" \) 2>/dev/null | wc -l)
    NEW_FILES=$((FILES_AFTER - FILES_BEFORE))
    
    if [ -n "$LATEST_FILE" ] && [ -f "$LATEST_FILE" ]; then
        FILE_SIZE=$(stat -c%s "$LATEST_FILE" 2>/dev/null || echo 0)
        FILE_NAME=$(basename "$LATEST_FILE")
        FILE_EXT=$(echo "$LATEST_FILE" | grep -o '\.[^.]*$' | tr '[:upper:]' '[:lower:]')
        
        log_json "SUCCESS" "🎉 File successfully downloaded: $FILE_NAME"
        
        cat << EOF
{
  "status": "success",
  "message": "File successfully downloaded from extracted base URL",
  "extraction_performed": true,
  "original_url": "$URL",
  "extracted_base_url": "$BASE_URL",
  "file": {
    "name": "$FILE_NAME",
    "path": "$LATEST_FILE",
    "size": $FILE_SIZE,
    "extension": "$FILE_EXT"
  },
  "statistics": {
    "new_files": $NEW_FILES,
    "files_before": $FILES_BEFORE,
    "files_after": $FILES_AFTER
  },
  "timestamp": "$(date -Iseconds)"
}
EOF
    else
        log_json "WARNING" "⚠️ Download completed but no new files detected"
        
        cat << EOF
{
  "status": "partial_success",
  "message": "Download completed but no new document files detected",
  "extraction_performed": true,
  "original_url": "$URL",
  "extracted_base_url": "$BASE_URL",
  "statistics": {
    "new_files": $NEW_FILES,
    "files_before": $FILES_BEFORE,
    "files_after": $FILES_AFTER
  },
  "timestamp": "$(date -Iseconds)"
}
EOF
    fi
else
    log_json "ERROR" "❌ Download failed with exit code: $DOWNLOAD_STATUS"
    
    cat << EOF
{
  "status": "error",
  "message": "Download failed from extracted base URL",
  "extraction_performed": true,
  "original_url": "$URL",
  "extracted_base_url": "$BASE_URL",
  "error": "Download process failed",
  "exit_code": $DOWNLOAD_STATUS,
  "timestamp": "$(date -Iseconds)"
}
EOF
    exit 1
fi
