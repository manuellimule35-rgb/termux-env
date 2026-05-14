#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# modules/workspace.sh — Workspaces thématiques : dev, pentest, osint, serveur
# Dépend de : core/config.sh, core/logger.sh, core/ui.sh, core/utils.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

readonly WS_CONFIG_DIR="${CFG_CONFIGS_DIR:-$HOME/mon_env/configs}/workspaces"
readonly WS_CURRENT_FILE="$WS_CONFIG_DIR/current.conf"

# ─── Workspaces prédéfinis ────────────────────────────────────────────
declare -A WS_BUILTIN_DESC=(
    ["dev"]="Développement — éditeur, git, node, python"
    ["pentest"]="Pentest — nmap, hydra, sqlmap, tor"
    ["osint"]="OSINT — recherche, subfinder, whois, curl"
    ["serveur"]="Serveur — SSH, monitoring, logs, réseau"
    ["perso"]="Personnel — notes, scripts, backup"
)

# ═══════════════════════════════════════════════════════════════════════
#  WORKSPACE ACTUEL
# ═══════════════════════════════════════════════════════════════════════

_ws_current() {
    [[ -f "$WS_CURRENT_FILE" ]] && \
        grep "WORKSPACE=" "$WS_CURRENT_FILE" 2>/dev/null | \
        cut -d'=' -f2 | tr -d '"' || echo "aucun"
}

# ═══════════════════════════════════════════════════════════════════════
#  LISTE DES WORKSPACES
# ═══════════════════════════════════════════════════════════════════════

_ws_list() {
    clear
    printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}🖥️  WORKSPACES${NC:-\e[0m}  —  Actuel : ${G:-\e[32m}%s${NC:-\e[0m}\n" \
        "$(_ws_current)"
    printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"

    local current
    current=$(_ws_current)

    # Workspaces prédéfinis
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${W:-\e[1;37m}Prédéfinis :${NC:-\e[0m}\n"
    for ws_name in "${!WS_BUILTIN_DESC[@]}"; do
        local icon=" "
        [[ "$ws_name" == "$current" ]] && icon="${G:-\e[32m}▶${NC:-\e[0m}"
        printf "${C:-\e[36m}║${NC:-\e[0m}  %b %-12s ${D:-\e[2;37m}%s${NC:-\e[0m}\n" \
            "$icon" "$ws_name" "${WS_BUILTIN_DESC[$ws_name]}"
    done

    # Workspaces personnalisés
    mkdir -p "$WS_CONFIG_DIR"
    local custom_found=false
    while IFS= read -r ws_file; do
        local ws_name
        ws_name=$(basename "$ws_file" .ws)
        # Ignorer les prédéfinis
        [[ -v "WS_BUILTIN_DESC[$ws_name]" ]] && continue
        if ! $custom_found; then
            printf "${C:-\e[36m}║${NC:-\e[0m}\n"
            printf "${C:-\e[36m}║${NC:-\e[0m}  ${W:-\e[1;37m}Personnalisés :${NC:-\e[0m}\n"
            custom_found=true
        fi
        local ws_desc
        ws_desc=$(grep "DESC=" "$ws_file" 2>/dev/null | cut -d'"' -f2 || echo "")
        local icon=" "
        [[ "$ws_name" == "$current" ]] && icon="${G:-\e[32m}▶${NC:-\e[0m}"
        printf "${C:-\e[36m}║${NC:-\e[0m}  %b ${M:-\e[35m}%-12s${NC:-\e[0m} ${D:-\e[2;37m}%s${NC:-\e[0m}\n" \
            "$icon" "$ws_name" "$ws_desc"
    done < <(find "$WS_CONFIG_DIR" -name "*.ws" 2>/dev/null | sort)

    printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
}

# ═══════════════════════════════════════════════════════════════════════
#  ACTIVER UN WORKSPACE
# ═══════════════════════════════════════════════════════════════════════

_ws_activate() {
    local ws_name="$1"

    case "$ws_name" in
        dev)     _ws_setup_dev     ;;
        pentest) _ws_setup_pentest ;;
        osint)   _ws_setup_osint   ;;
        serveur) _ws_setup_serveur ;;
        perso)   _ws_setup_perso   ;;
        *)
            # Workspace personnalisé
            local ws_file="$WS_CONFIG_DIR/${ws_name}.ws"
            [[ -f "$ws_file" ]] && _ws_run_custom "$ws_file" || {
                ui_error "Workspace '$ws_name' introuvable."
                sleep 2; return 1
            }
            ;;
    esac

    # Sauvegarder le workspace actuel
    mkdir -p "$WS_CONFIG_DIR"
    echo "WORKSPACE=\"$ws_name\"" > "$WS_CURRENT_FILE"
    echo "ACTIVATED_AT=\"$(utils_timestamp_human)\"" >> "$WS_CURRENT_FILE"

    log_action "Workspace activé : $ws_name" "workspace"
    utils_notify "Workspace" "Activé : $ws_name" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════════
