#!/data/data/com.termux/files/usr/bin/bash
# ╔══════════════════════════════════════════════════════════╗
# ║          MON ENVIRONNEMENT TERMUX v4.0 — Shadow          ║
# ║  Projets | Outils | Pentest | Code | SSH | TOR | Réseau  ║
# ╚══════════════════════════════════════════════════════════╝

# ─── CHEMINS ────────────────────────────────────────────────
ENV_DIR="$HOME/.mon_env"
PROJETS_FILE="$ENV_DIR/projets.conf"
OUTILS_FILE="$ENV_DIR/outils.conf"
PENTEST_FILE="$ENV_DIR/pentest.conf"
ALIAS_FILE="$ENV_DIR/mes_alias.sh"
SSH_FILE="$ENV_DIR/ssh_hosts.conf"
THEME_FILE="$ENV_DIR/theme.conf"
NOTES_FILE="$ENV_DIR/notes.conf"
LOG_FILE="$ENV_DIR/historique.log"

# ─── COULEURS (défaut, écrasées par le thème) ────────────────
load_theme() {
    ACCENT='\033[0;36m'
    ACCENT2='\033[0;34m'
    SUCCESS='\033[0;32m'
    WARN='\033[1;33m'
    DANGER='\033[0;31m'
    BOLD='\033[1;37m'
    DIM='\033[0;37m'
    NC='\033[0m'

    if [ -f "$THEME_FILE" ]; then
        source "$THEME_FILE"
    fi
    R="$DANGER"; G="$SUCCESS"; Y="$WARN"; B="$ACCENT2"; C="$ACCENT"; M='\033[0;35m'; W="$BOLD"
}

# ─── LOGGER ──────────────────────────────────────────────────
log_action() {
    echo "[$(date '+%d/%m/%Y %H:%M')] $1" >> "$LOG_FILE"
}

# ─── RETOUR PROPRE AU SHELL ──────────────────────────────────
quitter_proprement() {
    echo -e "\n${G}╔══════════════════════════════════╗${NC}"
    echo -e "${G}║  À bientôt, ${PSEUDO_NAME:-Shadow} ! 👋       ║${NC}"
    echo -e "${G}╚══════════════════════════════════╝${NC}\n"
    # Restaurer un prompt propre
    tput cnorm 2>/dev/null  # réafficher le curseur
    stty sane 2>/dev/null   # restaurer le terminal
    exit 0
}
# Intercepter Ctrl+C pour quitter proprement
trap quitter_proprement INT TERM

# ═══════════════════════════════════════════════════════════
#                    BANNER NEOFETCH STYLE
# ═══════════════════════════════════════════════════════════
show_banner() {
    local PSEUDO="${PSEUDO_NAME:-Shadow}"
    local ram_used ram_total storage uptime_s nb_proj nb_outils nb_notes
    ram_used=$(free -m 2>/dev/null | awk 'NR==2{print $3}')
    ram_total=$(free -m 2>/dev/null | awk 'NR==2{print $2}')
    storage=$(df -h "$HOME" 2>/dev/null | awk 'NR==2{print $3"/"$2}')
    uptime_s=$(uptime -p 2>/dev/null | sed 's/up //' || echo "?")
    nb_proj=$(grep -v "^#" "$PROJETS_FILE" 2>/dev/null | grep -c "|" || echo 0)
    nb_outils=$(grep -v "^#" "$OUTILS_FILE" 2>/dev/null | grep -c "|" || echo 0)
    nb_notes=$(grep -v "^#" "$NOTES_FILE" 2>/dev/null | grep -c "." || echo 0)

    local LC="$ACCENT"

    clear
    echo -e "${LC}"
    echo "         .o8888b.              ${BOLD}${PSEUDO}${NC}${LC}@termux"
    echo "        d8P'    'Y8b           ${DIM}─────────────────────${NC}"
    echo "       88P       888     888   ${B}OS     :${NC} Android (Termux)"
    echo "       88P       888     888   ${B}Shell  :${NC} $(basename "$SHELL") $(bash --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+' | head -1)"
    echo "       88P       888     888   ${B}RAM    :${NC} ${ram_used}MB / ${ram_total}MB"
    echo "        Y8b      d8P     88P   ${B}Disque :${NC} $storage"
    echo "         'Y8888888P'    d8P    ${B}Uptime :${NC} $uptime_s"
    echo "                   88888P'     ${B}Projets:${NC} ${G}$nb_proj${NC}  ${B}Outils:${NC} ${G}$nb_outils${NC}  ${B}Notes:${NC} ${G}$nb_notes${NC}"
    echo -e "${NC}"

    echo -e "  \033[41m   \033[42m   \033[43m   \033[44m   \033[45m   \033[46m   \033[47m   \033[0m"
    echo ""
}

# ═══════════════════════════════════════════════════════════
#                    DASHBOARD AU DÉMARRAGE
# ═══════════════════════════════════════════════════════════
show_dashboard() {
    show_banner

    local tor_status
    if pgrep -x "tor" &>/dev/null; then
        tor_status="${G}● ACTIF${NC}"
    else
        tor_status="${R}● INACTIF${NC}"
    fi

    local ip_pub
    ip_pub=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || echo "?")

    local ip_loc
    ip_loc=$(ip route get 1 2>/dev/null | awk '{print $7; exit}' || hostname -I 2>/dev/null | awk '{print $1}' || echo "?")

    # Dernière note si elle existe
    local last_note
    last_note=$(grep -v "^#" "$NOTES_FILE" 2>/dev/null | tail -1 | cut -d'|' -f2)

    echo -e "  ┌─────────────────────────────────────────────┐"
    echo -e "  │  ${B}TOR    :${NC} $tor_status"
    echo -e "  │  ${B}IP pub :${NC} ${WARN}$ip_pub${NC}"
    echo -e "  │  ${B}IP loc :${NC} ${DIM}$ip_loc${NC}"
    [ -n "$last_note" ] && echo -e "  │  ${B}Note   :${NC} ${DIM}$last_note${NC}"
    echo -e "  └─────────────────────────────────────────────┘"
    echo ""
}

# ═══════════════════════════════════════════════════════════
#                    INITIALISATION
# ═══════════════════════════════════════════════════════════
init_env() {
    mkdir -p "$ENV_DIR"

    [ ! -f "$PROJETS_FILE" ] && echo "# FORMAT: nom|type|chemin|commande_lancer|description|date_ajout" > "$PROJETS_FILE"

    [ ! -f "$OUTILS_FILE" ] && cat > "$OUTILS_FILE" << 'EOF'
# FORMAT: nom|categorie|cmd_install|cmd_lancer|description
python|Langage|pkg install python -y|python --version|Langage Python
nodejs|Langage|pkg install nodejs -y|node --version|Langage Node.js
git|Outil|pkg install git -y|git --version|Gestion de version
curl|Outil|pkg install curl -y|curl --version|Transfert HTTP
wget|Outil|pkg install wget -y|wget --version|Téléchargement fichiers
nano|Editeur|pkg install nano -y|nano|Editeur simple
vim|Editeur|pkg install vim -y|vim|Editeur avancé
htop|Systeme|pkg install htop -y|htop|Moniteur de processus
EOF

    [ ! -f "$PENTEST_FILE" ] && cat > "$PENTEST_FILE" << 'EOF'
# FORMAT: nom|deps|cmd_install|cmd_lancer|exemple|description
nmap|pkg install nmap -y|pkg install nmap -y|nmap|nmap -sV 192.168.1.1|Scanner de ports et services réseau
sqlmap|pip install sqlmap|pip install sqlmap|sqlmap|sqlmap -u "http://site.com/?id=1" --dbs|Test d'injection SQL
hydra|pkg install hydra -y|pkg install hydra -y|hydra|hydra -l admin -P pass.txt ssh://192.168.1.1|Test de force brute
nikto|pkg install perl -y|pkg install perl -y|perl nikto.pl|perl nikto.pl -h http://monsite.com|Scanner de vulnérabilités web
metasploit|pkg install unstable-repo && pkg install metasploit -y|pkg install unstable-repo -y && pkg install metasploit -y|msfconsole|msfconsole|Framework pentest complet
EOF

    [ ! -f "$SSH_FILE" ] && echo "# FORMAT: alias|user|host|port|description" > "$SSH_FILE"

    [ ! -f "$NOTES_FILE" ] && echo "# FORMAT: date|contenu" > "$NOTES_FILE"

    [ ! -f "$LOG_FILE" ] && echo "# Journal des actions" > "$LOG_FILE"

    if [ ! -f "$ALIAS_FILE" ]; then
        cat > "$ALIAS_FILE" << 'EOF'
# Mes alias personnalisés
alias ll='ls -la'
alias cls='clear'
alias update='pkg update && pkg upgrade -y'
alias env='bash ~/mon_env_termux.sh'
alias projets='cd $HOME/projets'
EOF
        grep -qF "source $ALIAS_FILE" ~/.bashrc 2>/dev/null || echo "source $ALIAS_FILE" >> ~/.bashrc
    fi

    if [ ! -f "$THEME_FILE" ]; then
        cat > "$THEME_FILE" << 'EOF'
PSEUDO_NAME="Shadow"
THEME_NAME="Arch"
ACCENT='\033[0;36m'
ACCENT2='\033[0;34m'
SUCCESS='\033[0;32m'
WARN='\033[1;33m'
DANGER='\033[0;31m'
BOLD='\033[1;37m'
DIM='\033[0;37m'
EOF
    fi

    setup_autocomplete
    source "$ALIAS_FILE" 2>/dev/null
    source "$THEME_FILE" 2>/dev/null
    R="$DANGER"; G="$SUCCESS"; Y="$WARN"; B="$ACCENT2"; C="$ACCENT"; W="$BOLD"
}

