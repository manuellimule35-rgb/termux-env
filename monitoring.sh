#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# modules/monitoring.sh — Monitoring système temps réel
# Dépend de : core/config.sh, core/logger.sh, core/ui.sh, core/utils.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

# ═══════════════════════════════════════════════════════════════════════
#  COLLECTE DES MÉTRIQUES
# ═══════════════════════════════════════════════════════════════════════

_mon_get_ram() {
    free -m 2>/dev/null | awk '
        NR==2 {
            printf "used=%s total=%s free=%s percent=%d",
                $3, $2, $4, ($2>0 ? ($3/$2)*100 : 0)
        }' || echo "used=? total=? free=? percent=0"
}

_mon_get_cpu() {
    local load
    load=$(cat /proc/loadavg 2>/dev/null || echo "? ? ?")
    printf "load1=%s load5=%s load15=%s" \
        "$(echo "$load" | awk '{print $1}')" \
        "$(echo "$load" | awk '{print $2}')" \
        "$(echo "$load" | awk '{print $3}')"
}

_mon_get_processes() {
    local total running sleeping
    total=$(ps aux 2>/dev/null | tail -n +2 | wc -l || echo "?")
    running=$(ps aux 2>/dev/null | awk 'NR>1 && $8=="R"' | wc -l || echo "0")
    sleeping=$(ps aux 2>/dev/null | awk 'NR>1 && $8=="S"' | wc -l || echo "0")
    printf "total=%s running=%s sleeping=%s" "$total" "$running" "$sleeping"
}

_mon_get_storage() {
    df -h "$HOME" 2>/dev/null | awk '
        NR==2 {
            gsub(/%/,"",$5)
            printf "used=%s total=%s free=%s percent=%s",
                $3, $2, $4, $5
        }' || echo "used=? total=? free=? percent=0"
}

_mon_get_network_io() {
    local iface
    iface=$(ip route 2>/dev/null | grep default | awk '{print $5}' | head -1 || echo "")
    if [[ -z "$iface" ]]; then
        printf "rx=? tx=? iface=unknown"; return
    fi
    local rx tx
    rx=$(cat "/sys/class/net/${iface}/statistics/rx_bytes" 2>/dev/null || echo "0")
    tx=$(cat "/sys/class/net/${iface}/statistics/tx_bytes" 2>/dev/null || echo "0")
    local rx_mb tx_mb
    rx_mb=$(echo "scale=1; $rx / 1048576" | bc 2>/dev/null || echo "?")
    tx_mb=$(echo "scale=1; $tx / 1048576" | bc 2>/dev/null || echo "?")
    printf "rx=%sMB tx=%sMB iface=%s" "$rx_mb" "$tx_mb" "$iface"
}

_mon_top_cpu() {
    ps aux 2>/dev/null \
        | awk 'NR>1 {printf "%-22s %5s %5s\n", $11, $3, $4}' \
        | sort -k2 -rn | head -5
}

_mon_top_ram() {
    ps aux 2>/dev/null \
        | awk 'NR>1 {printf "%-22s %5s %5s\n", $11, $3, $4}' \
        | sort -k3 -rn | head -5
}

# ═══════════════════════════════════════════════════════════════════════
#  BARRE DE PROGRESSION VISUELLE
# ═══════════════════════════════════════════════════════════════════════

_mon_bar() {
    local percent="$1"
    local width="${2:-28}"
    local filled color

    [[ "$percent" =~ ^[0-9]+$ ]] || percent=0
    (( percent > 100 )) && percent=100
    filled=$(( (percent * width) / 100 ))

    if   (( percent >= 90 )); then color="${R:-\e[31m}"
    elif (( percent >= 70 )); then color="${Y:-\e[33m}"
    else                           color="${G:-\e[32m}"
    fi

    local bar="" i
    for (( i=0; i<filled; i++ ));         do bar+="█"; done
    for (( i=filled; i<width; i++ ));     do bar+="░"; done

    printf "%b%s%b %3d%%" "$color" "$bar" "${NC:-\e[0m}" "$percent"
}

# ═══════════════════════════════════════════════════════════════════════
#  DASHBOARD SYSTÈME
# ═══════════════════════════════════════════════════════════════════════

