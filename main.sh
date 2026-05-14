#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# main.sh — Point d'entrée principal du Cyber Dashboard Termux v1.0
# Usage : bash main.sh  |  cyd
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

# ─── Résolution du dossier d'installation ────────────────────────────
readonly MAIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CORE_DIR="$MAIN_DIR/core"
readonly MODULES_DIR="$MAIN_DIR/modules"

# ═══════════════════════════════════════════════════════════════════════
#  CHARGEMENT DU NOYAU (ordre strict)
# ═══════════════════════════════════════════════════════════════════════
_load_core() {
    local core_files=(
        "config"
        "logger"
        "security"
        "database"
        "utils"
        "themes"
        "ui"
        "dependencies"
    )

    for module in "${core_files[@]}"; do
        local file="$CORE_DIR/${module}.sh"
        if [[ -f "$file" ]]; then
            # shellcheck source=/dev/null
            source "$file"
        else
            printf "\e[31m  ❌ Fichier core manquant : %s\e[0m\n" "$file" >&2
            printf "\e[33m  Lance d'abord : bash install.sh\e[0m\n" >&2
            exit 1
        fi
    done
}

# ═══════════════════════════════════════════════════════════════════════
#  CHARGEMENT D'UN MODULE
# ═══════════════════════════════════════════════════════════════════════
_load_module() {
    local name="$1"
    local file="$MODULES_DIR/${name}.sh"

    if [[ ! -f "$file" ]]; then
        ui_warning "Module '$name' non trouvé : $file"
        log_warn "Module manquant : $name" "main"
        read -rp "  Entrée..."
        return 1
    fi

    # Vérifier les dépendances du module avant chargement
    deps_check_module "$name" || return 1

    # shellcheck source=/dev/null
    source "$file"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════
#  CHARGEMENT DES PLUGINS
# ═══════════════════════════════════════════════════════════════════════
_load_plugins() {
    local plugins_dir="$MAIN_DIR/plugins"
    [[ ! -d "$plugins_dir" ]] && return 0

    local count=0
    while IFS= read -r -d '' plugin; do
        # shellcheck source=/dev/null
        source "$plugin" 2>/dev/null && (( count++ )) || \
            log_warn "Échec chargement plugin : $plugin" "main"
    done < <(find "$plugins_dir" -name "*.plugin.sh" -print0 2>/dev/null)

    (( count > 0 )) && log_info "$count plugin(s) chargé(s)" "main"
}

# ═══════════════════════════════════════════════════════════════════════
#  GESTION DES SIGNAUX
# ═══════════════════════════════════════════════════════════════════════
_setup_traps() {
    trap '_handle_exit' EXIT
    trap '_handle_interrupt' INT TERM
}

_handle_interrupt() {
    printf "\n"
    ui_quit
}

_handle_exit() {
    tput cnorm 2>/dev/null || true
    stty sane 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════════
#  VÉRIFICATION AU DÉMARRAGE
# ═══════════════════════════════════════════════════════════════════════
_startup_checks() {
    # Vérifier dossiers critiques
    config_check_dirs

    # Vérification rapide des dépendances requises
    if ! deps_check_all_fast; then
        printf "${Y}  ⚠️  Certaines dépendances requises sont manquantes.${NC}\n"
        printf "  ${D}Lance [i] depuis le menu pour les installer.${NC}\n\n"
        sleep 2
    fi

    # Correction silencieuse des permissions
    sec_check_permissions

    # Logger le démarrage
    log_info "=== Démarrage Cyber Dashboard v${CFG_VERSION} ===" "main"
    db_log_action "démarrage" "main" "ok" "version=${CFG_VERSION}"
}

# ═══════════════════════════════════════════════════════════════════════
#  ROUTEUR DES MODULES
# ═══════════════════════════════════════════════════════════════════════
_route_module() {
    local choice="$1"

    case "$choice" in
        1)  # Monitoring
            _load_module "monitoring" && monitoring_menu
            ;;
        2)  # GitHub
            _load_module "github" && github_menu
            ;;
        3)  # Projets
            _load_module "projects" && projects_menu
            ;;
        4)  # Pentest
            sec_pentest_disclaimer && \
            _load_module "pentest" && pentest_menu
            ;;
        5)  # SSH
            _load_module "ssh" && ssh_menu
            ;;
        6)  # Workspace
            _load_module "workspace" && workspace_menu
            ;;
        7)  # Notes
            _load_module "notes" && notes_menu
            ;;
        8)  # Scripts
            _load_module "scripts" && scripts_menu
            ;;
        9)  # Réseau
            _load_module "network" && network_menu
            ;;
        10) # TOR
            _load_module "tor" && tor_menu
            ;;
        11) # Backup
            _load_module "backup" && backup_menu
            ;;
        12) # Plugins
            _load_module "plugins" && plugins_menu
            ;;
        i|I)
            log_action "Ouverture installateur" "main"
            deps_installer_menu
            ;;
        l|L)
            log_action "Ouverture logs" "main"
            logger_menu
            ;;
        s|S)
            log_action "Ouverture paramètres" "main"
            ui_settings_menu
            # Recharger le thème si changé
            themes_load "${THEME_NAME:-cyber}"
            ;;
        u|U)
            log_action "Lancement mise à jour" "main"
            bash "$MAIN_DIR/update.sh"
            read -rp "  Entrée pour revenir..."
            ;;
        h|H)
            ui_help
            ;;
        0|q|Q)
            log_action "Arrêt dashboard" "main"
            db_log_action "arrêt" "main" "ok"
            ui_quit
            ;;
        "")
            # Entrée vide : rafraîchir le dashboard
            ;;
        *)
            printf "  ${R}Choix invalide : %s${NC}\n" "$choice"
            sleep 1
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════
#  BOUCLE PRINCIPALE
# ═══════════════════════════════════════════════════════════════════════
_main_loop() {
    while true; do
        clear

        # Afficher banner + header si activé
        if [[ "${SHOW_BANNER:-1}" == "1" ]]; then
            ui_banner
        fi
        ui_header
        ui_main_menu

        # Lire le choix
        read -r user_choice

        # Logger le choix (sauf entrée vide)
        [[ -n "$user_choice" ]] && \
            log_debug "Choix menu : $user_choice" "main"

        # Router vers le bon module
        _route_module "$user_choice"
    done
}

# ═══════════════════════════════════════════════════════════════════════
#  POINT D'ENTRÉE
# ═══════════════════════════════════════════════════════════════════════
main() {
    # 1. Charger tout le noyau
    _load_core

    # 2. Configurer les signaux
    _setup_traps

    # 3. Vérifications démarrage
    _startup_checks

    # 4. Charger les plugins
    _load_plugins

    # 5. Lancer la boucle principale
    _main_loop
}

main "$@"
