#!/data/data/com.termux/files/usr/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║        MON ENVIRONNEMENT TERMUX v5.0 — Shadow               ║
# ║  Projets | Outils | Pentest | Code | SSH | TOR | Réseau     ║
# ║  Extensions | Wordlists | Scripts | Recherche globale        ║
# ╚══════════════════════════════════════════════════════════════╝

# ─── CHEMINS ─────────────────────────────────────────────────────
ENV_DIR="$HOME/.mon_env"
PROJETS_FILE="$ENV_DIR/projets.conf"
OUTILS_FILE="$ENV_DIR/outils.conf"
PENTEST_FILE="$ENV_DIR/pentest.conf"
ALIAS_FILE="$ENV_DIR/mes_alias.sh"
SSH_FILE="$ENV_DIR/ssh_hosts.conf"
THEME_FILE="$ENV_DIR/theme.conf"
NOTES_FILE="$ENV_DIR/notes.conf"
LOG_FILE="$ENV_DIR/historique.log"
SCRIPTS_FILE="$ENV_DIR/scripts.conf"
WORDLISTS_DIR="$ENV_DIR/wordlists"

# ─── COULEURS ────────────────────────────────────────────────────
load_theme() {
    ACCENT='\033[0;36m'
    ACCENT2='\033[0;34m'
    SUCCESS='\033[0;32m'
    WARN='\033[1;33m'
    DANGER='\033[0;31m'
    BOLD='\033[1;37m'
    DIM='\033[0;37m'
    NC='\033[0m'
    [ -f "$THEME_FILE" ] && source "$THEME_FILE"
    R="$DANGER"; G="$SUCCESS"; Y="$WARN"; B="$ACCENT2"; C="$ACCENT"; M='\033[0;35m'; W="$BOLD"
}

# ─── LOGGER ──────────────────────────────────────────────────────
log_action() {
    echo "[$(date '+%d/%m/%Y %H:%M')] $1" >> "$LOG_FILE"
}

# ─── QUITTER PROPREMENT ──────────────────────────────────────────
quitter_proprement() {
    echo -e "\n${G}╔══════════════════════════════════╗${NC}"
    echo -e "${G}║  À bientôt, ${PSEUDO_NAME:-Shadow} ! 👋       ║${NC}"
    echo -e "${G}╚══════════════════════════════════╝${NC}\n"
    tput cnorm 2>/dev/null
    stty sane 2>/dev/null
    exit 0
}
trap quitter_proprement INT TERM

# ═══════════════════════════════════════════════════════════════
#                    BANNER NEOFETCH STYLE
# ═══════════════════════════════════════════════════════════════
show_banner() {
    local PSEUDO="${PSEUDO_NAME:-Shadow}"
    local ram_used ram_total storage uptime_s nb_proj nb_outils nb_notes nb_scripts
    ram_used=$(free -m 2>/dev/null | awk 'NR==2{print $3}')
    ram_total=$(free -m 2>/dev/null | awk 'NR==2{print $2}')
    storage=$(df -h "$HOME" 2>/dev/null | awk 'NR==2{print $3"/"$2}')
    uptime_s=$(uptime -p 2>/dev/null | sed 's/up //' || echo "?")
    nb_proj=$(grep -v "^#" "$PROJETS_FILE" 2>/dev/null | grep -c "|" || echo 0)
    nb_outils=$(grep -v "^#" "$OUTILS_FILE" 2>/dev/null | grep -c "|" || echo 0)
    nb_notes=$(grep -v "^#" "$NOTES_FILE" 2>/dev/null | grep -c "." || echo 0)
    nb_scripts=$(grep -v "^#" "$SCRIPTS_FILE" 2>/dev/null | grep -c "|" || echo 0)

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
    echo "                   88888P'     ${B}Projets:${NC} ${G}$nb_proj${NC}  ${B}Outils:${NC} ${G}$nb_outils${NC}  ${B}Notes:${NC} ${G}$nb_notes${NC}  ${B}Scripts:${NC} ${G}$nb_scripts${NC}"
    echo -e "${NC}"
    echo -e "  \033[41m   \033[42m   \033[43m   \033[44m   \033[45m   \033[46m   \033[47m   \033[0m"
    echo ""
}

# ═══════════════════════════════════════════════════════════════
#                    DASHBOARD
# ═══════════════════════════════════════════════════════════════
show_dashboard() {
    show_banner

    local tor_status
    pgrep -x "tor" &>/dev/null && tor_status="${G}● ACTIF${NC}" || tor_status="${R}● INACTIF${NC}"

    # IP publique
    local ip_pub
    ip_pub=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || echo "?")

    # IP locale — méthode robuste multi-fallback
    local ip_loc
    ip_loc=$(ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -1)
    [ -z "$ip_loc" ] && ip_loc=$(ip route get 1 2>/dev/null | grep -oP 'src \K\S+')
    [ -z "$ip_loc" ] && ip_loc=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$ip_loc" ] && ip_loc="?"

    local last_note
    last_note=$(grep -v "^#" "$NOTES_FILE" 2>/dev/null | tail -1 | cut -d'|' -f2)

    echo -e "  ┌─────────────────────────────────────────────┐"
    echo -e "  │  ${B}TOR    :${NC} $tor_status"
    echo -e "  │  ${B}IP pub :${NC} ${WARN}$ip_pub${NC}"
    echo -e "  │  ${B}IP loc :${NC} ${DIM}$ip_loc${NC}"
    [ -n "$last_note" ] && echo -e "  │  ${B}Note   :${NC} ${DIM}${last_note:0:40}${NC}"
    echo -e "  └─────────────────────────────────────────────┘"
    echo ""
}

