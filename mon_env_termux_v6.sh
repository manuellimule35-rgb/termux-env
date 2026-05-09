#!/data/data/com.termux/files/usr/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║        MON ENVIRONNEMENT TERMUX v6.0 — Shadow                   ║
# ║  Projets GitHub | Outils | Pentest | Code | SSH | TOR | Réseau  ║
# ║  Notes | Wordlists | Scripts | Recherche | Git intégré           ║
# ╚══════════════════════════════════════════════════════════════════╝

# ─── CHEMINS ─────────────────────────────────────────────────────────
ENV_DIR="$HOME/.mon_env"
PROJETS_FILE="$ENV_DIR/projets.conf"
GITHUB_FILE="$ENV_DIR/github_projets.conf"
OUTILS_FILE="$ENV_DIR/outils.conf"
PENTEST_FILE="$ENV_DIR/pentest.conf"
ALIAS_FILE="$ENV_DIR/mes_alias.sh"
SSH_FILE="$ENV_DIR/ssh_hosts.conf"
THEME_FILE="$ENV_DIR/theme.conf"
NOTES_FILE="$ENV_DIR/notes.conf"
LOG_FILE="$ENV_DIR/historique.log"
SCRIPTS_FILE="$ENV_DIR/scripts.conf"
WORDLISTS_DIR="$ENV_DIR/wordlists"
GITHUB_DIR="$HOME/github_projets"

# ─── COULEURS ─────────────────────────────────────────────────────────
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
    R="$DANGER"; G="$SUCCESS"; Y="$WARN"; B="$ACCENT2"
    C="$ACCENT"; M='\033[0;35m'; W="$BOLD"
}

# ─── LOGGER ──────────────────────────────────────────────────────────
log_action() {
    echo "[$(date '+%d/%m/%Y %H:%M')] $1" >> "$LOG_FILE"
}

# ─── QUITTER ─────────────────────────────────────────────────────────
quitter_proprement() {
    echo -e "\n${G}╔══════════════════════════════════════╗${NC}"
    echo -e "${G}║   À bientôt, ${PSEUDO_NAME:-Shadow} ! 👋          ║${NC}"
    echo -e "${G}╚══════════════════════════════════════╝${NC}\n"
    tput cnorm 2>/dev/null; stty sane 2>/dev/null
    exit 0
}
trap quitter_proprement INT TERM

# ═══════════════════════════════════════════════════════════════════════
#                    BANNER NEOFETCH STYLE (comme photo)
# ═══════════════════════════════════════════════════════════════════════
show_banner() {
    local PSEUDO="${PSEUDO_NAME:-Shadow}"
    local ram_used ram_total storage uptime_s nb_proj nb_github nb_outils nb_notes nb_scripts
    ram_used=$(free -m 2>/dev/null | awk 'NR==2{print $3}')
    ram_total=$(free -m 2>/dev/null | awk 'NR==2{print $2}')
    storage=$(df -h "$HOME" 2>/dev/null | awk 'NR==2{print $3"/"$2}')
    uptime_s=$(uptime -p 2>/dev/null | sed 's/up //' || echo "?")
    nb_proj=$(grep -v "^#" "$PROJETS_FILE" 2>/dev/null | grep -c "|" || echo 0)
    nb_github=$(grep -v "^#" "$GITHUB_FILE" 2>/dev/null | grep -c "|" || echo 0)
    nb_outils=$(grep -v "^#" "$OUTILS_FILE" 2>/dev/null | grep -c "|" || echo 0)
    nb_notes=$(grep -v "^#" "$NOTES_FILE" 2>/dev/null | grep -c "." || echo 0)
    nb_scripts=$(grep -v "^#" "$SCRIPTS_FILE" 2>/dev/null | grep -c "|" || echo 0)

    local LC="$C"
    clear
    echo -e "${LC}"
    printf "         .o8888b.              ${BOLD}%s${NC}${LC}@termux\n" "$PSEUDO"
    printf "        d8P'    'Y8b           ${DIM}───────────────────────${NC}\n"
    printf "       88P       888     888   ${B}OS     :${NC} Android (Termux)\n"
    printf "       88P       888     888   ${B}Shell  :${NC} %s\n" "$(basename "$SHELL")"
    printf "       88P       888     888   ${B}RAM    :${NC} %sMB / %sMB\n" "$ram_used" "$ram_total"
    printf "        Y8b      d8P     88P   ${B}Disque :${NC} %s\n" "$storage"
    printf "         'Y8888888P'    d8P    ${B}Uptime :${NC} %s\n" "$uptime_s"
    printf "                   88888P'     ${B}Projets:${NC} ${G}%s${NC} Local  ${B}GitHub:${NC} ${G}%s${NC}\n" "$nb_proj" "$nb_github"
    echo -e "${NC}"
    echo -e "  \033[41m   \033[42m   \033[43m   \033[44m   \033[45m   \033[46m   \033[47m   \033[0m"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════
#                    DASHBOARD
# ═══════════════════════════════════════════════════════════════════════
show_dashboard() {
    show_banner

    local tor_status
    pgrep -x "tor" &>/dev/null && tor_status="${G}● ACTIF${NC}" || tor_status="${R}● INACTIF${NC}"

    local ip_pub
    ip_pub=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || echo "?")

    local ip_loc
    ip_loc=$(ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -1)
    [ -z "$ip_loc" ] && ip_loc=$(ip route get 1 2>/dev/null | grep -oP 'src \K\S+')
    [ -z "$ip_loc" ] && ip_loc=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$ip_loc" ] && ip_loc="?"

    local last_note
    last_note=$(grep -v "^#" "$NOTES_FILE" 2>/dev/null | tail -1 | cut -d'|' -f2)

    echo -e "  ┌──────────────────────────────────────────────────┐"
    echo -e "  │  ${B}TOR    :${NC} $tor_status"
    echo -e "  │  ${B}IP pub :${NC} ${Y}$ip_pub${NC}"
    echo -e "  │  ${B}IP loc :${NC} ${DIM}$ip_loc${NC}"
    [ -n "$last_note" ] && echo -e "  │  ${B}Note   :${NC} ${DIM}${last_note:0:45}...${NC}"
    echo -e "  └──────────────────────────────────────────────────┘"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════
#                    INITIALISATION
# ═══════════════════════════════════════════════════════════════════════
init_env() {
    mkdir -p "$ENV_DIR" "$WORDLISTS_DIR" "$GITHUB_DIR"

    [ ! -f "$PROJETS_FILE" ] && echo "# FORMAT: nom|type|chemin|commande_lancer|description|date_ajout" > "$PROJETS_FILE"

    [ ! -f "$GITHUB_FILE" ] && cat > "$GITHUB_FILE" << 'EOF'
# FORMAT: nom|url_github|chemin_local|branche|description|date_ajout
EOF

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
metasploit|Framework|pkg install unstable-repo -y && pkg install metasploit -y|msfconsole|msfconsole|Framework pentest complet
masscan|Réseau|pkg install masscan -y|masscan|masscan -p80,443 192.168.1.0/24 --rate=1000|Scanner de ports ultra-rapide
gobuster|Web|pkg install golang -y && go install github.com/OJ/gobuster/v3@latest|gobuster|gobuster dir -u http://site.com -w wordlist.txt|Énumération de dossiers web
subfinder|Recon|pkg install golang -y && go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest|subfinder|subfinder -d example.com|Découverte de sous-domaines
EOF

    [ ! -f "$SSH_FILE" ] && echo "# FORMAT: alias|user|host|port|description" > "$SSH_FILE"
    [ ! -f "$NOTES_FILE" ] && echo "# FORMAT: date|contenu" > "$NOTES_FILE"
    [ ! -f "$LOG_FILE" ] && echo "# Journal des actions" > "$LOG_FILE"
    [ ! -f "$SCRIPTS_FILE" ] && echo "# FORMAT: nom|description|chemin|commande" > "$SCRIPTS_FILE"

    if [ ! -f "$ALIAS_FILE" ]; then
        cat > "$ALIAS_FILE" << 'EOF'
# Mes alias personnalisés
alias ll='ls -la'
alias cls='clear'
alias update='pkg update && pkg upgrade -y'
alias env='bash ~/mon_env_termux_v6.sh'
alias projets='cd $HOME/projets'
alias github='cd $HOME/github_projets'
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
[ -f /data/data/com.termux/files/usr/share/bash-completion/bash_completion ] && \
    source /data/data/com.termux/files/usr/share/bash-completion/bash_completion
EOF
}

# ═══════════════════════════════════════════════════════════════════════
#                    RECHERCHE GLOBALE
# ═══════════════════════════════════════════════════════════════════════
recherche_globale() {
    clear
    echo -e "${W}🔍 RECHERCHE GLOBALE${NC}\n"
    echo -ne "${C}Mot-clé à chercher : ${NC}"; read -r mot
    [ -z "$mot" ] && menu_principal && return

    local found=0

    echo -e "\n${Y}══ Projets locaux ══${NC}"
    while IFS='|' read -r nom type chemin lancer desc date; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        if echo "$nom $desc $type" | grep -qi "$mot"; then
            echo -e "  ${G}●${NC} ${W}$nom${NC} [$type] — $desc"; found=$((found+1))
        fi
    done < "$PROJETS_FILE"

    echo -e "\n${Y}══ Projets GitHub ══${NC}"
    while IFS='|' read -r nom url chemin branche desc date; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        if echo "$nom $desc $url" | grep -qi "$mot"; then
            echo -e "  ${G}●${NC} ${W}$nom${NC} [GitHub] — $url"; found=$((found+1))
        fi
    done < "$GITHUB_FILE"

    echo -e "\n${Y}══ Outils ══${NC}"
    while IFS='|' read -r nom cat install lancer desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        if echo "$nom $desc $cat" | grep -qi "$mot"; then
            echo -e "  ${G}●${NC} ${W}$nom${NC} [$cat] — $desc"; found=$((found+1))
        fi
    done < "$OUTILS_FILE"

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

# ═══════════════════════════════════════════════════════════════════════
#                    MENU PRINCIPAL (SLEEK)
# ═══════════════════════════════════════════════════════════════════════
menu_principal() {
    show_dashboard

    echo -e "  ${G}1)${NC} 🚀  Mes Projets locaux"
    echo -e "  ${G}2)${NC} 🐙  Projets GitHub"
    echo -e "  ${G}3)${NC} 🔧  Mes Outils"
    echo -e "  ${G}4)${NC} 🔐  Pentesting"
    echo -e "  ${G}5)${NC} 💻  Codage & Git"
    echo -e "  ${G}6)${NC} 📊  Système"
    echo -e "  ${G}7)${NC} 🧅  TOR / Réseau Onion"
    echo -e "  ${G}8)${NC} 🌐  Outils Réseau"
    echo -e "  ${G}9)${NC} 🔑  Gestionnaire SSH"
    echo -e "  ${G}n)${NC} 📝  Notes rapides"
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
        2) menu_github ;;
        3) menu_outils ;;
        4) menu_pentest ;;
        5) menu_codage ;;
        6) menu_systeme ;;
        7) menu_tor ;;
        8) menu_reseau ;;
        9) menu_ssh ;;
        n|N) menu_notes ;;
        e|E) menu_extensions ;;
        w|W) menu_wordlists ;;
        b|B) menu_scripts ;;
        /|r|R) recherche_globale ;;
        s|S) menu_parametres ;;
        q|Q|0) quitter_proprement ;;
        *) menu_principal ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════
