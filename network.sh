#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# modules/network.sh — Outils réseau : scan, ping, DNS, ports, IP
# Dépend de : core/config.sh, core/logger.sh, core/ui.sh, core/utils.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

# ═══════════════════════════════════════════════════════════════════════
#  INFORMATIONS RÉSEAU LOCALES
# ═══════════════════════════════════════════════════════════════════════

_net_show_info() {
    clear
    printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}🌐 INFORMATIONS RÉSEAU${NC:-\e[0m}\n"
    printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"

    # IP publique
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}IP Publique   :${NC:-\e[0m} "
    local ip_pub
    ip_pub=$(utils_get_public_ip)
    printf "%s\n" "$ip_pub"

    # IP locale
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}IP Locale     :${NC:-\e[0m} %s\n" "$(utils_get_local_ip)"

    # Passerelle
    local gateway
    gateway=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -1 || echo "?")
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}Passerelle    :${NC:-\e[0m} %s\n" "$gateway"

    # DNS
    local dns
    dns=$(grep "^nameserver" /etc/resolv.conf 2>/dev/null \
          | awk '{print $2}' | head -3 | tr '\n' ' ' || echo "?")
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}DNS           :${NC:-\e[0m} %s\n" "$dns"

    # Interfaces réseau
    printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${W:-\e[1;37m}Interfaces actives :${NC:-\e[0m}\n"
    ip -4 addr show 2>/dev/null | grep -E "^[0-9]+:|inet " | \
    while IFS= read -r line; do
        if [[ "$line" =~ ^[0-9] ]]; then
            # Ligne interface
            local iface
            iface=$(echo "$line" | awk -F': ' '{print $2}' | awk '{print $1}')
            printf "${C:-\e[36m}║${NC:-\e[0m}    ${G:-\e[32m}%-12s${NC:-\e[0m}" "$iface"
        elif [[ "$line" =~ inet ]]; then
            # Ligne IP
            local ip_cidr
            ip_cidr=$(echo "$line" | awk '{print $2}')
            printf " %s\n" "$ip_cidr"
        fi
    done

    printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"

    # TOR status
    if pgrep -x "tor" &>/dev/null; then
        printf "  ${G:-\e[32m}🧅 TOR : ACTIF${NC:-\e[0m}\n\n"
    else
        printf "  ${D:-\e[2;37m}🧅 TOR : inactif${NC:-\e[0m}\n\n"
    fi
}

# ═══════════════════════════════════════════════════════════════════════
#  PING
# ═══════════════════════════════════════════════════════════════════════

_net_ping() {
    echo -ne "\n  ${C:-\e[36m}Hôte ou IP à pinger (défaut: 8.8.8.8) : ${NC:-\e[0m}"
    read -r target
    target="${target:-8.8.8.8}"

    # Valider la cible
    if ! sec_safe_string "$target" "Cible ping" 2>/dev/null; then
        ui_error "Cible invalide"; sleep 2; return 1
    fi

    echo -ne "  ${C:-\e[36m}Nombre de paquets (défaut: 4) : ${NC:-\e[0m}"
    read -r count
    count="${count:-4}"
    [[ "$count" =~ ^[0-9]+$ ]] && (( count <= 20 )) || count=4

    printf "\n  ${Y:-\e[33m}Ping vers %s (%s paquets)...${NC:-\e[0m}\n\n" "$target" "$count"
    log_action "Ping : $target" "network"

    ping -c "$count" "$target" 2>/dev/null || {
        printf "  ${R:-\e[31m}❌ Ping échoué : %s${NC:-\e[0m}\n" "$target"
        log_warn "Ping échoué : $target" "network"
    }

    echo ""
    read -rp "  Entrée pour continuer..."
}

# ═══════════════════════════════════════════════════════════════════════
#  DNS LOOKUP
# ═══════════════════════════════════════════════════════════════════════

_net_dns_lookup() {
    echo -ne "\n  ${C:-\e[36m}Domaine à résoudre : ${NC:-\e[0m}"
    read -r domain

    if ! sec_safe_string "$domain" "Domaine" 2>/dev/null; then
        ui_error "Domaine invalide"; sleep 2; return 1
    fi

    [[ -z "$domain" ]] && return

    printf "\n  ${Y:-\e[33m}Résolution DNS de : %s${NC:-\e[0m}\n\n" "$domain"
    log_action "DNS lookup : $domain" "network"

    # nslookup ou host ou dig selon ce qui est disponible
    if utils_cmd_exists nslookup; then
        nslookup "$domain" 2>/dev/null || true
    elif utils_cmd_exists host; then
        host "$domain" 2>/dev/null || true
    elif utils_cmd_exists dig; then
        dig "$domain" +short 2>/dev/null || true
    else
        # Fallback : getent
        printf "  ${D:-\e[2;37m}(utilisation de getent)${NC:-\e[0m}\n"
        getent hosts "$domain" 2>/dev/null || \
            printf "  ${R:-\e[31m}❌ Résolution échouée.${NC:-\e[0m}\n"
    fi

    echo ""
    read -rp "  Entrée pour continuer..."
}

# ═══════════════════════════════════════════════════════════════════════
#  SCAN DE PORTS (nmap ou fallback natif)
# ═══════════════════════════════════════════════════════════════════════

_net_port_scan() {
    printf "\n  ${R:-\e[31m}⚠️  Scanner uniquement des systèmes que vous possédez !${NC:-\e[0m}\n\n"

    echo -ne "  ${C:-\e[36m}Cible (IP ou hostname) : ${NC:-\e[0m}"
    read -r target

    if ! sec_safe_string "$target" "Cible" 2>/dev/null; then
        ui_error "Cible invalide"; sleep 2; return 1
    fi
    [[ -z "$target" ]] && return

    echo -ne "  ${C:-\e[36m}Ports [ex: 80,443 ou 1-1000] (défaut: 1-1000) : ${NC:-\e[0m}"
    read -r ports
    ports="${ports:-1-1000}"

    # Valider le format ports
    if ! [[ "$ports" =~ ^[0-9,\-]+$ ]]; then
        ui_error "Format de ports invalide"; sleep 2; return 1
    fi

    printf "\n  ${Y:-\e[33m}Scan de %s sur ports %s...${NC:-\e[0m}\n\n" "$target" "$ports"
    log_action "Scan ports : $target ports=$ports" "network"
    log_security "Port scan lancé sur : $target ports=$ports" "network"

    if utils_cmd_exists nmap; then
        nmap -p "$ports" --open "$target" 2>/dev/null
    else
        # Fallback bash natif (lent mais fonctionnel)
        printf "  ${D:-\e[2;37m}nmap absent — scan natif Bash (lent)${NC:-\e[0m}\n\n"
        _net_bash_portscan "$target" "$ports"
    fi

    echo ""
    read -rp "  Entrée pour continuer..."
}

# Scan de ports natif Bash (fallback sans nmap)
_net_bash_portscan() {
    local host="$1"
    local port_range="$2"
    local start end

    # Parser le range
    if [[ "$port_range" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        start="${BASH_REMATCH[1]}"
        end="${BASH_REMATCH[2]}"
        (( end > 1024 )) && end=1024  # Limiter en mode fallback
    elif [[ "$port_range" =~ ^[0-9,]+$ ]]; then
        # Liste de ports
        IFS=',' read -ra port_list <<< "$port_range"
        for port in "${port_list[@]}"; do
            _net_check_port_bash "$host" "$port"
        done
        return
    else
        start=1; end=1024
    fi

    printf "  ${D:-\e[2;37m}Scan %s:%d-%d (timeout 1s/port)${NC:-\e[0m}\n" \
        "$host" "$start" "$end"

    local open_count=0
    for (( port=start; port<=end; port++ )); do
        if _net_check_port_bash "$host" "$port"; then
            (( open_count++ ))
        fi
    done
    printf "\n  ${B:-\e[34m}%d port(s) ouvert(s) trouvé(s).${NC:-\e[0m}\n" "$open_count"
}

_net_check_port_bash() {
    local host="$1"
    local port="$2"
    if (echo >/dev/tcp/"$host"/"$port") 2>/dev/null; then
        printf "  ${G:-\e[32m}✅ OUVERT${NC:-\e[0m}  Port %d\n" "$port"
        return 0
    fi
    return 1
}

# ═══════════════════════════════════════════════════════════════════════
#  PORTS OUVERTS LOCAUX
# ═══════════════════════════════════════════════════════════════════════

_net_local_ports() {
    clear
    printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}🔌 PORTS OUVERTS LOCALEMENT${NC:-\e[0m}\n"
    printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"

    printf "  ${D:-\e[2;37m}%-8s %-22s %-10s %s${NC:-\e[0m}\n" \
        "Proto" "Adresse locale" "État" "Processus"
    printf "  %s\n" "──────────────────────────────────────────────────────"

    if utils_cmd_exists ss; then
        ss -tlnp 2>/dev/null | tail -n +2 | \
        while IFS= read -r line; do
            printf "  ${G:-\e[32m}%-8s${NC:-\e[0m} %-22s %-10s %s\n" \
                "$(echo "$line" | awk '{print $1}')" \
                "$(echo "$line" | awk '{print $4}')" \
                "$(echo "$line" | awk '{print $2}')" \
                "$(echo "$line" | awk '{print $6}' | grep -oP 'users:\(\("\K[^"]+' || echo '')"
        done
    elif utils_cmd_exists netstat; then
        netstat -tlnp 2>/dev/null | tail -n +3 | \
        while IFS= read -r line; do
            printf "  ${G:-\e[32m}%s${NC:-\e[0m}\n" "$line"
        done
    else
        printf "  ${Y:-\e[33m}ss/netstat non disponibles.${NC:-\e[0m}\n"
    fi

    echo ""
    read -rp "  Entrée pour continuer..."
}

# ═══════════════════════════════════════════════════════════════════════
#  TRACEROUTE
# ═══════════════════════════════════════════════════════════════════════

_net_traceroute() {
    echo -ne "\n  ${C:-\e[36m}Cible traceroute : ${NC:-\e[0m}"
    read -r target

    if ! sec_safe_string "$target" "Cible" 2>/dev/null; then
        ui_error "Cible invalide"; sleep 2; return 1
    fi
    [[ -z "$target" ]] && return

    printf "\n  ${Y:-\e[33m}Traceroute vers %s...${NC:-\e[0m}\n\n" "$target"
    log_action "Traceroute : $target" "network"

    if utils_cmd_exists traceroute; then
        traceroute "$target" 2>/dev/null || \
            printf "  ${R:-\e[31m}❌ Traceroute échoué.${NC:-\e[0m}\n"
    else
        printf "  ${Y:-\e[33m}traceroute non installé.${NC:-\e[0m}\n"
        printf "  ${D:-\e[2;37m}Installe avec [i] → traceroute${NC:-\e[0m}\n"
    fi

    echo ""
    read -rp "  Entrée pour continuer..."
}

# ═══════════════════════════════════════════════════════════════════════
#  WHOIS
# ═══════════════════════════════════════════════════════════════════════

_net_whois() {
    echo -ne "\n  ${C:-\e[36m}Domaine ou IP (whois) : ${NC:-\e[0m}"
    read -r target

    if ! sec_safe_string "$target" "Cible" 2>/dev/null; then
        ui_error "Cible invalide"; sleep 2; return 1
    fi
    [[ -z "$target" ]] && return

    printf "\n  ${Y:-\e[33m}Whois : %s${NC:-\e[0m}\n\n" "$target"
    log_action "Whois : $target" "network"

    if utils_cmd_exists whois; then
        whois "$target" 2>/dev/null | head -40 || \
            printf "  ${R:-\e[31m}❌ Whois échoué.${NC:-\e[0m}\n"
    else
        printf "  ${Y:-\e[33m}whois non installé.${NC:-\e[0m}\n"
        printf "  ${D:-\e[2;37m}Installe avec [i] → whois${NC:-\e[0m}\n"
    fi

    echo ""
    read -rp "  Entrée pour continuer..."
}

# ═══════════════════════════════════════════════════════════════════════
#  TEST DE VITESSE BASIQUE
# ═══════════════════════════════════════════════════════════════════════

_net_speed_test() {
    printf "\n  ${Y:-\e[33m}Test de débit (download depuis un serveur de test)...${NC:-\e[0m}\n\n"
    log_action "Speed test lancé" "network"

    if ! utils_check_internet; then
        ui_error "Pas de connexion internet"; sleep 2; return
    fi

    # Télécharger 5MB depuis un serveur connu et mesurer
    local url="https://speed.hetzner.de/5MB.bin"
    local start_time end_time elapsed speed_mbps bytes

    printf "  ${D:-\e[2;37m}Téléchargement 5MB depuis speed.hetzner.de...${NC:-\e[0m}\n"
    start_time=$(date +%s%N)

    bytes=$(curl -s -o /dev/null -w "%{size_download}" \
            --max-time 30 "$url" 2>/dev/null || echo "0")

    end_time=$(date +%s%N)
    elapsed=$(( (end_time - start_time) / 1000000 ))  # en millisecondes

    if (( elapsed > 0 && bytes > 0 )); then
        # Calcul en Mbps : (bytes * 8) / (elapsed / 1000) / 1000000
        speed_mbps=$(echo "scale=2; ($bytes * 8) / ($elapsed / 1000) / 1000000" \
                     | bc 2>/dev/null || echo "?")
        printf "\n  ${G:-\e[32m}✅ Débit download : %s Mbps${NC:-\e[0m}\n" "$speed_mbps"
        printf "  ${D:-\e[2;37m}%s octets en %dms${NC:-\e[0m}\n" "$bytes" "$elapsed"
        log_info "Speed test : ${speed_mbps} Mbps" "network"
    else
        printf "  ${R:-\e[31m}❌ Test échoué.${NC:-\e[0m}\n"
        log_warn "Speed test échoué" "network"
    fi

    echo ""
    read -rp "  Entrée pour continuer..."
}

# ═══════════════════════════════════════════════════════════════════════
#  SURVEILLANCE RÉSEAU (netstat live)
# ═══════════════════════════════════════════════════════════════════════

_net_live_connections() {
    printf "\n  ${Y:-\e[33m}Connexions actives — Ctrl+C pour arrêter${NC:-\e[0m}\n\n"
    trap 'printf "\n"; return 0' INT

    while true; do
        clear
        printf "${C:-\e[36m}  ═══ CONNEXIONS ACTIVES — %s ═══${NC:-\e[0m}\n\n" \
            "$(date '+%H:%M:%S')"

        if utils_cmd_exists ss; then
            ss -tnp state established 2>/dev/null | head -20 || true
        elif utils_cmd_exists netstat; then
            netstat -tnp 2>/dev/null | grep ESTABLISHED | head -20 || true
        else
            printf "  ${Y:-\e[33m}ss/netstat non disponibles.${NC:-\e[0m}\n"
        fi

        printf "\n  ${D:-\e[2;37m}Ctrl+C pour arrêter${NC:-\e[0m}"
        sleep 3
    done
}

# ═══════════════════════════════════════════════════════════════════════
#  MENU PRINCIPAL RÉSEAU
# ═══════════════════════════════════════════════════════════════════════

network_menu() {
    log_action "Module réseau ouvert" "network"

    while true; do
        clear
        printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}🌐 OUTILS RÉSEAU${NC:-\e[0m}\n"
        printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[1]${NC:-\e[0m} Informations réseau\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[2]${NC:-\e[0m} Ping\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[3]${NC:-\e[0m} DNS Lookup\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[4]${NC:-\e[0m} Scan de ports (nmap)\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[5]${NC:-\e[0m} Ports ouverts locaux\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[6]${NC:-\e[0m} Traceroute\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[7]${NC:-\e[0m} Whois\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[8]${NC:-\e[0m} Test de débit\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[9]${NC:-\e[0m} Connexions actives (live)\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[0]${NC:-\e[0m} Retour\n"
        printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
        echo -ne "  ${C:-\e[36m}Choix : ${NC:-\e[0m}"
        read -r choice

        case "$choice" in
            1)  _net_show_info; read -rp "  Entrée..." ;;
            2)  _net_ping ;;
            3)  _net_dns_lookup ;;
            4)  _net_port_scan ;;
            5)  _net_local_ports ;;
            6)  _net_traceroute ;;
            7)  _net_whois ;;
            8)  _net_speed_test ;;
            9)  _net_live_connections ;;
            0|"") log_action "Module réseau fermé" "network"; return 0 ;;
            *)    ui_warning "Choix invalide"; sleep 1 ;;
        esac
    done
}
