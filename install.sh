#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# install.sh — Installateur du Cyber Dashboard Termux v1.0
# Auteur  : Shadow
# Usage   : bash install.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

# ─── Chemins ──────────────────────────────────────────────────────────
readonly INSTALL_DIR="$HOME/mon_env"
readonly CORE_DIR="$INSTALL_DIR/core"
readonly MODULES_DIR="$INSTALL_DIR/modules"
readonly PLUGINS_DIR="$INSTALL_DIR/plugins"
readonly THEMES_DIR="$INSTALL_DIR/themes"
readonly CONFIGS_DIR="$INSTALL_DIR/configs"
readonly LOGS_DIR="$INSTALL_DIR/logs"
readonly BACKUPS_DIR="$INSTALL_DIR/backups"
readonly GITHUB_DIR="$INSTALL_DIR/github_projects"
readonly WORDLISTS_DIR="$INSTALL_DIR/wordlists"
readonly DATABASE_DIR="$INSTALL_DIR/database"
readonly BASHRC="$HOME/.bashrc"
readonly LOG_INSTALL="$HOME/install_cyber_dashboard.log"

# ─── Couleurs (inline, core/ui.sh pas encore chargé) ──────────────────
C='\e[36m'; G='\e[32m'; Y='\e[33m'; R='\e[31m'
B='\e[34m'; W='\e[1;37m'; D='\e[2;37m'; NC='\e[0m'

# ─── Logger install ───────────────────────────────────────────────────
_log() { echo "[$(date '+%d/%m/%Y %H:%M:%S')] $*" >> "$LOG_INSTALL"; }

# ─── Affichage ────────────────────────────────────────────────────────
info()    { printf "${C}  ℹ  ${NC}%s\n"  "$*"; _log "INFO    $*"; }
success() { printf "${G}  ✅  ${NC}%s\n" "$*"; _log "SUCCESS $*"; }
warning() { printf "${Y}  ⚠️   ${NC}%s\n" "$*"; _log "WARNING $*"; }
error()   { printf "${R}  ❌  ${NC}%s\n" "$*" >&2; _log "ERROR   $*"; }
step()    { printf "\n${W}━━━ %s ${NC}\n\n" "$*"; }

# ─── Bannière ─────────────────────────────────────────────────────────
show_banner() {
    clear
    printf "${C}"
    printf "╔══════════════════════════════════════════════════════════════╗\n"
    printf "║                                                              ║\n"
    printf "║        ██████╗██╗   ██╗██████╗ ███████╗██████╗             ║\n"
    printf "║       ██╔════╝╚██╗ ██╔╝██╔══██╗██╔════╝██╔══██╗            ║\n"
    printf "║       ██║      ╚████╔╝ ██████╔╝█████╗  ██████╔╝            ║\n"
    printf "║       ██║       ╚██╔╝  ██╔══██╗██╔══╝  ██╔══██╗            ║\n"
    printf "║       ╚██████╗   ██║   ██████╔╝███████╗██║  ██║            ║\n"
    printf "║        ╚═════╝   ╚═╝   ╚═════╝ ╚══════╝╚═╝  ╚═╝            ║\n"
    printf "║                                                              ║\n"
    printf "║          DASHBOARD  —  TERMUX  —  v1.0                     ║\n"
    printf "║                                                              ║\n"
    printf "╚══════════════════════════════════════════════════════════════╝\n"
    printf "${NC}\n"
    printf "${D}  Installateur automatique — Android / Termux${NC}\n\n"
}

# ═══════════════════════════════════════════════════════════════════════
#  ÉTAPE 1 — VÉRIFICATIONS PRÉALABLES
# ═══════════════════════════════════════════════════════════════════════
check_requirements() {
    step "ÉTAPE 1 — Vérifications préalables"

    # Vérifier qu'on est bien dans Termux
    if [[ ! -d "/data/data/com.termux" ]]; then
        error "Ce script doit être exécuté dans Termux (Android)."
        exit 1
    fi
    success "Environnement Termux détecté"

    # Vérifier la version de Bash (>= 4)
    local bash_ver
    bash_ver=$(bash --version | head -1 | grep -oP '\d+\.\d+' | head -1)
    local bash_major
    bash_major=$(echo "$bash_ver" | cut -d. -f1)
    if (( bash_major < 4 )); then
        error "Bash >= 4 requis. Version actuelle : $bash_ver"
        exit 1
    fi
    success "Bash $bash_ver ✓"

    # Vérifier la connexion internet
    if ! curl -s --max-time 5 https://google.com > /dev/null 2>&1; then
        error "Pas de connexion internet. Vérifie ton réseau."
        exit 1
    fi
    success "Connexion internet active ✓"

    # Vérifier l'espace disque (minimum 200 MB)
    local free_mb
    free_mb=$(df -m "$HOME" 2>/dev/null | awk 'NR==2{print $4}')
    if (( free_mb < 200 )); then
        error "Espace disque insuffisant : ${free_mb}MB disponibles (200MB requis)"
        exit 1
    fi
    success "Espace disque : ${free_mb}MB disponibles ✓"
}