#                    MES PROJETS LOCAUX
# ═══════════════════════════════════════════════════════════════════════
menu_projets() {
    clear
    echo -e "${C}${W}🚀 MES PROJETS LOCAUX${NC}\n"
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
        echo -e "  ${Y}┌── $nom ${DIM}[$type]${NC}"
        echo -e "  ${Y}│${NC}  ${B}Dossier    :${NC} $chemin"
        echo -e "  ${Y}│${NC}  ${B}Lancer     :${NC} ${G}$lancer${NC}"
        echo -e "  ${Y}│${NC}  ${B}Description:${NC} $desc"
        echo -e "  ${Y}└── Ajouté le $date${NC}\n"
    done < "$PROJETS_FILE"
    [ $nb -eq 0 ] && echo -e "  ${Y}Aucun projet local. Utilise 'Ajouter' !${NC}\n"
    echo -e "${Y}Entrée pour revenir...${NC}"; read
    menu_projets
}

ajouter_projet() {
    clear
    echo -e "${C}${W}➕ AJOUTER UN PROJET LOCAL${NC}\n"
    echo -ne "  Nom du projet : "; read -r nom
    [ -z "$nom" ] && echo -e "${R}Nom vide, annulé.${NC}" && sleep 1 && menu_projets && return
    echo -e "\n  Type :"
    echo -e "  ${G}1)${NC} Python  ${G}2)${NC} Node.js  ${G}3)${NC} Bash  ${G}4)${NC} Pentest  ${G}5)${NC} Autre"
    echo -ne "  Choix : "; read -r t
    case $t in 1) type="Python";; 2) type="Node.js";; 3) type="Bash";; 4) type="Pentest";; *) type="Autre";; esac
    echo -ne "  Chemin (ex: ~/projets/monapp) : "; read -r chemin
    echo -ne "  Commande pour lancer (ex: python app.py) : "; read -r lancer
    echo -ne "  Description courte : "; read -r desc
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
        echo -e "  ${G}$i)${NC} ${W}$nom${NC} ${B}($type)${NC} — ${DIM}$lancer${NC}"
        noms+=("$nom"); cmds+=("$lancer"); chemins+=("$chemin")
        i=$((i+1))
    done < "$PROJETS_FILE"
    [ ${#noms[@]} -eq 0 ] && echo -e "${Y}Aucun projet.${NC}" && sleep 2 && menu_projets && return
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_projets && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local idx=$((num-1))
        local chemin_reel; chemin_reel=$(eval echo "${chemins[$idx]}" 2>/dev/null)
        echo -e "\n${G}▶ Lancement : ${cmds[$idx]}${NC}\n"
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

# ═══════════════════════════════════════════════════════════════════════
#                    PROJETS GITHUB ★ NOUVEAU
# ═══════════════════════════════════════════════════════════════════════
menu_github() {
    clear
    echo -e "${C}${W}🐙 PROJETS GITHUB${NC}\n"

    # Résumé rapide
    local nb=0
    while IFS='|' read -r nom url chemin branche desc date; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        nb=$((nb+1))
    done < "$GITHUB_FILE"
    echo -e "  ${B}Projets GitHub enregistrés :${NC} ${G}$nb${NC}"
    echo -e "  ${B}Dossier de travail        :${NC} ${DIM}$GITHUB_DIR${NC}\n"

    echo -e "  ${G}1)${NC} 📋 Voir tous mes projets GitHub"
    echo -e "  ${G}2)${NC} ➕ Ajouter un repo GitHub (URL)"
    echo -e "  ${G}3)${NC} ⬇️  Cloner / Mettre à jour un projet"
    echo -e "  ${G}4)${NC} 🌿 Git actions sur un projet (push/pull/status)"
    echo -e "  ${G}5)${NC} 📂 Ouvrir un projet dans le terminal"
    echo -e "  ${G}6)${NC} ❌ Supprimer un projet GitHub"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1) github_voir ;;
        2) github_ajouter ;;
        3) github_cloner_ou_update ;;
        4) github_git_actions ;;
        5) github_ouvrir ;;
        6) github_supprimer ;;
        0) menu_principal ;;
        *) menu_github ;;
    esac
}

github_voir() {
    clear
    echo -e "${C}${W}📋 MES PROJETS GITHUB${NC}\n"
    local nb=0
    while IFS='|' read -r nom url chemin branche desc date; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        nb=$((nb+1))
        local cloned="${R}❌ pas cloné${NC}"
        [ -d "$chemin/.git" ] && cloned="${G}✅ cloné${NC}"
        echo -e "  ${Y}┌── $nom${NC}"
        echo -e "  ${Y}│${NC}  ${B}URL      :${NC} ${C}$url${NC}"
        echo -e "  ${Y}│${NC}  ${B}Dossier  :${NC} $chemin"
        echo -e "  ${Y}│${NC}  ${B}Branche  :${NC} $branche"
        echo -e "  ${Y}│${NC}  ${B}Statut   :${NC} $cloned"
        echo -e "  ${Y}│${NC}  ${B}Desc     :${NC} $desc"
        echo -e "  ${Y}└── Ajouté le $date${NC}\n"
    done < "$GITHUB_FILE"
    [ $nb -eq 0 ] && echo -e "  ${Y}Aucun projet GitHub. Utilise 'Ajouter' !${NC}\n"
    echo -e "${Y}Entrée pour revenir...${NC}"; read
    menu_github
}

github_ajouter() {
    clear
    echo -e "${C}${W}➕ AJOUTER UN REPO GITHUB${NC}\n"
    echo -e "  ${DIM}Exemple : https://github.com/username/monrepo${NC}\n"
    echo -ne "  URL GitHub : "; read -r url
    [ -z "$url" ] && echo -e "${R}URL vide, annulé.${NC}" && sleep 1 && menu_github && return

    # Auto-détecter le nom depuis l'URL
    local nom_auto; nom_auto=$(basename "$url" .git)
    echo -ne "  Nom du projet (défaut: ${G}$nom_auto${NC}) : "; read -r nom
    [ -z "$nom" ] && nom="$nom_auto"

    echo -ne "  Branche (défaut: main) : "; read -r branche
    [ -z "$branche" ] && branche="main"

    echo -ne "  Description courte : "; read -r desc

    local chemin="$GITHUB_DIR/$nom"
    local date; date=$(date +"%d/%m/%Y")

    # Vérifier si déjà existant
    if grep -q "^$nom|" "$GITHUB_FILE" 2>/dev/null; then
        echo -e "${R}❌ Un projet '$nom' existe déjà !${NC}"
        sleep 2; menu_github; return
    fi

    echo "$nom|$url|$chemin|$branche|$desc|$date" >> "$GITHUB_FILE"
    log_action "Projet GitHub ajouté : $nom ($url)"
    echo -e "\n${G}✅ Projet '$nom' enregistré !${NC}"
    echo -e "${B}→ URL  : $url${NC}"
    echo -e "${B}→ Dossier cible : $chemin${NC}\n"
    echo -ne "${C}Cloner maintenant ? (o/n) : ${NC}"; read -r r
    if [ "$r" = "o" ]; then
        _github_cloner_projet "$nom" "$url" "$chemin" "$branche"
    fi
    sleep 1; menu_github
}

_github_cloner_projet() {
    local nom="$1" url="$2" chemin="$3" branche="$4"
    echo -e "\n${Y}Clonage de $nom...${NC}"
    if ! command -v git &>/dev/null; then
        echo -e "${R}❌ git n'est pas installé ! Lance : pkg install git${NC}"
        return 1
    fi
    if [ -d "$chemin/.git" ]; then
        echo -e "${Y}Déjà cloné. Mise à jour (git pull)...${NC}"
        cd "$chemin" && git pull origin "$branche" 2>&1 | tail -5
        cd "$HOME"
    else
        mkdir -p "$(dirname "$chemin")"
        git clone -b "$branche" "$url" "$chemin" 2>&1 | tail -10
    fi
    if [ $? -eq 0 ]; then
        echo -e "${G}✅ '$nom' prêt dans $chemin${NC}"
        log_action "GitHub cloné : $nom"
    else
        echo -e "${R}❌ Erreur lors du clonage. Vérifie l'URL et ta connexion.${NC}"
    fi
}

