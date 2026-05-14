#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# modules/backup.sh — Backup automatique : configs, BDD, thèmes, plugins
# Dépend de : core/config.sh, core/logger.sh, core/ui.sh
#             core/utils.sh, core/security.sh, core/database.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

readonly BACKUP_BASE="${CFG_BACKUPS_DIR:-$HOME/mon_env/backups}"
readonly BACKUP_MAX_COUNT=10   # Garder les 10 derniers backups

# ═══════════════════════════════════════════════════════════════════════
#  LISTE DES BACKUPS
# ═══════════════════════════════════════════════════════════════════════

_bak_list() {
    clear
    printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}💾 BACKUPS DISPONIBLES${NC:-\e[0m}\n"
    printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"

    local count=0
    while IFS= read -r entry; do
        local name size
        name=$(basename "$entry")
        size=$(du -sh "$entry" 2>/dev/null | awk '{print $1}' || echo "?")
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}●${NC:-\e[0m} %-38s ${D:-\e[2;37m}%s${NC:-\e[0m}\n" \
            "$name" "$size"
        (( count++ ))
    done < <(find "$BACKUP_BASE" -mindepth 1 -maxdepth 1 \
                \( -type d -o -name "*.tar.gz" -o -name "*.db" \) \
                2>/dev/null | sort -r)

    if (( count == 0 )); then
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}Aucun backup trouvé.${NC:-\e[0m}\n"
    fi

    printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}Total : %d backup(s)${NC:-\e[0m}\n" "$count"
    printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
}

# ═══════════════════════════════════════════════════════════════════════
#  BACKUP COMPLET (tout le dashboard)
# ═══════════════════════════════════════════════════════════════════════

_bak_full() {
    local ts
    ts=$(utils_timestamp)
    local backup_name="backup_full_${ts}"
    local backup_path="$BACKUP_BASE/$backup_name"
    local archive="${backup_path}.tar.gz"

    mkdir -p "$BACKUP_BASE"

    printf "\n  ${Y:-\e[33m}Backup complet en cours...${NC:-\e[0m}\n\n"
    log_action "Backup complet démarré" "backup"

    local install_dir="${CFG_INSTALL_DIR:-$HOME/mon_env}"

    # Éléments à sauvegarder
    local items_to_backup=(
        "$install_dir/configs"
        "$install_dir/database"
        "$install_dir/themes"
        "$install_dir/plugins"
        "$install_dir/logs"
    )

    # Créer dossier temporaire
    mkdir -p "$backup_path"

    local ok=0 ko=0
    for item in "${items_to_backup[@]}"; do
        local item_name
        item_name=$(basename "$item")
        printf "  ${B:-\e[34m}→${NC:-\e[0m} %-20s " "$item_name"
        if [[ -e "$item" ]]; then
            cp -r "$item" "$backup_path/" 2>/dev/null && {
                printf "${G:-\e[32m}✅${NC:-\e[0m}\n"
                (( ok++ ))
            } || {
                printf "${R:-\e[31m}❌${NC:-\e[0m}\n"
                (( ko++ ))
            }
        else
            printf "${D:-\e[2;37m}— absent${NC:-\e[0m}\n"
        fi
    done

    # Ajouter aussi ~/.ssh/config si présent
    if [[ -f "$HOME/.ssh/config" ]]; then
        mkdir -p "$backup_path/ssh_config"
        cp "$HOME/.ssh/config" "$backup_path/ssh_config/" 2>/dev/null && {
            printf "  ${B:-\e[34m}→${NC:-\e[0m} %-20s ${G:-\e[32m}✅${NC:-\e[0m}\n" "ssh_config"
            (( ok++ ))
        }
    fi

    # Métadonnées du backup
    cat > "$backup_path/backup_info.txt" << EOF
Backup Cyber Dashboard Termux
Date    : $(utils_timestamp_human)
Version : ${CFG_VERSION:-1.0}
Pseudo  : ${PSEUDO_NAME:-Shadow}
Items OK: $ok
Items KO: $ko
EOF

    # Compresser en tar.gz
    printf "\n  ${D:-\e[2;37m}Compression en tar.gz...${NC:-\e[0m}\n"
    if tar -czf "$archive" -C "$BACKUP_BASE" "$backup_name" 2>/dev/null; then
        rm -rf "$backup_path"
        local size
        size=$(du -sh "$archive" 2>/dev/null | awk '{print $1}')
        printf "\n  ${G:-\e[32m}╔══════════════════════════════════════════╗${NC:-\e[0m}\n"
        printf "  ${G:-\e[32m}║  ✅ Backup complet créé !                ║${NC:-\e[0m}\n"
        printf "  ${G:-\e[32m}║  %-42s║${NC:-\e[0m}\n" "Fichier : ${archive/$HOME/~}"
        printf "  ${G:-\e[32m}║  Taille : %-31s║${NC:-\e[0m}\n" "$size"
        printf "  ${G:-\e[32m}║  Éléments : %d OK / %d KO%-18s║${NC:-\e[0m}\n" "$ok" "$ko" ""
        printf "  ${G:-\e[32m}╚══════════════════════════════════════════╝${NC:-\e[0m}\n"
        log_info "Backup complet OK : $archive ($size)" "backup"
        db_log_action "backup_full" "backup" "ok" "$archive" 2>/dev/null || true
    else
        rm -rf "$backup_path"
        ui_error "Compression échouée."
        log_error "Échec compression backup" "backup"
    fi

    _bak_rotate
    echo ""; read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  BACKUP BASE DE DONNÉES UNIQUEMENT
# ═══════════════════════════════════════════════════════════════════════

_bak_database() {
    printf "\n  ${Y:-\e[33m}Backup de la base de données...${NC:-\e[0m}\n"
    log_action "Backup BDD" "backup"

    db_backup 2>/dev/null || {
        ui_error "Échec backup BDD."
        sleep 2; return 1
    }

    log_info "Backup BDD OK" "backup"
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#  BACKUP CONFIGS UNIQUEMENT
# ═══════════════════════════════════════════════════════════════════════

_bak_configs() {
    local ts
    ts=$(utils_timestamp)
    local archive="$BACKUP_BASE/configs_${ts}.tar.gz"
    mkdir -p "$BACKUP_BASE"

    printf "\n  ${Y:-\e[33m}Backup des configurations...${NC:-\e[0m}\n"

    local configs_dir="${CFG_CONFIGS_DIR:-$HOME/mon_env/configs}"
    local themes_dir="${CFG_THEMES_DIR:-$HOME/mon_env/themes}"

    if tar -czf "$archive" \
        -C "$(dirname "$configs_dir")" "$(basename "$configs_dir")" \
        -C "$(dirname "$themes_dir")" "$(basename "$themes_dir")" \
        2>/dev/null; then
        local size
        size=$(du -sh "$archive" 2>/dev/null | awk '{print $1}')
        printf "  ${G:-\e[32m}✅ Configs sauvegardées : %s (%s)${NC:-\e[0m}\n" \
            "${archive/$HOME/~}" "$size"
        log_info "Backup configs OK : $archive" "backup"
    else
        ui_error "Échec backup configs."
        log_error "Échec backup configs" "backup"
    fi
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#  RESTAURATION
# ═══════════════════════════════════════════════════════════════════════

_bak_restore() {
    _bak_list

    echo -ne "  ${C:-\e[36m}Nom du backup à restaurer (sans chemin) : ${NC:-\e[0m}"
    read -r backup_name
    [[ -z "$backup_name" ]] && return

    sec_validate_name "$backup_name" "Backup" 2>/dev/null || return 1

    local backup_path="$BACKUP_BASE/$backup_name"

    # Chercher .tar.gz ou dossier
    if [[ -f "${backup_path}.tar.gz" ]]; then
        backup_path="${backup_path}.tar.gz"
    elif [[ -f "$backup_path" ]]; then
        : # Fichier direct (ex: .db)
    elif [[ ! -d "$backup_path" ]]; then
        ui_error "Backup introuvable : $backup_name"; sleep 2; return 1
    fi

    printf "\n  ${R:-\e[31m}⚠️  Restauration depuis : %s${NC:-\e[0m}\n" \
        "${backup_path/$HOME/~}"
    printf "  ${R:-\e[31m}⚠️  Les données actuelles seront écrasées !${NC:-\e[0m}\n\n"
    echo -ne "  ${R:-\e[31m}Confirmer la restauration ? (tape RESTAURER) : ${NC:-\e[0m}"
    read -r confirm
    [[ "$confirm" != "RESTAURER" ]] && \
        printf "${Y:-\e[33m}  Restauration annulée.${NC:-\e[0m}\n" && sleep 1 && return

    log_action "Restauration depuis : $backup_path" "backup"
    log_security "Restauration backup : $backup_path" "backup"

    # Backup préventif avant restauration
    printf "  ${D:-\e[2;37m}Sauvegarde préventive avant restauration...${NC:-\e[0m}\n"
    _bak_database 2>/dev/null || true

    local install_dir="${CFG_INSTALL_DIR:-$HOME/mon_env}"

    if [[ "$backup_path" == *.tar.gz ]]; then
        printf "  ${Y:-\e[33m}Décompression...${NC:-\e[0m}\n"
        local tmp_dir
        tmp_dir=$(mktemp -d /tmp/cyd_restore_XXXXX)

        if tar -xzf "$backup_path" -C "$tmp_dir" 2>/dev/null; then
            # Restaurer configs
            [[ -d "$tmp_dir"/*/configs ]] && \
                cp -r "$tmp_dir"/*/configs "$install_dir/" 2>/dev/null && \
                printf "  ${G:-\e[32m}✅ configs restaurées${NC:-\e[0m}\n"
            # Restaurer database
            [[ -d "$tmp_dir"/*/database ]] && \
                cp -r "$tmp_dir"/*/database "$install_dir/" 2>/dev/null && \
                printf "  ${G:-\e[32m}✅ database restaurée${NC:-\e[0m}\n"
            # Restaurer thèmes
            [[ -d "$tmp_dir"/*/themes ]] && \
                cp -r "$tmp_dir"/*/themes "$install_dir/" 2>/dev/null && \
                printf "  ${G:-\e[32m}✅ thèmes restaurés${NC:-\e[0m}\n"
            # Restaurer plugins
            [[ -d "$tmp_dir"/*/plugins ]] && \
                cp -r "$tmp_dir"/*/plugins "$install_dir/" 2>/dev/null && \
                printf "  ${G:-\e[32m}✅ plugins restaurés${NC:-\e[0m}\n"
            rm -rf "$tmp_dir"
            printf "\n  ${G:-\e[32m}✅ Restauration terminée.${NC:-\e[0m}\n"
            log_info "Restauration OK depuis : $backup_path" "backup"
        else
            rm -rf "$tmp_dir"
            ui_error "Échec décompression."
            log_error "Échec restauration : $backup_path" "backup"
        fi
    elif [[ "$backup_path" == *.db ]]; then
        db_restore "$backup_path" 2>/dev/null
    fi

    echo ""; read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  ROTATION DES BACKUPS (garder les N derniers)
# ═══════════════════════════════════════════════════════════════════════

_bak_rotate() {
    local backups count_to_delete

    # Compter les backups
    mapfile -t backups < <(find "$BACKUP_BASE" -maxdepth 1 \
        \( -name "backup_full_*.tar.gz" -o -name "backup_full_*" \) \
        2>/dev/null | sort)

    local total=${#backups[@]}
    count_to_delete=$(( total - BACKUP_MAX_COUNT ))

    if (( count_to_delete > 0 )); then
        printf "  ${D:-\e[2;37m}Rotation : suppression de %d ancien(s) backup(s)...${NC:-\e[0m}\n" \
            "$count_to_delete"
        for (( i=0; i<count_to_delete; i++ )); do
            rm -rf "${backups[$i]}" 2>/dev/null && \
                log_info "Backup supprimé (rotation) : ${backups[$i]}" "backup"
        done
    fi
}

# ═══════════════════════════════════════════════════════════════════════
#  SUPPRIMER UN BACKUP
# ═══════════════════════════════════════════════════════════════════════

_bak_delete() {
    _bak_list

    echo -ne "  ${C:-\e[36m}Nom du backup à supprimer : ${NC:-\e[0m}"
    read -r bak_name
    [[ -z "$bak_name" ]] && return
    sec_validate_name "$bak_name" "Backup" 2>/dev/null || return 1

    local bak_path="$BACKUP_BASE/$bak_name"
    [[ ! -e "$bak_path" && ! -f "${bak_path}.tar.gz" ]] && {
        ui_error "Backup introuvable."; sleep 2; return 1
    }

    [[ -f "${bak_path}.tar.gz" ]] && bak_path="${bak_path}.tar.gz"

    printf "  ${Y:-\e[33m}Supprimer '%s' ? (o/n) : ${NC:-\e[0m}" "$bak_name"
    read -r confirm
    [[ "${confirm,,}" != "o" ]] && return

    sec_safe_remove "$bak_path" "true" 2>/dev/null && {
        ui_success "Backup supprimé."
        log_action "Backup supprimé : $bak_name" "backup"
    }
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#  BACKUP AUTOMATIQUE (appelable depuis un cron ou au démarrage)
# ═══════════════════════════════════════════════════════════════════════

backup_auto() {
    log_info "Backup automatique lancé" "backup"
    _bak_database 2>/dev/null || true
    _bak_rotate
    log_info "Backup automatique terminé" "backup"
}

# ═══════════════════════════════════════════════════════════════════════
#  INFORMATIONS ESPACE
# ═══════════════════════════════════════════════════════════════════════

_bak_info() {
    clear
    ui_box_title "ℹ️  INFORMATIONS BACKUPS"

    local backup_size total_size
    backup_size=$(du -sh "$BACKUP_BASE" 2>/dev/null | awk '{print $1}' || echo "?")
    total_size=$(df -h "$HOME" 2>/dev/null | awk 'NR==2{print $2}' || echo "?")
    local free_size
    free_size=$(df -h "$HOME" 2>/dev/null | awk 'NR==2{print $4}' || echo "?")

    local count
    count=$(find "$BACKUP_BASE" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l || echo 0)

    printf "  ${B:-\e[34m}Dossier backups   :${NC:-\e[0m} %s\n" \
        "${BACKUP_BASE/$HOME/~}"
    printf "  ${B:-\e[34m}Taille backups    :${NC:-\e[0m} %s\n" "$backup_size"
    printf "  ${B:-\e[34m}Nombre de backups :${NC:-\e[0m} %d / %d max\n" \
        "$count" "$BACKUP_MAX_COUNT"
    printf "  ${B:-\e[34m}Espace disque     :${NC:-\e[0m} %s libre / %s total\n\n" \
        "$free_size" "$total_size"

    printf "  ${W:-\e[1;37m}Contenu sauvegardé dans un backup complet :${NC:-\e[0m}\n"
    printf "  ${D:-\e[2;37m}  configs/ themes/ database/ plugins/ logs/ ssh_config${NC:-\e[0m}\n\n"

    read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  MENU PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════

backup_menu() {
    log_action "Module backup ouvert" "backup"
    mkdir -p "$BACKUP_BASE"

    while true; do
        clear
        _bak_list

        printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}💾 ACTIONS BACKUP${NC:-\e[0m}\n"
        printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[1]${NC:-\e[0m} Backup complet (tout le dashboard)\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[2]${NC:-\e[0m} Backup base de données uniquement\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[3]${NC:-\e[0m} Backup configurations\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[4]${NC:-\e[0m} Restaurer un backup\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[5]${NC:-\e[0m} Supprimer un backup\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[6]${NC:-\e[0m} Informations et espace\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[0]${NC:-\e[0m} Retour\n"
        printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
        echo -ne "  ${C:-\e[36m}Choix : ${NC:-\e[0m}"; read -r choice

        case "$choice" in
            1) _bak_full     ;;
            2) _bak_database ;;
            3) _bak_configs  ;;
            4) _bak_restore  ;;
            5) _bak_delete   ;;
            6) _bak_info     ;;
            0|"") log_action "Module backup fermé" "backup"; return 0 ;;
            *) ui_warning "Choix invalide"; sleep 1 ;;
        esac
    done
}
