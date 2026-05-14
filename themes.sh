#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# core/themes.sh — Gestionnaire de thèmes dynamique
# Dépend de : core/config.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

# ─── Couleurs de secours (avant chargement thème) ─────────────────────
_THEMES_DIR="${CFG_THEMES_DIR:-$HOME/mon_env/themes}"

# ═══════════════════════════════════════════════════════════════════════
#  CHARGEMENT D'UN THÈME
# ═══════════════════════════════════════════════════════════════════════

# Charger un thème par son nom
themes_load() {
    local theme_name="${1:-${THEME_NAME:-cyber}}"
    local theme_file="${_THEMES_DIR}/${theme_name}.theme"

    # Fallback cyber si fichier absent
    if [[ ! -f "$theme_file" ]]; then
        theme_file="${_THEMES_DIR}/cyber.theme"
        theme_name="cyber"
    fi

    # Fallback ultime : couleurs codées en dur
    if [[ ! -f "$theme_file" ]]; then
        _themes_load_fallback
        return 0
    fi

    # shellcheck source=/dev/null
    source "$theme_file"

    # Exporter les variables couleur pour tous les modules
    export C ACCENT G SUCCESS Y WARN R DANGER
    export B ACCENT2 M MAGENTA W BOLD D DIM NC
    export BOX_TOP BOX_MID BOX_BOT BOX_L

    # Alias courts garantis
    C="${ACCENT:-\e[36m}"
    G="${SUCCESS:-\e[32m}"
    Y="${WARN:-\e[33m}"
    R="${DANGER:-\e[31m}"
    B="${ACCENT2:-\e[34m}"
    M="${MAGENTA:-\e[35m}"
    W="${BOLD:-\e[1;37m}"
    D="${DIM:-\e[2;37m}"
    NC="${NC:-\e[0m}"

    export C G Y R B M W D NC

    log_info "Thème chargé : $theme_name" "themes" 2>/dev/null || true
}

# Couleurs de secours hardcodées si aucun fichier thème
_themes_load_fallback() {
    C='\e[36m'; G='\e[32m'; Y='\e[33m'; R='\e[31m'
    B='\e[34m'; M='\e[35m'; W='\e[1;37m'; D='\e[2;37m'; NC='\e[0m'

    ACCENT="$C"; SUCCESS="$G"; WARN="$Y"; DANGER="$R"
    ACCENT2="$B"; MAGENTA="$M"; BOLD="$W"; DIM="$D"

    BOX_TOP="╔══════════════════════════════════════════════════════════════╗"
    BOX_MID="╠══════════════════════════════════════════════════════════════╣"
    BOX_BOT="╚══════════════════════════════════════════════════════════════╝"
    BOX_L="║"

    export C G Y R B M W D NC
    export ACCENT SUCCESS WARN DANGER ACCENT2 MAGENTA BOLD DIM
    export BOX_TOP BOX_MID BOX_BOT BOX_L
}

# ═══════════════════════════════════════════════════════════════════════
#  LISTE DES THÈMES DISPONIBLES
# ═══════════════════════════════════════════════════════════════════════

themes_list() {
    local themes=()
    while IFS= read -r -d '' file; do
        local name
        name=$(basename "$file" .theme)
        themes+=("$name")
    done < <(find "$_THEMES_DIR" -name "*.theme" -print0 2>/dev/null)

    echo "${themes[@]}"
}

# Afficher les thèmes avec description
themes_list_pretty() {
    printf "\n${C:-\e[36m}  Thèmes disponibles :${NC:-\e[0m}\n\n"

    local i=1
    while IFS= read -r file; do
        local name desc
        name=$(basename "$file" .theme)
        # Lire la description dans le fichier
        desc=$(grep "^THEME_DESC=" "$file" 2>/dev/null \
               | cut -d'"' -f2 || echo "Pas de description")

        # Indiquer le thème actif
        local active=""
        [[ "$name" == "${THEME_NAME:-cyber}" ]] && active=" ${G:-\e[32m}← actif${NC:-\e[0m}"

        printf "  ${B:-\e[34m}[%d]${NC:-\e[0m} %-10s ${D:-\e[2;37m}%s${NC:-\e[0m}%b\n" \
               "$i" "$name" "$desc" "$active"
        (( i++ ))
    done < <(find "$_THEMES_DIR" -name "*.theme" 2>/dev/null | sort)

    echo ""
}

# ═══════════════════════════════════════════════════════════════════════
#  PRÉVISUALISATION D'UN THÈME
# ═══════════════════════════════════════════════════════════════════════

themes_preview() {
    local theme_name="$1"
    local theme_file="${_THEMES_DIR}/${theme_name}.theme"

    if [[ ! -f "$theme_file" ]]; then
        printf "${R:-\e[31m}  Thème '%s' introuvable.${NC:-\e[0m}\n" "$theme_name"
        return 1
    fi

    # Charger temporairement dans un sous-shell pour ne pas affecter l'env
    (
        # shellcheck source=/dev/null
        source "$theme_file"
        local C="${ACCENT:-\e[36m}"
        local G="${SUCCESS:-\e[32m}"
        local Y="${WARN:-\e[33m}"
        local R="${DANGER:-\e[31m}"
        local W="${BOLD:-\e[1;37m}"
        local D="${DIM:-\e[2;37m}"
        local NC='\e[0m'

        printf "\n${C}  ═══ Prévisualisation : %s ═══${NC}\n\n" "$theme_name"
        printf "${C}  ╔═══════════════════════════╗${NC}\n"
        printf "${C}  ║${NC}  ${W}Cyber Dashboard Termux${NC}   ${C}║${NC}\n"
        printf "${C}  ╚═══════════════════════════╝${NC}\n\n"
        printf "  ${G}✅ Succès${NC}   ${Y}⚠️  Attention${NC}   ${R}❌ Erreur${NC}\n"
        printf "  ${C}ℹ Info${NC}     ${W}Titre${NC}          ${D}Atténué${NC}\n\n"
    )
}

