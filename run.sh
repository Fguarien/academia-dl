#!/bin/bash
# Script helper pour academia-dl - Version complète avec extract

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Fonctions d'affichage
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_tip() { echo -e "${BLUE}[TIP]${NC} $1"; }
log_success() { echo -e "${PURPLE}[SUCCESS]${NC} $1"; }

# Assure-toi que les répertoires existent
ensure_directories() {
    local base_dir=$(pwd)
    
    if [ ! -d "$base_dir/downloads" ]; then
        log_info "Création du répertoire downloads..."
        mkdir -p "$base_dir/downloads"
    fi
    
    if [ ! -d "$base_dir/logs" ]; then
        mkdir -p "$base_dir/logs"
    fi
    
    log_info "Répertoires prêts:"
    log_info "  - Downloads: $base_dir/downloads"
    log_info "  - Logs: $base_dir/logs"
}

# Fonction d'aide
show_help() {
    echo "=== Academia-dl Docker Helper - Version Complète ==="
    echo ""
    echo "Usage:"
    echo "  $0 download <url>     - Télécharge un PDF depuis academia.edu"
    echo "  $0 extract <url>      - 🆕 Extrait l'URL de base depuis une URL keypass"
    echo "  $0 analyze <url>      - 🆕 Analyse une URL et donne des conseils"
    echo "  $0 test               - Teste le conteneur"
    echo "  $0 debug              - Lance un shell de débogage"
    echo "  $0 build              - Construit l'image Docker"
    echo "  $0 clean              - Nettoie les conteneurs"
    echo "  $0 history            - 🆕 Affiche l'historique des téléchargements"
    echo "  $0 help               - Affiche cette aide"
    echo ""
    echo "🎯 Types d'URL supportées:"
    echo ""
    echo "✅ URL DE BASE (RECOMMANDÉE):"
    echo "   https://www.academia.edu/123456/Paper_Title"
    echo "   → Fonctionne de manière fiable"
    echo ""
    echo "❌ URL AVEC KEYPASS (PROBLÉMATIQUE):"
    echo "   https://www.academia.edu/keypass/xxx.../auto=download"
    echo "   → Souvent expirées, utilisez 'extract' pour obtenir l'URL de base"
    echo ""
    echo "Exemples:"
    echo "  $0 build"
    echo "  $0 download 'https://www.academia.edu/123456/Paper_Title'"
    echo "  $0 extract 'https://www.academia.edu/keypass/xxx...'"
    echo "  $0 analyze 'https://www.academia.edu/keypass/xxx...'"
    echo ""
}