# ═══════════════════════════════════════════════════════════════
#                    INITIALISATION
# ═══════════════════════════════════════════════════════════════
init_env() {
    mkdir -p "$ENV_DIR" "$WORDLISTS_DIR"

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
nmap|Réseau|pkg install nmap -y|nmap --version|Scanner réseau
tmux|Terminal|pkg install tmux -y|tmux|Multiplexeur de terminal
EOF

    [ ! -f "$PENTEST_FILE" ] && cat > "$PENTEST_FILE" << 'EOF'
# FORMAT: nom|categorie|cmd_install|cmd_lancer|exemple|description
nmap|Réseau|pkg install nmap -y|nmap|nmap -sV -p 1-1000 192.168.1.1|Scanner de ports et services réseau
sqlmap|Web|pip install sqlmap --break-system-packages|sqlmap|sqlmap -u "http://site.com/?id=1" --dbs|Test d'injection SQL automatisé
hydra|Bruteforce|pkg install hydra -y|hydra|hydra -l admin -P wordlist.txt ssh://192.168.1.1|Test de force brute multi-protocoles
nikto|Web|pkg install perl -y && cpan -i LWP::UserAgent|perl nikto.pl|perl nikto.pl -h http://monsite.com|Scanner de vulnérabilités web
metasploit|Framework|pkg install unstable-repo -y && pkg install metasploit -y|msfconsole|msfconsole|Framework pentest complet
masscan|Réseau|pkg install masscan -y|masscan|masscan -p80,443 192.168.1.0/24 --rate=1000|Scanner de ports ultra-rapide
gobuster|Web|pkg install golang -y && go install github.com/OJ/gobuster/v3@latest|gobuster|gobuster dir -u http://site.com -w wordlist.txt|Énumération de dossiers web
subfinder|Recon|pkg install golang -y && go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest|subfinder|subfinder -d example.com|Découverte de sous-domaines
EOF

    [ ! -f "$SSH_FILE" ] && echo "# FORMAT: alias|user|host|port|description" > "$SSH_FILE"
    [ ! -f "$NOTES_FILE" ] && echo "# FORMAT: date|contenu" > "$NOTES_FILE"
    [ ! -f "$LOG_FILE" ] && echo "# Journal des actions" > "$LOG_FILE"

    [ ! -f "$SCRIPTS_FILE" ] && cat > "$SCRIPTS_FILE" << 'EOF'
# FORMAT: nom|description|chemin|commande
EOF

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

# ═══════════════════════════════════════════════════════════════
#                    RECHERCHE GLOBALE
# ═══════════════════════════════════════════════════════════════
recherche_globale() {
    clear
    echo -e "${W}🔍 RECHERCHE GLOBALE${NC}\n"
    echo -ne "${C}Mot-clé à chercher : ${NC}"; read -r mot
    [ -z "$mot" ] && menu_principal && return

    local found=0
    echo -e "\n${Y}══ Projets ══${NC}"
    while IFS='|' read -r nom type chemin lancer desc date; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        if echo "$nom $desc $type" | grep -qi "$mot"; then
            echo -e "  ${G}●${NC} ${W}$nom${NC} [$type] — $desc"; found=$((found+1))
        fi
    done < "$PROJETS_FILE"

    echo -e "\n${Y}══ Outils ══${NC}"
    while IFS='|' read -r nom cat install lancer desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        if echo "$nom $desc $cat" | grep -qi "$mot"; then
            echo -e "  ${G}●${NC} ${W}$nom${NC} [$cat] — $desc"; found=$((found+1))
        fi
    done < "$OUTILS_FILE"

    echo -e "\n${Y}══ Outils Pentest ══${NC}"
    while IFS='|' read -r nom cat install lancer exemple desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        if echo "$nom $desc $cat" | grep -qi "$mot"; then
            echo -e "  ${G}●${NC} ${W}$nom${NC} [$cat] — $desc"; found=$((found+1))
        fi
    done < "$PENTEST_FILE"

    echo -e "\n${Y}══ Notes ══${NC}"
    while IFS='|' read -r date contenu; do
        [[ "$date" == \#* || -z "$date" ]] && continue
        if echo "$contenu" | grep -qi "$mot"; then
            echo -e "  ${G}●${NC} ${DIM}$date${NC} — $contenu"; found=$((found+1))
        fi
    done < "$NOTES_FILE"

    echo -e "\n${Y}══ Scripts ══${NC}"
    while IFS='|' read -r nom desc chemin cmd; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        if echo "$nom $desc" | grep -qi "$mot"; then
            echo -e "  ${G}●${NC} ${W}$nom${NC} — $desc"; found=$((found+1))
        fi
    done < "$SCRIPTS_FILE"

    echo ""
    [ $found -eq 0 ] && echo -e "${R}Aucun résultat pour \"$mot\".${NC}" || echo -e "${G}$found résultat(s) trouvé(s).${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_principal
}

# ═══════════════════════════════════════════════════════════════
#                    MENU PRINCIPAL
# ═══════════════════════════════════════════════════════════════
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
    echo -e "  ${G}e)${NC} 🧩  Extensions & Plugins"
    echo -e "  ${G}w)${NC} 📖  Wordlists"
    echo -e "  ${G}b)${NC} 📜  Mes Scripts Bash"
    echo -e "  ${G}/)${NC} 🔍  Recherche globale"
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
        e|E) menu_extensions ;;
        w|W) menu_wordlists ;;
        b|B) menu_scripts ;;
        /|r|R) recherche_globale ;;
        s|S) menu_parametres ;;
        q|Q|0) quitter_proprement ;;
        *) menu_principal ;;
    esac
}

# ═══════════════════════════════════════════════════════════════
#                    MES PROJETS
# ═══════════════════════════════════════════════════════════════
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
    nom="${nom//|/\\|}"; desc="${desc//|/\\|}"
    echo "$nom|$type|$chemin|$lancer|$desc|$date" >> "$PROJETS_FILE"
    mkdir -p "$(eval echo "$chemin")" 2>/dev/null
    log_action "Projet ajouté : $nom"
    echo -e "\n${G}✅ Projet '$nom' sauvegardé !${NC}"
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
        grep -vF "${n}|" "$PROJETS_FILE" > /tmp/_mon_env_tmp && mv /tmp/_mon_env_tmp "$PROJETS_FILE"
        log_action "Projet supprimé : $n"
        echo -e "${G}✅ '$n' supprimé.${NC}"
    fi
    sleep 1; menu_projets
}

# ═══════════════════════════════════════════════════════════════
#                    MES OUTILS
# ═══════════════════════════════════════════════════════════════
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
        local s; command -v "$cmd1" &>/dev/null && s="${G}✅${NC}" || s="${R}❌${NC}"
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

# ═══════════════════════════════════════════════════════════════
#                    PENTESTING AMÉLIORÉ
# ═══════════════════════════════════════════════════════════════
menu_pentest() {
    clear
    echo -e "${R}${W}🔐 PENTESTING${NC}"
    echo -e "${Y}⚠️  Usage éthique uniquement — tes propres systèmes !${NC}\n"
    echo -e "  ${G}1)${NC} Voir mes outils pentest (statut installé)"
    echo -e "  ${G}2)${NC} Installer un outil pentest"
    echo -e "  ${G}3)${NC} Fiche de lancement & exemples"
    echo -e "  ${G}4)${NC} Lancer un outil directement"
    echo -e "  ${G}5)${NC} Ajouter un outil pentest"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1) voir_pentest ;;
        2) installer_pentest ;;
        3) guide_pentest ;;
        4) lancer_pentest ;;
        5) ajouter_pentest ;;
        0) menu_principal ;;
        *) menu_pentest ;;
    esac
}

voir_pentest() {
    clear
    echo -e "${R}${W}🔐 MES OUTILS PENTEST${NC}\n"
    while IFS='|' read -r nom cat install lancer exemple desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        local cmd1; cmd1=$(echo "$lancer" | awk '{print $1}')
        local s; command -v "$cmd1" &>/dev/null && s="${G}✅ Installé${NC}" || s="${R}❌ Non installé${NC}"
        echo -e "  $s — ${W}$nom${NC} ${DIM}[$cat]${NC}"
        echo -e "   ${B}Desc    :${NC} $desc"
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
    declare -a noms installs cats
    while IFS='|' read -r nom cat install lancer exemple desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        local cmd1; cmd1=$(echo "$lancer" | awk '{print $1}')
        local s; command -v "$cmd1" &>/dev/null && s="${G}✅${NC}" || s="${R}❌${NC}"
        echo -e "  ${G}$i)${NC} $s ${W}$nom${NC} ${DIM}[$cat]${NC} — $desc"
        noms+=("$nom"); installs+=("$install"); cats+=("$cat")
        i=$((i+1))
    done < "$PENTEST_FILE"
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_pentest && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local idx=$((num-1))
        echo -e "\n${Y}Installation de ${noms[$idx]} [${cats[$idx]}]...${NC}\n"
        bash -c "${installs[$idx]}" && \
            echo -e "\n${G}✅ ${noms[$idx]} installé avec succès !${NC}" || \
            echo -e "\n${R}❌ Erreur lors de l'installation${NC}"
        log_action "Pentest installé : ${noms[$idx]}"
    fi
    echo -e "${Y}Entrée pour revenir...${NC}"; read
    menu_pentest
}