setup_autocomplete() {
    pkg list-installed 2>/dev/null | grep -q "bash-completion" || pkg install bash-completion -y &>/dev/null
    grep -qF "HISTSIZE=10000" ~/.bashrc 2>/dev/null || cat >> ~/.bashrc << 'EOF'

# ── Autocomplétion & Historique ──
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoredups:erasedups
shopt -s histappend
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
[ -f /data/data/com.termux/files/usr/share/bash-completion/bash_completion ] && \
    source /data/data/com.termux/files/usr/share/bash-completion/bash_completion
EOF
}

# ═══════════════════════════════════════════════════════════
#                    MENU PRINCIPAL
# ═══════════════════════════════════════════════════════════
menu_principal() {
    show_dashboard

    echo -e "  ${G}1)${NC} 🚀  Mes Projets"
    echo -e "  ${G}2)${NC} 🔧  Mes Outils"
    echo -e "  ${G}3)${NC} 🔐  Pentesting"
    echo -e "  ${G}4)${NC} 💻  Codage"
    echo -e "  ${G}5)${NC} 📊  Système"
    echo -e "  ${G}6)${NC} 🧅  TOR / Réseau Onion"
    echo -e "  ${G}7)${NC} 🌐  Outils Réseau"
    echo -e "  ${G}8)${NC} 🔑  Gestionnaire SSH"
    echo -e "  ${G}9)${NC} 📝  Notes rapides"
    echo -e "  ${G}s)${NC} ⚙️   Paramètres"
    echo -e "  ${G}q)${NC} 🚪  Quitter vers Termux"
    echo ""
    echo -ne "${C}Ton choix : ${NC}"
    read -r choix

    case $choix in
        1) menu_projets ;;
        2) menu_outils ;;
        3) menu_pentest ;;
        4) menu_codage ;;
        5) menu_systeme ;;
        6) menu_tor ;;
        7) menu_reseau ;;
        8) menu_ssh ;;
        9) menu_notes ;;
        s|S) menu_parametres ;;
        q|Q|0) quitter_proprement ;;
        *) menu_principal ;;
    esac
}

# ═══════════════════════════════════════════════════════════
#                    MES PROJETS
# ═══════════════════════════════════════════════════════════
menu_projets() {
    clear
    echo -e "${C}${W}🚀 MES PROJETS${NC}\n"
    echo -e "  ${G}1)${NC} Voir tous mes projets"
    echo -e "  ${G}2)${NC} Ajouter un projet"
    echo -e "  ${G}3)${NC} Lancer un projet"
    echo -e "  ${G}4)${NC} Supprimer un projet"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1) voir_projets ;;
        2) ajouter_projet ;;
        3) lancer_projet ;;
        4) supprimer_projet ;;
        0) menu_principal ;;
        *) menu_projets ;;
    esac
}

voir_projets() {
    clear
    echo -e "${C}${W}📁 MES PROJETS SAUVEGARDÉS${NC}\n"
    local nb=0
    while IFS='|' read -r nom type chemin lancer desc date; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        nb=$((nb+1))
        echo -e "${Y}── $nom ────────────────────────${NC}"
        echo -e "  ${B}Type       :${NC} $type"
        echo -e "  ${B}Dossier    :${NC} $chemin"
        echo -e "  ${B}Lancer     :${NC} ${G}$lancer${NC}"
        echo -e "  ${B}Description:${NC} $desc"
        echo -e "  ${B}Ajouté le  :${NC} $date\n"
    done < "$PROJETS_FILE"
    [ $nb -eq 0 ] && echo -e "${Y}Aucun projet. Utilise 'Ajouter' !${NC}\n"
    echo -e "${Y}Entrée pour revenir...${NC}"; read
    menu_projets
}

ajouter_projet() {
    clear
    echo -e "${C}${W}➕ AJOUTER UN PROJET${NC}\n"
    echo -ne "Nom du projet : "; read -r nom
    [ -z "$nom" ] && echo -e "${R}Nom vide, annulé.${NC}" && sleep 1 && menu_projets && return
    echo -e "\nType :"
    echo -e "  ${G}1)${NC} Python   ${G}2)${NC} Node.js   ${G}3)${NC} Bash   ${G}4)${NC} Pentest   ${G}5)${NC} Autre"
    echo -ne "Choix : "; read -r t
    case $t in 1) type="Python";; 2) type="Node.js";; 3) type="Bash";; 4) type="Pentest";; *) type="Autre";; esac
    echo -ne "Chemin (ex: ~/projets/monapp) : "; read -r chemin
    echo -ne "Commande pour lancer (ex: python app.py) : "; read -r lancer
    echo -ne "Description courte : "; read -r desc
    local date; date=$(date +"%d/%m/%Y")
    # Échapper les pipes dans les champs saisis
    nom="${nom//|/\\|}"; desc="${desc//|/\\|}"
    echo "$nom|$type|$chemin|$lancer|$desc|$date" >> "$PROJETS_FILE"
    mkdir -p "$(eval echo "$chemin")" 2>/dev/null
    log_action "Projet ajouté : $nom"
    echo -e "\n${G}✅ Projet '$nom' sauvegardé !${NC}"
    echo -e "${B}Pour le lancer : ${G}$lancer${NC}"
    sleep 2; menu_projets
}

