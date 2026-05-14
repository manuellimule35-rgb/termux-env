#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# core/config.sh — Configuration centrale du Cyber Dashboard
# Chargé en premier par main.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

# ─── Chemins racine ───────────────────────────────────────────────────
readonly CFG_INSTALL_DIR="$HOME/mon_env"
readonly CFG_CORE_DIR="$CFG_INSTALL_DIR/core"
readonly CFG_MODULES_DIR="$CFG_INSTALL_DIR/modules"
readonly CFG_PLUGINS_DIR="$CFG_INSTALL_DIR/plugins"
readonly CFG_THEMES_DIR="$CFG_INSTALL_DIR/themes"
readonly CFG_CONFIGS_DIR="$CFG_INSTALL_DIR/configs"
readonly CFG_LOGS_DIR="$CFG_INSTALL_DIR/logs"
readonly CFG_BACKUPS_DIR="$CFG_INSTALL_DIR/backups"
readonly CFG_GITHUB_DIR="$CFG_INSTALL_DIR/github_projects"
readonly CFG_WORDLISTS_DIR="$CFG_INSTALL_DIR/wordlists"
readonly CFG_DATABASE_DIR="$CFG_INSTALL_DIR/database"
readonly CFG_DATABASE_FILE="$CFG_DATABASE_DIR/env.db"

# ─── Fichiers de config ───────────────────────────────────────────────
readonly CFG_USER_FILE="$CFG_CONFIGS_DIR/user.conf"
readonly CFG_LOG_ACTIONS="$CFG_LOGS_DIR/actions.log"
readonly CFG_LOG_ERRORS="$CFG_LOGS_DIR/errors.log"
readonly CFG_LOG_SECURITY="$CFG_LOGS_DIR/security.log"

# ─── Version ──────────────────────────────────────────────────────────
readonly CFG_VERSION="1.0"
readonly CFG_APP_NAME="Cyber Dashboard Termux"

# ─── Valeurs par défaut (écrasées par user.conf si présent) ───────────
PSEUDO_NAME="Shadow"
THEME_NAME="cyber"
THEME_FILE="$CFG_THEMES_DIR/cyber.theme"
LANG_UI="fr"
AUTO_UPDATE="1"
SHOW_BANNER="1"
LOG_LEVEL="info"   # debug | info | warn | error

# ─── Chargement de user.conf ──────────────────────────────────────────
config_load() {
    if [[ -f "$CFG_USER_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CFG_USER_FILE"
    else
        # Créer une config minimale si absente
        config_create_default
    fi

    # S'assurer que THEME_FILE pointe vers le bon fichier
    THEME_FILE="$CFG_THEMES_DIR/${THEME_NAME}.theme"

    # Fallback si le thème demandé n'existe pas
    if [[ ! -f "$THEME_FILE" ]]; then
        THEME_FILE="$CFG_THEMES_DIR/cyber.theme"
        THEME_NAME="cyber"
    fi

    export PSEUDO_NAME THEME_NAME THEME_FILE LANG_UI
    export AUTO_UPDATE SHOW_BANNER LOG_LEVEL
}

# ─── Créer une config par défaut ──────────────────────────────────────
config_create_default() {
    mkdir -p "$CFG_CONFIGS_DIR"
    cat > "$CFG_USER_FILE" << EOF
# ── Configuration utilisateur — Cyber Dashboard ──
PSEUDO_NAME="Shadow"
THEME_NAME="cyber"
THEME_FILE="$CFG_THEMES_DIR/cyber.theme"
INSTALL_DIR="$CFG_INSTALL_DIR"
VERSION="$CFG_VERSION"
LANG_UI="fr"
AUTO_UPDATE="1"
SHOW_BANNER="1"
LOG_LEVEL="info"
EOF
}

# ─── Sauvegarder une valeur dans user.conf ────────────────────────────
# Usage : config_set "PSEUDO_NAME" "Shadow"
config_set() {
    local key="$1"
    local value="$2"

    if [[ ! -f "$CFG_USER_FILE" ]]; then
        config_create_default
    fi

    # Mettre à jour la ligne si elle existe, sinon l'ajouter
    if grep -q "^${key}=" "$CFG_USER_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$CFG_USER_FILE"
    else
        echo "${key}=\"${value}\"" >> "$CFG_USER_FILE"
    fi

    # Mettre à jour en mémoire
    export "${key}=${value}"
}

# ─── Lire une valeur depuis user.conf ────────────────────────────────
# Usage : val=$(config_get "PSEUDO_NAME")
config_get() {
    local key="$1"
    local default="${2:-}"
    local value

    value=$(grep "^${key}=" "$CFG_USER_FILE" 2>/dev/null \
            | cut -d'"' -f2 || echo "$default")
    echo "${value:-$default}"
}

# ─── Vérifier que les dossiers critiques existent ────────────────────
config_check_dirs() {
    local dirs=(
        "$CFG_INSTALL_DIR"
        "$CFG_CORE_DIR"
        "$CFG_MODULES_DIR"
        "$CFG_LOGS_DIR"
        "$CFG_CONFIGS_DIR"
        "$CFG_DATABASE_DIR"
        "$CFG_THEMES_DIR"
        "$CFG_BACKUPS_DIR"
        "$CFG_GITHUB_DIR"
        "$CFG_WORDLISTS_DIR"
        "$CFG_PLUGINS_DIR"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$dir" 2>/dev/null || true
    done
}

# ─── Afficher la configuration actuelle ───────────────────────────────
config_show() {
    echo "  Pseudo      : $PSEUDO_NAME"
    echo "  Thème       : $THEME_NAME"
    echo "  Version     : $CFG_VERSION"
    echo "  Langue      : $LANG_UI"
    echo "  Auto-update : $AUTO_UPDATE"
    echo "  Log level   : $LOG_LEVEL"
    echo "  Install dir : $CFG_INSTALL_DIR"
}

# ─── Auto-chargement à l'inclusion ───────────────────────────────────
config_check_dirs
config_load