guide_pentest() {
    clear
    echo -e "${R}${W}📖 FICHES DE LANCEMENT${NC}\n"
    local i=1
    declare -a noms
    while IFS='|' read -r nom cat install lancer exemple desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        local cmd1; cmd1=$(echo "$lancer" | awk '{print $1}')
        local s; command -v "$cmd1" &>/dev/null && s="${G}✅${NC}" || s="${R}❌${NC}"
        echo -e "  ${G}$i)${NC} $s ${W}$nom${NC} ${DIM}[$cat]${NC}"
        noms+=("$nom"); i=$((i+1))
    done < "$PENTEST_FILE"
    echo -ne "\n${C}Numéro pour la fiche (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_pentest && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local target="${noms[$((num-1))]}"
        while IFS='|' read -r nom cat install lancer exemple desc; do
            [[ "$nom" != "$target" ]] && continue
            clear
            echo -e "${R}${W}╔══════════════════════════════════════╗${NC}"
            echo -e "${R}${W}║  📖 FICHE : $nom${NC}"
            echo -e "${R}${W}╚══════════════════════════════════════╝${NC}\n"
            echo -e "${B}Catégorie    :${NC} $cat"
            echo -e "${B}Description  :${NC}\n  $desc\n"
            echo -e "${B}Installation :${NC}\n  ${Y}$install${NC}\n"
            echo -e "${B}Commande     :${NC}\n  ${G}$lancer${NC}\n"
            echo -e "${B}Exemple réel :${NC}\n  ${C}$exemple${NC}\n"
            echo -e "${R}⚠️  Utilise uniquement sur tes propres systèmes !${NC}"
        done < "$PENTEST_FILE"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_pentest
}

lancer_pentest() {
    clear
    echo -e "${R}${W}⚡ LANCER UN OUTIL PENTEST${NC}\n"
    local i=1
    declare -a noms lancers
    while IFS='|' read -r nom cat install lancer exemple desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        local cmd1; cmd1=$(echo "$lancer" | awk '{print $1}')
        if command -v "$cmd1" &>/dev/null; then
            echo -e "  ${G}$i)${NC} ${W}$nom${NC} — ${DIM}$lancer${NC}"
            noms+=("$nom"); lancers+=("$lancer"); i=$((i+1))
        fi
    done < "$PENTEST_FILE"
    [ ${#noms[@]} -eq 0 ] && echo -e "${R}Aucun outil pentest installé. Va dans 'Installer'.${NC}" && sleep 2 && menu_pentest && return
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_pentest && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local idx=$((num-1))
        echo -e "\n${Y}Lancement de ${noms[$idx]}...${NC}"
        echo -ne "${C}Arguments supplémentaires (Entrée pour aucun) : ${NC}"; read -r args
        log_action "Pentest lancé : ${noms[$idx]}"
        bash -c "${lancers[$idx]} $args"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_pentest
}

ajouter_pentest() {
    clear
    echo -e "${C}${W}➕ AJOUTER OUTIL PENTEST${NC}\n"
    echo -ne "Nom : "; read -r nom
    echo -ne "Catégorie (Réseau/Web/Bruteforce/Recon/Framework) : "; read -r cat
    echo -ne "Commande d'installation : "; read -r install
    echo -ne "Commande pour lancer : "; read -r lancer
    echo -ne "Exemple d'utilisation : "; read -r exemple
    echo -ne "Description : "; read -r desc
    echo "$nom|$cat|$install|$lancer|$exemple|$desc" >> "$PENTEST_FILE"
    echo -e "\n${G}✅ '$nom' ajouté !${NC}"
    sleep 2; menu_pentest
}

# ═══════════════════════════════════════════════════════════════
#                    CODAGE
# ═══════════════════════════════════════════════════════════════
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

# ═══════════════════════════════════════════════════════════════
#                    SYSTÈME
# ═══════════════════════════════════════════════════════════════
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

# ═══════════════════════════════════════════════════════════════
#                    TOR / RÉSEAU ONION
# ═══════════════════════════════════════════════════════════════
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
    echo -ne "\n${C}Commande à lancer via TOR : ${NC}"; read -r cmd
    local pc_cmd; command -v proxychains4 &>/dev/null && pc_cmd="proxychains4" || pc_cmd="proxychains"
    echo -e "\n${Y}Lancement via $pc_cmd...${NC}\n"
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

# ═══════════════════════════════════════════════════════════════
#                    OUTILS RÉSEAU AMÉLIORÉS
# ═══════════════════════════════════════════════════════════════
menu_reseau() {
    clear
    echo -e "${B}${W}🌐 OUTILS RÉSEAU${NC}\n"
    echo -e "  ${G}1)${NC} Voir mes IPs (locale + publique)"
    echo -e "  ${G}2)${NC} Scanner les appareils du réseau WiFi"
    echo -e "  ${G}3)${NC} Tester la vitesse de connexion"
    echo -e "  ${G}4)${NC} Ping une adresse"
    echo -e "  ${G}5)${NC} Traceroute"
    echo -e "  ${G}6)${NC} DNS lookup"
    echo -e "  ${G}7)${NC} Infos sur une IP publique (geo/whois)"
    echo -e "  ${G}8)${NC} Écouter sur un port (netcat)"
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
        8) reseau_netcat ;;
        0) menu_principal ;;
        *) menu_reseau ;;
    esac
}

reseau_mes_ips() {
    clear
    echo -e "${B}${W}📡 MES IPs${NC}\n"

    # IP locale — robuste
    local ip_loc
    ip_loc=$(ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -1)
    [ -z "$ip_loc" ] && ip_loc=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$ip_loc" ] && ip_loc="indisponible"

    echo -e "${W}IP locale    :${NC} ${G}$ip_loc${NC}"
    echo -ne "${W}IP publique  :${NC} "
    curl -s --max-time 5 https://api.ipify.org 2>/dev/null && echo "" || echo "?"
    echo -ne "${W}Interface    :${NC} "
    ip route 2>/dev/null | grep "^default" | awk '{print $5}' || echo "?"
    echo -ne "${W}Passerelle   :${NC} "
    ip route 2>/dev/null | grep "^default" | awk '{print $3}' || echo "?"
    echo -ne "${W}Masque       :${NC} "
    ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | grep -v '^127\.' | head -1 || echo "?"
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
        echo -e "${Y}Entrée pour revenir...${NC}"; read
        menu_reseau; return
    fi

    # Détecter la passerelle et le subnet
    local gateway
    gateway=$(ip route 2>/dev/null | grep "^default" | awk '{print $3}' | head -1)
    local subnet
    subnet=$(ip route 2>/dev/null | grep -v "^default" | grep "/" | head -1 | awk '{print $1}')
    [ -z "$subnet" ] && subnet=$(echo "$gateway" | sed 's/\.[0-9]*$/.0\/24/')

    echo -e "${Y}Réseau cible : ${W}$subnet${NC}"
    echo -e "${Y}Scan en cours (peut prendre 30-60s)...${NC}\n"

    # Scan avec infos IP + MAC + hostname
    local scan_result
    scan_result=$(nmap -sn --host-timeout 5s "$subnet" 2>/dev/null)

    # Affichage formaté
    local count=0
    local current_ip="" current_mac="" current_host=""
    while IFS= read -r line; do
        if echo "$line" | grep -q "Nmap scan report"; then
            # Afficher l'appareil précédent si on en a un
            if [ -n "$current_ip" ]; then
                count=$((count+1))
                echo -e "  ${G}[$count]${NC} ${W}$current_ip${NC}"
                [ -n "$current_host" ] && echo -e "       ${B}Hostname :${NC} $current_host"
                [ -n "$current_mac" ] && echo -e "       ${B}MAC      :${NC} $current_mac"
                echo ""
            fi
            current_ip=$(echo "$line" | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1)
            current_host=$(echo "$line" | grep -oP '(?<=for )[^\(]+' | sed 's/ $//' || echo "")
            current_mac=""
        elif echo "$line" | grep -qi "mac address"; then
            current_mac=$(echo "$line" | grep -oP '([0-9A-F]{2}[:]){5}[0-9A-F]{2}' | head -1)
            local vendor; vendor=$(echo "$line" | grep -oP '\(.*\)' | tr -d '()')
            [ -n "$vendor" ] && current_mac="$current_mac ${DIM}($vendor)${NC}"
        fi
    done <<< "$scan_result"

    # Dernier appareil
    if [ -n "$current_ip" ]; then
        count=$((count+1))
        echo -e "  ${G}[$count]${NC} ${W}$current_ip${NC}"
        [ -n "$current_host" ] && echo -e "       ${B}Hostname :${NC} $current_host"
        [ -n "$current_mac" ] && echo -e "       ${B}MAC      :${NC} $current_mac"
        echo ""
    fi

    echo -e "  ${DIM}──────────────────────────────────${NC}"
    echo -e "  ${G}$count appareil(s) trouvé(s) sur $subnet${NC}\n"
    echo -e "${Y}Entrée pour revenir...${NC}"; read
    menu_reseau
}