# ═══════════════════════════════════════════════════════════════════════
#  CHANGER DE THÈME (interactif)
# ═══════════════════════════════════════════════════════════════════════

themes_switch_menu() {
    while true; do
        clear
        printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}🎨 GESTIONNAIRE DE THÈMES${NC:-\e[0m}\n"
        printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n"

        themes_list_pretty

        printf "  ${B:-\e[34m}[p]${NC:-\e[0m} Prévisualiser un thème\n"
        printf "  ${B:-\e[34m}[0]${NC:-\e[0m} Retour\n\n"
        echo -ne "  ${C:-\e[36m}Choix (nom ou numéro) : ${NC:-\e[0m}"
        read -r choice

        case "$choice" in
            0|"") return 0 ;;
            p|P)
                echo -ne "  ${C:-\e[36m}Nom du thème à prévisualiser : ${NC:-\e[0m}"
                read -r preview_name
                themes_preview "$preview_name"
                read -rp "  Entrée pour continuer..."
                ;;
            *)
                # Accepter numéro ou nom direct
                local theme_names
                theme_names=$(themes_list)
                local selected=""

                if [[ "$choice" =~ ^[0-9]+$ ]]; then
                    # Sélection par numéro
                    local arr
                    IFS=' ' read -ra arr <<< "$theme_names"
                    local idx=$(( choice - 1 ))
                    if (( idx >= 0 && idx < ${#arr[@]} )); then
                        selected="${arr[$idx]}"
                    fi
                else
                    # Sélection par nom
                    for t in $theme_names; do
                        [[ "$t" == "$choice" ]] && selected="$t" && break
                    done
                fi

                if [[ -n "$selected" ]]; then
                    themes_load "$selected"
                    # Sauvegarder dans config
                    config_set "THEME_NAME" "$selected" 2>/dev/null || true
                    THEME_NAME="$selected"
                    printf "\n${G:-\e[32m}  ✅ Thème changé : %s${NC:-\e[0m}\n\n" "$selected"
                    sleep 1
                else
                    printf "\n${R:-\e[31m}  ❌ Thème invalide : %s${NC:-\e[0m}\n\n" "$choice"
                    sleep 1
                fi
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════
#  CRÉER UN THÈME PERSONNALISÉ
# ═══════════════════════════════════════════════════════════════════════

themes_create() {
    clear
    printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}✨ CRÉER UN THÈME PERSONNALISÉ${NC:-\e[0m}\n"
    printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"

    printf "  ${D:-\e[2;37m}Codes couleurs ANSI : 30=noir 31=rouge 32=vert 33=jaune\n"
    printf "  34=bleu 35=magenta 36=cyan 37=blanc 9x=version brillante${NC:-\e[0m}\n\n"

    echo -ne "  ${C:-\e[36m}Nom du thème (ex: darkblue) : ${NC:-\e[0m}"
    read -r theme_name

    # Valider le nom
    if ! [[ "$theme_name" =~ ^[a-z0-9_-]+$ ]]; then
        printf "${R:-\e[31m}  Nom invalide (alphanumérique, tirets, underscores).${NC:-\e[0m}\n"
        return 1
    fi

    echo -ne "  Description : "
    read -r theme_desc

    echo -ne "  Couleur principale (ACCENT, ex: 36 pour cyan) : "
    read -r col_accent

    echo -ne "  Couleur secondaire (ACCENT2, ex: 34 pour bleu) : "
    read -r col_accent2

    local theme_file="${_THEMES_DIR}/${theme_name}.theme"

    cat > "$theme_file" << EOF
# ── Thème : ${theme_name^^} ─────────────────────────────────────────
THEME_NAME="${theme_name}"
THEME_DESC="${theme_desc:-Thème personnalisé}"

ACCENT='\\e[${col_accent:-36}m'
ACCENT2='\\e[${col_accent2:-34}m'
SUCCESS='\\e[32m'
WARN='\\e[33m'
DANGER='\\e[31m'
BOLD='\\e[1;37m'
DIM='\\e[2;37m'
MAGENTA='\\e[35m'
NC='\\e[0m'

R="\$DANGER"; G="\$SUCCESS"; Y="\$WARN"
B="\$ACCENT2"; C="\$ACCENT"; M="\$MAGENTA"; W="\$BOLD"

BOX_TOP="╔══════════════════════════════════════════════════════════════╗"
BOX_MID="╠══════════════════════════════════════════════════════════════╣"
BOX_BOT="╚══════════════════════════════════════════════════════════════╝"
BOX_L="║"
EOF

    printf "\n${G:-\e[32m}  ✅ Thème '%s' créé : %s${NC:-\e[0m}\n" \
           "$theme_name" "${theme_file/$HOME/~}"
    log_info "Thème créé : $theme_name" "themes" 2>/dev/null || true

    echo -ne "  ${C:-\e[36m}Appliquer ce thème maintenant ? (o/n) : ${NC:-\e[0m}"
    read -r apply
    if [[ "$apply" == "o" || "$apply" == "O" ]]; then
        themes_load "$theme_name"
        config_set "THEME_NAME" "$theme_name" 2>/dev/null || true
        THEME_NAME="$theme_name"
        printf "${G:-\e[32m}  ✅ Thème appliqué.${NC:-\e[0m}\n"
    fi
    sleep 1
}

# ─── Auto-chargement à l'inclusion ───────────────────────────────────
themes_load "${THEME_NAME:-cyber}"
