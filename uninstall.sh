#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# uninstall.sh — Désinstallateur du Cyber Dashboard Termux v1.0
# Usage : bash uninstall.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

readonly INSTALL_DIR="$HOME/mon_env"
readonly BASHRC="$HOME/.bashrc"
readonly BASHRC_BACKUP="${BASHRC}.bak_cyd_$(date +%Y%m%d%H%M)"

C='\e[36m'; G='\e[32m'; Y='\e[33m'; R='\e[31m'
W='\e[1;37m'; D='\e[2;37m'; NC='\e[0m'

info()    { printf "${C}  ℹ  ${NC}%s\n" "$*"; }
success() { printf "${G}  ✅  ${NC}%s\n" "$*"; }
warning() { printf "${Y}  ⚠️   ${NC}%s\n" "$*"; }
error()   { printf "${R}  ❌  ${NC}%s\n" "$*" >&2; }

main() {
    clear
    printf "${R}"
    printf "╔══════════════════════════════════════════════════════════════╗\n"
    printf "║         ⚠️   DÉSINSTALLATION — Cyber Dashboard              ║\n"
    printf "╚══════════════════════════════════════════════════════════════╝\n"
    printf "${NC}\n"

    warning "Cette opération va supprimer TOUT le dossier : $INSTALL_DIR"
    warning "Les alias dans .bashrc seront supprimés."
    echo ""
    echo -ne "${R}  Confirmer la désinstallation ? (tape SUPPRIMER pour confirmer) : ${NC}"
    read -r confirm

    [[ "$confirm" != "SUPPRIMER" ]] && \
        echo -e "\n${Y}Désinstallation annulée.${NC}" && exit 0

    # Sauvegarde .bashrc avant modification
    cp "$BASHRC" "$BASHRC_BACKUP" 2>/dev/null && \
        success "Sauvegarde .bashrc → $BASHRC_BACKUP"

    # Supprimer le bloc Cyber Dashboard dans .bashrc
    if grep -qF "# ── Cyber Dashboard Termux ──" "$BASHRC" 2>/dev/null; then
        # Supprimer entre les deux marqueurs
        sed -i '/# ── Cyber Dashboard Termux ──/,/# ──────────────────────────────────────────────────────────────────/d' \
            "$BASHRC" 2>/dev/null && success "Alias .bashrc supprimés ✓"
    fi

    # Supprimer le dossier d'installation
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR" && success "Dossier $INSTALL_DIR supprimé ✓"
    else
        warning "Dossier $INSTALL_DIR introuvable"
    fi

    printf "\n${G}╔══════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${G}║  ✅  Cyber Dashboard désinstallé proprement.                ║${NC}\n"
    printf "${G}║  Relance le terminal pour appliquer les changements.        ║${NC}\n"
    printf "${G}╚══════════════════════════════════════════════════════════════╝${NC}\n\n"
}

main "$@"