reseau_speedtest() {
    clear
    echo -e "${B}${W}⚡ TEST DE VITESSE${NC}\n"
    if command -v curl &>/dev/null; then
        echo -e "${Y}Test de téléchargement (10MB)...${NC}"
        local speed
        speed=$(curl -s --max-time 20 -o /dev/null -w "%{speed_download}" http://speedtest.tele2.net/10MB.zip 2>/dev/null)
        if [ -n "$speed" ] && [ "$speed" != "0" ]; then
            local speed_mb; speed_mb=$(echo "$speed" | awk '{printf "%.2f", $1/1048576}')
            local speed_kb; speed_kb=$(echo "$speed" | awk '{printf "%.0f", $1/1024}')
            echo -e "${G}✅ Vitesse : ${speed_mb} MB/s (${speed_kb} KB/s)${NC}"
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
        grep -E '"ip"|"city"|"region"|"country"|"org"|"timezone"' | \
        sed 's/[",]//g' | sed 's/^  /  /' || echo -e "${R}❌ Impossible de récupérer les infos${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_reseau
}

reseau_netcat() {
    clear
    echo -e "${B}${W}🔌 ÉCOUTER SUR UN PORT (netcat)${NC}\n"
    if ! command -v nc &>/dev/null && ! command -v ncat &>/dev/null; then
        echo -e "${R}❌ netcat non installé.${NC}"
        echo -ne "Installer ? (o/n) : "; read -r r
        [ "$r" = "o" ] && pkg install netcat-openbsd -y
        echo -e "${Y}Entrée pour revenir...${NC}"; read
        menu_reseau; return
    fi
    echo -ne "${C}Port à écouter (ex: 4444) : ${NC}"; read -r port
    [[ ! "$port" =~ ^[0-9]+$ ]] && echo -e "${R}Port invalide.${NC}" && sleep 1 && menu_reseau && return
    echo -e "\n${Y}Écoute sur le port $port (Ctrl+C pour arrêter)...${NC}\n"
    local nc_cmd; command -v ncat &>/dev/null && nc_cmd="ncat" || nc_cmd="nc"
    $nc_cmd -lvp "$port"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_reseau
}

# ═══════════════════════════════════════════════════════════════
#                    GESTIONNAIRE SSH
# ═══════════════════════════════════════════════════════════════
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
        echo -e "${B}Voici ta clé publique :${NC}\n"
        cat "$HOME/.ssh/id_rsa.pub"
        echo -e "\n${B}Pour l'ajouter sur un serveur :${NC}"
        echo -e "${G}ssh-copy-id -p PORT user@host${NC}"
    else
        echo -e "${R}❌ Aucune clé SSH trouvée. Génère-en une d'abord (option 5).${NC}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_ssh
}

# ═══════════════════════════════════════════════════════════════
#                    NOTES RAPIDES
# ═══════════════════════════════════════════════════════════════
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
            echo -e "  ${Y}$date${NC} — $contenu"; found=$((found+1))
        fi
    done < "$NOTES_FILE"
    [ $found -eq 0 ] && echo -e "${Y}Aucun résultat.${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_notes
}

# ═══════════════════════════════════════════════════════════════
#                    EXTENSIONS & PLUGINS
# ═══════════════════════════════════════════════════════════════
menu_extensions() {
    clear
    echo -e "${M}${W}🧩 EXTENSIONS & PLUGINS${NC}\n"
    echo -e "  ${G}1)${NC} 🎨 Thèmes Termux (termux-style)"
    echo -e "  ${G}2)${NC} 💬 ZSH + Oh-My-Zsh + Powerlevel10k"
    echo -e "  ${G}3)${NC} 🔤 Polices Nerd Fonts"
    echo -e "  ${G}4)${NC} 📦 Paquets communautaires utiles"
    echo -e "  ${G}5)${NC} 🐍 Outils Python (pip essentials)"
    echo -e "  ${G}6)${NC} 🌐 Outils Go (gobuster, subfinder...)"
    echo -e "  ${G}7)${NC} 🔧 tmux + config personnalisée"
    echo -e "  ${G}8)${NC} ⬆️  Mettre à jour ce script depuis GitHub"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1) ext_themes ;;
        2) ext_zsh ;;
        3) ext_fonts ;;
        4) ext_paquets_utiles ;;
        5) ext_python_pip ;;
        6) ext_go_tools ;;
        7) ext_tmux ;;
        8) ext_update_script ;;
        0) menu_principal ;;
        *) menu_extensions ;;
    esac
}

ext_themes() {
    clear
    echo -e "${M}${W}🎨 THÈMES TERMUX${NC}\n"
    echo -e "${B}termux-style${NC} — Change couleurs + police en une commande\n"
    echo -e "  ${G}1)${NC} Installer termux-style (depuis GitHub officiel)"
    echo -e "  ${G}2)${NC} Voir les thèmes dispo (liste)"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1)
            echo -e "\n${Y}Clonage de termux-style...${NC}"
            pkg install git -y &>/dev/null
            git clone https://github.com/adi1090x/termux-style "$HOME/.termux-style" 2>/dev/null || \
                (cd "$HOME/.termux-style" && git pull 2>/dev/null)
            if [ -f "$HOME/.termux-style/setup.sh" ]; then
                bash "$HOME/.termux-style/setup.sh"
                echo -e "${G}✅ termux-style installé !${NC}"
            else
                echo -e "${G}✅ Téléchargé dans ~/.termux-style${NC}"
                echo -e "${B}Lance : bash ~/.termux-style/setup.sh${NC}"
            fi
            ;;
        2)
            echo -e "\n${Y}Thèmes disponibles dans termux-style :${NC}"
            if [ -d "$HOME/.termux-style/themes" ]; then
                ls "$HOME/.termux-style/themes/" | sed 's/\.conf//' | column
            else
                echo -e "${R}termux-style non installé (option 1 d'abord).${NC}"
                echo -e "\n${B}Exemples de thèmes : Dracula, Nord, Monokai, Solarized, Gruvbox, One-Dark...${NC}"
            fi
            ;;
        0) menu_extensions; return ;;
    esac
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_extensions
}

