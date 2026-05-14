#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# core/ui.sh — Interface terminal : couleurs, menus, widgets, dashboard
# Dépend de : core/config.sh, core/themes.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

# ─── Couleurs de secours (si themes.sh pas encore chargé) ─────────────
: "${C:='\e[36m'}"
: "${G:='\e[32m'}"
: "${Y:='\e[33m'}"
: "${R:='\e[31m'}"
: "${B:='\e[34m'}"
: "${M:='\e[35m'}"
: "${W:='\e[1;37m'}"
: "${D:='\e[2;37m'}"
: "${NC:='\e[0m'}"

# ═══════════════════════════════════════════════════════════════════════
#  FONCTIONS D'AFFICHAGE DE BASE
# ═══════════════════════════════════════════════════════════════════════

ui_info()    { printf "${C}  ℹ  ${NC}%s\n"  "$*"; }
ui_success() { printf "${G}  ✅  ${NC}%s\n" "$*"; }
ui_warning() { printf "${Y}  ⚠️   ${NC}%s\n" "$*"; }
ui_error()   { printf "${R}  ❌  ${NC}%s\n" "$*" >&2; }
ui_step()    { printf "\n${W}━━━ %s ${NC}\n\n" "$*"; }
ui_dim()     { printf "${D}  %s${NC}\n" "$*"; }
ui_title()   { printf "\n${Y}  ★  %s${NC}\n\n" "$*"; }

# ─── Séparateur ──────────────────────────────────────────────────────
ui_sep() {
    local char="${1:─}"
    local width="${2:-62}"
    printf "${D}"
    printf '%*s' "$width" '' | tr ' ' "$char"
    printf "${NC}\n"
}

# ─── Boîte titre ─────────────────────────────────────────────────────
ui_box_title() {
    local title="$1"
    local color="${2:-$C}"
    printf "${color}╔══════════════════════════════════════════════════════════════╗\n"
    printf "║${NC}  ${Y}%-60s${color}║${NC}\n" "$title"
    printf "${color}╚══════════════════════════════════════════════════════════════╝${NC}\n\n"
}

# ─── Barre de progression ────────────────────────────────────────────
ui_progress() {
    local label="${1:-Traitement}"
    local steps="${2:-20}"
    local delay="${3:-0.04}"

    printf "\n${C}  %s ${NC}" "$label"
    for (( i=0; i<steps; i++ )); do
        printf "${G}█${NC}"
        sleep "$delay"
    done
    printf " ${G}✅${NC}\n\n"
}