#  WORKSPACE DEV
# ═══════════════════════════════════════════════════════════════════════

_ws_setup_dev() {
    clear
    printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}💻 WORKSPACE DEV${NC:-\e[0m}\n"
    printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"

    _ws_check_tool "git"    "pkg install git -y"
    _ws_check_tool "python" "pkg install python -y"
    _ws_check_tool "node"   "pkg install nodejs -y"
    _ws_check_tool "vim"    "pkg install vim -y"
    _ws_check_tool "tmux"   "pkg install tmux -y"

    printf "\n  ${W:-\e[1;37m}Commandes utiles :${NC:-\e[0m}\n"
    printf "  ${G:-\e[32m}git clone${NC:-\e[0m}  <url>       Cloner un dépôt\n"
    printf "  ${G:-\e[32m}python${NC:-\e[0m}               Lancer Python\n"
    printf "  ${G:-\e[32m}node${NC:-\e[0m}                 Lancer Node.js\n"
    printf "  ${G:-\e[32m}tmux${NC:-\e[0m}                 Ouvrir tmux\n\n"

    printf "  ${Y:-\e[33m}Workspace DEV activé.${NC:-\e[0m}\n\n"

    printf "  ${G:-\e[32m}[1]${NC:-\e[0m} Ouvrir tmux\n"
    printf "  ${G:-\e[32m}[2]${NC:-\e[0m} Ouvrir vim\n"
    printf "  ${G:-\e[32m}[3]${NC:-\e[0m} Naviguer vers github_projects/\n"
    printf "  ${G:-\e[32m}[0]${NC:-\e[0m} Retour\n\n"
    echo -ne "  ${C:-\e[36m}Action : ${NC:-\e[0m}"; read -r action

    case "$action" in
        1) utils_cmd_exists tmux && tmux new-session -s dev 2>/dev/null || \
               ui_warning "tmux non disponible" ;;
        2) utils_cmd_exists vim && vim || ui_warning "vim non disponible" ;;
        3) cd "${CFG_GITHUB_DIR:-$HOME/mon_env/github_projects}" && \
               printf "  ${G:-\e[32m}→ %s${NC:-\e[0m}\n" \
               "${CFG_GITHUB_DIR/$HOME/~}" && ls -la ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════
#  WORKSPACE PENTEST
# ═══════════════════════════════════════════════════════════════════════

