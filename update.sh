#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# update.sh — Mise à jour du Cyber Dashboard Termux v1.0
# Usage : bash update.sh
#         bash update.sh --auto     (mode silencieux, cron-friendly)
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

readonly INSTALL_DIR="$HOME/mon_env"
readonly CONFIGS_DIR="$INSTALL_DIR/configs"
readonly LOGS_DIR="$INSTALL_DIR/logs"
readonly BACKUPS_DIR="$INSTALL_DIR/backups"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly LOG_FILE="$LOGS_DIR/actions.log"

C='\e[36m'; G='\e[32m'; Y='\e[33m'; R='\e[31m'
W='\e[1;37m'; D='\e[2;37m'; NC='\e[0m'

AUTO_MODE="${1:-}"

_log()    { echo "[$(date '+%d/%m/%Y %H:%M:%S')] [UPDATE] $*" >> "$LOG_FILE" 2>/dev/null || true; }
info()    { printf "${C}  ℹ  ${NC}%s\n" "$*"; _log "INFO $*"; }
success() { printf "${G}  ✅  ${NC}%s\n" "$*"; _log "OK   $*"; }
warning() { printf "${Y}  ⚠️   ${NC}%s\n" "$*"; _log "WARN $*"; }
error()   { printf "${R}  ❌  ${NC}%s\n" "$*" >&2; _log "ERR  $*"; }

# ─── Vérifier connexion ───────────────────────────────────────────────
check_internet() {
    if ! curl -s --max-time 5 https://google.com > /dev/null 2>&1; then
        error "Pas de connexion internet."
        exit 1
    fi
}

# ─── Backup avant mise à jour ─────────────────────────────────────────
do_backup() {
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUPS_DIR/backup_${ts}"
    mkdir -p "$backup_path"

    # Sauvegarder configs, database, thèmes
    cp -r "$CONFIGS_DIR" "$backup_path/" 2>/dev/null && true
    cp -r "$INSTALL_DIR/database" "$backup_path/" 2>/dev/null && true
    cp -r "$INSTALL_DIR/themes" "$backup_path/" 2>/dev/null && true

    success "Backup créé : ${backup_path/$HOME/~}"
    _log "Backup : $backup_path"
}

# ─── Mise à jour via git pull ─────────────────────────────────────────
update_via_git() {
    info "Méthode : git pull"
    cd "$SCRIPT_DIR"
    git pull 2>&1 | tee -a "$LOG_FILE"
    local code=${PIPESTATUS[0]}

    if [[ $code -eq 0 ]]; then
        # Rendre tous les scripts exécutables
        find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
        success "Mise à jour git réussie ✓"
        _log "git pull OK"
        return 0
    else
        error "git pull échoué (code $code)"
        return 1
    fi
}

# ─── Mise à jour pkg ──────────────────────────────────────────────────
update_packages() {
    info "Mise à jour des paquets Termux..."
    pkg update -y >> "$LOG_FILE" 2>&1 && success "Paquets mis à jour ✓" || \
        warning "Mise à jour paquets partielle"
}

# ─── Vérifier version ─────────────────────────────────────────────────
check_version() {
    local current
    current=$(grep "VERSION" "$CONFIGS_DIR/user.conf" 2>/dev/null \
              | cut -d'"' -f2 || echo "inconnue")
    info "Version actuelle : $current"
}

# ─── Main ─────────────────────────────────────────────────────────────
main() {
    if [[ "$AUTO_MODE" != "--auto" ]]; then
        clear
        printf "${C}"
        printf "╔══════════════════════════════════════════════════════════════╗\n"
        printf "║         ⬆️   MISE À JOUR — Cyber Dashboard Termux           ║\n"
        printf "╚══════════════════════════════════════════════════════════════╝\n"
        printf "${NC}\n"
    fi

    _log "=== Début mise à jour ==="
    check_version
    check_internet
    do_backup

    # Mise à jour via git si dépôt détecté
    if [[ -d "$SCRIPT_DIR/.git" ]]; then
        update_via_git
    else
        warning "Pas de dépôt git détecté."
        info "Configure un dépôt git pour les mises à jour automatiques."
        info "Exemple : cd $INSTALL_DIR && git init && git remote add origin <URL>"
    fi

    update_packages

    if [[ "$AUTO_MODE" != "--auto" ]]; then
        printf "\n${G}╔══════════════════════════════════════════════════════════════╗${NC}\n"
        printf "${G}║  ✅  Mise à jour terminée !                                  ║${NC}\n"
        printf "${G}╚══════════════════════════════════════════════════════════════╝${NC}\n\n"
        echo -e "${Y}Recharge le terminal ou tape : source ~/.bashrc${NC}"
    fi

    _log "=== Mise à jour terminée ==="
}

main "$@"