# ─── Spinner ─────────────────────────────────────────────────────────
ui_spinner() {
    local pid="$1"
    local label="${2:-Chargement}"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0

    tput civis 2>/dev/null || true
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${C}  %s${NC} ${Y}%s${NC} " "${frames[$i]}" "$label"
        (( i = (i + 1) % ${#frames[@]} ))
        sleep 0.1
    done
    printf "\r${G}  ✅${NC} %-40s\n" "$label"
    tput cnorm 2>/dev/null || true
}

# ─── Prompt de confirmation ──────────────────────────────────────────
ui_confirm() {
    local question="$1"
    local default="${2:-n}"   # o ou n

    local hint
    [[ "$default" == "o" ]] && hint="[O/n]" || hint="[o/N]"

    echo -ne "${Y}  ${question} ${hint} : ${NC}"
    read -r answer

    answer="${answer:-$default}"
    [[ "${answer,,}" == "o" ]]
}

# ─── Input texte avec valeur par défaut ──────────────────────────────
ui_input() {
    local prompt="$1"
    local default="${2:-}"

    if [[ -n "$default" ]]; then
        echo -ne "${C}  ${prompt} ${D}(défaut: ${default})${NC}${C} : ${NC}"
    else
        echo -ne "${C}  ${prompt} : ${NC}"
    fi

    read -r value
    echo "${value:-$default}"
}

# ─── Sélection dans une liste ────────────────────────────────────────
ui_select() {
    local prompt="$1"
    shift
    local options=("$@")
    local i=1

    echo -e "\n${C}  ${prompt}${NC}"
    for opt in "${options[@]}"; do
        printf "  ${B}[%d]${NC} %s\n" "$i" "$opt"
        (( i++ ))
    done
    echo ""
    echo -ne "${C}  Choix : ${NC}"
    read -r sel

    # Valider la sélection
    if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#options[@]} )); then
        echo "${options[$((sel-1))]}"
        return 0
    fi
    return 1
}

# ─── Menu fzf (si disponible) ou fallback ────────────────────────────
ui_fzf_menu() {
    local prompt="$1"
    shift
    local options=("$@")

    if command -v fzf &>/dev/null; then
        printf '%s\n' "${options[@]}" | fzf \
            --prompt="  ${prompt} > " \
            --height=40% \
            --border=rounded \
            --color="fg:#cdd6f4,bg:#1e1e2e,hl:#89b4fa,fg+:#cdd6f4,bg+:#313244,hl+:#89b4fa,info:#cba6f7,prompt:#89b4fa,pointer:#f38ba8,marker:#a6e3a1" \
            --reverse
    else
        # Fallback sans fzf
        ui_select "$prompt" "${options[@]}"
    fi
}

# ═══════════════════════════════════════════════════════════════════════
#  DASHBOARD — EN-TÊTE DYNAMIQUE
# ═══════════════════════════════════════════════════════════════════════

ui_header() {
    local pseudo="${PSEUDO_NAME:-Shadow}"
    local heure modele batterie ip_pub ip_loc ram_used ram_total

    heure=$(date '+%H:%M:%S')
    modele=$(getprop ro.product.model 2>/dev/null || echo "Termux Device")

    # Batterie
    local bat_path
    bat_path=$(ls /sys/class/power_supply/battery/capacity \
               /sys/class/power_supply/Battery/capacity 2>/dev/null | head -1 || echo "")
    if [[ -n "$bat_path" && -f "$bat_path" ]]; then
        batterie="$(cat "$bat_path" 2>/dev/null || echo "?")%"
    else
        local bat_json
        bat_json=$(termux-battery-status 2>/dev/null || echo "")
        if [[ -n "$bat_json" ]]; then
            batterie=$(echo "$bat_json" | grep -oP '"percentage":\s*\K\d+' || echo "?")
            [[ "$batterie" != "?" ]] && batterie="${batterie}%" || batterie="N/A"
        else
            batterie="N/A"
        fi
    fi

    # IP publique (timeout court)
    ip_pub=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || echo "offline")

    # IP locale
    ip_loc=$(ip -4 addr show 2>/dev/null \
             | grep -oP '(?<=inet\s)\d+(\.\d+){3}' \
             | grep -v '^127\.' | head -1 || echo "")
    [[ -z "$ip_loc" ]] && ip_loc=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "?")
    [[ -z "$ip_loc" ]] && ip_loc="?"

    # RAM
    ram_used=$(free -m 2>/dev/null | awk 'NR==2{print $3}' || echo "?")
    ram_total=$(free -m 2>/dev/null | awk 'NR==2{print $2}' || echo "?")

    printf "${C}╔══════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${C}║${NC}  ${Y}%-22s${NC}  ${W}CYBER DASHBOARD v%s${NC}  ${D}%s${NC}  ${C}║${NC}\n" \
           "${pseudo}@termux" "${CFG_VERSION:-1.0}" "$heure"
    printf "${C}╠══════════════════════════════════════════════════════════════╣${NC}\n"
    printf "${C}║${NC}  ${B}📱 Appareil :${NC} %-22s  ${B}🔋 Batterie:${NC} %-7s ${C}║${NC}\n" \
           "$modele" "$batterie"
    printf "${C}║${NC}  ${B}🌐 IP Pub   :${NC} %-22s  ${B}📡 IP Loc  :${NC} %-7s ${C}║${NC}\n" \
           "$ip_pub" "$ip_loc"
    printf "${C}║${NC}  ${B}💾 RAM      :${NC} %-22s  ${B}🐚 Shell   :${NC} %-7s ${C}║${NC}\n" \
           "${ram_used}MB / ${ram_total}MB" "$(basename "${SHELL:-bash}")"
    printf "${C}╚══════════════════════════════════════════════════════════════╝${NC}\n\n"
}

# ═══════════════════════════════════════════════════════════════════════
#  BANNER NÉOFETCH STYLE
# ═══════════════════════════════════════════════════════════════════════

ui_banner() {
    local pseudo="${PSEUDO_NAME:-Shadow}"
    local ram_used ram_total storage uptime_s

    ram_used=$(free -m 2>/dev/null | awk 'NR==2{print $3}' || echo "?")
    ram_total=$(free -m 2>/dev/null | awk 'NR==2{print $2}' || echo "?")
    storage=$(df -h "$HOME" 2>/dev/null | awk 'NR==2{print $3"/"$2}' || echo "?")
    uptime_s=$(uptime -p 2>/dev/null | sed 's/up //' || echo "?")

    printf "${C}"
    printf "         .o8888b.              ${W}%s${NC}${C}@termux\n"         "$pseudo"
    printf "        d8P'    'Y8b           ${D}─────────────────────────${NC}\n"
    printf "       88P       888           ${B}OS     :${NC} Android (Termux)\n"
    printf "       88P       888           ${B}Shell  :${NC} %s\n"           "$(basename "${SHELL:-bash}")"
    printf "       88P       888           ${B}RAM    :${NC} %sMB / %sMB\n"  "$ram_used" "$ram_total"
    printf "        Y8b      d8P           ${B}Disque :${NC} %s\n"           "$storage"
    printf "         'Y8888888P'           ${B}Uptime :${NC} %s\n"           "$uptime_s"
    printf "                               ${B}Thème  :${NC} ${G}%s${NC}\n"  "${THEME_NAME:-cyber}"
    printf "${NC}\n"
    printf "  \033[41m   \033[42m   \033[43m   \033[44m   \033[45m   \033[46m   \033[47m   \033[0m\n\n"
}

# ═══════════════════════════════════════════════════════════════════════
#  MENU PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════

ui_main_menu() {
    # Statut TOR
    local tor_status
    pgrep -x "tor" &>/dev/null \
        && tor_status="${G}● ACTIF  ${NC}" \
        || tor_status="${R}● INACTIF${NC}"

    printf "${C}╔══════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${C}║${NC}  ${W}MENU PRINCIPAL${NC}                              TOR: %b  ${C}║${NC}\n" \
           "$tor_status"
    printf "${C}╠══════════════════════════════════════╦═══════════════════════╣${NC}\n"
    printf "${C}║${NC}  ${G}[1]${NC} 📊 Monitoring système           ${C}║${NC}  ${G}[7]${NC}  📝 Notes          ${C}║${NC}\n"
    printf "${C}║${NC}  ${G}[2]${NC} 🐙 GitHub                       ${C}║${NC}  ${G}[8]${NC}  🔧 Scripts        ${C}║${NC}\n"
    printf "${C}║${NC}  ${G}[3]${NC} 📁 Projets                      ${C}║${NC}  ${G}[9]${NC}  🌐 Réseau         ${C}║${NC}\n"
    printf "${C}║${NC}  ${G}[4]${NC} 🔒 Pentest toolkit              ${C}║${NC}  ${G}[10]${NC} 🧅 TOR            ${C}║${NC}\n"
    printf "${C}║${NC}  ${G}[5]${NC} 🔑 SSH manager                  ${C}║${NC}  ${G}[11]${NC} 💾 Backup         ${C}║${NC}\n"
    printf "${C}║${NC}  ${G}[6]${NC} 🖥️  Workspace                   ${C}║${NC}  ${G}[12]${NC} 🔌 Plugins        ${C}║${NC}\n"
    printf "${C}╠══════════════════════════════════════╩═══════════════════════╣${NC}\n"
    printf "${C}║${NC}  ${Y}[i]${NC} 📦 Installer paquet   ${Y}[l]${NC} 📋 Logs   ${Y}[s]${NC} ⚙️  Paramètres  ${C}║${NC}\n"
    printf "${C}║${NC}  ${Y}[u]${NC} ⬆️  Mise à jour        ${Y}[h]${NC} ❓ Aide   ${Y}[0]${NC} 🚪 Quitter       ${C}║${NC}\n"
    printf "${C}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    echo -ne "\n  ${C}Choix :${NC} "
}

# ═══════════════════════════════════════════════════════════════════════
#  ÉCRAN D'AIDE
# ═══════════════════════════════════════════════════════════════════════

ui_help() {
    clear
    ui_box_title "❓ AIDE — Cyber Dashboard Termux v${CFG_VERSION:-1.0}"

    printf "${B}  Commandes disponibles depuis le terminal :${NC}\n\n"
    printf "  ${G}cyd${NC}            → Lancer le dashboard\n"
    printf "  ${G}cyd-update${NC}     → Mettre à jour\n"
    printf "  ${G}cyd-install${NC}    → Réinstaller\n"
    printf "  ${G}ll${NC}             → ls -la\n"
    printf "  ${G}cls${NC}            → clear\n"
    printf "  ${G}update${NC}         → pkg update && pkg upgrade\n"
    printf "  ${G}gh${NC}             → cd github_projects/\n"
    printf "  ${G}myenv${NC}          → cd mon_env/\n\n"

    printf "${B}  Structure :${NC}\n\n"
    printf "  ${D}~/mon_env/core/     ${NC}→ Noyau\n"
    printf "  ${D}~/mon_env/modules/  ${NC}→ Modules\n"
    printf "  ${D}~/mon_env/themes/   ${NC}→ Thèmes\n"
    printf "  ${D}~/mon_env/plugins/  ${NC}→ Plugins\n"
    printf "  ${D}~/mon_env/logs/     ${NC}→ Journaux\n"
    printf "  ${D}~/mon_env/database/ ${NC}→ SQLite\n\n"

    printf "${Y}  ⚠️  Les outils pentest sont pour usage légal uniquement.${NC}\n\n"
    read -rp "  Entrée pour revenir..."
}

# ═══════════════════════════════════════════════════════════════════════
#  MENU PARAMÈTRES
# ═══════════════════════════════════════════════════════════════════════

ui_settings_menu() {
    while true; do
        clear
        ui_box_title "⚙️  PARAMÈTRES"

        printf "  ${B}Pseudo actuel :${NC} ${W}${PSEUDO_NAME:-Shadow}${NC}\n"
        printf "  ${B}Thème actuel  :${NC} ${W}${THEME_NAME:-cyber}${NC}\n\n"

        printf "  ${G}[1]${NC} Changer le pseudo\n"
        printf "  ${G}[2]${NC} Changer le thème\n"
        printf "  ${G}[3]${NC} Afficher la config complète\n"
        printf "  ${G}[4]${NC} Niveau de log [actuel: ${LOG_LEVEL:-info}]\n"
        printf "  ${G}[0]${NC} Retour\n\n"

        echo -ne "  ${C}Choix : ${NC}"
        read -r choice

        case "$choice" in
            1)
                local new_pseudo
                new_pseudo=$(ui_input "Nouveau pseudo" "${PSEUDO_NAME:-Shadow}")
                if [[ -n "$new_pseudo" ]]; then
                    config_set "PSEUDO_NAME" "$new_pseudo"
                    PSEUDO_NAME="$new_pseudo"
                    ui_success "Pseudo mis à jour : $new_pseudo"
                    sleep 1
                fi
                ;;
            2)
                local themes_list=("cyber" "matrix" "neon" "red")
                printf "\n  ${C}Thèmes disponibles :${NC}\n"
                for i in "${!themes_list[@]}"; do
                    printf "  ${B}[%d]${NC} %s\n" "$((i+1))" "${themes_list[$i]}"
                done
                echo -ne "\n  ${C}Choix (1-4) : ${NC}"
                read -r t
                if [[ "$t" =~ ^[1-4]$ ]]; then
                    local new_theme="${themes_list[$((t-1))]}"
                    config_set "THEME_NAME" "$new_theme"
                    THEME_NAME="$new_theme"
                    # Recharger le thème
                    # shellcheck source=/dev/null
                    source "${CFG_THEMES_DIR:-$HOME/mon_env/themes}/${new_theme}.theme" 2>/dev/null || true
                    ui_success "Thème changé : $new_theme"
                    sleep 1
                fi
                ;;
            3)
                clear
                ui_box_title "📋 Configuration complète"
                config_show 2>/dev/null || true
                echo ""
                read -rp "  Entrée..."
                ;;
            4)
                local levels=("debug" "info" "warn" "error")
                printf "\n  ${C}Niveaux :${NC}\n"
                for i in "${!levels[@]}"; do
                    printf "  ${B}[%d]${NC} %s\n" "$((i+1))" "${levels[$i]}"
                done
                echo -ne "\n  ${C}Choix (1-4) : ${NC}"
                read -r lv
                if [[ "$lv" =~ ^[1-4]$ ]]; then
                    local new_level="${levels[$((lv-1))]}"
                    config_set "LOG_LEVEL" "$new_level"
                    LOG_LEVEL="$new_level"
                    ui_success "Niveau de log : $new_level"
                    sleep 1
                fi
                ;;
            0|"") return 0 ;;
        esac
    done
}

# ─── Quitter proprement ───────────────────────────────────────────────
ui_quit() {
    clear
    printf "\n${G}╔══════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${G}║${NC}   À bientôt, ${W}%-48s${G}║${NC}\n" "${PSEUDO_NAME:-Shadow} !"
    printf "${G}║${NC}   ${D}Cyber Dashboard Termux v${CFG_VERSION:-1.0} — Stay in the shadows...${NC}  ${G}║${NC}\n"
    printf "${G}╚══════════════════════════════════════════════════════════════╝${NC}\n\n"
    tput cnorm 2>/dev/null || true
    stty sane 2>/dev/null || true
    exit 0
}