_mon_dashboard() {
    clear
    printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}📊 MONITORING SYSTÈME${NC:-\e[0m}  —  %s\n" "$(date '+%d/%m/%Y %H:%M:%S')"
    printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"

    # RAM
    local ram_info; ram_info=$(_mon_get_ram)
    local ram_used ram_total ram_pct
    ram_used=$(echo "$ram_info" | grep -oP 'used=\K\S+')
    ram_total=$(echo "$ram_info" | grep -oP 'total=\K\S+')
    ram_pct=$(echo "$ram_info" | grep -oP 'percent=\K\S+')
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}💾 RAM      :${NC:-\e[0m} %sMB / %sMB\n" "$ram_used" "$ram_total"
    printf "${C:-\e[36m}║${NC:-\e[0m}    "; _mon_bar "${ram_pct:-0}"; printf "\n"

    # CPU
    local cpu_info; cpu_info=$(_mon_get_cpu)
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}⚡ CPU Load :${NC:-\e[0m} 1m: %-7s 5m: %-7s 15m: %s\n" \
        "$(echo "$cpu_info" | grep -oP 'load1=\K\S+')" \
        "$(echo "$cpu_info" | grep -oP 'load5=\K\S+')" \
        "$(echo "$cpu_info" | grep -oP 'load15=\K\S+')"

    # Température
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}🌡️  Temp     :${NC:-\e[0m} %s\n" "$(utils_get_temp)"

    # Stockage
    local stor_info; stor_info=$(_mon_get_storage)
    local stor_used stor_total stor_pct
    stor_used=$(echo "$stor_info" | grep -oP 'used=\K\S+')
    stor_total=$(echo "$stor_info" | grep -oP 'total=\K\S+')
    stor_pct=$(echo "$stor_info" | grep -oP 'percent=\K\S+')
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}💿 Disque   :${NC:-\e[0m} %s / %s\n" "$stor_used" "$stor_total"
    printf "${C:-\e[36m}║${NC:-\e[0m}    "; _mon_bar "${stor_pct:-0}"; printf "\n"

    # Batterie
    local battery bat_num
    battery=$(utils_get_battery)
    bat_num=$(echo "$battery" | tr -cd '0-9')
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}🔋 Batterie :${NC:-\e[0m} %s\n" "$battery"
    if [[ "$bat_num" =~ ^[0-9]+$ ]]; then
        printf "${C:-\e[36m}║${NC:-\e[0m}    "; _mon_bar "$bat_num"; printf "\n"
    fi

    # Réseau
    local net_info; net_info=$(_mon_get_network_io)
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}🌐 Réseau   :${NC:-\e[0m} %s  ↓ %s  ↑ %s\n" \
        "$(echo "$net_info" | grep -oP 'iface=\K\S+')" \
        "$(echo "$net_info" | grep -oP 'rx=\K\S+')" \
        "$(echo "$net_info" | grep -oP 'tx=\K\S+')"

    # Processus + uptime
    local proc_info; proc_info=$(_mon_get_processes)
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}🔄 Process  :${NC:-\e[0m} total=%-5s running=%-5s sleeping=%s\n" \
        "$(echo "$proc_info" | grep -oP 'total=\K\S+')" \
        "$(echo "$proc_info" | grep -oP 'running=\K\S+')" \
        "$(echo "$proc_info" | grep -oP 'sleeping=\K\S+')"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}⏱️  Uptime   :${NC:-\e[0m} %s\n" "$(utils_get_uptime)"

    # Appareil
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}📱 Appareil :${NC:-\e[0m} %s  Android %s\n" \
        "$(utils_get_device_model)" "$(utils_get_android_version)"

    printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
}

# ═══════════════════════════════════════════════════════════════════════
#  VUE PROCESSUS
# ═══════════════════════════════════════════════════════════════════════

_mon_show_processes() {
    clear
    printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}🔄 TOP PROCESSUS${NC:-\e[0m}\n"
    printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n"

    printf "\n  ${W:-\e[1;37m}Top 5 par CPU :${NC:-\e[0m}\n"
    printf "  ${D:-\e[2;37m}%-22s %5s %5s${NC:-\e[0m}\n" "Commande" "CPU%" "RAM%"
    printf "  %s\n" "──────────────────────────────────────"
    _mon_top_cpu | while IFS= read -r line; do
        printf "  ${G:-\e[32m}%-22s${NC:-\e[0m} %s\n" \
            "$(echo "$line" | awk '{print $1}')" \
            "$(echo "$line" | awk '{print $2, $3}')"
    done

    printf "\n  ${W:-\e[1;37m}Top 5 par RAM :${NC:-\e[0m}\n"
    printf "  ${D:-\e[2;37m}%-22s %5s %5s${NC:-\e[0m}\n" "Commande" "CPU%" "RAM%"
    printf "  %s\n" "──────────────────────────────────────"
    _mon_top_ram | while IFS= read -r line; do
        printf "  ${C:-\e[36m}%-22s${NC:-\e[0m} %s\n" \
            "$(echo "$line" | awk '{print $1}')" \
            "$(echo "$line" | awk '{print $2, $3}')"
    done

    printf "\n  ${D:-\e[2;37m}[h] htop interactif   [Entrée] retour${NC:-\e[0m}\n"
    read -r key
    if [[ "${key,,}" == "h" ]]; then
        utils_cmd_exists htop && htop || ui_warning "htop non installé"
    fi
}