_ws_setup_pentest() {
    # Afficher le disclaimer avant de continuer
    sec_pentest_disclaimer 2>/dev/null || return 1

    clear
    printf "${R:-\e[31m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${R:-\e[31m}║${NC:-\e[0m}  ${Y:-\e[33m}🔒 WORKSPACE PENTEST${NC:-\e[0m}\n"
    printf "${R:-\e[31m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"

    _ws_check_tool "nmap"        "pkg install nmap -y"
    _ws_check_tool "hydra"       "pkg install thc-hydra -y"
    _ws_check_tool "sqlmap"      "pip install sqlmap --break-system-packages"
    _ws_check_tool "proxychains4" "pkg install proxychains-ng -y"
    _ws_check_tool "tor"         "pkg install tor -y"

    printf "\n  ${W:-\e[1;37m}Accès rapide :${NC:-\e[0m}\n"
    printf "  ${R:-\e[31m}nmap${NC:-\e[0m} -sV <ip>          Scanner services\n"
    printf "  ${R:-\e[31m}hydra${NC:-\e[0m} -l user -P wl.txt  Bruteforce\n"
    printf "  ${R:-\e[31m}sqlmap${NC:-\e[0m} -u <url> --dbs   Injection SQL\n"
    printf "  ${R:-\e[31m}proxychains4${NC:-\e[0m} <cmd>       Via TOR\n\n"

    printf "  ${Y:-\e[33m}Workspace PENTEST activé.${NC:-\e[0m}\n\n"

    printf "  ${G:-\e[32m}[1]${NC:-\e[0m} Démarrer TOR automatiquement\n"
    printf "  ${G:-\e[32m}[2]${NC:-\e[0m} Ouvrir le module Pentest\n"
    printf "  ${G:-\e[32m}[0]${NC:-\e[0m} Retour\n\n"
    echo -ne "  ${C:-\e[36m}Action : ${NC:-\e[0m}"; read -r action

    case "$action" in
        1)
            source "${CFG_MODULES_DIR:-$HOME/mon_env/modules}/tor.sh" 2>/dev/null && \
                _tor_start || ui_warning "Module TOR non disponible"
            ;;
        2)
            source "${CFG_MODULES_DIR:-$HOME/mon_env/modules}/pentest.sh" 2>/dev/null && \
                pentest_menu || ui_warning "Module pentest non disponible"
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════
#  WORKSPACE OSINT
# ═══════════════════════════════════════════════════════════════════════

_ws_setup_osint() {
    clear
    printf "${M:-\e[35m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${M:-\e[35m}║${NC:-\e[0m}  ${Y:-\e[33m}🔍 WORKSPACE OSINT${NC:-\e[0m}\n"
    printf "${M:-\e[35m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"

    _ws_check_tool "curl"      "pkg install curl -y"
    _ws_check_tool "wget"      "pkg install wget -y"
    _ws_check_tool "whois"     "pkg install whois -y"
    _ws_check_tool "nmap"      "pkg install nmap -y"
    _ws_check_tool "jq"        "pkg install jq -y"
    _ws_check_tool "subfinder" "go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"

    printf "\n  ${W:-\e[1;37m}Commandes OSINT utiles :${NC:-\e[0m}\n"
    printf "  ${M:-\e[35m}whois${NC:-\e[0m} <domaine>             Infos domaine\n"
    printf "  ${M:-\e[35m}subfinder${NC:-\e[0m} -d <domaine>      Sous-domaines\n"
    printf "  ${M:-\e[35m}nmap -sn${NC:-\e[0m} 192.168.1.0/24     Hôtes réseau\n"
    printf "  ${M:-\e[35m}curl${NC:-\e[0m} https://api.ipify.org  IP publique\n"
    printf "  ${M:-\e[35m}curl${NC:-\e[0m} https://ipinfo.io/<ip> Infos IP\n\n"

    printf "  ${Y:-\e[33m}Workspace OSINT activé.${NC:-\e[0m}\n\n"

    printf "  ${G:-\e[32m}[1]${NC:-\e[0m} Recherche IP (ipinfo.io)\n"
    printf "  ${G:-\e[32m}[2]${NC:-\e[0m} Whois rapide\n"
    printf "  ${G:-\e[32m}[3]${NC:-\e[0m} IP publique actuelle\n"
    printf "  ${G:-\e[32m}[0]${NC:-\e[0m} Retour\n\n"
    echo -ne "  ${C:-\e[36m}Action : ${NC:-\e[0m}"; read -r action

    case "$action" in
        1)
            echo -ne "  ${C:-\e[36m}IP à rechercher : ${NC:-\e[0m}"; read -r target_ip
            [[ -n "$target_ip" ]] && \
                curl -s "https://ipinfo.io/${target_ip}/json" 2>/dev/null \
                | jq . 2>/dev/null || \
                curl -s "https://ipinfo.io/${target_ip}" 2>/dev/null
            echo ""; read -rp "  Entrée..."
            ;;
        2)
            echo -ne "  ${C:-\e[36m}Domaine : ${NC:-\e[0m}"; read -r domain
            [[ -n "$domain" ]] && whois "$domain" 2>/dev/null | head -30
            echo ""; read -rp "  Entrée..."
            ;;
        3)
            printf "\n  ${B:-\e[34m}IP publique :${NC:-\e[0m} %s\n\n" "$(utils_get_public_ip)"
            read -rp "  Entrée..."
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════
#  WORKSPACE SERVEUR
# ═══════════════════════════════════════════════════════════════════════