lancer_projet() {
    clear
    echo -e "${C}${W}⚡ LANCER UN PROJET${NC}\n"
    local i=1
    declare -a noms cmds chemins
    while IFS='|' read -r nom type chemin lancer desc date; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        echo -e "  ${G}$i)${NC} ${W}$nom${NC} ${B}($type)${NC}"
        echo -e "     ${Y}→ $lancer${NC}  📂 $chemin\n"
        noms+=("$nom"); cmds+=("$lancer"); chemins+=("$chemin")
        i=$((i+1))
    done < "$PROJETS_FILE"
    [ ${#noms[@]} -eq 0 ] && echo -e "${Y}Aucun projet.${NC}" && sleep 2 && menu_projets && return
    echo -ne "${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_projets && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local idx=$((num-1))
        local chemin_reel; chemin_reel=$(eval echo "${chemins[$idx]}" 2>/dev/null)
        echo -e "\n${G}Lancement : ${cmds[$idx]}${NC}\n"
        log_action "Projet lancé : ${noms[$idx]}"
        cd "$chemin_reel" 2>/dev/null
        bash -c "${cmds[$idx]}"
        cd "$HOME"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_projets
}

supprimer_projet() {
    clear
    echo -e "${C}${W}❌ SUPPRIMER UN PROJET${NC}\n"
    local i=1
    declare -a noms
    while IFS='|' read -r nom type chemin lancer desc date; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        echo -e "  ${G}$i)${NC} $nom ($type)"; noms+=("$nom"); i=$((i+1))
    done < "$PROJETS_FILE"
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_projets && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local n="${noms[$((num-1))]}"
        # Suppression sécurisée avec grep -F pour éviter l'interprétation regex
        grep -vF "${n}|" "$PROJETS_FILE" > /tmp/_mon_env_tmp && mv /tmp/_mon_env_tmp "$PROJETS_FILE"
        log_action "Projet supprimé : $n"
        echo -e "${G}✅ '$n' supprimé.${NC}"
    fi
    sleep 1; menu_projets
}

# ═══════════════════════════════════════════════════════════
#                    MES OUTILS
# ═══════════════════════════════════════════════════════════
menu_outils() {
    clear
    echo -e "${C}${W}🔧 MES OUTILS${NC}\n"
    echo -e "  ${G}1)${NC} Voir tous mes outils (statut)"
    echo -e "  ${G}2)${NC} Installer un outil"
    echo -e "  ${G}3)${NC} Ajouter un outil perso"
    echo -e "  ${G}4)${NC} Supprimer un outil"
    echo -e "  ${G}5)${NC} Installer TOUS les outils"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1) voir_outils ;;
        2) installer_outil_seul ;;
        3) ajouter_outil ;;
        4) supprimer_outil ;;
        5) installer_tous_outils ;;
        0) menu_principal ;;
        *) menu_outils ;;
    esac
}

voir_outils() {
    clear
    echo -e "${C}${W}🔧 TOUS MES OUTILS${NC}\n"
    while IFS='|' read -r nom cat install lancer desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        local cmd1; cmd1=$(echo "$lancer" | awk '{print $1}')
        local s
        command -v "$cmd1" &>/dev/null && s="${G}✅${NC}" || s="${R}❌${NC}"
        echo -e "  $s ${W}$nom${NC} ${DIM}[$cat]${NC} — $desc"
        echo -e "     ${B}Lancer :${NC} ${G}$lancer${NC}\n"
    done < "$OUTILS_FILE"
    echo -e "${Y}Entrée pour revenir...${NC}"; read
    menu_outils
}

installer_outil_seul() {
    clear
    echo -e "${C}${W}📥 INSTALLER UN OUTIL${NC}\n"
    local i=1
    declare -a noms installs
    while IFS='|' read -r nom cat install lancer desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        local cmd1; cmd1=$(echo "$lancer" | awk '{print $1}')
        local s; command -v "$cmd1" &>/dev/null && s="${G}✅${NC}" || s="${R}❌${NC}"
        echo -e "  ${G}$i)${NC} $s ${W}$nom${NC} — $desc"
        noms+=("$nom"); installs+=("$install"); i=$((i+1))
    done < "$OUTILS_FILE"
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_outils && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local idx=$((num-1))
        echo -e "\n${Y}Installation de ${noms[$idx]}...${NC}"
        bash -c "${installs[$idx]}" && echo -e "${G}✅ Installé !${NC}" || echo -e "${R}❌ Erreur${NC}"
        log_action "Outil installé : ${noms[$idx]}"
    fi
    echo -e "${Y}Entrée pour revenir...${NC}"; read
    menu_outils
}

ajouter_outil() {
    clear
    echo -e "${C}${W}➕ AJOUTER UN OUTIL${NC}\n"
    echo -ne "Nom : "; read -r nom
    echo -ne "Catégorie (Langage/Outil/Editeur/Autre) : "; read -r cat
    echo -ne "Commande d'installation : "; read -r install
    echo -ne "Commande pour lancer : "; read -r lancer
    echo -ne "Description : "; read -r desc
    echo "$nom|$cat|$install|$lancer|$desc" >> "$OUTILS_FILE"
    echo -e "\n${G}✅ '$nom' ajouté !${NC}"
    sleep 2; menu_outils
}

supprimer_outil() {
    clear
    echo -e "${C}${W}❌ SUPPRIMER UN OUTIL${NC}\n"
    local i=1
    declare -a noms
    while IFS='|' read -r nom cat install lancer desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        echo -e "  ${G}$i)${NC} $nom ($cat)"; noms+=("$nom"); i=$((i+1))
    done < "$OUTILS_FILE"
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_outils && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local n="${noms[$((num-1))]}"
        grep -vF "${n}|" "$OUTILS_FILE" > /tmp/_mon_env_tmp && mv /tmp/_mon_env_tmp "$OUTILS_FILE"
        echo -e "${G}✅ '$n' supprimé.${NC}"
    fi
    sleep 1; menu_outils
}

installer_tous_outils() {
    clear
    echo -e "${C}${W}📥 INSTALLATION DE TOUS LES OUTILS${NC}\n"
    pkg update -y && pkg upgrade -y
    while IFS='|' read -r nom cat install lancer desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        echo -ne "${Y}→ $nom ... ${NC}"
        bash -c "$install" &>/dev/null && echo -e "${G}✅${NC}" || echo -e "${R}❌${NC}"
    done < "$OUTILS_FILE"
    echo -e "\n${G}Terminé !${NC}"
    echo -e "${Y}Entrée pour revenir...${NC}"; read
    menu_outils
}

# ═══════════════════════════════════════════════════════════
#                    PENTESTING
# ═══════════════════════════════════════════════════════════
menu_pentest() {
    clear
    echo -e "${R}${W}🔐 PENTESTING${NC}"
    echo -e "${Y}⚠️  Usage éthique uniquement — tes propres machines !${NC}\n"
    echo -e "  ${G}1)${NC} Voir mes outils pentest"
    echo -e "  ${G}2)${NC} Installer un outil pentest"
    echo -e "  ${G}3)${NC} Guide de lancement"
    echo -e "  ${G}4)${NC} Ajouter un outil pentest"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1) voir_pentest ;;
        2) installer_pentest ;;
        3) guide_pentest ;;
        4) ajouter_pentest ;;
        0) menu_principal ;;
        *) menu_pentest ;;
    esac
}

voir_pentest() {
    clear
    echo -e "${R}${W}🔐 MES OUTILS PENTEST${NC}\n"
    while IFS='|' read -r nom deps install lancer exemple desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        local cmd1; cmd1=$(echo "$lancer" | awk '{print $1}')
        local s; command -v "$cmd1" &>/dev/null && s="${G}✅${NC}" || s="${R}❌${NC}"
        echo -e "$s ${W}$nom${NC} — $desc"
        echo -e "   ${B}Lancer  :${NC} ${G}$lancer${NC}"
        echo -e "   ${B}Exemple :${NC} ${Y}$exemple${NC}\n"
    done < "$PENTEST_FILE"
    echo -e "${Y}Entrée pour revenir...${NC}"; read
    menu_pentest
}

installer_pentest() {
    clear
    echo -e "${R}${W}📥 INSTALLER OUTIL PENTEST${NC}\n"
    local i=1
    declare -a noms installs deps_list
    while IFS='|' read -r nom deps install lancer exemple desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        echo -e "  ${G}$i)${NC} ${W}$nom${NC} — $desc"
        echo -e "     ${B}Dépendances :${NC} $deps\n"
        noms+=("$nom"); installs+=("$install"); deps_list+=("$deps")
        i=$((i+1))
    done < "$PENTEST_FILE"
    echo -ne "${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_pentest && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local idx=$((num-1))
        echo -e "\n${Y}Dépendances : ${deps_list[$idx]}${NC}"
        echo -e "${Y}Installation de ${noms[$idx]}...${NC}"
        bash -c "${installs[$idx]}" && echo -e "\n${G}✅ ${noms[$idx]} installé !${NC}" || echo -e "\n${R}❌ Erreur${NC}"
    fi
    echo -e "${Y}Entrée pour revenir...${NC}"; read
    menu_pentest
}