ext_zsh() {
    clear
    echo -e "${M}${W}💬 ZSH + OH-MY-ZSH + POWERLEVEL10K${NC}\n"
    echo -e "${Y}Cela va installer :${NC}"
    echo -e "  • ZSH (shell avancé)"
    echo -e "  • Oh-My-Zsh (framework)"
    echo -e "  • zsh-autosuggestions (depuis github.com/zsh-users)"
    echo -e "  • zsh-syntax-highlighting (depuis github.com/zsh-users)"
    echo -e "  • Powerlevel10k (depuis github.com/romkatv)\n"
    echo -ne "${C}Continuer ? (o/n) : ${NC}"; read -r r
    [ "$r" != "o" ] && menu_extensions && return

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
        grep -qF "mon_env_termux" "$HOME/.zshrc" || echo -e "\n# Mon env Termux\nbash ~/mon_env_termux.sh" >> "$HOME/.zshrc"
    fi

    echo -e "\n${G}✅ ZSH + Oh-My-Zsh + Powerlevel10k installés !${NC}"
    echo -e "${B}Lance 'zsh' pour démarrer.${NC}"
    echo -e "${Y}Entrée pour revenir...${NC}"; read
    menu_extensions
}

ext_fonts() {
    clear
    echo -e "${M}${W}🔤 INSTALLER UNE POLICE NERD FONT${NC}\n"
    echo -e "  ${G}1)${NC} Fira Code Nerd Font (recommandée)"
    echo -e "  ${G}2)${NC} Meslo LG Nerd Font (pour Powerlevel10k)"
    echo -e "  ${G}3)${NC} Ubuntu Mono Nerd Font"
    echo -e "  ${G}4)${NC} JetBrains Mono Nerd Font"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c

    mkdir -p "$HOME/.termux"
    local base_url="https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts"
    local font_url="" font_name=""

    case $c in
        1) font_url="$base_url/FiraCode/Regular/FiraCodeNerdFont-Regular.ttf"; font_name="Fira Code" ;;
        2) font_url="$base_url/Meslo/S/Regular/MesloLGSNerdFont-Regular.ttf"; font_name="Meslo LG" ;;
        3) font_url="$base_url/UbuntuMono/Regular/UbuntuMonoNerdFont-Regular.ttf"; font_name="Ubuntu Mono" ;;
        4) font_url="$base_url/JetBrainsMono/Ligatures/Regular/JetBrainsMonoNerdFont-Regular.ttf"; font_name="JetBrains Mono" ;;
        0) menu_extensions; return ;;
        *) echo -e "${R}Choix invalide.${NC}"; sleep 1; menu_extensions; return ;;
    esac

    echo -e "\n${Y}Téléchargement $font_name...${NC}"
    curl -fLo "$HOME/.termux/font.ttf" "$font_url" && \
        echo -e "${G}✅ $font_name installée !${NC}" || \
        echo -e "${R}❌ Erreur de téléchargement${NC}"
    echo -e "${B}Recharge Termux (glisser depuis la gauche → Nouveau Terminal) pour voir la police.${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_extensions
}

ext_paquets_utiles() {
    clear
    echo -e "${M}${W}📦 PAQUETS COMMUNAUTAIRES UTILES${NC}\n"
    echo -e "${Y}Paquets à installer via pkg :${NC}\n"

    declare -A paquets=(
        ["fd"]="Recherche de fichiers ultra-rapide (remplace find)"
        ["bat"]="cat amélioré avec coloration syntaxique"
        ["exa"]="ls amélioré avec couleurs et icônes"
        ["ripgrep"]="grep ultra-rapide (rg)"
        ["jq"]="Parser JSON en ligne de commande"
        ["fzf"]="Fuzzy finder interactif"
        ["neovim"]="Vim next-gen (nvim)"
        ["tree"]="Afficher l'arborescence des dossiers"
        ["sl"]="Easter egg : train dans le terminal"
        ["cmatrix"]="Effet Matrix dans le terminal"
    )

    local i=1
    declare -a keys
    for k in "${!paquets[@]}"; do
        local s; command -v "$k" &>/dev/null && s="${G}✅${NC}" || s="${R}❌${NC}"
        echo -e "  ${G}$i)${NC} $s ${W}$k${NC} — ${paquets[$k]}"
        keys+=("$k"); i=$((i+1))
    done

    echo -e "\n  ${G}a)${NC} Installer TOUS"
    echo -e "  ${G}0)${NC} ← Retour"
    echo -ne "\n${C}Choix : ${NC}"; read -r c

    if [ "$c" = "a" ] || [ "$c" = "A" ]; then
        for k in "${!paquets[@]}"; do
            echo -ne "${Y}→ $k ... ${NC}"
            pkg install "$k" -y &>/dev/null && echo -e "${G}✅${NC}" || echo -e "${R}❌${NC}"
        done
        echo -e "${G}\nInstallation terminée !${NC}"
    elif [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -ge 1 ] && [ "$c" -lt "$i" ]; then
        local pkg_name="${keys[$((c-1))]}"
        echo -e "\n${Y}Installation de $pkg_name...${NC}"
        pkg install "$pkg_name" -y && echo -e "${G}✅ $pkg_name installé !${NC}" || echo -e "${R}❌ Erreur${NC}"
    fi

    [ "$c" != "0" ] && echo -e "\n${Y}Entrée pour revenir...${NC}" && read
    menu_extensions
}

ext_python_pip() {
    clear
    echo -e "${M}${W}🐍 OUTILS PYTHON (pip)${NC}\n"
    echo -e "${Y}Paquets pip essentiels :${NC}\n"

    local tools=(
        "requests:Requêtes HTTP simplifiées"
        "beautifulsoup4:Parser HTML/XML (web scraping)"
        "scapy:Manipulation de paquets réseau"
        "paramiko:SSH en Python"
        "pwntools:CTF et exploit development"
        "flask:Micro-framework web"
        "httpx:HTTP client moderne"
        "rich:Terminal beau avec couleurs et tables"
    )

    local i=1
    declare -a pkgs
    for tool in "${tools[@]}"; do
        local name="${tool%%:*}"
        local desc="${tool##*:}"
        local s; python3 -c "import ${name//-/_}" &>/dev/null && s="${G}✅${NC}" || s="${R}❌${NC}"
        echo -e "  ${G}$i)${NC} $s ${W}$name${NC} — $desc"
        pkgs+=("$name"); i=$((i+1))
    done

    echo -e "\n  ${G}a)${NC} Installer TOUS"
    echo -e "  ${G}0)${NC} ← Retour"
    echo -ne "\n${C}Choix : ${NC}"; read -r c

    pkg install python -y &>/dev/null

    if [ "$c" = "a" ] || [ "$c" = "A" ]; then
        for p in "${pkgs[@]}"; do
            echo -ne "${Y}→ $p ... ${NC}"
            pip install "$p" --break-system-packages -q && echo -e "${G}✅${NC}" || echo -e "${R}❌${NC}"
        done
    elif [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -ge 1 ] && [ "$c" -lt "$i" ]; then
        local p="${pkgs[$((c-1))]}"
        echo -e "\n${Y}Installation de $p...${NC}"
        pip install "$p" --break-system-packages && echo -e "${G}✅ $p installé !${NC}" || echo -e "${R}❌ Erreur${NC}"
    fi

    [ "$c" != "0" ] && echo -e "\n${Y}Entrée pour revenir...${NC}" && read
    menu_extensions
}