github_cloner_ou_update() {
    clear
    echo -e "${C}${W}⬇️  CLONER / METTRE À JOUR${NC}\n"
    local i=1
    declare -a noms urls chemins branches
    while IFS='|' read -r nom url chemin branche desc date; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        local s="${R}❌${NC}"
        [ -d "$chemin/.git" ] && s="${G}✅${NC}"
        echo -e "  ${G}$i)${NC} $s ${W}$nom${NC}"
        echo -e "     ${DIM}$url${NC}"
        noms+=("$nom"); urls+=("$url"); chemins+=("$chemin"); branches+=("$branche")
        i=$((i+1))
    done < "$GITHUB_FILE"
    [ ${#noms[@]} -eq 0 ] && echo -e "${Y}Aucun projet. Ajoute-en un d'abord.${NC}" && sleep 2 && menu_github && return

    echo -e "\n  ${G}a)${NC} Mettre à jour TOUS les projets"
    echo -ne "\n${C}Numéro ou 'a' (0=retour) : ${NC}"; read -r num

    if [ "$num" = "0" ]; then
        menu_github; return
    elif [ "$num" = "a" ] || [ "$num" = "A" ]; then
        for idx in "${!noms[@]}"; do
            echo -e "\n${Y}══ ${noms[$idx]} ══${NC}"
            _github_cloner_projet "${noms[$idx]}" "${urls[$idx]}" "${chemins[$idx]}" "${branches[$idx]}"
        done
    elif [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local idx=$((num-1))
        _github_cloner_projet "${noms[$idx]}" "${urls[$idx]}" "${chemins[$idx]}" "${branches[$idx]}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_github
}

github_git_actions() {
    clear
    echo -e "${C}${W}🌿 GIT ACTIONS SUR UN PROJET${NC}\n"
    local i=1
    declare -a noms chemins branches
    while IFS='|' read -r nom url chemin branche desc date; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        local s="${R}❌${NC}"
        [ -d "$chemin/.git" ] && s="${G}✅${NC}"
        echo -e "  ${G}$i)${NC} $s ${W}$nom${NC} ${DIM}($branche)${NC}"
        noms+=("$nom"); chemins+=("$chemin"); branches+=("$branche")
        i=$((i+1))
    done < "$GITHUB_FILE"
    [ ${#noms[@]} -eq 0 ] && echo -e "${Y}Aucun projet.${NC}" && sleep 2 && menu_github && return
    echo -ne "\n${C}Numéro du projet (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_github && return

    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local idx=$((num-1))
        local nom="${noms[$idx]}" chemin="${chemins[$idx]}" branche="${branches[$idx]}"

        if [ ! -d "$chemin/.git" ]; then
            echo -e "${R}❌ Projet pas encore cloné. Utilise l'option 3 d'abord.${NC}"
            sleep 2; menu_github; return
        fi

        cd "$chemin" || return
        clear
        echo -e "${C}${W}🌿 GIT : $nom${NC}\n"
        echo -e "  ${G}1)${NC} 📊 Status (git status)"
        echo -e "  ${G}2)${NC} ⬆️  Push (git add . → commit → push)"
        echo -e "  ${G}3)${NC} ⬇️  Pull (git pull origin $branche)"
        echo -e "  ${G}4)${NC} 📜 Log (git log --oneline -15)"
        echo -e "  ${G}5)${NC} 🌿 Branches disponibles"
        echo -e "  ${G}6)${NC} 🔀 Changer de branche"
        echo -e "  ${G}7)${NC} 🔄 Reset (git reset --hard HEAD)"
        echo -e "  ${G}0)${NC} ← Retour"
        echo ""
        echo -ne "${C}Choix : ${NC}"; read -r gc
        case $gc in
            1)
                echo -e "\n${Y}Status de $nom :${NC}\n"
                git status
                ;;
            2)
                git status --short
                echo -ne "\n${C}Message du commit : ${NC}"; read -r msg
                [ -z "$msg" ] && msg="Update $(date +%d/%m/%Y)"
                git add .
                git commit -m "$msg"
                echo -e "\n${Y}Push vers origin/$branche...${NC}"
                git push origin "$branche"
                log_action "GitHub push : $nom"
                ;;
            3)
                echo -e "\n${Y}Pull origin/$branche...${NC}"
                git pull origin "$branche"
                log_action "GitHub pull : $nom"
                ;;
            4)
                git log --oneline -15
                ;;
            5)
                git branch -a
                ;;
            6)
                git branch -a
                echo -ne "\n${C}Nom de la branche : ${NC}"; read -r b
                git checkout "$b" && echo -e "${G}✅ Branche '$b' activée.${NC}"
                # Mettre à jour la branche dans le fichier config
                sed -i "s/^$nom|.*|$chemin|\([^|]*\)|/^$nom|${url}|${chemin}|$b|/" "$GITHUB_FILE" 2>/dev/null
                ;;
            7)
                echo -ne "${R}⚠️  Confirmer reset --hard HEAD ? (o/n) : ${NC}"; read -r r
                [ "$r" = "o" ] && git reset --hard HEAD && echo -e "${G}✅ Reset effectué.${NC}"
                ;;
            0) ;;
        esac
        cd "$HOME"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_github
}

github_ouvrir() {
    clear
    echo -e "${C}${W}📂 OUVRIR UN PROJET${NC}\n"
    local i=1
    declare -a noms chemins
    while IFS='|' read -r nom url chemin branche desc date; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        local s="${R}❌${NC}"
        [ -d "$chemin/.git" ] && s="${G}✅${NC}"
        echo -e "  ${G}$i)${NC} $s ${W}$nom${NC} ${DIM}→ $chemin${NC}"
        noms+=("$nom"); chemins+=("$chemin")
        i=$((i+1))
    done < "$GITHUB_FILE"
    [ ${#noms[@]} -eq 0 ] && echo -e "${Y}Aucun projet.${NC}" && sleep 2 && menu_github && return
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_github && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local idx=$((num-1))
        local chemin="${chemins[$idx]}"
        if [ -d "$chemin" ]; then
            echo -e "\n${G}Ouverture de ${noms[$idx]} dans le terminal...${NC}"
            echo -e "${B}cd $chemin${NC}"
            echo -e "${Y}(Le dossier est accessible. Lance 'ls' pour voir les fichiers.)${NC}\n"
            cd "$chemin"
            ls --color=always 2>/dev/null || ls
            echo -e "\n${Y}Entrée pour revenir au menu...${NC}"; read
            cd "$HOME"
        else
            echo -e "${R}❌ Dossier non trouvé : $chemin${NC}"
            echo -e "${Y}Utilise l'option 3 pour cloner d'abord.${NC}"
            sleep 2
        fi
    fi
    menu_github
}

github_supprimer() {
    clear
    echo -e "${C}${W}❌ SUPPRIMER UN PROJET GITHUB${NC}\n"
    local i=1
    declare -a noms chemins
    while IFS='|' read -r nom url chemin branche desc date; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        echo -e "  ${G}$i)${NC} ${W}$nom${NC} ${DIM}($url)${NC}"
        noms+=("$nom"); chemins+=("$chemin"); i=$((i+1))
    done < "$GITHUB_FILE"
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_github && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local n="${noms[$((num-1))]}"
        local c="${chemins[$((num-1))]}"
        echo -e "\n  ${G}1)${NC} Supprimer seulement de la liste (garder les fichiers)"
        echo -e "  ${G}2)${NC} Supprimer de la liste ET les fichiers locaux"
        echo -ne "${C}Choix : ${NC}"; read -r d
        case $d in
            1)
                grep -vF "${n}|" "$GITHUB_FILE" > /tmp/_mon_env_tmp && mv /tmp/_mon_env_tmp "$GITHUB_FILE"
                echo -e "${G}✅ '$n' retiré de la liste (fichiers conservés).${NC}"
                ;;
            2)
                echo -ne "${R}⚠️  Supprimer aussi $c ? (o/n) : ${NC}"; read -r r
                grep -vF "${n}|" "$GITHUB_FILE" > /tmp/_mon_env_tmp && mv /tmp/_mon_env_tmp "$GITHUB_FILE"
                [ "$r" = "o" ] && rm -rf "$c" && echo -e "${G}✅ '$n' supprimé + fichiers effacés.${NC}" || echo -e "${G}✅ '$n' retiré de la liste.${NC}"
                ;;
        esac
        log_action "GitHub supprimé : $n"
    fi
    sleep 1; menu_github
}

# ═══════════════════════════════════════════════════════════════════════
#                    MES OUTILS
# ═══════════════════════════════════════════════════════════════════════
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
    echo -e "${C}${W}🔧 MES OUTILS${NC}\n"
    while IFS='|' read -r nom cat install lancer desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        local cmd1; cmd1=$(echo "$lancer" | awk '{print $1}')
        local s; command -v "$cmd1" &>/dev/null && s="${G}✅ installé${NC}" || s="${R}❌ non installé${NC}"
        printf "  %s  ${W}%-15s${NC} ${DIM}[%s]${NC} %s\n" "$s" "$nom" "$cat" "$desc"
    done < "$OUTILS_FILE"
    echo ""
    echo -e "${Y}Entrée pour revenir...${NC}"; read
    menu_outils
}

installer_outil_seul() {
    clear
    echo -e "${C}${W}📦 INSTALLER UN OUTIL${NC}\n"
    local i=1
    declare -a noms installs
    while IFS='|' read -r nom cat install lancer desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        local cmd1; cmd1=$(echo "$lancer" | awk '{print $1}')
        local s; command -v "$cmd1" &>/dev/null && s="${G}✅${NC}" || s="${R}❌${NC}"
        echo -e "  ${G}$i)${NC} $s ${W}$nom${NC} ${DIM}[$cat]${NC} — $desc"
        noms+=("$nom"); installs+=("$install"); i=$((i+1))
    done < "$OUTILS_FILE"
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_outils && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local idx=$((num-1))
        echo -e "\n${Y}Installation de ${noms[$idx]}...${NC}\n"
        bash -c "${installs[$idx]}"
        echo -e "\n${G}✅ Terminé !${NC}"
        log_action "Outil installé : ${noms[$idx]}"
    fi
    echo -e "${Y}Entrée pour revenir...${NC}"; read
    menu_outils
}

installer_tous_outils() {
    echo -e "\n${Y}Installation de tous les outils...${NC}\n"
    while IFS='|' read -r nom cat install lancer desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        echo -ne "${Y}→ $nom ... ${NC}"
        bash -c "$install" &>/dev/null && echo -e "${G}✅${NC}" || echo -e "${R}❌${NC}"
    done < "$OUTILS_FILE"
    echo -e "\n${G}Terminé !${NC}"
    echo -e "${Y}Entrée pour revenir...${NC}"; read
    menu_outils
}

ajouter_outil() {
    clear
    echo -e "${C}${W}➕ AJOUTER UN OUTIL PERSO${NC}\n"
    echo -ne "  Nom : "; read -r nom
    echo -ne "  Catégorie : "; read -r cat
    echo -ne "  Commande d'installation : "; read -r install
    echo -ne "  Commande pour lancer : "; read -r lancer
    echo -ne "  Description : "; read -r desc
    [ -z "$nom" ] && menu_outils && return
    echo "$nom|$cat|$install|$lancer|$desc" >> "$OUTILS_FILE"
    echo -e "\n${G}✅ '$nom' ajouté !${NC}"
    sleep 2; menu_outils
}

