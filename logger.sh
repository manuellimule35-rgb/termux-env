#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# core/logger.sh — Système de logs avancé
# Dépend de : core/config.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

# ─── Niveaux de log (numérique pour comparaison) ──────────────────────
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3

# ─── Résoudre le niveau configuré ────────────────────────────────────
_logger_level_num() {
    case "${LOG_LEVEL:-info}" in
        debug) echo $LOG_LEVEL_DEBUG ;;
        info)  echo $LOG_LEVEL_INFO  ;;
        warn)  echo $LOG_LEVEL_WARN  ;;
        error) echo $LOG_LEVEL_ERROR ;;
        *)     echo $LOG_LEVEL_INFO  ;;
    esac
}

# ─── Rotation des logs (max 500 lignes par fichier) ───────────────────
_logger_rotate() {
    local file="$1"
    local max_lines=500

    if [[ -f "$file" ]]; then
        local lines
        lines=$(wc -l < "$file" 2>/dev/null || echo 0)
        if (( lines > max_lines )); then
            # Garder les 250 dernières lignes
            local tmp
            tmp=$(tail -250 "$file")
            echo "$tmp" > "$file"
        fi
    fi
}

# ─── Fonction d'écriture interne ──────────────────────────────────────
_logger_write() {
    local level="$1"      # DEBUG | INFO | WARN | ERROR
    local module="$2"     # nom du module appelant
    local message="$3"    # message
    local log_file="$4"   # fichier cible

    local ts
    ts=$(date '+%d/%m/%Y %H:%M:%S')
    local line="[$ts] [$level] [$module] $message"

    # Créer le fichier si absent
    mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
    echo "$line" >> "$log_file" 2>/dev/null || true

    # Rotation si nécessaire
    _logger_rotate "$log_file"
}

# ═══════════════════════════════════════════════════════════════════════
#  API PUBLIQUE — Fonctions appelables par tous les modules
# ═══════════════════════════════════════════════════════════════════════

# ─── log_debug : messages de débogage ────────────────────────────────
log_debug() {
    local message="$1"
    local module="${2:-system}"
    local current_level
    current_level=$(_logger_level_num)

    if (( current_level <= LOG_LEVEL_DEBUG )); then
        _logger_write "DEBUG" "$module" "$message" "${CFG_LOG_ACTIONS:-$HOME/mon_env/logs/actions.log}"
    fi
}

# ─── log_info : actions normales ─────────────────────────────────────
log_info() {
    local message="$1"
    local module="${2:-system}"
    local current_level
    current_level=$(_logger_level_num)

    if (( current_level <= LOG_LEVEL_INFO )); then
        _logger_write "INFO " "$module" "$message" "${CFG_LOG_ACTIONS:-$HOME/mon_env/logs/actions.log}"
    fi
}

# ─── log_warn : avertissements ───────────────────────────────────────
log_warn() {
    local message="$1"
    local module="${2:-system}"

    _logger_write "WARN " "$module" "$message" "${CFG_LOG_ACTIONS:-$HOME/mon_env/logs/actions.log}"
}

# ─── log_error : erreurs (écrit aussi dans errors.log) ───────────────
log_error() {
    local message="$1"
    local module="${2:-system}"

    _logger_write "ERROR" "$module" "$message" "${CFG_LOG_ACTIONS:-$HOME/mon_env/logs/actions.log}"
    _logger_write "ERROR" "$module" "$message" "${CFG_LOG_ERRORS:-$HOME/mon_env/logs/errors.log}"
}

# ─── log_security : événements sécurité ──────────────────────────────
log_security() {
    local message="$1"
    local module="${2:-security}"

    _logger_write "SEC  " "$module" "$message" "${CFG_LOG_SECURITY:-$HOME/mon_env/logs/security.log}"
    _logger_write "SEC  " "$module" "$message" "${CFG_LOG_ACTIONS:-$HOME/mon_env/logs/actions.log}"
}

# ─── log_action : alias court pour log_info ──────────────────────────
log_action() {
    log_info "$1" "${2:-system}"
}

# ═══════════════════════════════════════════════════════════════════════
#  AFFICHAGE DES LOGS (pour le menu logs)
# ═══════════════════════════════════════════════════════════════════════