guide_pentest() {
    clear
    echo -e "${R}${W}📖 GUIDE DE LANCEMENT${NC}\n"
    local i=1
    declare -a noms lancers exemples descs
    while IFS='|' read -r nom deps install lancer exemple desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        echo -e "  ${G}$i)${NC} $nom"
        noms+=("$nom"); lancers+=("$lancer"); exemples+=("$exemple"); descs+=("$desc")
        i=$((i+1))
    done < "$PENTEST_FILE"
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_pentest && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local idx=$((num-1))
        clear
        echo -e "${R}${W}📖 ${noms[$idx]}${NC}\n"
        echo -e "${B}Description :${NC}\n  ${descs[$idx]}\n"
        echo -e "${B}Commande de base :${NC}\n  ${G}${lancers[$idx]}${NC}\n"
        echo -e "${B}Exemple concret :${NC}\n  ${Y}${exemples[$idx]}${NC}\n"
        echo -e "${R}⚠️  Utilise uniquement sur des systèmes que tu possèdes !${NC}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_pentest
}

ajouter_pentest() {
    clear
    echo -e "${C}${W}➕ AJOUTER OUTIL PENTEST${NC}\n"
    echo -ne "Nom : "; read -r nom
    echo -ne "Dépendances : "; read -r deps
    echo -ne "Commande d'installation : "; read -r install
    echo -ne "Commande pour lancer : "; read -r lancer
    echo -ne "Exemple d'utilisation : "; read -r exemple
    echo -ne "Description : "; read -r desc
    echo "$nom|$deps|$install|$lancer|$exemple|$desc" >> "$PENTEST_FILE"
    echo -e "\n${G}✅ '$nom' ajouté !${NC}"
    sleep 2; menu_pentest
}

# ═══════════════════════════════════════════════════════════
#                    CODAGE
# ═══════════════════════════════════════════════════════════
menu_codage() {
    clear
    echo -e "${B}${W}💻 CODAGE${NC}\n"
    echo -e "  ${G}1)${NC} Ouvrir nano"
    echo -e "  ${G}2)${NC} Ouvrir vim"
    echo -e "  ${G}3)${NC} Nouveau fichier Python"
    echo -e "  ${G}4)${NC} Nouveau fichier Node.js"
    echo -e "  ${G}5)${NC} Nouveau script Bash"
    echo -e "  ${G}6)${NC} Git — actions rapides"
    echo -e "  ${G}7)${NC} Correcteur de commande"
    echo -e "  ${G}8)${NC} Exécuter un fichier"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1) nano ;;
        2) vim ;;
        3) nouveau_python ;;
        4) nouveau_node ;;
        5) nouveau_bash ;;
        6) menu_git ;;
        7) correcteur_cmd ;;
        8) executer_fichier ;;
        0) menu_principal; return ;;
        *) menu_codage ;;
    esac
    menu_codage
}

nouveau_python() {
    echo -ne "\n${C}Nom du fichier (sans .py) : ${NC}"; read -r nom
    [ -z "$nom" ] && return
    local f="$nom.py"
    cat > "$f" << EOF
#!/usr/bin/env python3
# $nom.py — créé le $(date +%d/%m/%Y)

def main():
    print("Hello depuis $nom !")

if __name__ == "__main__":
    main()
EOF
    echo -e "${G}✅ '$f' créé !${NC}"
    echo -ne "Ouvrir dans nano ? (o/n) : "; read -r r
    [ "$r" = "o" ] && nano "$f"
}

nouveau_node() {
    echo -ne "\n${C}Nom du fichier (sans .js) : ${NC}"; read -r nom
    [ -z "$nom" ] && return
    local f="$nom.js"
    cat > "$f" << EOF
// $nom.js — créé le $(date +%d/%m/%Y)

function main() {
    console.log("Hello depuis $nom !");
}

main();
EOF
    echo -e "${G}✅ '$f' créé !${NC}"
    echo -ne "Ouvrir dans nano ? (o/n) : "; read -r r
    [ "$r" = "o" ] && nano "$f"
}

nouveau_bash() {
    echo -ne "\n${C}Nom du script (sans .sh) : ${NC}"; read -r nom
    [ -z "$nom" ] && return
    local f="$nom.sh"
    cat > "$f" << EOF
#!/data/data/com.termux/files/usr/bin/bash
# $nom.sh — créé le $(date +%d/%m/%Y)

echo "Hello depuis $nom !"
EOF
    chmod +x "$f"
    echo -e "${G}✅ '$f' créé et rendu exécutable !${NC}"
    echo -ne "Ouvrir dans nano ? (o/n) : "; read -r r
    [ "$r" = "o" ] && nano "$f"
}

executer_fichier() {
    clear
    echo -e "${B}${W}▶️  EXÉCUTER UN FICHIER${NC}\n"
    echo -e "${DIM}Fichiers dans le dossier courant :${NC}"
    ls --color=always 2>/dev/null || ls
    echo ""
    echo -ne "${C}Nom du fichier à exécuter : ${NC}"; read -r fichier
    [ -z "$fichier" ] && return
    if [ ! -f "$fichier" ]; then
        echo -e "${R}❌ Fichier introuvable.${NC}"; sleep 2; return
    fi
    case "$fichier" in
        *.py)  echo -e "\n${Y}Exécution Python...${NC}\n"; python3 "$fichier" ;;
        *.js)  echo -e "\n${Y}Exécution Node.js...${NC}\n"; node "$fichier" ;;
        *.sh)  echo -e "\n${Y}Exécution Bash...${NC}\n"; bash "$fichier" ;;
        *)     echo -e "\n${Y}Exécution directe...${NC}\n"; bash -c "./$fichier" ;;
    esac
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
}

menu_git() {
    clear
    echo -e "${B}${W}🌿 GIT — ACTIONS RAPIDES${NC}\n"
    echo -e "  ${G}1)${NC} git status"
    echo -e "  ${G}2)${NC} git add . && commit"
    echo -e "  ${G}3)${NC} git push"
    echo -e "  ${G}4)${NC} git pull"
    echo -e "  ${G}5)${NC} git clone un repo"
    echo -e "  ${G}6)${NC} Initialiser un repo"
    echo -e "  ${G}7)${NC} Voir les logs git"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1) git status ;;
        2) echo -ne "Message du commit : "; read -r msg; git add . && git commit -m "$msg" ;;
        3) git push ;;
        4) git pull ;;
        5) echo -ne "URL du repo : "; read -r url; git clone "$url" ;;
        6) git init && echo -e "${G}✅ Repo initialisé !${NC}" ;;
        7) git log --oneline -15 2>/dev/null || echo -e "${R}Pas de repo git ici.${NC}" ;;
        0) return ;;
    esac
    echo -e "\n${Y}Entrée pour continuer...${NC}"; read
}

correcteur_cmd() {
    clear
    echo -e "${B}${W}🔧 CORRECTEUR DE COMMANDE${NC}\n"
    echo -ne "${C}> ${NC}"; read -r cmd
    declare -A corrections=(
        ["pyhton"]="python3" ["pyton"]="python3" ["pytohn"]="python3"
        ["gti"]="git" ["got"]="git" ["giot"]="git"
        ["nmp"]="npm" ["npn"]="npm"
        ["naon"]="nano" ["nao"]="nano"
        ["celar"]="clear" ["cealr"]="clear"
        ["sl"]="ls" ["dc"]="cd"
        ["mroe"]="more" ["moer"]="more"
        ["grpe"]="grep" ["gerp"]="grep"
    )
    local corrected="${corrections[$cmd]}"
    if [ -n "$corrected" ]; then
        echo -e "\n${Y}Tu voulais dire : ${G}$corrected${NC} ?"
        echo -ne "Exécuter ? (o/n) : "; read -r r
        [ "$r" = "o" ] && bash -c "$corrected"
    else
        echo -e "\n${G}Exécution :${NC}"; bash -c "$cmd"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
}