ext_go_tools() {
    clear
    echo -e "${M}${W}🌐 OUTILS GO (pentest & réseau)${NC}\n"
    echo -e "${Y}Nécessite Go installé (pkg install golang)${NC}\n"

    local tools=(
        "gobuster:github.com/OJ/gobuster/v3@latest:Énumération de dossiers/vhosts web"
        "subfinder:github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest:Découverte de sous-domaines"
        "httpx:github.com/projectdiscovery/httpx/cmd/httpx@latest:Probe HTTP rapide"
        "nuclei:github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest:Scanner de vulnérabilités basé sur templates"
        "ffuf:github.com/ffuf/ffuf/v2@latest:Fuzzer web ultra-rapide"
    )

    local i=1
    declare -a names urls
    for tool in "${tools[@]}"; do
        IFS=':' read -r name url desc <<< "$tool"
        local s; command -v "$name" &>/dev/null && s="${G}✅${NC}" || s="${R}❌${NC}"
        echo -e "  ${G}$i)${NC} $s ${W}$name${NC} — $desc"
        names+=("$name"); urls+=("$url"); i=$((i+1))
    done

    echo -e "\n  ${G}a)${NC} Installer TOUS"
    echo -e "  ${G}0)${NC} ← Retour"
    echo -ne "\n${C}Choix : ${NC}"; read -r c

    install_go_tool() {
        local name="$1" url="$2"
        echo -e "\n${Y}Installation de $name...${NC}"
        if ! command -v go &>/dev/null; then
            echo -e "${Y}Installation de Go...${NC}"
            pkg install golang -y
        fi
        go install "$url" 2>&1 && echo -e "${G}✅ $name installé !${NC}" || echo -e "${R}❌ Erreur${NC}"
    }

    if [ "$c" = "a" ] || [ "$c" = "A" ]; then
        pkg install golang -y &>/dev/null
        for idx in "${!names[@]}"; do
            install_go_tool "${names[$idx]}" "${urls[$idx]}"
        done
    elif [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -ge 1 ] && [ "$c" -lt "$i" ]; then
        install_go_tool "${names[$((c-1))]}" "${urls[$((c-1))]}"
    fi

    [ "$c" != "0" ] && echo -e "\n${Y}Entrée pour revenir...${NC}" && read
    menu_extensions
}

ext_tmux() {
    clear
    echo -e "${M}${W}🔧 TMUX + CONFIG${NC}\n"
    echo -e "${Y}tmux = multiplexeur de terminal (plusieurs fenêtres dans un terminal)${NC}\n"
    echo -e "  ${G}1)${NC} Installer tmux"
    echo -e "  ${G}2)${NC} Créer une config tmux confortable"
    echo -e "  ${G}3)${NC} Raccourcis tmux rapides"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1)
            pkg install tmux -y && echo -e "${G}✅ tmux installé !${NC}" || echo -e "${R}❌ Erreur${NC}"
            ;;
        2)
            cat > "$HOME/.tmux.conf" << 'EOF'
# Prefix : Ctrl+a (plus ergonomique que Ctrl+b)
unbind C-b
set-option -g prefix C-a
bind-key C-a send-prefix

# Découpe écran intuitive
bind | split-window -h
bind - split-window -v

# Navigation entre panneaux avec Alt+flèches
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Recharger config
bind r source-file ~/.tmux.conf \; display "Config rechargée!"

# Couleurs
set -g default-terminal "screen-256color"
set -g status-bg colour235
set -g status-fg white
set -g status-left '#[fg=green]#H '
set -g status-right '#[fg=yellow]%d/%m/%Y %H:%M'

# Numéroter à partir de 1
set -g base-index 1
setw -g pane-base-index 1

# Historique plus long
set -g history-limit 10000
EOF
            echo -e "${G}✅ ~/.tmux.conf créé !${NC}"
            echo -e "${B}Lance 'tmux' et Ctrl+a + r pour recharger.${NC}"
            ;;
        3)
            clear
            echo -e "${W}📋 RACCOURCIS TMUX${NC}\n"
            echo -e "  ${C}Ctrl+a + |${NC}  → Découper verticalement"
            echo -e "  ${C}Ctrl+a + -${NC}  → Découper horizontalement"
            echo -e "  ${C}Alt + ←↑↓→${NC} → Naviguer entre panneaux"
            echo -e "  ${C}Ctrl+a + c${NC}  → Nouvelle fenêtre"
            echo -e "  ${C}Ctrl+a + n${NC}  → Fenêtre suivante"
            echo -e "  ${C}Ctrl+a + d${NC}  → Détacher (tmux reste actif)"
            echo -e "  ${C}tmux attach${NC} → Re-attacher à tmux"
            echo -e "  ${C}Ctrl+a + r${NC}  → Recharger la config"
            ;;
        0) menu_extensions; return ;;
    esac
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_extensions
}

ext_update_script() {
    clear
    echo -e "${M}${W}⬆️  MISE À JOUR DU SCRIPT${NC}\n"
    echo -e "${Y}Cette option télécharge la dernière version depuis GitHub.${NC}"
    echo -e "${B}URL : https://github.com/TON_USER/mon_env_termux${NC}\n"
    echo -e "${R}⚠️  Configure ton URL GitHub dans le script avant d'utiliser cette option.${NC}"
    echo ""

    # Ici tu peux remplacer l'URL par ton propre repo GitHub
    local GITHUB_RAW_URL="https://raw.githubusercontent.com/TON_USER/TON_REPO/main/mon_env_termux.sh"

    echo -ne "${C}URL raw GitHub (Entrée = garder celle du script) : ${NC}"; read -r url
    [ -n "$url" ] && GITHUB_RAW_URL="$url"

    local backup="$HOME/mon_env_termux_backup_$(date +%Y%m%d_%H%M).sh"
    cp "$HOME/mon_env_termux.sh" "$backup" 2>/dev/null && \
        echo -e "${G}✅ Sauvegarde : $backup${NC}"

    echo -e "\n${Y}Téléchargement en cours...${NC}"
    if curl -fsSL "$GITHUB_RAW_URL" -o "$HOME/mon_env_termux.sh.new" 2>/dev/null; then
        mv "$HOME/mon_env_termux.sh.new" "$HOME/mon_env_termux.sh"
        chmod +x "$HOME/mon_env_termux.sh"
        echo -e "${G}✅ Script mis à jour ! Relance avec : bash ~/mon_env_termux.sh${NC}"
    else
        echo -e "${R}❌ Impossible de télécharger. Vérifie l'URL et ta connexion.${NC}"
        rm -f "$HOME/mon_env_termux.sh.new"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_extensions
}