supprimer_outil() {
    clear
    echo -e "${C}${W}❌ SUPPRIMER UN OUTIL${NC}\n"
    local i=1; declare -a noms
    while IFS='|' read -r nom cat install lancer desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        echo -e "  ${G}$i)${NC} $nom [$cat]"; noms+=("$nom"); i=$((i+1))
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

# ═══════════════════════════════════════════════════════════════════════
#                    PENTESTING
# ═══════════════════════════════════════════════════════════════════════
menu_pentest() {
    clear
    echo -e "${R}${W}🔐 PENTESTING${NC}\n"
    echo -e "  ${G}1)${NC} Voir les outils pentest (statut install)"
    echo -e "  ${G}2)${NC} Installer un outil pentest"
    echo -e "  ${G}3)${NC} Fiches de lancement (guide)"
    echo -e "  ${G}4)${NC} Lancer un outil pentest"
    echo -e "  ${G}5)${NC} Ajouter un outil pentest perso"
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
    echo -e "${R}${W}🔐 OUTILS PENTEST${NC}\n"
    while IFS='|' read -r nom cat install lancer exemple desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        local cmd1; cmd1=$(echo "$lancer" | awk '{print $1}')
        local s; command -v "$cmd1" &>/dev/null && s="${G}✅${NC}" || s="${R}❌${NC}"
        printf "  %s  ${W}%-15s${NC} ${DIM}[%s]${NC} — %s\n" "$s" "$nom" "$cat" "$desc"
    done < "$PENTEST_FILE"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
    menu_pentest
}

installer_pentest() {
    clear
    echo -e "${R}${W}📦 INSTALLER UN OUTIL PENTEST${NC}\n"
    local i=1; declare -a noms installs
    while IFS='|' read -r nom cat install lancer exemple desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        local cmd1; cmd1=$(echo "$lancer" | awk '{print $1}')
        local s; command -v "$cmd1" &>/dev/null && s="${G}✅${NC}" || s="${R}❌${NC}"
        echo -e "  ${G}$i)${NC} $s ${W}$nom${NC} ${DIM}[$cat]${NC}"
        noms+=("$nom"); installs+=("$install"); i=$((i+1))
    done < "$PENTEST_FILE"
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_pentest && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local idx=$((num-1))
        echo -e "\n${Y}Installation de ${noms[$idx]}...${NC}\n"
        bash -c "${installs[$idx]}" && \
            echo -e "\n${G}✅ ${noms[$idx]} installé !${NC}" || \
            echo -e "\n${R}❌ Erreur${NC}"
        log_action "Pentest installé : ${noms[$idx]}"
    fi
    echo -e "${Y}Entrée pour revenir...${NC}"; read
    menu_pentest
}

guide_pentest() {
    clear
    echo -e "${R}${W}📖 FICHES DE LANCEMENT${NC}\n"
    local i=1; declare -a noms
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
            echo -e "${R}${W}╔══════════════════════════════════════════╗${NC}"
            echo -e "${R}${W}║  📖 FICHE : $nom${NC}"
            echo -e "${R}${W}╚══════════════════════════════════════════╝${NC}\n"
            echo -e "${B}Catégorie    :${NC} $cat"
            echo -e "${B}Description  :${NC} $desc\n"
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
    local i=1; declare -a noms lancers
    while IFS='|' read -r nom cat install lancer exemple desc; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        local cmd1; cmd1=$(echo "$lancer" | awk '{print $1}')
        if command -v "$cmd1" &>/dev/null; then
            echo -e "  ${G}$i)${NC} ${W}$nom${NC} — ${DIM}$lancer${NC}"
            noms+=("$nom"); lancers+=("$lancer"); i=$((i+1))
        fi
    done < "$PENTEST_FILE"
    [ ${#noms[@]} -eq 0 ] && echo -e "${R}Aucun outil pentest installé.${NC}" && sleep 2 && menu_pentest && return
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
    echo -ne "  Nom : "; read -r nom
    echo -ne "  Catégorie (Réseau/Web/Bruteforce/Recon/Framework) : "; read -r cat
    echo -ne "  Commande d'installation : "; read -r install
    echo -ne "  Commande pour lancer : "; read -r lancer
    echo -ne "  Exemple d'utilisation : "; read -r exemple
    echo -ne "  Description : "; read -r desc
    [ -z "$nom" ] && menu_pentest && return
    echo "$nom|$cat|$install|$lancer|$exemple|$desc" >> "$PENTEST_FILE"
    echo -e "\n${G}✅ '$nom' ajouté !${NC}"
    sleep 2; menu_pentest
}

# ═══════════════════════════════════════════════════════════════════════
#                    CODAGE & GIT
# ═══════════════════════════════════════════════════════════════════════
menu_codage() {
    clear
    echo -e "${B}${W}💻 CODAGE & GIT${NC}\n"
    echo -e "  ${G}1)${NC} Ouvrir nano"
    echo -e "  ${G}2)${NC} Ouvrir vim"
    echo -e "  ${G}3)${NC} Nouveau fichier Python"
    echo -e "  ${G}4)${NC} Nouveau fichier Node.js"
    echo -e "  ${G}5)${NC} Nouveau script Bash"
    echo -e "  ${G}6)${NC} Git — actions rapides"
    echo -e "  ${G}7)${NC} Correcteur automatique de commande"
    echo -e "  ${G}8)${NC} Exécuter un fichier"
    echo -e "  ${G}9)${NC} Générateur de mots de passe"
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
        9) generateur_mdp ;;
        0) menu_principal; return ;;
        *) menu_codage ;;
    esac
    menu_codage
}

nouveau_python() {
    echo -ne "\n${C}Nom du fichier (sans .py) : ${NC}"; read -r nom
    [ -z "$nom" ] && return
    cat > "$nom.py" << EOF
#!/usr/bin/env python3
# $nom.py — créé le $(date +%d/%m/%Y)

def main():
    print("Hello depuis $nom !")

if __name__ == "__main__":
    main()
EOF
    echo -e "${G}✅ '$nom.py' créé !${NC}"
    echo -ne "Ouvrir dans nano ? (o/n) : "; read -r r
    [ "$r" = "o" ] && nano "$nom.py"
}

nouveau_node() {
    echo -ne "\n${C}Nom du fichier (sans .js) : ${NC}"; read -r nom
    [ -z "$nom" ] && return
    cat > "$nom.js" << EOF
// $nom.js — créé le $(date +%d/%m/%Y)

function main() {
    console.log("Hello depuis $nom !");
}

main();
EOF
    echo -e "${G}✅ '$nom.js' créé !${NC}"
    echo -ne "Ouvrir dans nano ? (o/n) : "; read -r r
    [ "$r" = "o" ] && nano "$nom.js"
}

nouveau_bash() {
    echo -ne "\n${C}Nom du script (sans .sh) : ${NC}"; read -r nom
    [ -z "$nom" ] && return
    cat > "$nom.sh" << EOF
#!/data/data/com.termux/files/usr/bin/bash
# $nom.sh — créé le $(date +%d/%m/%Y)

echo "Hello depuis $nom !"
EOF
    chmod +x "$nom.sh"
    echo -e "${G}✅ '$nom.sh' créé et rendu exécutable !${NC}"
    echo -ne "Ouvrir dans nano ? (o/n) : "; read -r r
    [ "$r" = "o" ] && nano "$nom.sh"
}

executer_fichier() {
    clear
    echo -e "${B}${W}▶️  EXÉCUTER UN FICHIER${NC}\n"
    ls --color=always 2>/dev/null || ls
    echo ""
    echo -ne "${C}Nom du fichier : ${NC}"; read -r fichier
    [ -z "$fichier" ] || [ ! -f "$fichier" ] && echo -e "${R}❌ Fichier introuvable.${NC}" && sleep 2 && return
    case "$fichier" in
        *.py)  echo -e "\n${Y}Python...${NC}\n"; python3 "$fichier" ;;
        *.js)  echo -e "\n${Y}Node.js...${NC}\n"; node "$fichier" ;;
        *.sh)  echo -e "\n${Y}Bash...${NC}\n"; bash "$fichier" ;;
        *)     echo -e "\n${Y}Exécution...${NC}\n"; bash -c "./$fichier" ;;
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
    echo -e "  ${G}8)${NC} Ajouter repo cloné dans 'Projets GitHub'"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1) git status ;;
        2) echo -ne "Message du commit : "; read -r msg; git add . && git commit -m "$msg" ;;
        3) git push ;;
        4) git pull ;;
        5)
            echo -ne "URL du repo : "; read -r url
            git clone "$url"
            # Proposer d'ajouter au gestionnaire GitHub
            local nom_auto; nom_auto=$(basename "$url" .git)
            echo -ne "\n${C}Ajouter '$nom_auto' dans Projets GitHub ? (o/n) : ${NC}"; read -r r
            if [ "$r" = "o" ]; then
                local date; date=$(date +"%d/%m/%Y")
                local chemin="$(pwd)/$nom_auto"
                echo "$nom_auto|$url|$chemin|main||$date" >> "$GITHUB_FILE"
                echo -e "${G}✅ '$nom_auto' ajouté dans Projets GitHub !${NC}"
            fi
            ;;
        6) git init && echo -e "${G}✅ Repo initialisé !${NC}" ;;
        7) git log --oneline -15 2>/dev/null || echo -e "${R}Pas de repo git ici.${NC}" ;;
        8)
            echo -ne "Nom du projet : "; read -r nom
            echo -ne "URL GitHub : "; read -r url
            local chemin; chemin="$(pwd)"
            local date; date=$(date +"%d/%m/%Y")
            echo "$nom|$url|$chemin|main||$date" >> "$GITHUB_FILE"
            echo -e "${G}✅ '$nom' ajouté dans Projets GitHub !${NC}"
            ;;
        0) return ;;
    esac
    echo -e "\n${Y}Entrée pour continuer...${NC}"; read
}

# ═══════════════════════════════════════════════════════════════════════
#            CORRECTEUR AUTOMATIQUE DE COMMANDES ★ AMÉLIORÉ
# ═══════════════════════════════════════════════════════════════════════
correcteur_cmd() {
    clear
    echo -e "${B}${W}🔧 CORRECTEUR AUTOMATIQUE${NC}\n"
    echo -e "  ${DIM}Tape une commande (même avec des fautes)${NC}\n"
    echo -ne "${C}> ${NC}"; read -r cmd
    [ -z "$cmd" ] && return

    # Table de corrections étendue
    declare -A corrections=(
        # Python
        ["pyhton"]="python3" ["pyton"]="python3" ["pytohn"]="python3"
        ["pythno"]="python3" ["pythn"]="python3" ["pyhon"]="python3"
        ["python"]="python3" ["py"]="python3"
        # Git
        ["gti"]="git" ["got"]="git" ["giot"]="git" ["gi"]="git"
        ["gitt"]="git" ["igt"]="git"
        # npm / node
        ["nmp"]="npm" ["npn"]="npm" ["npm"]="npm"
        ["ndoe"]="node" ["nod"]="node"
        # nano / vim
        ["naon"]="nano" ["nao"]="nano" ["nanoo"]="nano"
        ["vmi"]="vim" ["vimm"]="vim"
        # ls / cd
        ["sl"]="ls" ["LS"]="ls" ["lls"]="ls -la"
        ["dc"]="cd" ["CD"]="cd"
        # clear
        ["celar"]="clear" ["cealr"]="clear" ["claer"]="clear"
        ["clera"]="clear" ["clr"]="clear" ["clearr"]="clear"
        # grep / find
        ["grpe"]="grep" ["gerp"]="grep" ["greop"]="grep"
        ["fnid"]="find" ["fnd"]="find"
        # pkg / apt
        ["kpg"]="pkg" ["pkl"]="pkg" ["pkt"]="pkg"
        # cat / more / less
        ["mroe"]="more" ["moer"]="more" ["cta"]="cat"
        # chmod / chown
        ["chmdo"]="chmod" ["chomd"]="chmod"
        # bash
        ["bsh"]="bash" ["bas"]="bash" ["bah"]="bash"
        # curl / wget
        ["clur"]="curl" ["urll"]="curl"
        ["wegt"]="wget" ["wget"]="wget"
        # cp / mv / rm
        ["cp "]="cp" ["mv "]="mv" ["mV"]="mv"
        # touch / mkdir
        ["touhc"]="touch" ["tuch"]="touch"
        ["mkidr"]="mkdir" ["mkdr"]="mkdir"
        # exit
        ["exti"]="exit" ["exxit"]="exit" ["xit"]="exit"
        # ping
        ["pign"]="ping" ["pnig"]="ping"
        # ssh
        ["shs"]="ssh" ["sssh"]="ssh"
        # update
        ["updatee"]="pkg update && pkg upgrade -y"
        ["upgarde"]="pkg upgrade -y"
    )

    # Extraire le premier mot de la commande
    local first_word; first_word=$(echo "$cmd" | awk '{print $1}')
    local rest; rest=$(echo "$cmd" | cut -d' ' -f2-)
    [ "$rest" = "$first_word" ] && rest=""

    local corrected="${corrections[$first_word]}"

    if [ -n "$corrected" ]; then
        # Reconstruire la commande complète
        local full_corrected="$corrected"
        [ -n "$rest" ] && full_corrected="$corrected $rest"

        echo -e "\n  ${Y}┌─────────────────────────────────────────┐${NC}"
        echo -e "  ${Y}│${NC}  ${R}Tu as tapé  :${NC} $cmd"
        echo -e "  ${Y}│${NC}  ${G}Correction  :${NC} ${W}$full_corrected${NC}"
        echo -e "  ${Y}└─────────────────────────────────────────┘${NC}"
        echo ""
        echo -ne "${C}Exécuter la commande corrigée ? (o/n) : ${NC}"; read -r r
        if [ "$r" = "o" ]; then
            echo -e "\n${G}▶ $full_corrected${NC}\n"
            bash -c "$full_corrected"
        fi
    else
        # Tenter quand même la commande et chercher si elle existe
        echo -e "\n${DIM}Aucune correction trouvée. Exécution directe...${NC}\n"
        echo -e "${G}▶ $cmd${NC}\n"
        bash -c "$cmd" 2>&1
        local exit_code=$?
        if [ $exit_code -ne 0 ]; then
            echo -e "\n${Y}Commande échouée (code $exit_code).${NC}"
            echo -e "${DIM}Conseil : vérifie l'orthographe ou tape 'pkg install <outil>'${NC}"
        fi
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
}