# ═══════════════════════════════════════════════════════════
#                    SYSTÈME
# ═══════════════════════════════════════════════════════════
menu_systeme() {
    clear
    echo -e "${M}${W}📊 SYSTÈME${NC}\n"
    local ram_total ram_used ram_pct storage uptime_info nb_proc
    ram_total=$(free -m 2>/dev/null | awk 'NR==2{print $2}')
    ram_used=$(free -m 2>/dev/null | awk 'NR==2{print $3}')
    ram_pct=$(free 2>/dev/null | awk 'NR==2{printf "%.0f", $3/$2*100}')
    storage=$(df -h "$HOME" 2>/dev/null | awk 'NR==2{print $3"/"$2" ("$5")"}')
    uptime_info=$(uptime -p 2>/dev/null | sed 's/up //' || uptime)
    nb_proc=$(ps aux 2>/dev/null | wc -l)

    echo -e "${B}💾 RAM       :${NC} ${ram_used}MB / ${ram_total}MB (${Y}${ram_pct}%${NC})"
    echo -e "${B}💿 Stockage  :${NC} $storage"
    echo -e "${B}⏱️  Uptime    :${NC} $uptime_info"
    echo -e "${B}⚙️  Processus :${NC} $nb_proc"
    echo ""
    echo -e "  ${G}1)${NC} Voir processus (htop)"
    echo -e "  ${G}2)${NC} Nettoyer le cache apt"
    echo -e "  ${G}3)${NC} Mettre à jour Termux"
    echo -e "  ${G}4)${NC} Voir les processus actifs (ps)"
    echo -e "  ${G}5)${NC} Tuer un processus par nom"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1) htop 2>/dev/null || top ;;
        2) apt-get clean 2>/dev/null; pkg clean 2>/dev/null; echo -e "${G}✅ Cache nettoyé !${NC}"; sleep 2 ;;
        3) pkg update && pkg upgrade -y; sleep 2 ;;
        4) ps aux 2>/dev/null | head -20; echo -e "\n${Y}Entrée...${NC}"; read ;;
        5)
            echo -ne "\n${C}Nom du processus à tuer : ${NC}"; read -r pname
            pkill -f "$pname" && echo -e "${G}✅ Processus '$pname' tué.${NC}" || echo -e "${R}❌ Processus non trouvé.${NC}"
            sleep 2 ;;
        0) menu_principal; return ;;
    esac
    menu_systeme
}

# ═══════════════════════════════════════════════════════════
#                    TOR / RÉSEAU ONION
# ═══════════════════════════════════════════════════════════
menu_tor() {
    clear
    echo -e "${M}${W}🧅 TOR / RÉSEAU ONION${NC}\n"

    local tor_s
    pgrep -x "tor" &>/dev/null && tor_s="${G}● ACTIF${NC}" || tor_s="${R}● INACTIF${NC}"
    echo -e "  Statut TOR : $tor_s\n"

    echo -e "  ${G}1)${NC} Activer TOR (+ proxychains)"
    echo -e "  ${G}2)${NC} Désactiver TOR"
    echo -e "  ${G}3)${NC} Vérifier mon IP via TOR"
    echo -e "  ${G}4)${NC} Lancer une commande via TOR"
    echo -e "  ${G}5)${NC} Changer de circuit (nouvelle IP TOR)"
    echo -e "  ${G}6)${NC} Installer TOR + proxychains"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1) tor_activer ;;
        2) tor_desactiver ;;
        3) tor_verifier_ip ;;
        4) tor_cmd ;;
        5) tor_nouveau_circuit ;;
        6) tor_installer ;;
        0) menu_principal ;;
        *) menu_tor ;;
    esac
}

tor_installer() {
    echo -e "\n${Y}Installation de TOR et proxychains...${NC}"
    pkg install tor -y && echo -e "${G}✅ tor installé${NC}" || echo -e "${R}❌ Erreur tor${NC}"
    pkg install proxychains-ng -y && echo -e "${G}✅ proxychains-ng installé${NC}" || echo -e "${R}❌ Erreur proxychains${NC}"

    local pc_conf="$PREFIX/etc/proxychains.conf"
    if [ ! -f "$pc_conf" ]; then
        cat > "$pc_conf" << 'EOF'
strict_chain
proxy_dns
[ProxyList]
socks5 127.0.0.1 9050
EOF
        echo -e "${G}✅ proxychains.conf configuré${NC}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_tor
}

tor_activer() {
    echo -e "\n${Y}Démarrage de TOR...${NC}"
    if ! command -v tor &>/dev/null; then
        echo -e "${R}❌ TOR n'est pas installé. Utilise l'option 6.${NC}"
    else
        tor --quiet &
        sleep 3
        pgrep -x "tor" &>/dev/null && \
            echo -e "${G}✅ TOR actif ! Port SOCKS5 : 9050${NC}\n${B}Utilise proxychains <commande> pour passer par TOR.${NC}" || \
            echo -e "${R}❌ Échec du démarrage de TOR${NC}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_tor
}

tor_desactiver() {
    echo -e "\n${Y}Arrêt de TOR...${NC}"
    pkill -x tor 2>/dev/null && echo -e "${G}✅ TOR arrêté.${NC}" || echo -e "${Y}TOR n'était pas actif.${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_tor
}

tor_verifier_ip() {
    echo -e "\n${B}Vérification de ton IP...${NC}"
    echo -ne "${W}IP réelle   :${NC} "
    curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo "impossible à récupérer"
    echo ""
    echo -ne "${W}IP via TOR  :${NC} "
    if command -v proxychains4 &>/dev/null || command -v proxychains &>/dev/null; then
        local pc_cmd; command -v proxychains4 &>/dev/null && pc_cmd="proxychains4" || pc_cmd="proxychains"
        $pc_cmd curl -s --max-time 10 https://api.ipify.org 2>/dev/null || echo "TOR inactif ou erreur"
    else
        echo -e "${R}proxychains non installé${NC}"
    fi
    echo ""
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_tor
}

tor_cmd() {
    echo -ne "\n${C}Commande à lancer via TOR (ex: curl http://check.torproject.org) : ${NC}"
    read -r cmd
    local pc_cmd; command -v proxychains4 &>/dev/null && pc_cmd="proxychains4" || pc_cmd="proxychains"
    echo -e "\n${Y}Lancement via $pc_cmd...${NC}\n"
    # Passer la commande via bash -c pour gérer les espaces correctement
    bash -c "$pc_cmd $cmd"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_tor
}

tor_nouveau_circuit() {
    echo -e "\n${Y}Changement de circuit TOR...${NC}"
    if pgrep -x "tor" &>/dev/null; then
        pkill -HUP tor 2>/dev/null && echo -e "${G}✅ Nouveau circuit TOR demandé ! (attends ~10s)${NC}" || echo -e "${R}❌ Erreur${NC}"
    else
        echo -e "${R}❌ TOR n'est pas actif. Démarre-le d'abord.${NC}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_tor
}

# ═══════════════════════════════════════════════════════════
#                    OUTILS RÉSEAU
# ═══════════════════════════════════════════════════════════
menu_reseau() {
    clear
    echo -e "${B}${W}🌐 OUTILS RÉSEAU${NC}\n"
    echo -e "  ${G}1)${NC} Voir mes IPs (locale + publique)"
    echo -e "  ${G}2)${NC} Scanner les appareils du réseau WiFi"
    echo -e "  ${G}3)${NC} Tester la vitesse de connexion"
    echo -e "  ${G}4)${NC} Ping une adresse"
    echo -e "  ${G}5)${NC} Traceroute"
    echo -e "  ${G}6)${NC} DNS lookup"
    echo -e "  ${G}7)${NC} Infos sur une IP publique (whois/geo)"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1) reseau_mes_ips ;;
        2) reseau_scan_wifi ;;
        3) reseau_speedtest ;;
        4) reseau_ping ;;
        5) reseau_traceroute ;;
        6) reseau_dns ;;
        7) reseau_geoip ;;
        0) menu_principal ;;
        *) menu_reseau ;;
    esac
}

reseau_mes_ips() {
    clear
    echo -e "${B}${W}📡 MES IPs${NC}\n"
    echo -ne "${W}IP locale    :${NC} "
    ip route get 1 2>/dev/null | awk '{print $7; exit}' || hostname -I 2>/dev/null | awk '{print $1}' || echo "?"
    echo -ne "${W}IP publique  :${NC} "
    curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo "?"
    echo ""
    echo -ne "${W}Interface    :${NC} "
    ip route 2>/dev/null | grep "^default" | awk '{print $5}' || echo "?"
    echo -ne "${W}Passerelle   :${NC} "
    ip route 2>/dev/null | grep "^default" | awk '{print $3}' || echo "?"
    echo ""
    echo -e "${Y}Entrée pour revenir...${NC}"; read
    menu_reseau
}