# ═══════════════════════════════════════════════════════════════════════
#  ÉTAPE 2 — MISE À JOUR DE PKG
# ═══════════════════════════════════════════════════════════════════════
update_pkg() {
    step "ÉTAPE 2 — Mise à jour des dépôts pkg"
    info "Mise à jour de pkg (peut prendre quelques secondes)..."
    if pkg update -y >> "$LOG_INSTALL" 2>&1; then
        success "Dépôts pkg mis à jour ✓"
    else
        warning "Mise à jour partielle (non bloquant)"
    fi
}

# ═══════════════════════════════════════════════════════════════════════
#  ÉTAPE 3 — INSTALLATION DES DÉPENDANCES
# ═══════════════════════════════════════════════════════════════════════

# Liste des paquets à installer via pkg
readonly PKG_DEPS=(
    git
    curl
    wget
    jq
    sqlite
    bash-completion
    fzf
    python
    nodejs
    openssh
    tor
    proxychains-ng
    htop
    tmux
    nmap
    vim
    nano
    tree
    zip
    unzip
    termux-api
)

# Paquets optionnels (non bloquants)
readonly PKG_OPTIONAL=(
    gum
    whiptail
    shellcheck
    ripgrep
    fd
    bat
)

install_package() {
    local pkg="$1"
    local optional="${2:-false}"

    # Vérifier si déjà installé
    if pkg list-installed 2>/dev/null | grep -q "^${pkg}/"; then
        success "$pkg déjà installé ✓"
        return 0
    fi

    info "Installation de $pkg..."
    if pkg install "$pkg" -y >> "$LOG_INSTALL" 2>&1; then
        success "$pkg installé ✓"
        _log "Package installé : $pkg"
    else
        if [[ "$optional" == "true" ]]; then
            warning "$pkg non disponible (optionnel, ignoré)"
        else
            error "Échec installation : $pkg"
            _log "ERREUR installation : $pkg"
            return 1
        fi
    fi
}