# ═══════════════════════════════════════════════════════════════════════
#                    GÉNÉRATEUR DE MOTS DE PASSE
# ═══════════════════════════════════════════════════════════════════════
generateur_mdp() {
    clear
    echo -e "${C}${W}🔑 GÉNÉRATEUR DE MOTS DE PASSE${NC}\n"
    echo -ne "  Longueur (défaut: 20) : "; read -r len
    [ -z "$len" ] && len=20
    [[ ! "$len" =~ ^[0-9]+$ ]] && len=20

    echo -e "\n  Type :"
    echo -e "  ${G}1)${NC} Alphanumérique + symboles (max sécurité)"
    echo -e "  ${G}2)${NC} Alphanumérique seulement"
    echo -e "  ${G}3)${NC} Chiffres seulement (PIN)"
    echo -e "  ${G}4)${NC} Passphrase (4 mots aléatoires)"
    echo ""
    echo -ne "${C}Type : ${NC}"; read -r t

    local mdp
    case $t in
        1) mdp=$(tr -dc 'A-Za-z0-9!@#$%^&*()_+-=[]{}|;:,.<>?' < /dev/urandom | head -c "$len") ;;
        2) mdp=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$len") ;;
        3) mdp=$(tr -dc '0-9' < /dev/urandom | head -c "$len") ;;
        4)
            local words=("shadow" "cyber" "hack" "linux" "termux" "shell" "dark" "net" "void" "proxy" "matrix" "ghost" "byte" "node" "root" "code" "storm" "cloud" "fire" "ice" "zero" "ultra" "vector" "pulse")
            local w1="${words[$RANDOM % ${#words[@]}]}"
            local w2="${words[$RANDOM % ${#words[@]}]}"
            local w3="${words[$RANDOM % ${#words[@]}]}"
            local w4="${words[$RANDOM % ${#words[@]}]}"
            local n=$((RANDOM % 999))
            mdp="${w1^}-${w2^}-${w3^}-${w4^}${n}"
            ;;
        *) mdp=$(tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c "$len") ;;
    esac

    echo -e "\n  ${Y}┌────────────────────────────────────────────────┐${NC}"
    echo -e "  ${Y}│${NC}  ${W}Mot de passe généré :${NC}"
    echo -e "  ${Y}│${NC}  ${G}$mdp${NC}"
    echo -e "  ${Y}│${NC}  ${DIM}Longueur : ${#mdp} caractères${NC}"
    echo -e "  ${Y}└────────────────────────────────────────────────┘${NC}\n"

    echo -ne "${C}Sauvegarder dans les notes ? (o/n) : ${NC}"; read -r r
    if [ "$r" = "o" ]; then
        echo -ne "${C}Label (ex: GitHub, Netflix) : ${NC}"; read -r label
        local date; date=$(date +"%d/%m/%Y %H:%M")
        echo "$date|🔑 MDP [$label] : $mdp" >> "$NOTES_FILE"
        echo -e "${G}✅ Sauvegardé dans tes notes !${NC}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
}

# ═══════════════════════════════════════════════════════════════════════
#                    SYSTÈME
# ═══════════════════════════════════════════════════════════════════════
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

    # Barre RAM
    local filled=$(( ram_pct / 5 ))
    local bar=""
    for ((k=0; k<20; k++)); do
        if [ $k -lt $filled ]; then
            [ $k -lt 14 ] && bar+="${G}█${NC}" || bar+="${R}█${NC}"
        else
            bar+="${DIM}░${NC}"
        fi
    done

    echo -e "  ${B}💾 RAM       :${NC} [$bar${NC}] ${ram_used}MB/${ram_total}MB (${Y}${ram_pct}%${NC})"
    echo -e "  ${B}💿 Stockage  :${NC} $storage"
    echo -e "  ${B}⏱️  Uptime    :${NC} $uptime_info"
    echo -e "  ${B}⚙️  Processus :${NC} $nb_proc\n"

    echo -e "  ${G}1)${NC} Voir processus (htop)"
    echo -e "  ${G}2)${NC} Nettoyer le cache"
    echo -e "  ${G}3)${NC} Mettre à jour Termux"
    echo -e "  ${G}4)${NC} Voir les processus actifs (ps)"
    echo -e "  ${G}5)${NC} Tuer un processus par nom"
    echo -e "  ${G}6)${NC} Info Android / Termux"
    echo -e "  ${G}7)${NC} 🧹 Nettoyer anciens scripts (tuer PIDs)"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1) htop 2>/dev/null || top ;;
        2) apt-get clean 2>/dev/null; pkg clean 2>/dev/null; echo -e "${G}✅ Cache nettoyé !${NC}"; sleep 2 ;;
        3) pkg update && pkg upgrade -y; sleep 2 ;;
        4) ps aux 2>/dev/null | head -25; echo -e "\n${Y}Entrée...${NC}"; read ;;
        5)
            echo -ne "\n${C}Nom du processus à tuer : ${NC}"; read -r pname
            pkill -f "$pname" && echo -e "${G}✅ '$pname' tué.${NC}" || echo -e "${R}❌ Non trouvé.${NC}"
            sleep 2 ;;
        6) systeme_info_android ;;
        7) systeme_nettoyer_scripts ;;
        0) menu_principal; return ;;
    esac
    menu_systeme
}

systeme_info_android() {
    clear
    echo -e "${M}${W}📱 INFO ANDROID / TERMUX${NC}\n"
    echo -e "  ${B}Android   :${NC} $(getprop ro.build.version.release 2>/dev/null || echo '?')"
    echo -e "  ${B}Kernel    :${NC} $(uname -r 2>/dev/null)"
    echo -e "  ${B}Arch      :${NC} $(uname -m 2>/dev/null)"
    echo -e "  ${B}Hostname  :${NC} $(hostname 2>/dev/null)"
    echo -e "  ${B}Termux    :${NC} $PREFIX"
    echo -e "  ${B}Paquets   :${NC} $(pkg list-installed 2>/dev/null | wc -l) installés"
    echo -e "  ${B}Shell     :${NC} $SHELL"
    echo -e "  ${B}User      :${NC} $(whoami 2>/dev/null)"
    echo ""
    echo -e "${Y}Entrée pour revenir...${NC}"; read
}

systeme_nettoyer_scripts() {
    clear
    echo -e "${M}${W}🧹 NETTOYAGE DES ANCIENS SCRIPTS${NC}\n"
    echo -e "  Ceci va tuer les processus 'mon_env_termux' en arrière-plan.\n"

    local pids
    pids=$(pgrep -f "mon_env_termux" 2>/dev/null | grep -v "$$")
    if [ -z "$pids" ]; then
        echo -e "${G}✅ Aucun ancien processus à tuer.${NC}"
    else
        echo -e "${Y}PIDs trouvés : $pids${NC}"
        echo -ne "\n${C}Tuer ces processus ? (o/n) : ${NC}"; read -r r
        if [ "$r" = "o" ]; then
            echo "$pids" | xargs kill 2>/dev/null
            echo -e "${G}✅ Anciens processus nettoyés.${NC}"
            log_action "Nettoyage processus anciens scripts"
        fi
    fi

    echo -e "\n${B}Fichiers anciens versions dans $HOME :${NC}"
    find "$HOME" -maxdepth 1 -name "mon_env_termux_v*.sh" 2>/dev/null | grep -v "v6"
    echo -ne "\n${C}Supprimer les anciennes versions (.sh) ? (o/n) : ${NC}"; read -r r
    if [ "$r" = "o" ]; then
        find "$HOME" -maxdepth 1 -name "mon_env_termux_v*.sh" 2>/dev/null | grep -v "v6" | xargs rm -f 2>/dev/null
        echo -e "${G}✅ Anciennes versions supprimées.${NC}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
}

# ═══════════════════════════════════════════════════════════════════════
#                    TOR / RÉSEAU ONION
# ═══════════════════════════════════════════════════════════════════════
menu_tor() {
    clear
    echo -e "${M}${W}🧅 TOR / RÉSEAU ONION${NC}\n"
    local tor_s
    pgrep -x "tor" &>/dev/null && tor_s="${G}● ACTIF${NC}" || tor_s="${R}● INACTIF${NC}"
    echo -e "  Statut TOR : $tor_s\n"
    echo -e "  ${G}1)${NC} Activer TOR"
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
        echo -e "${R}❌ TOR non installé. Option 6.${NC}"
    else
        tor --quiet &
        sleep 3
        pgrep -x "tor" &>/dev/null && \
            echo -e "${G}✅ TOR actif ! Port SOCKS5 : 9050${NC}" || \
            echo -e "${R}❌ Échec TOR${NC}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_tor
}

tor_desactiver() {
    pkill -x tor 2>/dev/null && echo -e "${G}✅ TOR arrêté.${NC}" || echo -e "${Y}TOR n'était pas actif.${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_tor
}

tor_verifier_ip() {
    echo -e "\n${B}Vérification...${NC}"
    echo -ne "${W}IP réelle  :${NC} "; curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo "?"
    echo ""
    echo -ne "${W}IP via TOR :${NC} "
    local pc_cmd; command -v proxychains4 &>/dev/null && pc_cmd="proxychains4" || pc_cmd="proxychains"
    command -v "$pc_cmd" &>/dev/null && \
        $pc_cmd curl -s --max-time 10 https://api.ipify.org 2>/dev/null || \
        echo -e "${R}proxychains non installé${NC}"
    echo ""
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_tor
}

tor_cmd() {
    echo -ne "\n${C}Commande via TOR : ${NC}"; read -r cmd
    local pc_cmd; command -v proxychains4 &>/dev/null && pc_cmd="proxychains4" || pc_cmd="proxychains"
    bash -c "$pc_cmd $cmd"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_tor
}