reseau_scan_wifi() {
    clear
    echo -e "${B}${W}📡 SCAN RÉSEAU WiFi${NC}\n"
    if ! command -v nmap &>/dev/null; then
        echo -e "${R}❌ nmap n'est pas installé.${NC}"
        echo -ne "Installer maintenant ? (o/n) : "; read -r r
        [ "$r" = "o" ] && pkg install nmap -y
    else
        local gateway
        gateway=$(ip route 2>/dev/null | grep "^default" | awk '{print $3}')
        local subnet; subnet=$(echo "$gateway" | sed 's/\.[0-9]*$/.0\/24/')
        echo -e "${Y}Scan du réseau $subnet ...${NC}\n"
        nmap -sn "$subnet" 2>/dev/null | grep -E "report|latency"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_reseau
}

reseau_speedtest() {
    clear
    echo -e "${B}${W}⚡ TEST DE VITESSE${NC}\n"
    if command -v curl &>/dev/null; then
        echo -e "${Y}Test de téléchargement (10MB)...${NC}"
        local speed
        speed=$(curl -s --max-time 15 -o /dev/null -w "%{speed_download}" http://speedtest.tele2.net/10MB.zip 2>/dev/null)
        if [ -n "$speed" ] && [ "$speed" != "0" ]; then
            local speed_mb; speed_mb=$(echo "$speed" | awk '{printf "%.2f", $1/1048576}')
            echo -e "${G}✅ Vitesse : ${speed_mb} MB/s${NC}"
        else
            echo -e "${R}❌ Test impossible (vérifie ta connexion)${NC}"
        fi
    else
        echo -e "${R}❌ curl non installé${NC}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_reseau
}

reseau_ping() {
    echo -ne "\n${C}Adresse à pinger (ex: 8.8.8.8 ou google.com) : ${NC}"; read -r addr
    [ -z "$addr" ] && menu_reseau && return
    echo ""
    ping -c 4 "$addr" 2>/dev/null || echo -e "${R}❌ Ping échoué${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_reseau
}

reseau_traceroute() {
    echo -ne "\n${C}Adresse (ex: google.com) : ${NC}"; read -r addr
    [ -z "$addr" ] && menu_reseau && return
    echo ""
    if command -v traceroute &>/dev/null; then
        traceroute "$addr"
    else
        echo -e "${Y}traceroute non installé. Installation...${NC}"
        pkg install traceroute -y && traceroute "$addr"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_reseau
}

reseau_dns() {
    echo -ne "\n${C}Domaine à résoudre (ex: google.com) : ${NC}"; read -r dom
    [ -z "$dom" ] && menu_reseau && return
    echo ""
    if command -v nslookup &>/dev/null; then
        nslookup "$dom"
    elif command -v dig &>/dev/null; then
        dig "$dom"
    else
        echo -e "${Y}Installation de dnsutils...${NC}"
        pkg install dnsutils -y && nslookup "$dom"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_reseau
}

reseau_geoip() {
    echo -ne "\n${C}IP à analyser (vide = ma propre IP) : ${NC}"; read -r ip
    [ -z "$ip" ] && ip=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null)
    echo -e "\n${B}Infos sur $ip :${NC}\n"
    curl -s --max-time 8 "https://ipinfo.io/$ip" 2>/dev/null | \
        grep -E '"ip"|"city"|"region"|"country"|"org"' | \
        sed 's/[",]//g' | sed 's/^  /  /' || echo -e "${R}❌ Impossible de récupérer les infos${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_reseau
}

# ═══════════════════════════════════════════════════════════
#                    GESTIONNAIRE SSH
# ═══════════════════════════════════════════════════════════
menu_ssh() {
    clear
    echo -e "${Y}${W}🔑 GESTIONNAIRE SSH${NC}\n"
    echo -e "  ${G}1)${NC} Voir mes connexions SSH"
    echo -e "  ${G}2)${NC} Se connecter en un clic"
    echo -e "  ${G}3)${NC} Ajouter une connexion"
    echo -e "  ${G}4)${NC} Supprimer une connexion"
    echo -e "  ${G}5)${NC} Générer une clé SSH"
    echo -e "  ${G}6)${NC} Copier ma clé publique"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1) ssh_voir ;;
        2) ssh_connecter ;;
        3) ssh_ajouter ;;
        4) ssh_supprimer ;;
        5) ssh_generer_cle ;;
        6) ssh_copier_cle ;;
        0) menu_principal ;;
        *) menu_ssh ;;
    esac
}