install_dependencies() {
    step "ÉTAPE 3 — Installation des dépendances obligatoires"

    local total=${#PKG_DEPS[@]}
    local current=0

    for pkg in "${PKG_DEPS[@]}"; do
        (( current++ )) || true
        printf "${D}  [%d/%d]${NC} " "$current" "$total"
        install_package "$pkg" "false"
    done

    step "ÉTAPE 3b — Installation des dépendances optionnelles"

    for pkg in "${PKG_OPTIONAL[@]}"; do
        install_package "$pkg" "true"
    done

    # pip : sqlmap
    if command -v pip &>/dev/null; then
        info "Installation de sqlmap via pip..."
        pip install sqlmap --break-system-packages >> "$LOG_INSTALL" 2>&1 \
            && success "sqlmap installé ✓" \
            || warning "sqlmap non installé (optionnel)"
    fi
}

# ═══════════════════════════════════════════════════════════════════════
#  ÉTAPE 4 — CRÉATION DE L'ARBORESCENCE
# ═══════════════════════════════════════════════════════════════════════
create_structure() {
    step "ÉTAPE 4 — Création de l'arborescence"

    local dirs=(
        "$INSTALL_DIR"
        "$CORE_DIR"
        "$MODULES_DIR"
        "$PLUGINS_DIR"
        "$THEMES_DIR"
        "$CONFIGS_DIR"
        "$LOGS_DIR"
        "$BACKUPS_DIR"
        "$GITHUB_DIR"
        "$WORDLISTS_DIR"
        "$DATABASE_DIR"
    )

    for dir in "${dirs[@]}"; do
        if mkdir -p "$dir"; then
            success "Créé : ${dir/$HOME/~}"
        else
            error "Impossible de créer : $dir"
            exit 1
        fi
    done

    # Fichiers de base vides (seront remplis par les modules)
    local base_files=(
        "$LOGS_DIR/actions.log"
        "$LOGS_DIR/errors.log"
        "$LOGS_DIR/security.log"
        "$LOGS_DIR/install.log"
        "$CONFIGS_DIR/user.conf"
        "$DATABASE_DIR/env.db"
    )

    for f in "${base_files[@]}"; do
        touch "$f" 2>/dev/null && success "Fichier init : ${f/$HOME/~}"
    done
}

# ═══════════════════════════════════════════════════════════════════════
#  ÉTAPE 5 — INITIALISATION DE LA BASE SQLITE
# ═══════════════════════════════════════════════════════════════════════
init_database() {
    step "ÉTAPE 5 — Initialisation de la base de données SQLite"

    local db="$DATABASE_DIR/env.db"

    if ! command -v sqlite3 &>/dev/null; then
        warning "sqlite3 non disponible, base de données ignorée"
        return 0
    fi

    sqlite3 "$db" << 'SQL'
-- Table projets
CREATE TABLE IF NOT EXISTS projects (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT    NOT NULL UNIQUE,
    type        TEXT    DEFAULT 'other',
    path        TEXT,
    run_cmd     TEXT,
    description TEXT,
    created_at  TEXT    DEFAULT (datetime('now')),
    updated_at  TEXT    DEFAULT (datetime('now'))
);

-- Table GitHub
CREATE TABLE IF NOT EXISTS github_projects (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT    NOT NULL UNIQUE,
    url         TEXT    NOT NULL,
    local_path  TEXT,
    branch      TEXT    DEFAULT 'main',
    language    TEXT,
    description TEXT,
    last_pull   TEXT,
    created_at  TEXT    DEFAULT (datetime('now'))
);

-- Table notes
CREATE TABLE IF NOT EXISTS notes (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    title       TEXT    NOT NULL,
    content     TEXT,
    category    TEXT    DEFAULT 'general',
    tags        TEXT,
    created_at  TEXT    DEFAULT (datetime('now')),
    updated_at  TEXT    DEFAULT (datetime('now'))
);

-- Table SSH hosts
CREATE TABLE IF NOT EXISTS ssh_hosts (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    alias       TEXT    NOT NULL UNIQUE,
    username    TEXT    NOT NULL,
    host        TEXT    NOT NULL,
    port        INTEGER DEFAULT 22,
    key_path    TEXT,
    description TEXT,
    created_at  TEXT    DEFAULT (datetime('now'))
);

-- Table scripts
CREATE TABLE IF NOT EXISTS scripts (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT    NOT NULL UNIQUE,
    description TEXT,
    path        TEXT    NOT NULL,
    run_cmd     TEXT,
    category    TEXT    DEFAULT 'general',
    created_at  TEXT    DEFAULT (datetime('now'))
);

-- Table logs actions
CREATE TABLE IF NOT EXISTS action_logs (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    action      TEXT    NOT NULL,
    module      TEXT    DEFAULT 'system',
    status      TEXT    DEFAULT 'ok',
    details     TEXT,
    timestamp   TEXT    DEFAULT (datetime('now'))
);

-- Table settings
CREATE TABLE IF NOT EXISTS settings (
    key         TEXT    PRIMARY KEY,
    value       TEXT,
    updated_at  TEXT    DEFAULT (datetime('now'))
);

-- Paramètres par défaut
INSERT OR IGNORE INTO settings (key, value) VALUES
    ('pseudo',        'Shadow'),
    ('theme',         'cyber'),
    ('version',       '1.0'),
    ('lang',          'fr'),
    ('auto_update',   '1'),
    ('show_banner',   '1'),
    ('log_level',     'info');
SQL

    success "Base de données SQLite initialisée ✓"
    _log "Base SQLite créée : $db"
}

# ═══════════════════════════════════════════════════════════════════════
#  ÉTAPE 6 — INSTALLATION DES THÈMES PAR DÉFAUT
# ═══════════════════════════════════════════════════════════════════════
install_themes() {
    step "ÉTAPE 6 — Installation des thèmes"

    # ── Thème Cyber (défaut) ──────────────────────────────────────────
    cat > "$THEMES_DIR/cyber.theme" << 'EOF'
# ── Thème : CYBER ──────────────────────────────────────────────────
THEME_NAME="Cyber"
THEME_DESC="Interface cyan néon sur fond sombre"

ACCENT='\e[36m'       # Cyan
ACCENT2='\e[34m'      # Bleu
SUCCESS='\e[32m'      # Vert
WARN='\e[33m'         # Jaune
DANGER='\e[31m'       # Rouge
BOLD='\e[1;37m'       # Blanc gras
DIM='\e[2;37m'        # Gris
MAGENTA='\e[35m'      # Magenta
NC='\e[0m'            # Reset

# Aliases courts
R="$DANGER"; G="$SUCCESS"; Y="$WARN"
B="$ACCENT2"; C="$ACCENT"; M="$MAGENTA"; W="$BOLD"

# Styles boîtes
BOX_TOP="╔══════════════════════════════════════════════════════════════╗"
BOX_MID="╠══════════════════════════════════════════════════════════════╣"
BOX_BOT="╚══════════════════════════════════════════════════════════════╝"
BOX_L="║"
EOF
    success "Thème cyber.theme ✓"

    # ── Thème Matrix ─────────────────────────────────────────────────
    cat > "$THEMES_DIR/matrix.theme" << 'EOF'
# ── Thème : MATRIX ─────────────────────────────────────────────────
THEME_NAME="Matrix"
THEME_DESC="Vert terminal, style Matrix"

ACCENT='\e[32m'
ACCENT2='\e[92m'
SUCCESS='\e[92m'
WARN='\e[33m'
DANGER='\e[31m'
BOLD='\e[1;32m'
DIM='\e[2;32m'
MAGENTA='\e[35m'
NC='\e[0m'

R="$DANGER"; G="$SUCCESS"; Y="$WARN"
B="$ACCENT2"; C="$ACCENT"; M="$MAGENTA"; W="$BOLD"

BOX_TOP="┌──────────────────────────────────────────────────────────────┐"
BOX_MID="├──────────────────────────────────────────────────────────────┤"
BOX_BOT="└──────────────────────────────────────────────────────────────┘"
BOX_L="│"
EOF
    success "Thème matrix.theme ✓"

    # ── Thème Neon ────────────────────────────────────────────────────
    cat > "$THEMES_DIR/neon.theme" << 'EOF'
# ── Thème : NEON ───────────────────────────────────────────────────
THEME_NAME="Neon"
THEME_DESC="Magenta et violet, style neon"

ACCENT='\e[35m'
ACCENT2='\e[95m'
SUCCESS='\e[92m'
WARN='\e[93m'
DANGER='\e[91m'
BOLD='\e[1;97m'
DIM='\e[2;37m'
MAGENTA='\e[95m'
NC='\e[0m'

R="$DANGER"; G="$SUCCESS"; Y="$WARN"
B="$ACCENT2"; C="$ACCENT"; M="$MAGENTA"; W="$BOLD"

BOX_TOP="╔══════════════════════════════════════════════════════════════╗"
BOX_MID="╠══════════════════════════════════════════════════════════════╣"
BOX_BOT="╚══════════════════════════════════════════════════════════════╝"
BOX_L="║"
EOF
    success "Thème neon.theme ✓"

    # ── Thème Red ─────────────────────────────────────────────────────
    cat > "$THEMES_DIR/red.theme" << 'EOF'
# ── Thème : RED ────────────────────────────────────────────────────
THEME_NAME="Red"
THEME_DESC="Rouge agressif, style danger"

ACCENT='\e[31m'
ACCENT2='\e[91m'
SUCCESS='\e[32m'
WARN='\e[33m'
DANGER='\e[91m'
BOLD='\e[1;91m'
DIM='\e[2;37m'
MAGENTA='\e[35m'
NC='\e[0m'

R="$DANGER"; G="$SUCCESS"; Y="$WARN"
B="$ACCENT2"; C="$ACCENT"; M="$MAGENTA"; W="$BOLD"

BOX_TOP="╔══════════════════════════════════════════════════════════════╗"
BOX_MID="╠══════════════════════════════════════════════════════════════╣"
BOX_BOT="╚══════════════════════════════════════════════════════════════╝"
BOX_L="║"
EOF
    success "Thème red.theme ✓"
}

# ═══════════════════════════════════════════════════════════════════════
#  ÉTAPE 7 — CONFIGURATION UTILISATEUR
# ═══════════════════════════════════════════════════════════════════════
configure_user() {
    step "ÉTAPE 7 — Configuration utilisateur"

    echo -ne "  ${C}Ton pseudo (défaut: Shadow) : ${NC}"
    read -r pseudo
    pseudo="${pseudo:-Shadow}"

    echo -ne "  ${C}Thème [cyber/matrix/neon/red] (défaut: cyber) : ${NC}"
    read -r theme_choice
    theme_choice="${theme_choice:-cyber}"

    # Valider le thème
    local valid_themes=("cyber" "matrix" "neon" "red")
    local valid=false
    for t in "${valid_themes[@]}"; do
        [[ "$t" == "$theme_choice" ]] && valid=true && break
    done
    [[ "$valid" == "false" ]] && theme_choice="cyber" && warning "Thème invalide, cyber utilisé par défaut"

    # Écrire la config utilisateur
    cat > "$CONFIGS_DIR/user.conf" << EOF
# ── Configuration utilisateur ── $(date '+%d/%m/%Y')
PSEUDO_NAME="$pseudo"
THEME_NAME="$theme_choice"
THEME_FILE="$THEMES_DIR/${theme_choice}.theme"
INSTALL_DIR="$INSTALL_DIR"
VERSION="1.0"
LANG="fr"
AUTO_UPDATE="1"
SHOW_BANNER="1"
LOG_LEVEL="info"
EOF

    # Mettre à jour SQLite si disponible
    if command -v sqlite3 &>/dev/null; then
        sqlite3 "$DATABASE_DIR/env.db" \
            "UPDATE settings SET value='$pseudo' WHERE key='pseudo';
             UPDATE settings SET value='$theme_choice' WHERE key='theme';" \
            2>/dev/null || true
    fi

    success "Config utilisateur sauvegardée : pseudo=$pseudo, thème=$theme_choice"
}

# ═══════════════════════════════════════════════════════════════════════
#  ÉTAPE 8 — CONFIGURATION DE .BASHRC
# ═══════════════════════════════════════════════════════════════════════
configure_bashrc() {
    step "ÉTAPE 8 — Configuration de .bashrc"

    # Éviter la duplication
    if grep -qF "# ── Cyber Dashboard Termux ──" "$BASHRC" 2>/dev/null; then
        warning ".bashrc déjà configuré (ignoré)"
        return 0
    fi

    cat >> "$BASHRC" << EOF

# ── Cyber Dashboard Termux ──────────────────────────────────────────
export CYBER_DASHBOARD_DIR="$INSTALL_DIR"
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
shopt -s histappend 2>/dev/null || true

# Autocomplétion
[ -f /data/data/com.termux/files/usr/share/bash-completion/bash_completion ] && \\
    source /data/data/com.termux/files/usr/share/bash-completion/bash_completion

# Alias Cyber Dashboard
alias cyd='bash $INSTALL_DIR/main.sh'
alias cyd-update='bash $INSTALL_DIR/update.sh'
alias cyd-install='bash $INSTALL_DIR/install.sh'
alias ll='ls -la --color=auto'
alias cls='clear'
alias update='pkg update && pkg upgrade -y'
alias ..='cd ..'
alias ...='cd ../..'
alias gh='cd $INSTALL_DIR/github_projects'
alias myenv='cd $INSTALL_DIR'

# Lancer le dashboard au démarrage
# (décommente la ligne suivante si tu veux le lancer automatiquement)
# bash $INSTALL_DIR/main.sh
# ────────────────────────────────────────────────────────────────────
EOF

    success ".bashrc configuré ✓"
}

# ═══════════════════════════════════════════════════════════════════════
#  ÉTAPE 9 — PERMISSIONS
# ═══════════════════════════════════════════════════════════════════════
set_permissions() {
    step "ÉTAPE 9 — Définition des permissions"

    # Scripts exécutables
    local scripts=(
        "$INSTALL_DIR/main.sh"
        "$INSTALL_DIR/install.sh"
        "$INSTALL_DIR/update.sh"
        "$INSTALL_DIR/uninstall.sh"
    )

    for s in "${scripts[@]}"; do
        [[ -f "$s" ]] && chmod +x "$s" && success "chmod +x : ${s/$HOME/~}"
    done

    # core/ et modules/ exécutables
    find "$CORE_DIR" -name "*.sh" -exec chmod +x {} \; 2>/dev/null && \
        success "Permissions core/ ✓"
    find "$MODULES_DIR" -name "*.sh" -exec chmod +x {} \; 2>/dev/null && \
        success "Permissions modules/ ✓"

    # Sécurisation configs et database (lecture seule par les autres)
    chmod 700 "$CONFIGS_DIR" "$DATABASE_DIR" 2>/dev/null && \
        success "Sécurisation configs/ et database/ ✓"
}

# ═══════════════════════════════════════════════════════════════════════
#  ÉTAPE 10 — RÉSUMÉ FINAL
# ═══════════════════════════════════════════════════════════════════════
show_summary() {
    step "INSTALLATION TERMINÉE"

    local pseudo
    pseudo=$(grep "PSEUDO_NAME" "$CONFIGS_DIR/user.conf" 2>/dev/null \
             | cut -d'"' -f2 || echo "Shadow")
    local theme
    theme=$(grep "THEME_NAME" "$CONFIGS_DIR/user.conf" 2>/dev/null \
            | cut -d'"' -f2 || echo "cyber")

    printf "${G}"
    printf "╔══════════════════════════════════════════════════════════════╗\n"
    printf "║                                                              ║\n"
    printf "║   ✅  Cyber Dashboard Termux v1.0 installé !                ║\n"
    printf "║                                                              ║\n"
    printf "╠══════════════════════════════════════════════════════════════╣\n"
    printf "${NC}${G}║${NC}  ${B}Pseudo    :${NC} %-44s ${G}║${NC}\n" "$pseudo"
    printf "${G}║${NC}  ${B}Thème     :${NC} %-44s ${G}║${NC}\n" "$theme"
    printf "${G}║${NC}  ${B}Dossier   :${NC} %-44s ${G}║${NC}\n" "${INSTALL_DIR/$HOME/~}"
    printf "${G}║${NC}  ${B}Log       :${NC} %-44s ${G}║${NC}\n" "${LOG_INSTALL/$HOME/~}"
    printf "${G}"
    printf "╠══════════════════════════════════════════════════════════════╣\n"
    printf "║                                                              ║\n"
    printf "${NC}${G}║${NC}  ${W}Commandes disponibles :${NC}                                   ${G}║${NC}\n"
    printf "${G}║${NC}  ${C}  cyd${NC}           → Lancer le dashboard                    ${G}║${NC}\n"
    printf "${G}║${NC}  ${C}  cyd-update${NC}    → Mettre à jour                           ${G}║${NC}\n"
    printf "${G}║${NC}  ${C}  bash main.sh${NC}  → Lancement direct                        ${G}║${NC}\n"
    printf "${G}║                                                              ║\n"
    printf "╚══════════════════════════════════════════════════════════════╝\n"
    printf "${NC}\n"

    info "Recharge le terminal ou tape : source ~/.bashrc"
    info "Puis lance : cyd"
    echo ""
    _log "=== Installation terminée avec succès ==="
}

# ═══════════════════════════════════════════════════════════════════════
#  POINT D'ENTRÉE PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════
main() {
    # Créer le log d'install
    mkdir -p "$(dirname "$LOG_INSTALL")"
    : > "$LOG_INSTALL"
    _log "=== Démarrage installation Cyber Dashboard Termux v1.0 ==="
    _log "=== Date : $(date) ==="
    _log "=== Utilisateur : $(whoami) ==="

    show_banner

    echo -e "${Y}Ce script va installer le Cyber Dashboard Termux.${NC}"
    echo -e "${D}Toutes les opérations sont loggées dans : $LOG_INSTALL${NC}\n"
    echo -ne "${C}Continuer l'installation ? (o/n) : ${NC}"
    read -r confirm
    [[ "$confirm" != "o" && "$confirm" != "O" ]] && \
        echo -e "${Y}Installation annulée.${NC}" && exit 0

    check_requirements
    update_pkg
    install_dependencies
    create_structure
    init_database
    install_themes
    configure_user
    configure_bashrc
    set_permissions
    show_summary
}

main "$@"