_ws_setup_serveur() {
    clear
    printf "${B:-\e[34m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${B:-\e[34m}║${NC:-\e[0m}  ${Y:-\e[33m}🖥️  WORKSPACE SERVEUR${NC:-\e[0m}\n"
    printf "${B:-\e[34m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"

    _ws_check_tool "ssh"   "pkg install openssh -y"
    _ws_check_tool "htop"  "pkg install htop -y"
    _ws_check_tool "tmux"  "pkg install tmux -y"
    _ws_check_tool "curl"  "pkg install curl -y"
    _ws_check_tool "ss"    "(intégré au système)"

    printf "\n  ${W:-\e[1;37m}État rapide du système :${NC:-\e[0m}\n"
    printf "  ${B:-\e[34m}RAM    :${NC:-\e[0m} %s\n" "$(utils_get_ram)"
    printf "  ${B:-\e[34m}Disque :${NC:-\e[0m} %s\n" "$(utils_get_storage)"
    printf "  ${B:-\e[34m}Uptime :${NC:-\e[0m} %s\n" "$(utils_get_uptime)"
    printf "  ${B:-\e[34m}IP loc :${NC:-\e[0m} %s\n\n" "$(utils_get_local_ip)"

    printf "  ${G:-\e[32m}[1]${NC:-\e[0m} Lancer htop\n"
    printf "  ${G:-\e[32m}[2]${NC:-\e[0m} Ports ouverts locaux\n"
    printf "  ${G:-\e[32m}[3]${NC:-\e[0m} Connexions SSH rapides\n"
    printf "  ${G:-\e[32m}[4]${NC:-\e[0m} Ouvrir tmux (session serveur)\n"
    printf "  ${G:-\e[32m}[0]${NC:-\e[0m} Retour\n\n"
    echo -ne "  ${C:-\e[36m}Action : ${NC:-\e[0m}"; read -r action

    case "$action" in
        1) utils_cmd_exists htop && htop || ui_warning "htop non disponible" ;;
        2)
            printf "\n  ${W:-\e[1;37m}Ports ouverts :${NC:-\e[0m}\n\n"
            ss -tlnp 2>/dev/null | tail -n +2 || \
                netstat -tlnp 2>/dev/null | tail -n +3
            echo ""; read -rp "  Entrée..."
            ;;
        3)
            source "${CFG_MODULES_DIR:-$HOME/mon_env/modules}/ssh.sh" 2>/dev/null && \
                ssh_menu || ui_warning "Module SSH non disponible"
            ;;
        4)
            utils_cmd_exists tmux && \
                tmux new-session -s serveur 2>/dev/null || \
                ui_warning "tmux non disponible"
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════
#  WORKSPACE PERSO
# ═══════════════════════════════════════════════════════════════════════

