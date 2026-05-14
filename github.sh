#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# modules/github.sh — Gestionnaire GitHub : clone, pull, branches, run
# Dépend de : core/config.sh, core/logger.sh, core/ui.sh
#             core/utils.sh, core/security.sh, core/database.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

readonly GH_PROJECTS_DIR="${CFG_GITHUB_DIR:-$HOME/mon_env/github_projects}"

# ═══════════════════════════════════════════════════════════════════════
#  LISTE DES PROJETS
# ═══════════════════════════════════════════════════════════════════════

_gh_list() {
    clear
    printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}🐙 PROJETS GITHUB${NC:-\e[0m}\n"
    printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"

    local rows=""
    db_available 2>/dev/null && rows=$(db_github_list 2>/dev/null || echo "")

    if [[ -z "$rows" ]]; then
        # Fallback filesystem
        local count=0
        while IFS= read -r -d '' dir; do
            local name lang
            name=$(basename "$dir")
            lang=$(utils_detect_language "$dir")
            printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}●${NC:-\e[0m} %-24s ${D:-\e[2;37m}%s${NC:-\e[0m}\n" \
                "$name" "$lang"
            (( count++ ))
        done < <(find "$GH_PROJECTS_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
        (( count == 0 )) && \
            printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}Aucun projet. Utilise [1] pour cloner.${NC:-\e[0m}\n"
    else
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}%-4s %-20s %-10s %-7s %s${NC:-\e[0m}\n" \
            "ID" "Nom" "Langage" "Branche" "Pull"
        printf "${C:-\e[36m}║${NC:-\e[0m}  %s\n" "─────────────────────────────────────────────────────"
        while IFS='|' read -r id name _url branch lang last_pull; do
            local icon
            [[ -d "$GH_PROJECTS_DIR/$name" ]] \
                && icon="${G:-\e[32m}●${NC:-\e[0m}" \
                || icon="${R:-\e[31m}○${NC:-\e[0m}"
            printf "${C:-\e[36m}║${NC:-\e[0m}  %b ${B:-\e[34m}%-3s${NC:-\e[0m} %-20s %-10s %-7s %s\n" \
                "$icon" "$id" \
                "$(utils_truncate "$name" 19)" \
                "${lang:-?}" "${branch:-main}" \
                "${last_pull:--}"
        done <<< "$rows"
    fi

    printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
}

# ═══════════════════════════════════════════════════════════════════════
#  CLONER
# ═══════════════════════════════════════════════════════════════════════

_gh_clone() {
    clear
    ui_box_title "🐙 CLONER UN DÉPÔT GITHUB"

    echo -ne "  ${C:-\e[36m}URL GitHub : ${NC:-\e[0m}"
    read -r url
    [[ -z "$url" ]] && return

    sec_validate_github_url "$url" 2>/dev/null || return 1

    local default_name
    default_name=$(basename "$url" .git)
    echo -ne "  ${C:-\e[36m}Nom local (défaut: $default_name) : ${NC:-\e[0m}"
    read -r proj_name
    proj_name="${proj_name:-$default_name}"
    sec_validate_name "$proj_name" "Nom" 2>/dev/null || return 1

    echo -ne "  ${C:-\e[36m}Branche (défaut: main) : ${NC:-\e[0m}"
    read -r branch
    branch="${branch:-main}"

    echo -ne "  ${C:-\e[36m}Description (optionnel) : ${NC:-\e[0m}"
    read -r description

    local dest="$GH_PROJECTS_DIR/$proj_name"

    if [[ -d "$dest" ]]; then
        ui_warning "Dossier existant : ${dest/$HOME/~}"
        echo -ne "  ${Y:-\e[33m}Écraser ? (o/n) : ${NC:-\e[0m}"; read -r ow
        [[ "${ow,,}" == "o" ]] || return 0
        sec_safe_remove "$dest" "true" 2>/dev/null || return 1
    fi

    utils_check_internet || { ui_error "Pas de connexion."; sleep 2; return 1; }

    printf "\n  ${Y:-\e[33m}Clonage de %s...${NC:-\e[0m}\n\n" "$url"
    log_action "Clone : $url → $proj_name" "github"
    mkdir -p "$GH_PROJECTS_DIR"

    if git clone --branch "$branch" "$url" "$dest" 2>&1; then
        local lang
        lang=$(utils_detect_language "$dest")
        db_github_add "$proj_name" "$url" "$dest" \
            "$branch" "$lang" "$description" 2>/dev/null || true
        db_github_update_pull "$proj_name" 2>/dev/null || true
        printf "\n  ${G:-\e[32m}✅ Cloné : %s [%s]${NC:-\e[0m}\n" "$proj_name" "$lang"
        log_info "Clone OK : $proj_name ($lang)" "github"
    else
        ui_error "Échec clone. Vérifie l'URL et ta connexion."
        log_error "Échec clone : $url" "github"
    fi
    echo ""; read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  PULL (un projet)
# ═══════════════════════════════════════════════════════════════════════

_gh_pull() {
    _gh_list
    echo -ne "  ${C:-\e[36m}Projet à mettre à jour : ${NC:-\e[0m}"; read -r proj_name
    [[ -z "$proj_name" ]] && return
    sec_validate_name "$proj_name" "Nom" 2>/dev/null || return 1

    local dest="$GH_PROJECTS_DIR/$proj_name"
    [[ -d "$dest/.git" ]] || { ui_error "Dépôt git introuvable."; sleep 2; return 1; }
    utils_check_internet || { ui_error "Pas de connexion."; sleep 2; return 1; }

    printf "\n  ${Y:-\e[33m}git pull — %s...${NC:-\e[0m}\n\n" "$proj_name"
    log_action "git pull : $proj_name" "github"

    if git -C "$dest" pull 2>&1; then
        db_github_update_pull "$proj_name" 2>/dev/null || true
        printf "\n  ${G:-\e[32m}✅ %s mis à jour.${NC:-\e[0m}\n" "$proj_name"
        log_info "Pull OK : $proj_name" "github"
    else
        ui_error "Échec pull."
        log_error "Échec pull : $proj_name" "github"
    fi
    echo ""; read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  PULL ALL
# ═══════════════════════════════════════════════════════════════════════

_gh_pull_all() {
    utils_check_internet || { ui_error "Pas de connexion."; sleep 2; return 1; }
    printf "\n  ${Y:-\e[33m}Pull all — mise à jour de tous les projets...${NC:-\e[0m}\n\n"
    log_action "git pull all" "github"

    local ok=0 ko=0
    while IFS= read -r -d '' dir; do
        local name; name=$(basename "$dir")
        if [[ -d "$dir/.git" ]]; then
            printf "  ${B:-\e[34m}→${NC:-\e[0m} %-24s " "$name"
            if git -C "$dir" pull --quiet 2>/dev/null; then
                printf "${G:-\e[32m}✅${NC:-\e[0m}\n"
                db_github_update_pull "$name" 2>/dev/null || true
                (( ok++ ))
            else
                printf "${R:-\e[31m}❌${NC:-\e[0m}\n"
                (( ko++ ))
            fi
        fi
    done < <(find "$GH_PROJECTS_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

    printf "\n  ${G:-\e[32m}%d OK${NC:-\e[0m}  ${R:-\e[31m}%d KO${NC:-\e[0m}\n" "$ok" "$ko"
    log_info "Pull all : $ok OK / $ko KO" "github"
    echo ""; read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  LANCER UN PROJET
# ═══════════════════════════════════════════════════════════════════════

_gh_run() {
    _gh_list
    echo -ne "  ${C:-\e[36m}Projet à lancer : ${NC:-\e[0m}"; read -r proj_name
    [[ -z "$proj_name" ]] && return
    sec_validate_name "$proj_name" "Nom" 2>/dev/null || return 1

    local dest="$GH_PROJECTS_DIR/$proj_name"
    [[ -d "$dest" ]] || { ui_error "Projet introuvable."; sleep 2; return 1; }

    local lang run_cmd
    lang=$(utils_detect_language "$dest")
    run_cmd=$(utils_get_run_cmd "$lang" "$dest")

    printf "\n  ${B:-\e[34m}Langage  :${NC:-\e[0m} %s\n" "$lang"
    printf "  ${B:-\e[34m}Commande :${NC:-\e[0m} %s\n\n" "${run_cmd:-?}"

    if [[ -z "$run_cmd" ]]; then
        echo -ne "  ${C:-\e[36m}Commande : ${NC:-\e[0m}"; read -r run_cmd
        [[ -z "$run_cmd" ]] && return
        sec_safe_command "$run_cmd" 2>/dev/null || return 1
    fi

    printf "  ${Y:-\e[33m}Lancement dans %s...${NC:-\e[0m}\n\n" "${dest/$HOME/~}"
    log_action "Run GitHub : $proj_name — $run_cmd" "github"
    cd "$dest" && eval "$run_cmd"
    echo ""; read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  STATUT GIT
# ═══════════════════════════════════════════════════════════════════════

_gh_status() {
    _gh_list
    echo -ne "  ${C:-\e[36m}Projet : ${NC:-\e[0m}"; read -r proj_name
    [[ -z "$proj_name" ]] && return

    local dest="$GH_PROJECTS_DIR/$proj_name"
    [[ -d "$dest/.git" ]] || { ui_error "Dépôt git introuvable."; sleep 2; return 1; }

    clear
    ui_box_title "📋 STATUT — $proj_name"
    printf "  ${B:-\e[34m}Branche :${NC:-\e[0m} %s\n" \
        "$(git -C "$dest" branch --show-current 2>/dev/null || echo '?')"
    printf "  ${B:-\e[34m}Commit  :${NC:-\e[0m} %s\n\n" \
        "$(git -C "$dest" log --oneline -1 2>/dev/null || echo '?')"

    git -C "$dest" status --short 2>/dev/null | while IFS= read -r line; do
        local prefix="${line:0:2}"
        case "$prefix" in
            " M"|"M ") printf "  ${Y:-\e[33m}%s${NC:-\e[0m}\n" "$line" ;;
            "??")      printf "  ${D:-\e[2;37m}%s${NC:-\e[0m}\n" "$line" ;;
            "A "|" A") printf "  ${G:-\e[32m}%s${NC:-\e[0m}\n" "$line" ;;
            "D "|" D") printf "  ${R:-\e[31m}%s${NC:-\e[0m}\n" "$line" ;;
            *)         printf "  %s\n" "$line" ;;
        esac
    done || printf "  ${G:-\e[32m}Dépôt propre.${NC:-\e[0m}\n"

    echo ""; read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  BRANCHES
# ═══════════════════════════════════════════════════════════════════════

_gh_branches() {
    _gh_list
    echo -ne "  ${C:-\e[36m}Projet : ${NC:-\e[0m}"; read -r proj_name
    [[ -z "$proj_name" ]] && return

    local dest="$GH_PROJECTS_DIR/$proj_name"
    [[ -d "$dest/.git" ]] || { ui_error "Dépôt git introuvable."; sleep 2; return 1; }

    clear
    ui_box_title "🌿 BRANCHES — $proj_name"
    printf "  ${W:-\e[1;37m}Branches locales :${NC:-\e[0m}\n"
    git -C "$dest" branch 2>/dev/null | while IFS= read -r b; do
        if [[ "$b" == \** ]]; then
            printf "    ${G:-\e[32m}▶ %s (actuelle)${NC:-\e[0m}\n" "${b#\* }"
        else
            printf "    ${D:-\e[2;37m}  %s${NC:-\e[0m}\n" "${b# }"
        fi
    done

    printf "\n  ${G:-\e[32m}[1]${NC:-\e[0m} Changer  ${G:-\e[32m}[2]${NC:-\e[0m} Créer  "
    printf "${G:-\e[32m}[3]${NC:-\e[0m} Distantes  ${G:-\e[32m}[0]${NC:-\e[0m} Retour\n\n"
    echo -ne "  ${C:-\e[36m}Choix : ${NC:-\e[0m}"; read -r ch

    case "$ch" in
        1)
            echo -ne "  ${C:-\e[36m}Branche : ${NC:-\e[0m}"; read -r bn
            sec_validate_name "$bn" "Branche" 2>/dev/null || return 1
            git -C "$dest" checkout "$bn" 2>&1 \
                && ui_success "Branche : $bn" || ui_error "Échec checkout"
            sleep 2
            ;;
        2)
            echo -ne "  ${C:-\e[36m}Nouvelle branche : ${NC:-\e[0m}"; read -r bn
            sec_validate_name "$bn" "Branche" 2>/dev/null || return 1
            git -C "$dest" checkout -b "$bn" 2>&1 \
                && ui_success "Créée : $bn" || ui_error "Échec"
            sleep 2
            ;;
        3)
            printf "\n  ${W:-\e[1;37m}Branches distantes :${NC:-\e[0m}\n"
            git -C "$dest" branch -r 2>/dev/null | \
                while IFS= read -r b; do
                    printf "    ${D:-\e[2;37m}%s${NC:-\e[0m}\n" "$b"
                done
            echo ""; read -rp "  Entrée..."
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════
#  RECHERCHE
# ═══════════════════════════════════════════════════════════════════════

_gh_search() {
    echo -ne "\n  ${C:-\e[36m}Terme de recherche : ${NC:-\e[0m}"; read -r term
    [[ -z "$term" ]] && return
    sec_safe_string "$term" "Recherche" 2>/dev/null || return 1

    printf "\n  ${Y:-\e[33m}Résultats pour '%s' :${NC:-\e[0m}\n\n" "$term"

    if db_available 2>/dev/null; then
        local results
        results=$(db_github_search "$term" 2>/dev/null || echo "")
        if [[ -n "$results" ]]; then
            while IFS='|' read -r id name _url lang desc; do
                printf "  ${G:-\e[32m}[%s]${NC:-\e[0m} %-20s ${B:-\e[34m}%-10s${NC:-\e[0m} %s\n" \
                    "$id" "$name" "$lang" "$(utils_truncate "${desc:-}" 28)"
            done <<< "$results"
        else
            printf "  ${D:-\e[2;37m}Aucun résultat.${NC:-\e[0m}\n"
        fi
    else
        find "$GH_PROJECTS_DIR" -mindepth 1 -maxdepth 1 -type d \
            -iname "*${term}*" 2>/dev/null | \
        while IFS= read -r d; do
            printf "  ${G:-\e[32m}●${NC:-\e[0m} %s\n" "$(basename "$d")"
        done
    fi
    echo ""; read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  SUPPRIMER
# ═══════════════════════════════════════════════════════════════════════

_gh_delete() {
    _gh_list
    echo -ne "  ${C:-\e[36m}Projet à supprimer : ${NC:-\e[0m}"; read -r proj_name
    [[ -z "$proj_name" ]] && return
    sec_validate_name "$proj_name" "Nom" 2>/dev/null || return 1

    sec_safe_remove "$GH_PROJECTS_DIR/$proj_name" 2>/dev/null || return 1
    db_github_delete "$proj_name" 2>/dev/null || true
    ui_success "Projet '$proj_name' supprimé."
    log_action "GitHub projet supprimé : $proj_name" "github"
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#  MENU PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════

github_menu() {
    log_action "Module GitHub ouvert" "github"

    while true; do
        clear
        _gh_list

        printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}🐙 ACTIONS GITHUB${NC:-\e[0m}\n"
        printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[1]${NC:-\e[0m} Cloner un dépôt\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[2]${NC:-\e[0m} Pull — mettre à jour\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[3]${NC:-\e[0m} Pull ALL\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[4]${NC:-\e[0m} Lancer un projet\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[5]${NC:-\e[0m} Statut git\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[6]${NC:-\e[0m} Gestion des branches\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[7]${NC:-\e[0m} Rechercher\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[8]${NC:-\e[0m} Supprimer un projet\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[0]${NC:-\e[0m} Retour\n"
        printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
        echo -ne "  ${C:-\e[36m}Choix : ${NC:-\e[0m}"; read -r choice

        case "$choice" in
            1) _gh_clone   ;;
            2) _gh_pull    ;;
            3) _gh_pull_all ;;
            4) _gh_run     ;;
            5) _gh_status  ;;
            6) _gh_branches ;;
            7) _gh_search  ;;
            8) _gh_delete  ;;
            0|"") log_action "Module GitHub fermé" "github"; return 0 ;;
            *) ui_warning "Choix invalide"; sleep 1 ;;
        esac
    done
}