# ═══════════════════════════════════════════════════════════════
#                    WORDLISTS
# ═══════════════════════════════════════════════════════════════
menu_wordlists() {
    clear
    echo -e "${R}${W}📖 WORDLISTS${NC}\n"
    echo -e "${DIM}Stockées dans : $WORDLISTS_DIR${NC}\n"

    # Lister les wordlists déjà téléchargées
    local wls; wls=$(ls "$WORDLISTS_DIR" 2>/dev/null)
    if [ -n "$wls" ]; then
        echo -e "${G}Wordlists disponibles :${NC}"
        ls -lh "$WORDLISTS_DIR" | awk 'NR>1{printf "  %-30s %s\n", $9, $5}'
        echo ""
    else
        echo -e "${Y}Aucune wordlist téléchargée.${NC}\n"
    fi

    echo -e "  ${G}1)${NC} Télécharger rockyou.txt (135MB)"
    echo -e "  ${G}2)${NC} Télécharger SecLists — Common-Credentials (léger)"
    echo -e "  ${G}3)${NC} Télécharger SecLists — Discovery/Web-Content"
    echo -e "  ${G}4)${NC} Télécharger dirb wordlists (pkg)"
    echo -e "  ${G}5)${NC} Télécharger une wordlist custom (URL)"
    echo -e "  ${G}6)${NC} Voir/utiliser une wordlist"
    echo -e "  ${G}7)${NC} Supprimer une wordlist"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1) wordlist_rockyou ;;
        2) wordlist_seclists_creds ;;
        3) wordlist_seclists_web ;;
        4) wordlist_dirb ;;
        5) wordlist_custom ;;
        6) wordlist_voir ;;
        7) wordlist_supprimer ;;
        0) menu_principal ;;
        *) menu_wordlists ;;
    esac
}

wordlist_rockyou() {
    echo -e "\n${Y}Téléchargement de rockyou.txt (135MB)...${NC}"
    echo -e "${DIM}Source : github.com/brannondorsey/naive-hashcat${NC}"
    curl -fL "https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt" \
        -o "$WORDLISTS_DIR/rockyou.txt" \
        --progress-bar && \
        echo -e "${G}✅ rockyou.txt téléchargé ! ($(du -h "$WORDLISTS_DIR/rockyou.txt" | cut -f1))${NC}" || \
        echo -e "${R}❌ Erreur — essaie la version compressée :${NC}
${DIM}curl -L https://github.com/danielmiessler/SecLists/raw/master/Passwords/Leaked-Databases/rockyou.txt.tar.gz | tar -xz -C $WORDLISTS_DIR${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_wordlists
}

wordlist_seclists_creds() {
    echo -e "\n${Y}Téléchargement SecLists Common-Credentials...${NC}"
    local base="https://raw.githubusercontent.com/danielmiessler/SecLists/master/Passwords/Common-Credentials"
    for f in "10k-most-common.txt" "top-passwords-shortlist.txt" "10-million-password-list-top-1000.txt"; do
        echo -ne "${Y}→ $f ... ${NC}"
        curl -fsSL "$base/$f" -o "$WORDLISTS_DIR/$f" && echo -e "${G}✅${NC}" || echo -e "${R}❌${NC}"
    done
    echo -e "${G}✅ Téléchargé dans $WORDLISTS_DIR${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_wordlists
}

wordlist_seclists_web() {
    echo -e "\n${Y}Téléchargement SecLists Web-Content...${NC}"
    local base="https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content"
    for f in "common.txt" "big.txt" "directory-list-2.3-small.txt"; do
        echo -ne "${Y}→ $f ... ${NC}"
        curl -fsSL "$base/$f" -o "$WORDLISTS_DIR/$f" && echo -e "${G}✅${NC}" || echo -e "${R}❌${NC}"
    done
    echo -e "${G}✅ Téléchargé dans $WORDLISTS_DIR${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_wordlists
}

wordlist_dirb() {
    echo -e "\n${Y}Installation de dirb (inclut wordlists)...${NC}"
    pkg install dirb -y && \
        echo -e "${G}✅ dirb installé !${NC}\n${B}Wordlists dans : /data/data/com.termux/files/usr/share/dirb/wordlists/${NC}" || \
        echo -e "${R}❌ Erreur${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_wordlists
}

wordlist_custom() {
    echo -ne "\n${C}URL de la wordlist : ${NC}"; read -r url
    [ -z "$url" ] && menu_wordlists && return
    echo -ne "${C}Nom du fichier à sauvegarder : ${NC}"; read -r fname
    [ -z "$fname" ] && fname="custom_$(date +%Y%m%d).txt"
    echo -e "\n${Y}Téléchargement...${NC}"
    curl -fL "$url" -o "$WORDLISTS_DIR/$fname" --progress-bar && \
        echo -e "${G}✅ $fname téléchargé !${NC}" || \
        echo -e "${R}❌ Erreur de téléchargement${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_wordlists
}