_ws_setup_perso() {
    clear
    printf "${G:-\e[32m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${G:-\e[32m}║${NC:-\e[0m}  ${Y:-\e[33m}📋 WORKSPACE PERSO${NC:-\e[0m}\n"
    printf "${G:-\e[32m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"

    printf "  ${W:-\e[1;37m}Accès rapide :${NC:-\e[0m}\n"
    printf "  ${G:-\e[32m}[1]${NC:-\e[0m} Notes rapides\n"
    printf "  ${G:-\e[32m}[2]${NC:-\e[0m} Scripts personnels\n"
    printf "  ${G:-\e[32m}[3]${NC:-\e[0m} Backup rapide\n"
    printf "  ${G:-\e[32m}[4]${NC:-\e[0m} Stats base de données\n"
    printf "  ${G:-\e[32m}[0]${NC:-\e[0m} Retour\n\n"
    echo -ne "  ${C:-\e[36m}Action : ${NC:-\e[0m}"; read -r action

    case "$action" in
        1)
            source "${CFG_MODULES_DIR:-$HOME/mon_env/modules}/notes.sh" 2>/dev/null && \
                notes_menu || ui_warning "Module notes non disponible"
            ;;
        2)
            source "${CFG_MODULES_DIR:-$HOME/mon_env/modules}/scripts.sh" 2>/dev/null && \
                scripts_menu || ui_warning "Module scripts non disponible"
            ;;
        3)
            source "${CFG_MODULES_DIR:-$HOME/mon_env/modules}/backup.sh" 2>/dev/null && \
                _bak_database || ui_warning "Module backup non disponible"
            ;;
        4)
            clear; ui_box_title "📊 Stats BDD"
            db_stats 2>/dev/null || printf "  ${Y:-\e[33m}SQLite non disponible.${NC:-\e[0m}\n"
            echo ""; read -rp "  Entrée..."
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════
#  WORKSPACE PERSONNALISÉ — CRÉATION
# ═══════════════════════════════════════════════════════════════════════