# ─── Afficher les N dernières lignes d'un log ─────────────────────────
logger_show() {
    local log_type="${1:-actions}"   # actions | errors | security
    local lines="${2:-30}"

    local log_file
    case "$log_type" in
        actions)  log_file="${CFG_LOG_ACTIONS:-$HOME/mon_env/logs/actions.log}" ;;
        errors)   log_file="${CFG_LOG_ERRORS:-$HOME/mon_env/logs/errors.log}" ;;
        security) log_file="${CFG_LOG_SECURITY:-$HOME/mon_env/logs/security.log}" ;;
        *)        log_file="${CFG_LOG_ACTIONS:-$HOME/mon_env/logs/actions.log}" ;;
    esac

    if [[ ! -f "$log_file" ]]; then
        echo "  Aucun log disponible."
        return 0
    fi

    # Colorer les lignes selon le niveau
    tail -"$lines" "$log_file" | while IFS= read -r line; do
        if [[ "$line" == *"[ERROR]"* ]]; then
            printf '\e[31m%s\e[0m\n' "$line"
        elif [[ "$line" == *"[WARN ]"* ]]; then
            printf '\e[33m%s\e[0m\n' "$line"
        elif [[ "$line" == *"[SEC  ]"* ]]; then
            printf '\e[35m%s\e[0m\n' "$line"
        elif [[ "$line" == *"[DEBUG]"* ]]; then
            printf '\e[2;37m%s\e[0m\n' "$line"
        else
            printf '\e[37m%s\e[0m\n' "$line"
        fi
    done
}

# ─── Vider un fichier log ────────────────────────────────────────────
logger_clear() {
    local log_type="${1:-actions}"

    local log_file
    case "$log_type" in
        actions)  log_file="${CFG_LOG_ACTIONS:-$HOME/mon_env/logs/actions.log}" ;;
        errors)   log_file="${CFG_LOG_ERRORS:-$HOME/mon_env/logs/errors.log}" ;;
        security) log_file="${CFG_LOG_SECURITY:-$HOME/mon_env/logs/security.log}" ;;
        all)
            : > "${CFG_LOG_ACTIONS:-$HOME/mon_env/logs/actions.log}" 2>/dev/null || true
            : > "${CFG_LOG_ERRORS:-$HOME/mon_env/logs/errors.log}" 2>/dev/null || true
            : > "${CFG_LOG_SECURITY:-$HOME/mon_env/logs/security.log}" 2>/dev/null || true
            return 0
            ;;
        *) return 1 ;;
    esac

    : > "$log_file" 2>/dev/null || true
}

# ─── Stats des logs ──────────────────────────────────────────────────
logger_stats() {
    local actions_count errors_count security_count

    actions_count=$(wc -l < "${CFG_LOG_ACTIONS:-$HOME/mon_env/logs/actions.log}" 2>/dev/null || echo 0)
    errors_count=$(wc -l < "${CFG_LOG_ERRORS:-$HOME/mon_env/logs/errors.log}" 2>/dev/null || echo 0)
    security_count=$(wc -l < "${CFG_LOG_SECURITY:-$HOME/mon_env/logs/security.log}" 2>/dev/null || echo 0)

    echo "  Actions  : $actions_count entrées"
    echo "  Erreurs  : $errors_count entrées"
    echo "  Sécurité : $security_count entrées"
}

# ─── Menu logs interactif ────────────────────────────────────────────
logger_menu() {
    # Ce menu est appelé depuis main.sh
    # Les variables C, G, Y, R, W, NC doivent être chargées (themes.sh)
    while true; do
        clear
        printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗\n"
        printf "║${NC:-\e[0m}  ${Y:-\e[33m}📋 JOURNAUX SYSTÈME${NC:-\e[0m}\n"
        printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣\n"
        printf "║${NC:-\e[0m}  [1] Logs actions     [2] Logs erreurs    [3] Logs sécurité\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  [4] Statistiques    [5] Vider les logs  [0] Retour\n"
        printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝\n${NC:-\e[0m}"
        echo -ne "  Choix : "
        read -r choice

        case "$choice" in
            1) clear; echo -e "\n  ${Y:-\e[33m}=== LOGS ACTIONS (30 dernières) ===${NC:-\e[0m}\n"
               logger_show "actions" 30; echo ""; read -rp "  Entrée..." ;;
            2) clear; echo -e "\n  ${R:-\e[31m}=== LOGS ERREURS ===${NC:-\e[0m}\n"
               logger_show "errors" 30; echo ""; read -rp "  Entrée..." ;;
            3) clear; echo -e "\n  ${M:-\e[35m}=== LOGS SÉCURITÉ ===${NC:-\e[0m}\n"
               logger_show "security" 30; echo ""; read -rp "  Entrée..." ;;
            4) clear; echo -e "\n  ${C:-\e[36m}=== STATISTIQUES ===${NC:-\e[0m}\n"
               logger_stats; echo ""; read -rp "  Entrée..." ;;
            5) echo -ne "  ${R:-\e[31m}Vider TOUS les logs ? (o/n) : ${NC:-\e[0m}"
               read -r c
               [[ "$c" == "o" || "$c" == "O" ]] && logger_clear "all" && \
                   echo -e "  ${G:-\e[32m}Logs vidés.${NC:-\e[0m}" && sleep 1 ;;
            0|"") return 0 ;;
        esac
    done
}
