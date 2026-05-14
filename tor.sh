#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# modules/tor.sh — Gestionnaire TOR : démarrage, arrêt, statut, proxychains
# Dépend de : core/config.sh, core/logger.sh, core/ui.sh, core/utils.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

readonly TOR_PORT=9050
readonly TOR_CONTROL_PORT=9051
readonly PROXYCHAINS_CONF="/data/data/com.termux/files/usr/etc/proxychains.conf"
readonly TOR_DATA_DIR="$HOME/.tor"

# ═══════════════════════════════════════════════════════════════════════
#  STATUT TOR
# ═══════════════════════════════════════════════════════════════════════

_tor_is_running() {
    pgrep -x "tor" &>/dev/null
}

_tor_socks_ready() {
    # Vérifie que le port SOCKS est ouvert
    (echo >/dev/tcp/127.0.0.1/$TOR_PORT) 2>/dev/null
}

_tor_status_display() {
    clear
    printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}🧅 STATUT TOR${NC:-\e[0m}\n"
    printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"

    # TOR process
    if _tor_is_running; then
        local pid
        pid=$(pgrep -x "tor" | head -1)
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}Process     :${NC:-\e[0m} ${G:-\e[32m}● ACTIF${NC:-\e[0m} (PID: %s)\n" "$pid"
    else
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}Process     :${NC:-\e[0m} ${R:-\e[31m}● INACTIF${NC:-\e[0m}\n"
    fi

    # Port SOCKS
    if _tor_socks_ready; then
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}SOCKS5      :${NC:-\e[0m} ${G:-\e[32m}127.0.0.1:%d — OUVERT${NC:-\e[0m}\n" \
            "$TOR_PORT"
    else
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}SOCKS5      :${NC:-\e[0m} ${R:-\e[31m}127.0.0.1:%d — FERMÉ${NC:-\e[0m}\n" \
            "$TOR_PORT"
    fi

    # IP via TOR
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}IP publique :${NC:-\e[0m} "
    if _tor_is_running && _tor_socks_ready; then
        local tor_ip
        tor_ip=$(curl -s --socks5 127.0.0.1:${TOR_PORT} \
                 --max-time 10 https://api.ipify.org 2>/dev/null || echo "erreur")
        printf "%s\n" "$tor_ip"

        # IP réelle pour comparaison
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}IP réelle   :${NC:-\e[0m} "
        printf "%s\n" "$(utils_get_public_ip)"
    else
        printf "${D:-\e[2;37m}TOR inactif${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}IP réelle   :${NC:-\e[0m} %s\n" \
            "$(utils_get_public_ip)"
    fi

    # proxychains
    if utils_cmd_exists proxychains4 || utils_cmd_exists proxychains; then
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}proxychains :${NC:-\e[0m} ${G:-\e[32m}✅ disponible${NC:-\e[0m}\n"
    else
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}proxychains :${NC:-\e[0m} ${Y:-\e[33m}⚠️  non installé${NC:-\e[0m}\n"
    fi

    printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
}

# ═══════════════════════════════════════════════════════════════════════
#  DÉMARRER TOR
# ═══════════════════════════════════════════════════════════════════════

_tor_start() {
    utils_cmd_exists tor || {
        ui_error "tor non installé. Lance [i] → tor"
        sleep 2; return 1
    }

    if _tor_is_running; then
        ui_warning "TOR est déjà en cours d'exécution."
        sleep 2; return 0
    fi

    printf "\n  ${Y:-\e[33m}Démarrage de TOR...${NC:-\e[0m}\n"
    log_action "Démarrage TOR" "tor"
    log_security "TOR démarré" "tor"

    mkdir -p "$TOR_DATA_DIR"

    # Démarrer TOR en arrière-plan
    tor --SOCKSPort $TOR_PORT \
        --ControlPort $TOR_CONTROL_PORT \
        --DataDirectory "$TOR_DATA_DIR" \
        --Log "notice stdout" \
        &>/tmp/tor_startup.log &

    local tor_pid=$!

    # Attendre que TOR soit prêt (max 30s)
    printf "  ${D:-\e[2;37m}Attente connexion TOR"
    local timeout=30
    local elapsed=0
    while (( elapsed < timeout )); do
        sleep 1
        (( elapsed++ ))
        printf "."
        if _tor_socks_ready; then
            printf "\n\n  ${G:-\e[32m}✅ TOR actif sur 127.0.0.1:%d (PID: %d)${NC:-\e[0m}\n" \
                "$TOR_PORT" "$tor_pid"
            log_info "TOR démarré : PID=$tor_pid port=$TOR_PORT" "tor"
            sleep 2
            return 0
        fi
    done

    printf "\n\n  ${R:-\e[31m}❌ TOR n'a pas démarré dans les temps.${NC:-\e[0m}\n"
    printf "  ${D:-\e[2;37m}Consulte : /tmp/tor_startup.log${NC:-\e[0m}\n"
    log_error "Timeout démarrage TOR" "tor"
    sleep 2
    return 1
}

# ═══════════════════════════════════════════════════════════════════════
#  ARRÊTER TOR
# ═══════════════════════════════════════════════════════════════════════

_tor_stop() {
    if ! _tor_is_running; then
        ui_warning "TOR n'est pas en cours d'exécution."
        sleep 2; return 0
    fi

    printf "\n  ${Y:-\e[33m}Arrêt de TOR...${NC:-\e[0m}\n"
    log_action "Arrêt TOR" "tor"
    log_security "TOR arrêté" "tor"

    pkill -x "tor" 2>/dev/null || killall tor 2>/dev/null || true
    sleep 2

    if ! _tor_is_running; then
        printf "  ${G:-\e[32m}✅ TOR arrêté.${NC:-\e[0m}\n"
        log_info "TOR arrêté avec succès" "tor"
    else
        printf "  ${R:-\e[31m}❌ Impossible d'arrêter TOR.${NC:-\e[0m}\n"
        log_error "Échec arrêt TOR" "tor"
    fi
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#  REDÉMARRER (changer d'identité)
# ═══════════════════════════════════════════════════════════════════════

_tor_new_identity() {
    if ! _tor_is_running; then
        ui_warning "TOR n'est pas actif."
        sleep 2; return
    fi

    printf "\n  ${Y:-\e[33m}Demande d'une nouvelle identité TOR...${NC:-\e[0m}\n"

    if utils_cmd_exists torify || nc -z 127.0.0.1 $TOR_CONTROL_PORT 2>/dev/null; then
        # Signaler NEWNYM via le port de contrôle
        printf "AUTHENTICATE\nSIGNAL NEWNYM\nQUIT\n" | \
            nc -w 2 127.0.0.1 $TOR_CONTROL_PORT 2>/dev/null && {
            printf "  ${G:-\e[32m}✅ Nouvelle identité demandée.${NC:-\e[0m}\n"
            log_action "Nouvelle identité TOR demandée" "tor"
        } || {
            # Fallback : redémarrer TOR
            _tor_stop
            sleep 1
            _tor_start
        }
    else
        # Redémarrage simple
        printf "  ${D:-\e[2;37m}Redémarrage pour nouvelle identité...${NC:-\e[0m}\n"
        _tor_stop; sleep 1; _tor_start
    fi
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#  CONFIGURER PROXYCHAINS
# ═══════════════════════════════════════════════════════════════════════

_tor_setup_proxychains() {
    clear
    ui_box_title "🔗 CONFIGURATION PROXYCHAINS"

    if ! utils_cmd_exists proxychains4 && ! utils_cmd_exists proxychains; then
        ui_warning "proxychains non installé."
        echo -ne "  ${C:-\e[36m}Installer proxychains-ng ? (o/n) : ${NC:-\e[0m}"
        read -r inst
        [[ "${inst,,}" == "o" ]] && pkg install proxychains-ng -y || return
    fi

    # Créer/mettre à jour la config
    local conf_dir
    conf_dir=$(dirname "$PROXYCHAINS_CONF")
    mkdir -p "$conf_dir" 2>/dev/null || true

    cat > "$PROXYCHAINS_CONF" << EOF
# ── proxychains.conf — Cyber Dashboard Termux ──
# Généré le : $(date '+%d/%m/%Y %H:%M')

strict_chain
proxy_dns
quiet_mode

[ProxyList]
# TOR SOCKS5
socks5  127.0.0.1 ${TOR_PORT}
EOF

    chmod 644 "$PROXYCHAINS_CONF" 2>/dev/null || true

    printf "  ${G:-\e[32m}✅ proxychains configuré pour TOR (port %d)${NC:-\e[0m}\n" \
        "$TOR_PORT"
    printf "  ${D:-\e[2;37m}Config : %s${NC:-\e[0m}\n\n" "$PROXYCHAINS_CONF"
    printf "  ${W:-\e[1;37m}Usage :${NC:-\e[0m} proxychains4 <commande>\n"
    printf "  ${D:-\e[2;37m}Exemple : proxychains4 curl https://check.torproject.org${NC:-\e[0m}\n\n"

    log_action "proxychains configuré pour TOR" "tor"
    read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  LANCER UNE COMMANDE VIA TOR
# ═══════════════════════════════════════════════════════════════════════

_tor_run_cmd() {
    if ! _tor_is_running; then
        ui_warning "TOR n'est pas actif. Démarre TOR d'abord."
        sleep 2; return
    fi

    clear
    ui_box_title "⚡ COMMANDE VIA TOR"
    printf "  ${D:-\e[2;37m}La commande sera routée via TOR (proxychains4).${NC:-\e[0m}\n\n"
    printf "  ${D:-\e[2;37m}Exemples :${NC:-\e[0m}\n"
    printf "  ${D:-\e[2;37m}  curl https://check.torproject.org/api/ip${NC:-\e[0m}\n"
    printf "  ${D:-\e[2;37m}  wget -q -O- https://api.ipify.org${NC:-\e[0m}\n\n"

    echo -ne "  ${C:-\e[36m}Commande : ${NC:-\e[0m}"; read -r cmd
    [[ -z "$cmd" ]] && return
    sec_safe_command "$cmd" 2>/dev/null || return 1

    local proxy_cmd
    if utils_cmd_exists proxychains4; then
        proxy_cmd="proxychains4 -q $cmd"
    elif utils_cmd_exists proxychains; then
        proxy_cmd="proxychains -q $cmd"
    else
        # Fallback : utiliser torsocks si disponible, sinon SOCKS5 via curl
        proxy_cmd="curl -s --socks5 127.0.0.1:${TOR_PORT} $cmd"
        printf "  ${Y:-\e[33m}proxychains absent — fallback curl SOCKS5${NC:-\e[0m}\n"
    fi

    printf "\n  ${Y:-\e[33m}Exécution via TOR : %s${NC:-\e[0m}\n\n" "$cmd"
    log_action "Commande via TOR : $cmd" "tor"
    log_security "Commande tor : $cmd" "tor"

    eval "$proxy_cmd" 2>&1
    echo ""; read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  TEST CONNEXION TOR
# ═══════════════════════════════════════════════════════════════════════

_tor_test() {
    if ! _tor_is_running || ! _tor_socks_ready; then
        ui_warning "TOR n'est pas actif ou le port SOCKS n'est pas disponible."
        sleep 2; return
    fi

    printf "\n  ${Y:-\e[33m}Test de la connexion TOR...${NC:-\e[0m}\n\n"

    # Test via check.torproject.org
    local result
    result=$(curl -s --socks5 127.0.0.1:${TOR_PORT} \
             --max-time 15 \
             "https://check.torproject.org/api/ip" 2>/dev/null || echo "")

    if [[ -n "$result" ]]; then
        local is_tor tor_ip
        is_tor=$(echo "$result" | grep -oP '"IsTor":\s*\K(true|false)' || echo "?")
        tor_ip=$(echo "$result" | grep -oP '"IP":\s*"\K[^"]+' || echo "?")

        printf "  ${B:-\e[34m}IP via TOR :${NC:-\e[0m} %s\n" "$tor_ip"
        if [[ "$is_tor" == "true" ]]; then
            printf "  ${G:-\e[32m}✅ Confirmé : tu utilises TOR !${NC:-\e[0m}\n"
            log_info "Test TOR OK : IP=$tor_ip" "tor"
        else
            printf "  ${R:-\e[31m}❌ Non confirmé comme nœud TOR.${NC:-\e[0m}\n"
            log_warn "Test TOR : non confirmé TOR (IP=$tor_ip)" "tor"
        fi
    else
        # Fallback : juste récupérer l'IP
        local fallback_ip
        fallback_ip=$(curl -s --socks5 127.0.0.1:${TOR_PORT} \
                      --max-time 10 https://api.ipify.org 2>/dev/null || echo "échec")
        printf "  ${B:-\e[34m}IP via TOR :${NC:-\e[0m} %s\n" "$fallback_ip"
        [[ "$fallback_ip" != "échec" ]] \
            && printf "  ${G:-\e[32m}✅ Connexion TOR fonctionnelle.${NC:-\e[0m}\n" \
            || printf "  ${R:-\e[31m}❌ Connexion TOR échouée.${NC:-\e[0m}\n"
    fi

    echo ""; read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  VOIR LES LOGS TOR
# ═══════════════════════════════════════════════════════════════════════

_tor_logs() {
    clear
    ui_box_title "📋 LOGS TOR"

    if [[ -f /tmp/tor_startup.log ]]; then
        printf "  ${W:-\e[1;37m}Logs démarrage :${NC:-\e[0m}\n\n"
        tail -30 /tmp/tor_startup.log | while IFS= read -r line; do
            if [[ "$line" == *"[err]"* ]] || [[ "$line" == *"[warn]"* ]]; then
                printf "  ${R:-\e[31m}%s${NC:-\e[0m}\n" "$line"
            elif [[ "$line" == *"Bootstrapped 100%"* ]]; then
                printf "  ${G:-\e[32m}%s${NC:-\e[0m}\n" "$line"
            else
                printf "  ${D:-\e[2;37m}%s${NC:-\e[0m}\n" "$line"
            fi
        done
    else
        printf "  ${D:-\e[2;37m}Aucun log disponible.${NC:-\e[0m}\n"
    fi

    echo ""; read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  MENU PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════

tor_menu() {
    log_action "Module TOR ouvert" "tor"

    while true; do
        clear
        _tor_status_display

        printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}🧅 ACTIONS TOR${NC:-\e[0m}\n"
        printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"

        if _tor_is_running; then
            printf "${C:-\e[36m}║${NC:-\e[0m}  ${R:-\e[31m}[1]${NC:-\e[0m} Arrêter TOR\n"
            printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[2]${NC:-\e[0m} Nouvelle identité\n"
            printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[3]${NC:-\e[0m} Tester la connexion TOR\n"
            printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[4]${NC:-\e[0m} Lancer une commande via TOR\n"
        else
            printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[1]${NC:-\e[0m} Démarrer TOR\n"
            printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}[2]${NC:-\e[0m} Nouvelle identité (TOR requis)\n"
            printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}[3]${NC:-\e[0m} Test connexion (TOR requis)\n"
            printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}[4]${NC:-\e[0m} Commande via TOR (TOR requis)\n"
        fi

        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[5]${NC:-\e[0m} Configurer proxychains\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[6]${NC:-\e[0m} Voir les logs TOR\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[0]${NC:-\e[0m} Retour\n"
        printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
        echo -ne "  ${C:-\e[36m}Choix : ${NC:-\e[0m}"; read -r choice

        case "$choice" in
            1)
                _tor_is_running && _tor_stop || _tor_start
                ;;
            2) _tor_new_identity      ;;
            3) _tor_test              ;;
            4) _tor_run_cmd           ;;
            5) _tor_setup_proxychains ;;
            6) _tor_logs              ;;
            0|"") log_action "Module TOR fermé" "tor"; return 0 ;;
            *) ui_warning "Choix invalide"; sleep 1 ;;
        esac
    done
}