# Validation d'URL
validate_url() {
    if [[ ! "$1" =~ ^https?://.*academia\.edu.* ]]; then
        log_error "L'URL doit être une URL academia.edu valide"
        echo "Exemple: https://www.academia.edu/123456/Paper_Title"
        return 1
    fi
}

# 🆕 Fonction pour extraire l'URL de base depuis une URL keypass
extract_base_url() {
    local url="$1"
    
    log_info "🔍 Analyse de l'URL pour extraction..."
    echo "URL originale: $url"
    echo ""
    
    # Méthode 1: Extraction via work/ID/titre
    if echo "$url" | grep -o "work/[0-9]\+/[^/?&]*" > /dev/null; then
        local work_path=$(echo "$url" | grep -o "work/[0-9]\+/[^/?&]*")
        local base_url="https://www.academia.edu/$work_path"
        
        log_success "✅ URL de base extraite avec succès !"
        echo "📄 URL de base: $base_url"
        echo ""
        log_tip "💡 Utilisez cette URL de base pour télécharger:"
        echo "   $0 download '$base_url'"
        echo ""
        
        # Sauvegarde dans l'historique
        echo "$(date '+%Y-%m-%d %H:%M:%S') - EXTRACT: $url -> $base_url" >> logs/extract_history.log
        
        return 0
    fi
    
    # Méthode 2: Extraction via ID numérique simple
    if echo "$url" | grep -o "[0-9]\{7,\}" > /dev/null; then
        local paper_id=$(echo "$url" | grep -o "[0-9]\{7,\}" | head -1)
        local base_url="https://www.academia.edu/$paper_id"
        
        log_success "✅ ID du papier extrait !"
        echo "📄 URL de base (basique): $base_url"
        echo ""
        log_warn "⚠️  Cette URL peut nécessiter le titre complet pour fonctionner optimalement"
        
        return 0
    fi
    
    log_error "❌ Impossible d'extraire l'URL de base depuis cette URL"
    log_tip "💡 Essayez de copier l'URL directement depuis la page du papier sur academia.edu"
    return 1
}

# 🆕 Fonction pour analyser une URL et donner des conseils
analyze_url() {
    local url="$1"
    
    echo "🔬 === ANALYSE D'URL ACADEMIA.EDU ==="
    echo ""
    echo "URL à analyser: $url"
    echo ""
    
    # Validation de base
    if ! validate_url "$url"; then
        return 1
    fi
    
    # Analyse du type d'URL
    if echo "$url" | grep -q "keypass"; then
        echo "🔍 Type: URL avec keypass (lien de téléchargement direct)"
        echo ""
        echo "❌ PROBLÈMES POTENTIELS:"
        echo "   • Paramètres de sécurité souvent expirés"
        echo "   • Bloquage des téléchargements automatisés"
        echo "   • Fonctionnement imprévisible"
        echo ""
        echo "✅ SOLUTIONS RECOMMANDÉES:"
        echo "   1. Extraire l'URL de base: $0 extract '$url'"
        echo "   2. Aller sur la page du papier et copier l'URL sans paramètres"
        echo "   3. Télécharger manuellement depuis un navigateur"
        echo ""
        
        # Tentative d'extraction automatique
        log_info "🔧 Tentative d'extraction automatique de l'URL de base..."
        if extract_base_url "$url" > /dev/null 2>&1; then
            echo "✅ Extraction possible - utilisez la commande 'extract'"
        else
            echo "❌ Extraction automatique impossible"
        fi
        
    elif echo "$url" | grep -E "academia\.edu/[0-9]+/" > /dev/null; then
        echo "🔍 Type: URL de base avec ID numérique"
        echo ""
        echo "✅ EXCELLENT CHOIX:"
        echo "   • Format optimal pour les téléchargements"
        echo "   • Fiabilité maximale"
        echo "   • Fonctionne de manière consistante"
        echo ""
        echo "🚀 PRÊT POUR LE TÉLÉCHARGEMENT:"
        echo "   $0 download '$url'"
        
    else
        echo "🔍 Type: URL academia.edu (format non standard)"
        echo ""
        echo "⚠️  ATTENTION:"
        echo "   • Format d'URL inhabituel"
        echo "   • Peut nécessiter des ajustements"
        echo ""
        echo "💡 RECOMMANDATIONS:"
        echo "   • Vérifiez que l'URL est correcte"
        echo "   • Essayez le téléchargement direct"
        echo "   • En cas d'échec, utilisez l'URL de la page du papier"
    fi
    
    echo ""
    echo "📊 STATISTIQUES:"
    echo "   • Longueur de l'URL: $(echo -n "$url" | wc -c) caractères"
    echo "   • Domaine: $(echo "$url" | sed 's|https\?://||' | cut -d'/' -f1)"
    echo "   • Paramètres: $(echo "$url" | grep -o '?' | wc -l) groupe(s)"
    echo ""
}

# 🆕 Fonction pour afficher l'historique
show_history() {
    echo "📚 === HISTORIQUE DES TÉLÉCHARGEMENTS ==="
    echo ""
    
    if [ -f "logs/download_history.log" ]; then
        echo "🔽 Téléchargements:"
        cat logs/download_history.log | tail -10
        echo ""
    else
        echo "Aucun historique de téléchargement trouvé."
    fi
    
    if [ -f "logs/extract_history.log" ]; then
        echo "🔧 Extractions d'URL:"
        cat logs/extract_history.log | tail -5
        echo ""
    else
        echo "Aucun historique d'extraction trouvé."
    fi
    
    echo "📁 Fichiers dans downloads/:"
    ls -lah downloads/ 2>/dev/null || echo "Répertoire downloads vide"
}

# Fonction de téléchargement améliorée
download_with_analysis() {
    local url="$2"
    
    # Analyse préliminaire
    echo "🔍 Pré-analyse de l'URL..."
    
    if echo "$url" | grep -q "keypass"; then
        log_warn "⚠️  URL keypass détectée - risque d'échec élevé"
        echo ""
        echo "Voulez-vous essayer d'extraire l'URL de base d'abord? (y/N)"
        read -t 10 -r response 2>/dev/null || response="n"
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            log_info "🔧 Extraction de l'URL de base..."
            if extract_base_url "$url"; then
                echo ""
                echo "Continuer avec l'URL extraite? (Y/n)"
                read -t 10 -r continue_response 2>/dev/null || continue_response="y"
                if [[ ! "$continue_response" =~ ^[Nn]$ ]]; then
                    return 0  # L'utilisateur utilisera l'URL extraite manuellement
                fi
            fi
        fi
    fi
    
    # Téléchargement normal
    log_info "🚀 Début du téléchargement..."
    log_info "📄 Source: $url"
    log_info "📁 Destination: $(pwd)/downloads/"
    echo ""
    
    # Sauvegarde dans l'historique
    echo "$(date '+%Y-%m-%d %H:%M:%S') - DOWNLOAD: $url" >> logs/download_history.log
    
    if docker-compose run --rm academia-dl "$url"; then
        log_success "🎉 Téléchargement terminé avec succès !"
        echo ""
        echo "📄 Fichiers téléchargés :"
        ls -lah downloads/*.pdf 2>/dev/null || ls -lah downloads/ 2>/dev/null || log_warn "Aucun fichier visible"
    else
        log_error "❌ Échec du téléchargement"
        echo ""
        log_tip "💡 Suggestions:"
        log_tip "   1. Essayez: $0 extract '$url'"
        log_tip "   2. Utilisez l'URL de base du papier"
        log_tip "   3. Téléchargez manuellement depuis un navigateur"
        exit 1
    fi
}

# Assure-toi que les répertoires existent au début
ensure_directories

# Parse les arguments
case "${1:-help}" in
    build)
        log_info "🔨 Construction de l'image Docker..."
        if docker-compose build; then
            log_success "✅ Construction terminée avec succès !"
        else
            log_error "❌ Échec de la construction"
            exit 1
        fi
        ;;
        
    test)
        log_info "🧪 Test du conteneur..."
        if docker-compose run --rm academia-dl --help; then
            log_success "✅ Test réussi !"
        else
            log_error "❌ Test échoué"
            exit 1
        fi
        ;;
        
    download)
        if [ -z "$2" ]; then
            log_error "URL manquante"
            echo "Usage: $0 download <url>"
            exit 1
        fi
        
        validate_url "$2"
        download_with_analysis "$@"
        ;;
        
    extract)
        if [ -z "$2" ]; then
            log_error "URL manquante"
            echo "Usage: $0 extract <url>"
            echo "Exemple: $0 extract 'https://www.academia.edu/keypass/xxx...'"
            exit 1
        fi
        
        validate_url "$2"
        extract_base_url "$2"
        ;;
        
    analyze)
        if [ -z "$2" ]; then
            log_error "URL manquante"
            echo "Usage: $0 analyze <url>"
            exit 1
        fi
        
        analyze_url "$2"
        ;;
        
    history)
        show_history
        ;;
        
    debug)
        log_info "🐛 Lancement du shell de débogage..."
        log_info "Commandes utiles dans le conteneur :"
        log_info "  - ls -la /app/          (voir les fichiers du script)"
        log_info "  - ls -la /downloads/    (voir les téléchargements)"
        log_info "  - ruby --version        (version de Ruby)"
        log_info "  - gem list              (gems installés)"
        echo ""
        docker-compose --profile debug run --rm academia-dl-debug
        ;;
        
    clean)
        log_info "🧹 Nettoyage..."
        docker-compose down --rmi all --volumes --remove-orphans 2>/dev/null || true
        log_success "✅ Nettoyage terminé"
        ;;
        
    help|--help|-h)
        show_help
        ;;
        
    *)
        log_error "Commande inconnue: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