_ws_create_custom() {
    clear
    ui_box_title "✨ CRÉER UN WORKSPACE PERSONNALISÉ"

    echo -ne "  ${C:-\e[36m}Nom du workspace : ${NC:-\e[0m}"; read -r ws_name
    [[ -z "$ws_name" ]] && return
    sec_validate_name "$ws_name" "Nom workspace" 2>/dev/null || return 1

    # Vérifier unicité
    [[ -v "WS_BUILTIN_DESC[$ws_name]" ]] && {
        ui_error "Ce nom est réservé à un workspace prédéfini."
        sleep 2; return 1
    }

    echo -ne "  ${C:-\e[36m}Description : ${NC:-\e[0m}"; read -r ws_desc

    printf "\n  ${C:-\e[36m}Commandes à exécuter à l'activation :${NC:-\e[0m}\n"
    printf "  ${D:-\e[2;37m}(une par ligne, ligne vide pour terminer)${NC:-\e[0m}\n\n"

    local commands=()
    while true; do
        echo -ne "  ${B:-\e[34m}cmd> ${NC:-\e[0m}"; read -r cmd_line
        [[ -z "$cmd_line" ]] && break
        sec_safe_command "$cmd_line" 2>/dev/null || continue
        commands+=("$cmd_line")
    done

    mkdir -p "$WS_CONFIG_DIR"
    local ws_file="$WS_CONFIG_DIR/${ws_name}.ws"

    {
        echo "# Workspace personnalisé — $ws_name"
        echo "NAME=\"$ws_name\""
        echo "DESC=\"$ws_desc\""
        echo "CREATED=\"$(utils_timestamp_human)\""
        echo ""
        echo "# Commandes d'activation"
        for cmd in "${commands[@]}"; do
            echo "CMD=\"$cmd\""
        done
    } > "$ws_file"

    ui_success "Workspace '$ws_name' créé."
    log_action "Workspace créé : $ws_name" "workspace"
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#  EXÉCUTER UN WORKSPACE PERSONNALISÉ
# ═══════════════════════════════════════════════════════════════════════

_ws_run_custom() {
    local ws_file="$1"
    # shellcheck source=/dev/null
    source "$ws_file"

    clear
    printf "${M:-\e[35m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${M:-\e[35m}║${NC:-\e[0m}  ${Y:-\e[33m}✨ WORKSPACE : %s${NC:-\e[0m}\n" "${NAME:-custom}"
    printf "${M:-\e[35m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"

    printf "  ${D:-\e[2;37m}%s${NC:-\e[0m}\n\n" "${DESC:-}"

    # Exécuter les commandes
    while IFS= read -r line; do
        [[ "$line" =~ ^CMD=\"(.*)\"$ ]] || continue
        local cmd="${BASH_REMATCH[1]}"
        printf "  ${B:-\e[34m}→ %s${NC:-\e[0m}\n" "$cmd"
        eval "$cmd" 2>&1 || true
    done < "$ws_file"

    printf "\n  ${G:-\e[32m}✅ Workspace activé.${NC:-\e[0m}\n\n"
    read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  SUPPRIMER UN WORKSPACE PERSONNALISÉ
# ═══════════════════════════════════════════════════════════════════════

_ws_delete_custom() {
    echo -ne "  ${C:-\e[36m}Nom du workspace à supprimer : ${NC:-\e[0m}"; read -r ws_name
    [[ -z "$ws_name" ]] && return
    [[ -v "WS_BUILTIN_DESC[$ws_name]" ]] && {
        ui_error "Impossible de supprimer un workspace prédéfini."
        sleep 2; return 1
    }
    local ws_file="$WS_CONFIG_DIR/${ws_name}.ws"
    [[ -f "$ws_file" ]] || { ui_error "Workspace introuvable."; sleep 2; return 1; }

    printf "  ${Y:-\e[33m}Supprimer '%s' ? (o/n) : ${NC:-\e[0m}" "$ws_name"
    read -r confirm
    [[ "${confirm,,}" != "o" ]] && return

    rm -f "$ws_file" && ui_success "Workspace '$ws_name' supprimé."
    log_action "Workspace supprimé : $ws_name" "workspace"
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#  UTILITAIRE : vérifier/afficher un outil
# ═══════════════════════════════════════════════════════════════════════

_ws_check_tool() {
    local cmd="$1"
    local install_hint="$2"
    if utils_cmd_exists "$cmd"; then
        printf "  ${G:-\e[32m}✅${NC:-\e[0m} %-15s disponible\n" "$cmd"
    else
        printf "  ${Y:-\e[33m}⚠️ ${NC:-\e[0m} %-15s ${D:-\e[2;37m}absent → %s${NC:-\e[0m}\n" \
            "$cmd" "$install_hint"
    fi
}

# ═══════════════════════════════════════════════════════════════════════
#  MENU PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════

workspace_menu() {
    log_action "Module workspace ouvert" "workspace"
    mkdir -p "$WS_CONFIG_DIR"

    while true; do
        clear
        _ws_list

        printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}🖥️  ACTIONS WORKSPACE${NC:-\e[0m}\n"
        printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[1]${NC:-\e[0m} Activer un workspace\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[2]${NC:-\e[0m} Créer un workspace personnalisé\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[3]${NC:-\e[0m} Supprimer un workspace personnalisé\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[0]${NC:-\e[0m} Retour\n"
        printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
        echo -ne "  ${C:-\e[36m}Choix : ${NC:-\e[0m}"; read -r choice

        case "$choice" in
            1)
                echo -ne "  ${C:-\e[36m}Nom du workspace : ${NC:-\e[0m}"; read -r ws
                [[ -n "$ws" ]] && _ws_activate "$ws"
                ;;
            2) _ws_create_custom ;;
            3) _ws_delete_custom ;;
            0|"") log_action "Module workspace fermé" "workspace"; return 0 ;;
            *) ui_warning "Choix invalide"; sleep 1 ;;
        esac
    done
}