ssh_voir() {
    clear
    echo -e "${Y}${W}🔑 MES CONNEXIONS SSH${NC}\n"
    local nb=0
    while IFS='|' read -r alias user host port desc; do
        [[ "$alias" == \#* || -z "$alias" ]] && continue
        nb=$((nb+1))
        echo -e "${C}── $alias ──────────────────────${NC}"
        echo -e "  ${B}Serveur     :${NC} $user@$host:$port"
        echo -e "  ${B}Description :${NC} $desc"
        echo -e "  ${B}Commande    :${NC} ${G}ssh -p $port $user@$host${NC}\n"
    done < "$SSH_FILE"
    [ $nb -eq 0 ] && echo -e "${Y}Aucune connexion sauvegardée. Utilise 'Ajouter' !${NC}\n"
    echo -e "${Y}Entrée pour revenir...${NC}"; read
    menu_ssh
}

ssh_connecter() {
    clear
    echo -e "${Y}${W}⚡ SE CONNECTER${NC}\n"
    local i=1
    declare -a aliases users hosts ports
    while IFS='|' read -r alias user host port desc; do
        [[ "$alias" == \#* || -z "$alias" ]] && continue
        echo -e "  ${G}$i)${NC} ${W}$alias${NC} — $user@$host:$port ${DIM}($desc)${NC}"
        aliases+=("$alias"); users+=("$user"); hosts+=("$host"); ports+=("$port")
        i=$((i+1))
    done < "$SSH_FILE"
    [ ${#aliases[@]} -eq 0 ] && echo -e "${Y}Aucune connexion.${NC}" && sleep 2 && menu_ssh && return
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_ssh && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local idx=$((num-1))
        echo -e "\n${G}Connexion à ${aliases[$idx]}...${NC}"
        log_action "SSH vers ${aliases[$idx]} (${users[$idx]}@${hosts[$idx]})"
        ssh -p "${ports[$idx]}" "${users[$idx]}@${hosts[$idx]}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_ssh
}

ssh_ajouter() {
    clear
    echo -e "${C}${W}➕ AJOUTER UNE CONNEXION SSH${NC}\n"
    echo -ne "Alias (ex: monServeur) : "; read -r alias
    echo -ne "Utilisateur (ex: root) : "; read -r user
    echo -ne "Hôte/IP (ex: 192.168.1.100) : "; read -r host
    echo -ne "Port (défaut: 22) : "; read -r port
    [ -z "$port" ] && port="22"
    echo -ne "Description : "; read -r desc
    echo "$alias|$user|$host|$port|$desc" >> "$SSH_FILE"
    echo -e "\n${G}✅ Connexion '$alias' sauvegardée !${NC}"
    echo -e "${B}Pour te connecter : ${G}ssh -p $port $user@$host${NC}"
    sleep 2; menu_ssh
}

ssh_supprimer() {
    clear
    echo -e "${C}${W}❌ SUPPRIMER UNE CONNEXION${NC}\n"
    local i=1
    declare -a aliases
    while IFS='|' read -r alias user host port desc; do
        [[ "$alias" == \#* || -z "$alias" ]] && continue
        echo -e "  ${G}$i)${NC} $alias ($user@$host)"; aliases+=("$alias"); i=$((i+1))
    done < "$SSH_FILE"
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_ssh && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local n="${aliases[$((num-1))]}"
        grep -vF "${n}|" "$SSH_FILE" > /tmp/_mon_env_tmp && mv /tmp/_mon_env_tmp "$SSH_FILE"
        echo -e "${G}✅ '$n' supprimé.${NC}"
    fi
    sleep 1; menu_ssh
}

ssh_generer_cle() {
    clear
    echo -e "${Y}${W}🔐 GÉNÉRER UNE CLÉ SSH${NC}\n"
    if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
        echo -e "${Y}Une clé SSH existe déjà.${NC}"
        echo -ne "En générer une nouvelle quand même ? (o/n) : "; read -r r
        [ "$r" != "o" ] && menu_ssh && return
    fi
    mkdir -p "$HOME/.ssh"
    echo -ne "Email associé (ou pseudo) : "; read -r email
    echo -e "\n${Y}Génération de la clé...${NC}"
    ssh-keygen -t rsa -b 4096 -C "$email" -f "$HOME/.ssh/id_rsa" -N "" && \
        echo -e "\n${G}✅ Clé générée dans ~/.ssh/id_rsa${NC}" || \
        echo -e "\n${R}❌ Erreur — ssh-keygen est-il installé ? (pkg install openssh)${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_ssh
}

ssh_copier_cle() {
    clear
    echo -e "${Y}${W}📋 MA CLÉ PUBLIQUE${NC}\n"
    if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
        echo -e "${B}Voici ta clé publique (copie-la sur ton serveur) :${NC}\n"
        cat "$HOME/.ssh/id_rsa.pub"
        echo -e "\n${B}Pour l'ajouter sur un serveur :${NC}"
        echo -e "${G}ssh-copy-id -p PORT user@host${NC}"
        echo -e "${DIM}ou colle-la manuellement dans ~/.ssh/authorized_keys sur le serveur.${NC}"
    else
        echo -e "${R}❌ Aucune clé SSH trouvée. Génère-en une d'abord (option 5).${NC}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_ssh
}

# ═══════════════════════════════════════════════════════════
#                    NOTES RAPIDES  (NOUVEAU)
# ═══════════════════════════════════════════════════════════
menu_notes() {
    clear
    echo -e "${C}${W}📝 NOTES RAPIDES${NC}\n"
    echo -e "  ${G}1)${NC} Voir toutes mes notes"
    echo -e "  ${G}2)${NC} Ajouter une note"
    echo -e "  ${G}3)${NC} Supprimer une note"
    echo -e "  ${G}4)${NC} Rechercher dans les notes"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1) notes_voir ;;
        2) notes_ajouter ;;
        3) notes_supprimer ;;
        4) notes_rechercher ;;
        0) menu_principal ;;
        *) menu_notes ;;
    esac
}

notes_voir() {
    clear
    echo -e "${C}${W}📝 MES NOTES${NC}\n"
    local nb=0
    while IFS='|' read -r date contenu; do
        [[ "$date" == \#* || -z "$date" ]] && continue
        nb=$((nb+1))
        echo -e "  ${Y}[$nb]${NC} ${DIM}$date${NC}"
        echo -e "       $contenu\n"
    done < "$NOTES_FILE"
    [ $nb -eq 0 ] && echo -e "${Y}Aucune note. Utilise 'Ajouter' !${NC}\n"
    echo -e "${Y}Entrée pour revenir...${NC}"; read
    menu_notes
}

notes_ajouter() {
    echo -ne "\n${C}Ta note : ${NC}"; read -r contenu
    [ -z "$contenu" ] && return
    local date; date=$(date +"%d/%m/%Y %H:%M")
    echo "$date|$contenu" >> "$NOTES_FILE"
    echo -e "${G}✅ Note ajoutée !${NC}"
    log_action "Note ajoutée"
    sleep 1; menu_notes
}

notes_supprimer() {
    clear
    echo -e "${C}${W}❌ SUPPRIMER UNE NOTE${NC}\n"
    local i=1
    declare -a lignes
    while IFS='|' read -r date contenu; do
        [[ "$date" == \#* || -z "$date" ]] && continue
        echo -e "  ${G}$i)${NC} ${DIM}$date${NC} — $contenu"
        lignes+=("$date|$contenu"); i=$((i+1))
    done < "$NOTES_FILE"
    [ ${#lignes[@]} -eq 0 ] && echo -e "${Y}Aucune note.${NC}" && sleep 1 && menu_notes && return
    echo -ne "\n${C}Numéro à supprimer (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_notes && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local entry="${lignes[$((num-1))]}"
        grep -vF "$entry" "$NOTES_FILE" > /tmp/_mon_env_tmp && mv /tmp/_mon_env_tmp "$NOTES_FILE"
        echo -e "${G}✅ Note supprimée.${NC}"
    fi
    sleep 1; menu_notes
}

notes_rechercher() {
    echo -ne "\n${C}Mot-clé à chercher : ${NC}"; read -r mot
    [ -z "$mot" ] && menu_notes && return
    clear
    echo -e "${C}${W}🔍 Résultats pour \"$mot\" :${NC}\n"
    local found=0
    while IFS='|' read -r date contenu; do
        [[ "$date" == \#* || -z "$date" ]] && continue
        if echo "$contenu" | grep -qi "$mot"; then
            echo -e "  ${Y}$date${NC} — $contenu"
            found=$((found+1))
        fi
    done < "$NOTES_FILE"
    [ $found -eq 0 ] && echo -e "${Y}Aucun résultat.${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_notes
}

# ═══════════════════════════════════════════════════════════
#                    PARAMÈTRES
# ═══════════════════════════════════════════════════════════
menu_parametres() {
    clear
    echo -e "${W}⚙️  PARAMÈTRES${NC}\n"
    echo -e "  ${G}1)${NC} 🎨 Changer le thème de couleurs"
    echo -e "  ${G}2)${NC} 👤 Changer mon pseudo (banner)"
    echo -e "  ${G}3)${NC} 🔤 Installer une police (Fira Code / Meslo)"
    echo -e "  ${G}4)${NC} 💬 Installer ZSH + Oh-My-Zsh"
    echo -e "  ${G}5)${NC} ⚡ Gérer mes alias"
    echo -e "  ${G}6)${NC} 📜 Historique de commandes"
    echo -e "  ${G}7)${NC} 💾 Sauvegarder toute la config"
    echo -e "  ${G}8)${NC} 📦 Restaurer une sauvegarde"
    echo -e "  ${G}9)${NC} 📋 Journal des actions"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1) changer_theme ;;
        2) changer_pseudo ;;
        3) installer_police ;;
        4) installer_zsh ;;
        5) gerer_alias ;;
        6) voir_historique ;;
        7) sauvegarder_tout ;;
        8) restaurer_config ;;
        9) voir_journal ;;
        0) menu_principal; return ;;
    esac
    menu_parametres
}

changer_theme() {
    clear
    echo -e "${W}🎨 CHOISIR UN THÈME${NC}\n"
    echo -e "  ${G}1)${NC} \033[0;36mArch Linux\033[0m  — Cyan / Bleu"
    echo -e "  ${G}2)${NC} \033[0;32mMatrix / Kali\033[0m — Vert vif"
    echo -e "  ${G}3)${NC} \033[0;31mHacker Red\033[0m — Rouge"
    echo -e "  ${G}4)${NC} \033[0;35mDracula\033[0m — Violet / Magenta"
    echo -e "  ${G}5)${NC} \033[0;34mNord\033[0m — Bleu foncé"
    echo ""
    echo -ne "${C}Choix (0=annuler) : ${NC}"; read -r t
    local pseudo="${PSEUDO_NAME:-Shadow}"
    case $t in
        1)
            cat > "$THEME_FILE" << EOF
PSEUDO_NAME="$pseudo"
THEME_NAME="Arch"
ACCENT='\\033[0;36m'
ACCENT2='\\033[0;34m'
SUCCESS='\\033[0;32m'
WARN='\\033[1;33m'
DANGER='\\033[0;31m'
BOLD='\\033[1;37m'
DIM='\\033[0;37m'
EOF
            ;;
        2)
            cat > "$THEME_FILE" << EOF
PSEUDO_NAME="$pseudo"
THEME_NAME="Matrix"
ACCENT='\\033[0;32m'
ACCENT2='\\033[1;32m'
SUCCESS='\\033[0;32m'
WARN='\\033[1;33m'
DANGER='\\033[0;31m'
BOLD='\\033[1;37m'
DIM='\\033[0;37m'
EOF
            ;;
        3)
            cat > "$THEME_FILE" << EOF