tor_nouveau_circuit() {
    if pgrep -x "tor" &>/dev/null; then
        pkill -HUP tor 2>/dev/null && echo -e "${G}✅ Nouveau circuit TOR ! (attends ~10s)${NC}"
    else
        echo -e "${R}❌ TOR n'est pas actif.${NC}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_tor
}

# ═══════════════════════════════════════════════════════════════════════
#                    OUTILS RÉSEAU
# ═══════════════════════════════════════════════════════════════════════
menu_reseau() {
    clear
    echo -e "${B}${W}🌐 OUTILS RÉSEAU${NC}\n"
    echo -e "  ${G}1)${NC} Voir mes IPs (locale + publique)"
    echo -e "  ${G}2)${NC} Scanner le réseau WiFi"
    echo -e "  ${G}3)${NC} Tester la vitesse de connexion"
    echo -e "  ${G}4)${NC} Ping une adresse"
    echo -e "  ${G}5)${NC} Traceroute"
    echo -e "  ${G}6)${NC} DNS lookup"
    echo -e "  ${G}7)${NC} Infos sur une IP (geo/whois)"
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
    local ip_loc
    ip_loc=$(ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -1)
    [ -z "$ip_loc" ] && ip_loc=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$ip_loc" ] && ip_loc="indisponible"
    echo -e "  ${W}IP locale    :${NC} ${G}$ip_loc${NC}"
    echo -ne "  ${W}IP publique  :${NC} "
    curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo -e "${R}non disponible${NC}"
    echo -e "\n\n  ${Y}Entrée pour revenir...${NC}"; read
    menu_reseau
}

reseau_scan_wifi() {
    echo -e "\n${Y}Scan du réseau local...${NC}"
    if command -v nmap &>/dev/null; then
        local gw; gw=$(ip route | grep default | awk '{print $3}' | head -1)
        local subnet; subnet=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | grep -v '127\.' | head -1)
        echo -e "${B}Réseau : $subnet${NC}\n"
        nmap -sn "$subnet" 2>/dev/null | grep -E "Nmap scan|Host is up|report for"
    else
        echo -e "${R}❌ nmap non installé. Lance : pkg install nmap${NC}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_reseau
}

reseau_speedtest() {
    echo -e "\n${Y}Test de vitesse...${NC}"
    if command -v curl &>/dev/null; then
        echo -e "${B}Download speed :${NC}"
        curl -o /dev/null -s -w "%{speed_download} bytes/s\n" http://speedtest.tele2.net/1MB.zip 2>/dev/null | \
            awk '{printf "  %.2f MB/s\n", $1/1024/1024}'
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_reseau
}

reseau_ping() {
    echo -ne "\n${C}Adresse à pinguer (défaut: 8.8.8.8) : ${NC}"; read -r addr
    [ -z "$addr" ] && addr="8.8.8.8"
    ping -c 4 "$addr"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_reseau
}

reseau_traceroute() {
    echo -ne "\n${C}Adresse : ${NC}"; read -r addr
    [ -z "$addr" ] && menu_reseau && return
    if command -v traceroute &>/dev/null; then
        traceroute "$addr"
    else
        echo -e "${R}❌ traceroute non installé. Lance : pkg install traceroute${NC}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_reseau
}

reseau_dns() {
    echo -ne "\n${C}Domaine (ex: google.com) : ${NC}"; read -r domain
    [ -z "$domain" ] && menu_reseau && return
    if command -v nslookup &>/dev/null; then
        nslookup "$domain"
    elif command -v host &>/dev/null; then
        host "$domain"
    else
        echo -e "${R}❌ nslookup/host non disponible.${NC}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_reseau
}

reseau_geoip() {
    echo -ne "\n${C}IP publique (vide = la tienne) : ${NC}"; read -r ip
    [ -z "$ip" ] && ip=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null)
    echo -e "\n${B}Infos pour $ip :${NC}\n"
    curl -s "https://ipinfo.io/$ip" 2>/dev/null | grep -E '"ip"|"city"|"region"|"country"|"org"' | \
        sed 's/[",]//g' | awk '{print "  "$0}'
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_reseau
}

reseau_netcat() {
    echo -ne "\n${C}Port à écouter : ${NC}"; read -r port
    [ -z "$port" ] && menu_reseau && return
    echo -e "${Y}Écoute sur le port $port... (Ctrl+C pour arrêter)${NC}\n"
    nc -lvp "$port" 2>/dev/null || echo -e "${R}❌ netcat non disponible. Lance : pkg install netcat-openbsd${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_reseau
}