# ═══════════════════════════════════════════════════════════════════════
#  MODE LIVE
# ═══════════════════════════════════════════════════════════════════════

_mon_live() {
    local interval="${1:-3}"
    printf "\n  ${Y:-\e[33m}Mode live — Ctrl+C pour arrêter${NC:-\e[0m}\n"
    sleep 1
    trap 'tput cnorm 2>/dev/null || true; printf "\n"; return 0' INT
    tput civis 2>/dev/null || true
    while true; do
        _mon_dashboard
        printf "  ${D:-\e[2;37m}Rafraîchissement dans %ds — Ctrl+C pour arrêter${NC:-\e[0m}" \
            "$interval"
        sleep "$interval"
    done
}

# ═══════════════════════════════════════════════════════════════════════
#  RAPPORT SYSTÈME
# ═══════════════════════════════════════════════════════════════════════

_mon_report() {
    local report_file
    report_file="${CFG_LOGS_DIR:-$HOME/mon_env/logs}/sysreport_$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "RAPPORT SYSTÈME — $(date '+%d/%m/%Y %H:%M:%S')"
        echo "═════════════════════════════════════════"
        echo "Modèle   : $(utils_get_device_model)"
        echo "Android  : $(utils_get_android_version)"
        echo "Shell    : $(basename "${SHELL:-bash}")"
        echo "Uptime   : $(utils_get_uptime)"
        echo ""
        echo "── Mémoire ─────────────────────────────"
        free -m 2>/dev/null || echo "N/A"
        echo ""
        echo "── Stockage ────────────────────────────"
        df -h 2>/dev/null | grep -v "tmpfs\|devtmpfs" || echo "N/A"
        echo ""
        echo "── CPU Load ────────────────────────────"
        cat /proc/loadavg 2>/dev/null || echo "N/A"
        echo ""
        echo "── Température ─────────────────────────"
        utils_get_temp
        echo ""
        echo "── Top 10 processus CPU ─────────────────"
        ps aux 2>/dev/null | sort -k3 -rn | head -10 || echo "N/A"
        echo ""
        echo "── Interfaces réseau ───────────────────"
        ip addr show 2>/dev/null || echo "N/A"
    } > "$report_file"

    printf "\n  ${G:-\e[32m}✅ Rapport : %s${NC:-\e[0m}\n" "${report_file/$HOME/~}"
    log_info "Rapport système : $report_file" "monitoring"

    echo -ne "  ${C:-\e[36m}Afficher ? (o/n) : ${NC:-\e[0m}"
    read -r show
    [[ "${show,,}" == "o" ]] && less "$report_file"
}

# ═══════════════════════════════════════════════════════════════════════
#  MENU PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════

monitoring_menu() {
    log_action "Module monitoring ouvert" "monitoring"

    while true; do
        clear
        _mon_dashboard

        printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}📊 OPTIONS MONITORING${NC:-\e[0m}\n"
        printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[1]${NC:-\e[0m} Dashboard système\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[2]${NC:-\e[0m} Top processus (CPU / RAM)\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[3]${NC:-\e[0m} Mode live (rafraîchissement auto)\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[4]${NC:-\e[0m} Générer un rapport système\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[5]${NC:-\e[0m} Lancer htop interactif\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[0]${NC:-\e[0m} Retour\n"
        printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
        echo -ne "  ${C:-\e[36m}Choix : ${NC:-\e[0m}"
        read -r choice

        case "$choice" in
            1)  _mon_dashboard; read -rp "  Entrée..." ;;
            2)  _mon_show_processes ;;
            3)
                echo -ne "  ${C:-\e[36m}Intervalle en secondes (défaut: 3) : ${NC:-\e[0m}"
                read -r iv
                iv="${iv:-3}"
                [[ "$iv" =~ ^[0-9]+$ ]] && (( iv >= 1 )) || iv=3
                _mon_live "$iv"
                ;;
            4)  _mon_report; read -rp "  Entrée..." ;;
            5)
                if utils_cmd_exists htop; then htop
                else ui_warning "htop non installé ([i] pour installer)"; sleep 2
                fi
                ;;
            0|"") log_action "Module monitoring fermé" "monitoring"; return 0 ;;
            *)    ui_warning "Choix invalide"; sleep 1 ;;
        esac
    done
}