PSEUDO_NAME="$pseudo"
THEME_NAME="Hacker"
ACCENT='\\033[0;31m'
ACCENT2='\\033[1;31m'
SUCCESS='\\033[0;32m'
WARN='\\033[1;33m'
DANGER='\\033[0;31m'
BOLD='\\033[1;37m'
DIM='\\033[0;37m'
EOF
            ;;
        4)
            cat > "$THEME_FILE" << EOF
PSEUDO_NAME="$pseudo"
THEME_NAME="Dracula"
ACCENT='\\033[0;35m'
ACCENT2='\\033[1;35m'
SUCCESS='\\033[0;32m'
WARN='\\033[1;33m'
DANGER='\\033[0;31m'
BOLD='\\033[1;37m'
DIM='\\033[0;37m'
EOF
            ;;
        5)
            cat > "$THEME_FILE" << EOF
PSEUDO_NAME="$pseudo"
THEME_NAME="Nord"
ACCENT='\\033[0;34m'
ACCENT2='\\033[1;34m'
SUCCESS='\\033[0;32m'
WARN='\\033[1;33m'
DANGER='\\033[0;31m'
BOLD='\\033[1;37m'
DIM='\\033[0;37m'
EOF
            ;;
        0) return ;;
        *) return ;;
    esac
    [ "$t" != "0" ] && echo -e "${G}✅ Thème appliqué !${NC}" && sleep 1
    load_theme
}

changer_pseudo() {
    echo -ne "\n${C}Nouveau pseudo : ${NC}"; read -r pseudo
    [ -z "$pseudo" ] && return
    sed -i "s/^PSEUDO_NAME=.*/PSEUDO_NAME=\"$pseudo\"/" "$THEME_FILE"
    PSEUDO_NAME="$pseudo"
    echo -e "${G}✅ Pseudo changé en '$pseudo' !${NC}"
    sleep 1
}

installer_police() {
    clear
    echo -e "${W}🔤 INSTALLER UNE POLICE${NC}\n"
    echo -e "  ${G}1)${NC} Fira Code Nerd Font (recommandée pour les icônes)"
    echo -e "  ${G}2)${NC} Meslo LG Nerd Font (pour Oh-My-Zsh Powerline)"
    echo -e "  ${G}3)${NC} Ubuntu Mono Nerd Font"
    echo -e "  ${G}0)${NC} Annuler"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c

    mkdir -p "$HOME/.termux"
    case $c in
        1)
            echo -e "${Y}Téléchargement Fira Code...${NC}"
            curl -fLo "$HOME/.termux/font.ttf" \
                "https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/FiraCode/Regular/FiraCodeNerdFont-Regular.ttf" \
                && echo -e "${G}✅ Fira Code installée !${NC}" || echo -e "${R}❌ Erreur de téléchargement${NC}"
            ;;
        2)
            echo -e "${Y}Téléchargement Meslo...${NC}"
            curl -fLo "$HOME/.termux/font.ttf" \
                "https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Meslo/S/Regular/MesloLGSNerdFont-Regular.ttf" \
                && echo -e "${G}✅ Meslo installée !${NC}" || echo -e "${R}❌ Erreur de téléchargement${NC}"
            ;;
        3)
            echo -e "${Y}Téléchargement Ubuntu Mono...${NC}"
            curl -fLo "$HOME/.termux/font.ttf" \
                "https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/UbuntuMono/Regular/UbuntuMonoNerdFont-Regular.ttf" \
                && echo -e "${G}✅ Ubuntu Mono installée !${NC}" || echo -e "${R}❌ Erreur de téléchargement${NC}"
            ;;
        0) return ;;
    esac
    [ "$c" != "0" ] && echo -e "${B}Recharge Termux (glisser depuis la gauche → Nouveau Terminal) pour voir la police.${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
}

installer_zsh() {
    clear
    echo -e "${W}💬 INSTALLER ZSH + OH-MY-ZSH${NC}\n"
    echo -e "${Y}Cela va installer :${NC}"
    echo -e "  • ZSH (shell avancé)"
    echo -e "  • Oh-My-Zsh (framework)"
    echo -e "  • zsh-autosuggestions"
    echo -e "  • zsh-syntax-highlighting"
    echo -e "  • Powerlevel10k\n"
    echo -ne "${C}Continuer ? (o/n) : ${NC}"; read -r r
    [ "$r" != "o" ] && return

    pkg install zsh git curl -y

    echo -e "\n${Y}Installation Oh-My-Zsh...${NC}"
    export RUNZSH=no
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

    echo -e "\n${Y}Installation zsh-autosuggestions...${NC}"
    git clone https://github.com/zsh-users/zsh-autosuggestions \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" 2>/dev/null

    echo -e "\n${Y}Installation zsh-syntax-highlighting...${NC}"
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" 2>/dev/null

    echo -e "\n${Y}Installation Powerlevel10k...${NC}"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" 2>/dev/null

    if [ -f "$HOME/.zshrc" ]; then
        sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$HOME/.zshrc"
        sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"
        echo -e "\n# Mon env Termux\nbash ~/mon_env_termux.sh" >> "$HOME/.zshrc"
    fi

    echo -e "\n${G}✅ ZSH + Oh-My-Zsh + Powerlevel10k installés !${NC}"
    echo -e "${B}Lance 'zsh' pour démarrer.${NC}"
    echo -e "${Y}Entrée pour revenir...${NC}"; read
}

gerer_alias() {
    clear
    echo -e "${W}⚡ MES ALIAS${NC}\n"
    cat -n "$ALIAS_FILE"
    echo ""
    echo -e "  ${G}1)${NC} Ajouter un alias"
    echo -e "  ${G}2)${NC} Supprimer un alias"
    echo -e "  ${G}0)${NC} ← Retour"
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1)
            echo -ne "Nom (ex: mes_projets) : "; read -r anom
            echo -ne "Commande (ex: cd ~/projets && ls) : "; read -r acmd
            echo "alias $anom='$acmd'" >> "$ALIAS_FILE"
            source "$ALIAS_FILE"
            echo -e "${G}✅ Alias '$anom' ajouté !${NC}"; sleep 2
            ;;
        2)
            echo -ne "Numéro de ligne à supprimer : "; read -r ln
            [[ "$ln" =~ ^[0-9]+$ ]] && sed -i "${ln}d" "$ALIAS_FILE" && echo -e "${G}✅ Supprimé.${NC}" || echo -e "${R}Numéro invalide.${NC}"
            sleep 2
            ;;
    esac
}

voir_historique() {
    clear
    echo -e "${W}📜 HISTORIQUE DE COMMANDES${NC}\n"
    echo -e "${Y}Tes 30 dernières commandes :${NC}\n"
    # Lire directement le fichier d'historique pour fonctionner hors shell interactif
    tail -30 "${HISTFILE:-$HOME/.bash_history}" 2>/dev/null | cat -n || echo -e "${R}Historique non disponible.${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
}

voir_journal() {
    clear
    echo -e "${W}📋 JOURNAL DES ACTIONS${NC}\n"
    tail -40 "$LOG_FILE" 2>/dev/null || echo -e "${Y}Journal vide.${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
}

sauvegarder_tout() {
    local backup="$HOME/backup_env_$(date +%Y%m%d_%H%M).tar.gz"
    tar -czf "$backup" "$ENV_DIR" ~/.bashrc 2>/dev/null
    echo -e "${G}✅ Sauvegarde : $backup${NC}"
    echo -e "${B}Pour restaurer : tar -xzf $backup -C /${NC}"
    sleep 3
}

restaurer_config() {
    clear
    echo -e "${W}📦 RESTAURER UNE SAUVEGARDE${NC}\n"
    ls "$HOME"/backup_env_*.tar.gz 2>/dev/null || echo -e "${Y}Aucune sauvegarde trouvée.${NC}"
    echo -ne "\nNom du fichier (Entrée pour annuler) : "; read -r f
    [ -z "$f" ] && return
    [ -f "$f" ] && tar -xzf "$f" -C / && echo -e "${G}✅ Restauré !${NC}" || echo -e "${R}❌ Fichier introuvable${NC}"
    sleep 2
}

# ═══════════════════════════════════════════════════════════
#                    POINT D'ENTRÉE
# ═══════════════════════════════════════════════════════════
init_env
load_theme
menu_principal