# ═══════════════════════════════════════════════════════════════════════
#                    GESTIONNAIRE SSH
# ═══════════════════════════════════════════════════════════════════════
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
    clear; echo -e "${Y}${W}🔑 MES CONNEXIONS SSH${NC}\n"
    local nb=0
    while IFS='|' read -r alias user host port desc; do
        [[ "$alias" == \#* || -z "$alias" ]] && continue
        nb=$((nb+1))
        echo -e "  ${C}── $alias ──────────────────${NC}"
        echo -e "  ${B}Serveur :${NC} $user@$host:$port"
        echo -e "  ${B}Desc    :${NC} $desc"
        echo -e "  ${B}Cmd     :${NC} ${G}ssh -p $port $user@$host${NC}\n"
    done < "$SSH_FILE"
    [ $nb -eq 0 ] && echo -e "  ${Y}Aucune connexion. Utilise 'Ajouter' !${NC}\n"
    echo -e "${Y}Entrée pour revenir...${NC}"; read; menu_ssh
}

ssh_connecter() {
    clear; echo -e "${Y}${W}⚡ SE CONNECTER${NC}\n"
    local i=1; declare -a aliases users hosts ports
    while IFS='|' read -r alias user host port desc; do
        [[ "$alias" == \#* || -z "$alias" ]] && continue
        echo -e "  ${G}$i)${NC} ${W}$alias${NC} — $user@$host:$port ${DIM}($desc)${NC}"
        aliases+=("$alias"); users+=("$user"); hosts+=("$host"); ports+=("$port"); i=$((i+1))
    done < "$SSH_FILE"
    [ ${#aliases[@]} -eq 0 ] && echo -e "${Y}Aucune connexion.${NC}" && sleep 2 && menu_ssh && return
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_ssh && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local idx=$((num-1))
        log_action "SSH vers ${aliases[$idx]}"
        ssh -p "${ports[$idx]}" "${users[$idx]}@${hosts[$idx]}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_ssh
}

ssh_ajouter() {
    clear; echo -e "${C}${W}➕ AJOUTER UNE CONNEXION SSH${NC}\n"
    echo -ne "  Alias (ex: monServeur) : "; read -r alias
    echo -ne "  Utilisateur (ex: root) : "; read -r user
    echo -ne "  Hôte/IP : "; read -r host
    echo -ne "  Port (défaut: 22) : "; read -r port
    [ -z "$port" ] && port="22"
    echo -ne "  Description : "; read -r desc
    [ -z "$alias" ] && menu_ssh && return
    echo "$alias|$user|$host|$port|$desc" >> "$SSH_FILE"
    echo -e "\n${G}✅ '$alias' sauvegardé !${NC}"
    sleep 2; menu_ssh
}

ssh_supprimer() {
    clear; echo -e "${C}${W}❌ SUPPRIMER UNE CONNEXION${NC}\n"
    local i=1; declare -a aliases
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
    clear; echo -e "${Y}${W}🔐 GÉNÉRER UNE CLÉ SSH${NC}\n"
    if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
        echo -e "${Y}Une clé SSH existe déjà.${NC}"
        echo -ne "En générer une nouvelle ? (o/n) : "; read -r r
        [ "$r" != "o" ] && menu_ssh && return
    fi
    mkdir -p "$HOME/.ssh"
    echo -ne "Email ou pseudo : "; read -r email
    ssh-keygen -t rsa -b 4096 -C "$email" -f "$HOME/.ssh/id_rsa" -N "" && \
        echo -e "\n${G}✅ Clé dans ~/.ssh/id_rsa${NC}" || \
        echo -e "\n${R}❌ pkg install openssh${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_ssh
}

ssh_copier_cle() {
    clear; echo -e "${Y}${W}📋 MA CLÉ PUBLIQUE${NC}\n"
    if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
        cat "$HOME/.ssh/id_rsa.pub"
        echo -e "\n${B}Ajouter sur un serveur : ssh-copy-id -p PORT user@host${NC}"
    else
        echo -e "${R}❌ Pas de clé. Génère-en une (option 5).${NC}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_ssh
}

# ═══════════════════════════════════════════════════════════════════════
#                    NOTES RAPIDES
# ═══════════════════════════════════════════════════════════════════════
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
    clear; echo -e "${C}${W}📝 MES NOTES${NC}\n"
    local nb=0
    while IFS='|' read -r date contenu; do
        [[ "$date" == \#* || -z "$date" ]] && continue
        nb=$((nb+1))
        echo -e "  ${Y}[$nb]${NC} ${DIM}$date${NC}"
        echo -e "       $contenu\n"
    done < "$NOTES_FILE"
    [ $nb -eq 0 ] && echo -e "  ${Y}Aucune note. Utilise 'Ajouter' !${NC}\n"
    echo -e "${Y}Entrée pour revenir...${NC}"; read; menu_notes
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
    clear; echo -e "${C}${W}❌ SUPPRIMER UNE NOTE${NC}\n"
    local i=1; declare -a lignes
    while IFS='|' read -r date contenu; do
        [[ "$date" == \#* || -z "$date" ]] && continue
        echo -e "  ${G}$i)${NC} ${DIM}$date${NC} — ${contenu:0:50}"
        lignes+=("$date|$contenu"); i=$((i+1))
    done < "$NOTES_FILE"
    [ ${#lignes[@]} -eq 0 ] && echo -e "${Y}Aucune note.${NC}" && sleep 1 && menu_notes && return
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_notes && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local entry="${lignes[$((num-1))]}"
        grep -vF "$entry" "$NOTES_FILE" > /tmp/_mon_env_tmp && mv /tmp/_mon_env_tmp "$NOTES_FILE"
        echo -e "${G}✅ Note supprimée.${NC}"
    fi
    sleep 1; menu_notes
}

notes_rechercher() {
    echo -ne "\n${C}Mot-clé : ${NC}"; read -r mot
    [ -z "$mot" ] && menu_notes && return
    clear; echo -e "${C}${W}🔍 Résultats pour \"$mot\" :${NC}\n"
    local found=0
    while IFS='|' read -r date contenu; do
        [[ "$date" == \#* || -z "$date" ]] && continue
        if echo "$contenu" | grep -qi "$mot"; then
            echo -e "  ${Y}$date${NC} — $contenu"; found=$((found+1))
        fi
    done < "$NOTES_FILE"
    [ $found -eq 0 ] && echo -e "  ${Y}Aucun résultat.${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_notes
}

# ═══════════════════════════════════════════════════════════════════════
#                    EXTENSIONS & PLUGINS
# ═══════════════════════════════════════════════════════════════════════
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
    clear; echo -e "${M}${W}🎨 THÈMES TERMUX${NC}\n"
    echo -e "  ${G}1)${NC} Installer termux-style"
    echo -e "  ${G}2)${NC} Voir les thèmes dispo"
    echo -e "  ${G}0)${NC} ← Retour"
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1)
            pkg install git -y &>/dev/null
            git clone https://github.com/adi1090x/termux-style "$HOME/.termux-style" 2>/dev/null || \
                (cd "$HOME/.termux-style" && git pull 2>/dev/null)
            [ -f "$HOME/.termux-style/setup.sh" ] && bash "$HOME/.termux-style/setup.sh"
            echo -e "${G}✅ termux-style installé !${NC}"
            ;;
        2)
            [ -d "$HOME/.termux-style/themes" ] && \
                ls "$HOME/.termux-style/themes/" | sed 's/\.conf//' | column || \
                echo -e "${B}Thèmes : Dracula, Nord, Monokai, Solarized, Gruvbox, One-Dark...${NC}"
            ;;
    esac
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_extensions
}

ext_zsh() {
    clear; echo -e "${M}${W}💬 ZSH + OH-MY-ZSH + POWERLEVEL10K${NC}\n"
    echo -ne "${C}Continuer l'installation ? (o/n) : ${NC}"; read -r r
    [ "$r" != "o" ] && menu_extensions && return
    pkg install zsh git curl -y
    export RUNZSH=no
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    git clone https://github.com/zsh-users/zsh-autosuggestions \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" 2>/dev/null
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" 2>/dev/null
    git clone --depth=1 https://github.com/romkatv/powerlevel10k \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" 2>/dev/null
    [ -f "$HOME/.zshrc" ] && \
        sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$HOME/.zshrc" && \
        sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"
    echo -e "\n${G}✅ ZSH + Oh-My-Zsh + Powerlevel10k installés !${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_extensions
}

ext_fonts() {
    clear; echo -e "${M}${W}🔤 INSTALLER UNE POLICE NERD FONT${NC}\n"
    echo -e "  ${G}1)${NC} Fira Code Nerd Font"
    echo -e "  ${G}2)${NC} Meslo LG (pour Powerlevel10k)"
    echo -e "  ${G}3)${NC} Ubuntu Mono"
    echo -e "  ${G}4)${NC} JetBrains Mono"
    echo -e "  ${G}0)${NC} ← Retour"
    echo -ne "${C}Choix : ${NC}"; read -r c
    mkdir -p "$HOME/.termux"
    local base="https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts"
    local url="" name=""
    case $c in
        1) url="$base/FiraCode/Regular/FiraCodeNerdFont-Regular.ttf"; name="Fira Code" ;;
        2) url="$base/Meslo/S/Regular/MesloLGSNerdFont-Regular.ttf"; name="Meslo LG" ;;
        3) url="$base/UbuntuMono/Regular/UbuntuMonoNerdFont-Regular.ttf"; name="Ubuntu Mono" ;;
        4) url="$base/JetBrainsMono/Ligatures/Regular/JetBrainsMonoNerdFont-Regular.ttf"; name="JetBrains Mono" ;;
        0) menu_extensions; return ;;
    esac
    echo -e "\n${Y}Téléchargement $name...${NC}"
    curl -fLo "$HOME/.termux/font.ttf" "$url" && \
        echo -e "${G}✅ $name installée ! Recharge Termux.${NC}" || \
        echo -e "${R}❌ Erreur${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_extensions
}

ext_paquets_utiles() {
    clear; echo -e "${M}${W}📦 PAQUETS UTILES${NC}\n"
    declare -A paquets=(
        ["fd"]="Recherche de fichiers rapide"
        ["bat"]="cat avec coloration syntaxique"
        ["ripgrep"]="grep ultra-rapide (rg)"
        ["jq"]="Parser JSON"
        ["fzf"]="Fuzzy finder interactif"
        ["neovim"]="Vim next-gen (nvim)"
        ["tree"]="Arborescence des dossiers"
        ["cmatrix"]="Effet Matrix"
    )
    local i=1; declare -a keys
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
    elif [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -ge 1 ] && [ "$c" -lt "$i" ]; then
        pkg install "${keys[$((c-1))]}" -y && echo -e "${G}✅ Installé !${NC}" || echo -e "${R}❌ Erreur${NC}"
    fi
    [ "$c" != "0" ] && echo -e "\n${Y}Entrée pour revenir...${NC}" && read
    menu_extensions
}

ext_python_pip() {
    clear; echo -e "${M}${W}🐍 OUTILS PYTHON (pip)${NC}\n"
    local tools=("requests:Requêtes HTTP" "beautifulsoup4:Parser HTML (web scraping)" "scapy:Paquets réseau" "paramiko:SSH en Python" "flask:Framework web léger")
    local i=1; declare -a noms
    for t in "${tools[@]}"; do
        local nom="${t%%:*}" desc="${t##*:}"
        local s; python3 -c "import ${nom%%[^a-z]*}" &>/dev/null && s="${G}✅${NC}" || s="${R}❌${NC}"
        echo -e "  ${G}$i)${NC} $s ${W}$nom${NC} — $desc"
        noms+=("$nom"); i=$((i+1))
    done
    echo -e "\n  ${G}a)${NC} Installer TOUS"
    echo -e "  ${G}0)${NC} ← Retour"
    echo -ne "\n${C}Choix : ${NC}"; read -r c
    if [ "$c" = "a" ] || [ "$c" = "A" ]; then
        for n in "${noms[@]}"; do
            echo -ne "${Y}→ $n ... ${NC}"
            pip install "$n" --break-system-packages &>/dev/null && echo -e "${G}✅${NC}" || echo -e "${R}❌${NC}"
        done
    elif [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -ge 1 ] && [ "$c" -lt "$i" ]; then
        pip install "${noms[$((c-1))]}" --break-system-packages && echo -e "${G}✅${NC}" || echo -e "${R}❌${NC}"
    fi
    [ "$c" != "0" ] && echo -e "\n${Y}Entrée pour revenir...${NC}" && read
    menu_extensions
}

ext_go_tools() {
    clear; echo -e "${M}${W}🌐 OUTILS GO${NC}\n"
    echo -e "${Y}Installation de Go puis des outils...${NC}\n"
    echo -ne "${C}Continuer ? (o/n) : ${NC}"; read -r r
    [ "$r" != "o" ] && menu_extensions && return
    pkg install golang -y
    local tools=("github.com/OJ/gobuster/v3@latest:gobuster" "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest:subfinder")
    for t in "${tools[@]}"; do
        local pkg="${t%%:*}" name="${t##*:}"
        echo -ne "${Y}→ $name ... ${NC}"
        go install "$pkg" &>/dev/null && echo -e "${G}✅${NC}" || echo -e "${R}❌${NC}"
    done
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_extensions
}

ext_tmux() {
    clear; echo -e "${M}${W}🔧 TMUX${NC}\n"
    pkg install tmux -y
    if [ ! -f "$HOME/.tmux.conf" ]; then
        cat > "$HOME/.tmux.conf" << 'EOF'
set -g mouse on
set -g history-limit 10000
set -g base-index 1
set -g status-style 'bg=#1e1e2e fg=#cdd6f4'
set -g status-left '#[bold]  #S '
set -g status-right '#[dim]%H:%M '
bind-key r source-file ~/.tmux.conf \; display "Config rechargée!"
EOF
        echo -e "${G}✅ tmux installé + config personnalisée créée !${NC}"
    else
        echo -e "${Y}tmux déjà configuré.${NC}"
    fi
    echo -e "${B}Lance 'tmux' pour démarrer.${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_extensions
}

ext_update_script() {
    clear; echo -e "${M}${W}⬆️  METTRE À JOUR LE SCRIPT${NC}\n"
    echo -e "${Y}Cette option va chercher la dernière version sur GitHub.${NC}"
    echo -e "${B}Assure-toi d'avoir l'URL de ton repo GitHub avec le script.${NC}\n"
    echo -ne "${C}URL raw GitHub du script (Entrée pour annuler) : ${NC}"; read -r url
    [ -z "$url" ] && menu_extensions && return
    echo -e "\n${Y}Téléchargement...${NC}"
    local backup="$HOME/mon_env_termux_v6_backup_$(date +%Y%m%d%H%M).sh"
    cp "$0" "$backup" 2>/dev/null
    curl -fL "$url" -o "$HOME/mon_env_termux_v6.sh" && \
        chmod +x "$HOME/mon_env_termux_v6.sh" && \
        echo -e "${G}✅ Script mis à jour ! Sauvegarde : $backup${NC}" || \
        echo -e "${R}❌ Erreur. Sauvegarde conservée.${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_extensions
}

# ═══════════════════════════════════════════════════════════════════════
#                    WORDLISTS
# ═══════════════════════════════════════════════════════════════════════
menu_wordlists() {
    clear
    echo -e "${R}${W}📖 WORDLISTS${NC}\n"
    local nb=0
    for f in "$WORDLISTS_DIR"/*; do [ -f "$f" ] && nb=$((nb+1)); done
    echo -e "  ${B}Wordlists stockées :${NC} ${G}$nb${NC}  ${DIM}($WORDLISTS_DIR)${NC}\n"
    echo -e "  ${G}1)${NC} Télécharger une wordlist populaire"
    echo -e "  ${G}2)${NC} Télécharger depuis une URL custom"
    echo -e "  ${G}3)${NC} Voir mes wordlists"
    echo -e "  ${G}4)${NC} Supprimer une wordlist"
    echo -e "  ${G}0)${NC} ← Retour"
    echo ""
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1) wordlist_populaire ;;
        2) wordlist_custom ;;
        3) wordlist_voir ;;
        4) wordlist_supprimer ;;
        0) menu_principal ;;
        *) menu_wordlists ;;
    esac
}

wordlist_populaire() {
    clear; echo -e "${R}${W}⬇️  WORDLISTS POPULAIRES${NC}\n"
    echo -e "  ${G}1)${NC} rockyou.txt (133MB) — passwords classiques"
    echo -e "  ${G}2)${NC} common.txt (5MB) — dirs web communs"
    echo -e "  ${G}3)${NC} subdomains.txt — sous-domaines communs"
    echo -e "  ${G}0)${NC} ← Retour"
    echo -ne "${C}Choix : ${NC}"; read -r c
    local url="" fname=""
    case $c in
        1) url="https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt"; fname="rockyou.txt" ;;
        2) url="https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/common.txt"; fname="common.txt" ;;
        3) url="https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/subdomains-top1million-5000.txt"; fname="subdomains-top5k.txt" ;;
        0) menu_wordlists; return ;;
    esac
    echo -e "\n${Y}Téléchargement de $fname...${NC}"
    curl -fL "$url" -o "$WORDLISTS_DIR/$fname" --progress-bar && \
        echo -e "${G}✅ $fname téléchargé !${NC}" || \
        echo -e "${R}❌ Erreur${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_wordlists
}

wordlist_custom() {
    echo -ne "\n${C}URL : ${NC}"; read -r url
    [ -z "$url" ] && menu_wordlists && return
    echo -ne "${C}Nom du fichier : ${NC}"; read -r fname
    [ -z "$fname" ] && fname="custom_$(date +%Y%m%d).txt"
    curl -fL "$url" -o "$WORDLISTS_DIR/$fname" --progress-bar && \
        echo -e "${G}✅ $fname téléchargé !${NC}" || \
        echo -e "${R}❌ Erreur${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_wordlists
}

wordlist_voir() {
    clear; echo -e "${R}${W}📂 MES WORDLISTS${NC}\n"
    local i=1; declare -a wls
    for f in "$WORDLISTS_DIR"/*; do
        [ -f "$f" ] || continue
        local size; size=$(du -h "$f" | cut -f1)
        local lines; lines=$(wc -l < "$f" 2>/dev/null)
        echo -e "  ${G}$i)${NC} ${W}$(basename "$f")${NC} ${DIM}[$size — $lines lignes]${NC}"
        wls+=("$f"); i=$((i+1))
    done
    [ ${#wls[@]} -eq 0 ] && echo -e "${Y}Aucune wordlist.${NC}" && sleep 2 && menu_wordlists && return
    echo -ne "\n${C}Numéro pour aperçu (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_wordlists && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        echo -e "\n${Y}10 premières lignes :${NC}\n"
        head -10 "${wls[$((num-1))]}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_wordlists
}

wordlist_supprimer() {
    clear; echo -e "${R}${W}❌ SUPPRIMER UNE WORDLIST${NC}\n"
    local i=1; declare -a wls
    for f in "$WORDLISTS_DIR"/*; do
        [ -f "$f" ] || continue
        echo -e "  ${G}$i)${NC} $(basename "$f") ${DIM}($(du -h "$f" | cut -f1))${NC}"
        wls+=("$f"); i=$((i+1))
    done
    [ ${#wls[@]} -eq 0 ] && echo -e "${Y}Aucune wordlist.${NC}" && sleep 1 && menu_wordlists && return
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_wordlists && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local f="${wls[$((num-1))]}"
        echo -ne "${R}Confirmer suppression ? (o/n) : ${NC}"; read -r r
        [ "$r" = "o" ] && rm -f "$f" && echo -e "${G}✅ Supprimé.${NC}"
    fi
    sleep 1; menu_wordlists
}

# ═══════════════════════════════════════════════════════════════════════
#                    MES SCRIPTS BASH
# ═══════════════════════════════════════════════════════════════════════
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
    clear; echo -e "${Y}${W}📜 MES SCRIPTS${NC}\n"
    local nb=0
    while IFS='|' read -r nom desc chemin cmd; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        nb=$((nb+1))
        local s; [ -f "$chemin" ] && s="${G}✅${NC}" || s="${R}❌ introuvable${NC}"
        echo -e "  $s ${W}$nom${NC}"
        echo -e "     ${B}Desc  :${NC} $desc"
        echo -e "     ${B}Cmd   :${NC} ${G}$cmd${NC}\n"
    done < "$SCRIPTS_FILE"
    [ $nb -eq 0 ] && echo -e "${Y}Aucun script sauvegardé.${NC}\n"
    echo -e "${Y}Entrée pour revenir...${NC}"; read; menu_scripts
}

scripts_ajouter_existant() {
    clear; echo -e "${C}${W}➕ AJOUTER UN SCRIPT EXISTANT${NC}\n"
    echo -e "${DIM}Scripts .sh dans $HOME :${NC}"
    find "$HOME" -maxdepth 2 -name "*.sh" 2>/dev/null | grep -v ".mon_env" | head -15
    echo ""
    echo -ne "Nom : "; read -r nom
    echo -ne "Description : "; read -r desc
    echo -ne "Chemin complet : "; read -r chemin
    local chemin_reel; chemin_reel=$(eval echo "$chemin")
    echo -ne "Commande (défaut: bash $chemin_reel) : "; read -r cmd
    [ -z "$cmd" ] && cmd="bash $chemin_reel"
    echo "$nom|$desc|$chemin_reel|$cmd" >> "$SCRIPTS_FILE"
    log_action "Script ajouté : $nom"
    echo -e "\n${G}✅ '$nom' ajouté !${NC}"
    sleep 2; menu_scripts
}

scripts_creer() {
    clear; echo -e "${C}${W}✏️  CRÉER UN NOUVEAU SCRIPT${NC}\n"
    echo -ne "  Nom (sans .sh) : "; read -r nom
    [ -z "$nom" ] && menu_scripts && return
    echo -ne "  Description : "; read -r desc
    echo -ne "  Dossier (défaut: ~/scripts) : "; read -r dossier
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
    echo -ne "\nOuvrir dans nano ? (o/n) : "; read -r r
    [ "$r" = "o" ] && nano "$f"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_scripts
}

scripts_lancer() {
    clear; echo -e "${Y}${W}⚡ LANCER UN SCRIPT${NC}\n"
    local i=1; declare -a noms cmds
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
        echo -e "\n${G}▶ ${cmds[$idx]}${NC}\n"
        log_action "Script lancé : ${noms[$idx]}"
        bash -c "${cmds[$idx]}"
    fi
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read; menu_scripts
}

scripts_modifier() {
    clear; echo -e "${Y}${W}✏️  MODIFIER UN SCRIPT${NC}\n"
    local i=1; declare -a noms chemins
    while IFS='|' read -r nom desc chemin cmd; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        echo -e "  ${G}$i)${NC} ${W}$nom${NC}"
        noms+=("$nom"); chemins+=("$chemin"); i=$((i+1))
    done < "$SCRIPTS_FILE"
    [ ${#noms[@]} -eq 0 ] && echo -e "${Y}Aucun script.${NC}" && sleep 1 && menu_scripts && return
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_scripts && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local f="${chemins[$((num-1))]}"
        [ -f "$f" ] && nano "$f" || echo -e "${R}❌ Fichier introuvable.${NC}" && sleep 2
    fi
    menu_scripts
}

scripts_supprimer() {
    clear; echo -e "${R}${W}❌ SUPPRIMER UN SCRIPT${NC}\n"
    local i=1; declare -a noms
    while IFS='|' read -r nom desc chemin cmd; do
        [[ "$nom" == \#* || -z "$nom" ]] && continue
        echo -e "  ${G}$i)${NC} $nom ($chemin)"; noms+=("$nom"); i=$((i+1))
    done < "$SCRIPTS_FILE"
    echo -ne "\n${C}Numéro (0=retour) : ${NC}"; read -r num
    [ "$num" = "0" ] && menu_scripts && return
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
        local n="${noms[$((num-1))]}"
        grep -vF "${n}|" "$SCRIPTS_FILE" > /tmp/_mon_env_tmp && mv /tmp/_mon_env_tmp "$SCRIPTS_FILE"
        log_action "Script supprimé : $n"
        echo -e "${G}✅ '$n' retiré.${NC}"
    fi
    sleep 1; menu_scripts
}

# ═══════════════════════════════════════════════════════════════════════
#                    PARAMÈTRES
# ═══════════════════════════════════════════════════════════════════════
menu_parametres() {
    clear
    echo -e "${W}⚙️  PARAMÈTRES${NC}\n"
    echo -e "  ${G}1)${NC} 🎨 Changer le thème de couleurs"
    echo -e "  ${G}2)${NC} 👤 Changer mon pseudo"
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
    clear; echo -e "${W}🎨 CHOISIR UN THÈME${NC}\n"
    echo -e "  ${G}1)${NC} \033[0;36mArch Linux\033[0m  — Cyan / Bleu"
    echo -e "  ${G}2)${NC} \033[0;32mMatrix / Kali\033[0m — Vert vif"
    echo -e "  ${G}3)${NC} \033[0;31mHacker Red\033[0m — Rouge"
    echo -e "  ${G}4)${NC} \033[0;35mDracula\033[0m — Violet"
    echo -e "  ${G}5)${NC} \033[0;34mNord\033[0m — Bleu foncé"
    echo -e "  ${G}6)${NC} \033[1;33mCyberpunk\033[0m — Jaune / Orange"
    echo ""
    echo -ne "${C}Choix (0=annuler) : ${NC}"; read -r t
    local pseudo="${PSEUDO_NAME:-Shadow}"
    case $t in
        1) cat > "$THEME_FILE" << EOF
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
        2) cat > "$THEME_FILE" << EOF
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
        3) cat > "$THEME_FILE" << EOF
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
        4) cat > "$THEME_FILE" << EOF
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
        5) cat > "$THEME_FILE" << EOF
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
        6) cat > "$THEME_FILE" << EOF
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
    clear; echo -e "${W}⚡ MES ALIAS${NC}\n"
    cat -n "$ALIAS_FILE"
    echo ""
    echo -e "  ${G}1)${NC} Ajouter un alias"
    echo -e "  ${G}2)${NC} Supprimer un alias"
    echo -e "  ${G}0)${NC} ← Retour"
    echo -ne "${C}Choix : ${NC}"; read -r c
    case $c in
        1)
            echo -ne "Nom : "; read -r anom
            echo -ne "Commande : "; read -r acmd
            echo "alias $anom='$acmd'" >> "$ALIAS_FILE"
            source "$ALIAS_FILE"
            echo -e "${G}✅ Alias '$anom' ajouté !${NC}"; sleep 2
            ;;
        2)
            echo -ne "Numéro de ligne à supprimer : "; read -r ln
            [[ "$ln" =~ ^[0-9]+$ ]] && sed -i "${ln}d" "$ALIAS_FILE" && echo -e "${G}✅ Supprimé.${NC}" || echo -e "${R}Invalide.${NC}"
            sleep 2
            ;;
    esac
}

voir_historique() {
    clear; echo -e "${W}📜 HISTORIQUE${NC}\n"
    tail -30 "${HISTFILE:-$HOME/.bash_history}" 2>/dev/null | cat -n || echo -e "${R}Non disponible.${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
}

voir_journal() {
    clear; echo -e "${W}📋 JOURNAL DES ACTIONS${NC}\n"
    tail -40 "$LOG_FILE" 2>/dev/null || echo -e "${Y}Journal vide.${NC}"
    echo -e "\n${Y}Entrée pour revenir...${NC}"; read
}

sauvegarder_tout() {
    local backup="$HOME/backup_env_$(date +%Y%m%d_%H%M).tar.gz"
    tar -czf "$backup" "$ENV_DIR" ~/.bashrc 2>/dev/null
    echo -e "${G}✅ Sauvegarde : $backup${NC}"
    sleep 3
}

restaurer_config() {
    clear; echo -e "${W}📦 RESTAURER${NC}\n"
    ls "$HOME"/backup_env_*.tar.gz 2>/dev/null || echo -e "${Y}Aucune sauvegarde.${NC}"
    echo -ne "\nFichier (Entrée = annuler) : "; read -r f
    [ -z "$f" ] && return
    [ -f "$f" ] && tar -xzf "$f" -C / && echo -e "${G}✅ Restauré !${NC}" || echo -e "${R}❌ Fichier introuvable${NC}"
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#                    POINT D'ENTRÉE
# ═══════════════════════════════════════════════════════════════════════
init_env
load_theme
menu_principal