wordlist_voir() {
    clear
    echo -e "${R}${W}📂 MES WORDLISTS${NC}\n"
    local i=1
    declare -a wls
    for f in "$WORDLISTS_DIR"/*; do
        [ -f "$f" ] || continue
        local size; size=$(du -h "$f" | cut -f1)
        local lines; lines=$(wc -l < "$f" 2>/dev/null)
        echo -e "  ${G}$i)${NC} ${W}$(basename "$f")${NC} ${DIM}[$size — $lines lignes]${NC}"
        wls+=("$f"); i=$((i+1))
    done
    [ ${#wls[@]} -eq 0 ] && echo -e "${Y}Aucune wordlist. Télécharge-en une !${NC}" && sleep 2 && menu_wordlists && return
    echo -ne "\n${C}Numéro pour voir (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_wordlists && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local f="${wls[$((num-1))]}"
        echo -e "\n${Y}Aperçu de $(basename "$f") (10 premières lignes) :${NC}\n"
        head -10 "$f"
        echo -e "\n${B}Chemin complet : $f${NC}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_wordlists
}

wordlist_supprimer() {
    clear
    echo -e "${R}${W}❌ SUPPRIMER UNE WORDLIST${NC}\n"
    local i=1
    declare -a wls
    for f in "$WORDLISTS_DIR"/*; do
        [ -f "$f" ] || continue
        echo -e "  ${G}$i)${NC} $(basename "$f") ${DIM}($(du -h "$f" | cut -f1))${NC}"
        wls+=("$f"); i=$((i+1))
    done
    [ ${#wls[@]} -eq 0 ] && echo -e "${Y}Aucune wordlist.${NC}" && sleep 1 && menu_wordlists && return
    echo -ne "\n${C}Numéro à supprimer (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_wordlists && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local f="${wls[$((num-1))]}"
        echo -ne "${R}Confirmer suppression de $(basename "$f") ? (o/n) : ${NC}"; read -r r
        [ "$r" = "o" ] && rm -f "$f" && echo -e "${G}✅ Supprimé.${NC}" || echo -e "${Y}Annulé.${NC}"
    fi
    sleep 1; menu_wordlists
}

# ═══════════════════════════════════════════════════════════════
#                    MES SCRIPTS BASH
# ═══════════════════════════════════════════════════════════════
menu_scripts() {
    clear
    echo -e "${Y}${W}📜 MES SCRIPTS BASH${NC}\n"
    echo -e "  ${G}1)${NC} Voir mes scripts"
    echo -e "  ${G}2)${NC} Ajouter un script existant"
    echo -e "  ${G}3)${NC} Créer un nouveau script"
    echo -e "  ${G}4)${NC} Lancer un script"
    echo -e "  ${G}5)${NC} Modifier un script (nano)"
    echo -e "  ${G}6)${NC} Supprimer un script"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1) scripts_voir ;;
        2) scripts_ajouter_existant ;;
        3) scripts_creer ;;
        4) scripts_lancer ;;
        5) scripts_modifier ;;
        6) scripts_supprimer ;;
        0) menu_principal ;;
        *) menu_scripts ;;
    esac
}

scripts_voir() {
    clear
    echo -e "${Y}${W}📜 MES SCRIPTS${NC}\n"
    local nb=0
    while IFS='|' read -r nom desc chemin cmd; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        nb=$((nb+1))
        local s; [ -f "$chemin" ] && s="${G}✅${NC}" || s="${R}❌ fichier introuvable${NC}"
        echo -e "  $s ${W}$nom${NC}"
        echo -e "     ${B}Desc    :${NC} $desc"
        echo -e "     ${B}Fichier :${NC} $chemin"
        echo -e "     ${B}Lancer  :${NC} ${G}$cmd${NC}\n"
    done < "$SCRIPTS_FILE"
    [ $nb -eq 0 ] && echo -e "${Y}Aucun script sauvegardé.${NC}\n"
    echo -e "${Y}Entrée pour revenir...${NC}"; read
    menu_scripts
}

scripts_ajouter_existant() {
    clear
    echo -e "${C}${W}➕ AJOUTER UN SCRIPT EXISTANT${NC}\n"
    echo -e "${DIM}Scripts .sh dans $HOME :${NC}"
    find "$HOME" -maxdepth 2 -name "*.sh" 2>/dev/null | grep -v ".mon_env" | head -15
    echo ""
    echo -ne "Nom du script : "; read -r nom
    echo -ne "Description : "; read -r desc
    echo -ne "Chemin complet (ex: ~/scripts/monscript.sh) : "; read -r chemin
    local chemin_reel; chemin_reel=$(eval echo "$chemin")
    echo -ne "Commande pour lancer (défaut: bash $chemin_reel) : "; read -r cmd
    [ -z "$cmd" ] && cmd="bash $chemin_reel"
    echo "$nom|$desc|$chemin_reel|$cmd" >> "$SCRIPTS_FILE"
    log_action "Script ajouté : $nom"
    echo -e "\n${G}✅ Script '$nom' ajouté !${NC}"
    sleep 2; menu_scripts
}

scripts_creer() {
    clear
    echo -e "${C}${W}✏️  CRÉER UN NOUVEAU SCRIPT${NC}\n"
    echo -ne "Nom du script (sans .sh) : "; read -r nom
    [ -z "$nom" ] && menu_scripts && return
    echo -ne "Description : "; read -r desc
    echo -ne "Dossier (défaut: ~/scripts) : "; read -r dossier
    [ -z "$dossier" ] && dossier="$HOME/scripts"
    mkdir -p "$(eval echo "$dossier")"
    local f; f="$(eval echo "$dossier")/$nom.sh"
    cat > "$f" << EOF
#!/data/data/com.termux/files/usr/bin/bash
# $nom.sh — créé le $(date +%d/%m/%Y)
# $desc

echo "Script $nom démarré !"
EOF
    chmod +x "$f"
    echo "$nom|$desc|$f|bash $f" >> "$SCRIPTS_FILE"
    log_action "Script créé : $nom"
    echo -e "${G}✅ Script créé : $f${NC}"
    echo -ne "\nOuvrir dans nano maintenant ? (o/n) : "; read -r r
    [ "$r" = "o" ] && nano "$f"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_scripts
}

scripts_lancer() {
    clear
    echo -e "${Y}${W}⚡ LANCER UN SCRIPT${NC}\n"
    local i=1
    declare -a noms cmds
    while IFS='|' read -r nom desc chemin cmd; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        local s; [ -f "$chemin" ] && s="${G}✅${NC}" || s="${R}❌${NC}"
        echo -e "  ${G}$i)${NC} $s ${W}$nom${NC} — $desc"
        noms+=("$nom"); cmds+=("$cmd"); i=$((i+1))
    done < "$SCRIPTS_FILE"
    [ ${#noms[@]} -eq 0 ] && echo -e "${Y}Aucun script.${NC}" && sleep 1 && menu_scripts && return
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_scripts && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local idx=$((num-1))
        echo -e "\n${G}Lancement : ${cmds[$idx]}${NC}\n"
        log_action "Script lancé : ${noms[$idx]}"
        bash -c "${cmds[$idx]}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_scripts
}

scripts_modifier() {
    clear
    echo -e "${Y}${W}✏️  MODIFIER UN SCRIPT${NC}\n"
    local i=1
    declare -a noms chemins
    while IFS='|' read -r nom desc chemin cmd; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        echo -e "  ${G}$i)${NC} ${W}$nom${NC} — $chemin"
        noms+=("$nom"); chemins+=("$chemin"); i=$((i+1))
    done < "$SCRIPTS_FILE"
    [ ${#noms[@]} -eq 0 ] && echo -e "${Y}Aucun script.${NC}" && sleep 1 && menu_scripts && return
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_scripts && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local f="${chemins[$((num-1))]}"
        if [ -f "$f" ]; then
            nano "$f"
        else
            echo -e "${R}❌ Fichier introuvable : $f${NC}"; sleep 2
        fi
    fi
    menu_scripts
}

scripts_supprimer() {
    clear
    echo -e "${R}${W}❌ SUPPRIMER UN SCRIPT${NC}\n"
    local i=1
    declare -a noms
    while IFS='|' read -r nom desc chemin cmd; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        echo -e "  ${G}$i)${NC} $nom ($chemin)"
        noms+=("$nom"); i=$((i+1))
    done < "$SCRIPTS_FILE"
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_scripts && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local n="${noms[$((num-1))]}"
        grep -vF "${n}|" "$SCRIPTS_FILE" > /tmp/_mon_env_tmp && mv /tmp/_mon_env_tmp "$SCRIPTS_FILE"
        log_action "Script supprimé : $n"
        echo -e "${G}✅ '$n' retiré de la liste (fichier conservé).${NC}"
    fi
    sleep 1; menu_scripts
}

# ═══════════════════════════════════════════════════════════════
#                    PARAMÈTRES
# ═══════════════════════════════════════════════════════════════
menu_parametres() {
    clear
    echo -e "${W}⚙️  PARAMÈTRES${NC}\n"
    echo -e "  ${G}1)${NC} 🎨 Changer le thème de couleurs"
    echo -e "  ${G}2)${NC} 👤 Changer mon pseudo (banner)"
    echo -e "  ${G}3)${NC} ⚡ Gérer mes alias"
    echo -e "  ${G}4)${NC} 📜 Historique de commandes"
    echo -e "  ${G}5)${NC} 💾 Sauvegarder toute la config"
    echo -e "  ${G}6)${NC} 📦 Restaurer une sauvegarde"
    echo -e "  ${G}7)${NC} 📋 Journal des actions"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1) changer_theme ;;
        2) changer_pseudo ;;
        3) gerer_alias ;;
        4) voir_historique ;;
        5) sauvegarder_tout ;;
        6) restaurer_config ;;
        7) voir_journal ;;
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
    echo -e "  ${G}6)${NC} \033[1;33mCyberpunk\033[0m — Jaune / Orange"
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
        6)
            cat > "$THEME_FILE" << EOF
PSEUDO_NAME="$pseudo"
THEME_NAME="Cyberpunk"
ACCENT='\\033[1;33m'
ACCENT2='\\033[0;33m'
SUCCESS='\\033[0;32m'
WARN='\\033[1;35m'
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

# ═══════════════════════════════════════════════════════════════
#                    POINT D'ENTRÉE
# ═══════════════════════════════════════════════════════════════
init_env
load_theme
menu_principal
