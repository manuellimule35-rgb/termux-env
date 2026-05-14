#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# modules/ssh.sh — Gestionnaire SSH : hôtes, connexions, clés
# Dépend de : core/config.sh, core/logger.sh, core/ui.sh
#             core/utils.sh, core/security.sh, core/database.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

readonly SSH_KEYS_DIR="$HOME/.ssh"

# ═══════════════════════════════════════════════════════════════════════
#  LISTE DES HÔTES
# ═══════════════════════════════════════════════════════════════════════

_ssh_list() {
    clear
    printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}🔑 HÔTES SSH${NC:-\e[0m}\n"
    printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"

    local rows=""
    db_available 2>/dev/null && rows=$(db_ssh_list 2>/dev/null || echo "")

    if [[ -z "$rows" ]]; then
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}Aucun hôte SSH enregistré.${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}Utilise [1] pour en ajouter un.${NC:-\e[0m}\n"
    else
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}%-4s %-12s %-16s %-22s %s${NC:-\e[0m}\n" \
            "ID" "Alias" "Utilisateur" "Hôte:Port" "Description"
        printf "${C:-\e[36m}║${NC:-\e[0m}  %s\n" \
            "──────────────────────────────────────────────────────────"
        while IFS='|' read -r id alias username host port desc; do
            printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}%-4s${NC:-\e[0m} %-12s %-16s %-22s %s\n" \
                "$id" \
                "$(utils_truncate "$alias" 11)" \
                "$(utils_truncate "$username" 15)" \
                "${host}:${port}" \
                "$(utils_truncate "${desc:-}" 18)"
        done <<< "$rows"
    fi

    printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
}

# ═══════════════════════════════════════════════════════════════════════
#  AJOUTER UN HÔTE
# ═══════════════════════════════════════════════════════════════════════

_ssh_add() {
    clear
    ui_box_title "➕ AJOUTER UN HÔTE SSH"

    echo -ne "  ${C:-\e[36m}Alias (ex: mon-vps) : ${NC:-\e[0m}"; read -r alias_name
    [[ -z "$alias_name" ]] && return
    sec_validate_name "$alias_name" "Alias" 2>/dev/null || return 1

    echo -ne "  ${C:-\e[36m}Utilisateur : ${NC:-\e[0m}"; read -r username
    [[ -z "$username" ]] && return
    sec_safe_string "$username" "Utilisateur" 2>/dev/null || return 1

    echo -ne "  ${C:-\e[36m}Hôte (IP ou hostname) : ${NC:-\e[0m}"; read -r host
    [[ -z "$host" ]] && return
    sec_validate_ssh_host "$host" 2>/dev/null || return 1

    echo -ne "  ${C:-\e[36m}Port (défaut: 22) : ${NC:-\e[0m}"; read -r port
    port="${port:-22}"
    utils_is_port "$port" || { ui_error "Port invalide."; sleep 2; return 1; }

    echo -ne "  ${C:-\e[36m}Chemin clé privée (optionnel, ex: ~/.ssh/id_rsa) : ${NC:-\e[0m}"
    read -r key_path
    if [[ -n "$key_path" ]]; then
        key_path="${key_path/#\~/$HOME}"
        sec_safe_path "$key_path" 2>/dev/null || return 1
    fi

    echo -ne "  ${C:-\e[36m}Description : ${NC:-\e[0m}"; read -r description

    db_ssh_add "$alias_name" "$username" "$host" "$port" \
        "$key_path" "$description" 2>/dev/null || {
        ui_error "Échec ajout (alias peut-être déjà utilisé)."
        sleep 2; return 1
    }

    # Ajouter aussi dans ~/.ssh/config pour usage natif
    _ssh_update_config "$alias_name" "$username" "$host" "$port" "$key_path"

    ui_success "Hôte '$alias_name' ajouté : $username@$host:$port"
    log_action "SSH host ajouté : $alias_name → $username@$host:$port" "ssh"
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#  METTRE À JOUR ~/.ssh/config
# ═══════════════════════════════════════════════════════════════════════

_ssh_update_config() {
    local alias_name="$1"
    local username="$2"
    local host="$3"
    local port="${4:-22}"
    local key_path="${5:-}"

    local ssh_config="$SSH_KEYS_DIR/config"
    mkdir -p "$SSH_KEYS_DIR"
    chmod 700 "$SSH_KEYS_DIR"

    # Vérifier si l'entrée existe déjà dans config
    if grep -q "^Host ${alias_name}$" "$ssh_config" 2>/dev/null; then
        return 0  # Déjà présent
    fi

    {
        echo ""
        echo "# ── Cyber Dashboard — $alias_name ──"
        echo "Host ${alias_name}"
        echo "    HostName ${host}"
        echo "    User ${username}"
        echo "    Port ${port}"
        [[ -n "$key_path" && -f "$key_path" ]] && echo "    IdentityFile ${key_path}"
        echo "    ServerAliveInterval 60"
        echo "    ServerAliveCountMax 3"
    } >> "$ssh_config"

    chmod 600 "$ssh_config"
}

# ═══════════════════════════════════════════════════════════════════════
#  CONNECTER
# ═══════════════════════════════════════════════════════════════════════

_ssh_connect() {
    _ssh_list
    echo -ne "  ${C:-\e[36m}Alias de l'hôte à connecter : ${NC:-\e[0m}"; read -r alias_name
    [[ -z "$alias_name" ]] && return
    sec_validate_name "$alias_name" "Alias" 2>/dev/null || return 1

    local row=""
    db_available 2>/dev/null && row=$(db_ssh_get "$alias_name" 2>/dev/null || echo "")

    if [[ -z "$row" ]]; then
        # Tentative directe via ~/.ssh/config
        printf "\n  ${Y:-\e[33m}Connexion SSH via alias : %s...${NC:-\e[0m}\n\n" "$alias_name"
        log_action "Connexion SSH : $alias_name" "ssh"
        log_security "Connexion SSH initiée : $alias_name" "ssh"
        ssh "$alias_name"
        return
    fi

    local _id _alias username host port key_path _desc
    IFS='|' read -r _id _alias username host port key_path _desc <<< "$row"

    printf "\n  ${B:-\e[34m}Connexion :${NC:-\e[0m} %s@%s:%s\n\n" \
        "$username" "$host" "$port"
    log_action "Connexion SSH : $username@$host:$port" "ssh"
    log_security "Connexion SSH : $username@$host:$port" "ssh"

    # Construire la commande SSH
    local ssh_cmd="ssh -p ${port}"
    [[ -n "$key_path" && -f "$key_path" ]] && ssh_cmd+=" -i ${key_path}"
    ssh_cmd+=" ${username}@${host}"

    eval "$ssh_cmd"
    local code=$?
    echo ""
    (( code == 0 )) \
        && printf "  ${G:-\e[32m}✅ Session SSH terminée.${NC:-\e[0m}\n" \
        || printf "  ${Y:-\e[33m}⚠️  Session terminée avec code %d.${NC:-\e[0m}\n" "$code"
    read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  SUPPRIMER UN HÔTE
# ═══════════════════════════════════════════════════════════════════════

_ssh_delete() {
    _ssh_list
    echo -ne "  ${C:-\e[36m}Alias à supprimer : ${NC:-\e[0m}"; read -r alias_name
    [[ -z "$alias_name" ]] && return
    sec_validate_name "$alias_name" "Alias" 2>/dev/null || return 1

    printf "  ${Y:-\e[33m}Supprimer '%s' ? (o/n) : ${NC:-\e[0m}" "$alias_name"
    read -r confirm
    [[ "${confirm,,}" != "o" ]] && return

    db_ssh_delete "$alias_name" 2>/dev/null || true

    # Retirer aussi de ~/.ssh/config
    local ssh_config="$SSH_KEYS_DIR/config"
    if [[ -f "$ssh_config" ]] && grep -q "^Host ${alias_name}$" "$ssh_config"; then
        sed -i "/# ── Cyber Dashboard — ${alias_name}/,/ServerAliveCountMax/d" \
            "$ssh_config" 2>/dev/null || true
    fi

    ui_success "Hôte '$alias_name' supprimé."
    log_action "SSH host supprimé : $alias_name" "ssh"
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#  GESTION DES CLÉS SSH
# ═══════════════════════════════════════════════════════════════════════

_ssh_keys_menu() {
    while true; do
        clear
        ui_box_title "🗝️  GESTION DES CLÉS SSH"

        # Lister les clés existantes
        printf "  ${W:-\e[1;37m}Clés présentes dans ~/.ssh/ :${NC:-\e[0m}\n\n"
        local found=false
        while IFS= read -r key; do
            local key_name
            key_name=$(basename "$key")
            printf "  ${G:-\e[32m}●${NC:-\e[0m} %s\n" "$key_name"
            found=true
        done < <(find "$SSH_KEYS_DIR" -maxdepth 1 \
                    \( -name "id_rsa" -o -name "id_ed25519" -o -name "*.pem" \) \
                    2>/dev/null)
        $found || printf "  ${D:-\e[2;37m}Aucune clé trouvée.${NC:-\e[0m}\n"

        printf "\n  ${G:-\e[32m}[1]${NC:-\e[0m} Générer une clé ED25519 (recommandé)\n"
        printf "  ${G:-\e[32m}[2]${NC:-\e[0m} Générer une clé RSA 4096\n"
        printf "  ${G:-\e[32m}[3]${NC:-\e[0m} Afficher la clé publique\n"
        printf "  ${G:-\e[32m}[4]${NC:-\e[0m} Copier la clé publique (clipboard)\n"
        printf "  ${G:-\e[32m}[0]${NC:-\e[0m} Retour\n\n"
        echo -ne "  ${C:-\e[36m}Choix : ${NC:-\e[0m}"; read -r choice

        case "$choice" in
            1) _ssh_gen_key "ed25519" ;;
            2) _ssh_gen_key "rsa"     ;;
            3) _ssh_show_pubkey       ;;
            4) _ssh_copy_pubkey       ;;
            0|"") return 0            ;;
        esac
    done
}

_ssh_gen_key() {
    local type="${1:-ed25519}"
    echo -ne "  ${C:-\e[36m}Nom du fichier clé (défaut: id_${type}) : ${NC:-\e[0m}"
    read -r key_name
    key_name="${key_name:-id_${type}}"
    sec_validate_name "$key_name" "Nom clé" 2>/dev/null || return 1

    local key_path="$SSH_KEYS_DIR/$key_name"

    if [[ -f "$key_path" ]]; then
        ui_warning "Clé existante : $key_name"
        echo -ne "  ${Y:-\e[33m}Écraser ? (o/n) : ${NC:-\e[0m}"; read -r ow
        [[ "${ow,,}" != "o" ]] && return
    fi

    echo -ne "  ${C:-\e[36m}Email/commentaire : ${NC:-\e[0m}"; read -r email
    email="${email:-cyber_dashboard}"

    mkdir -p "$SSH_KEYS_DIR"; chmod 700 "$SSH_KEYS_DIR"

    printf "\n  ${Y:-\e[33m}Génération de la clé %s...${NC:-\e[0m}\n" "$type"
    log_action "Génération clé SSH $type : $key_name" "ssh"

    if [[ "$type" == "ed25519" ]]; then
        ssh-keygen -t ed25519 -C "$email" -f "$key_path" 2>&1
    else
        ssh-keygen -t rsa -b 4096 -C "$email" -f "$key_path" 2>&1
    fi

    [[ -f "$key_path" ]] && {
        chmod 600 "$key_path"
        chmod 644 "${key_path}.pub" 2>/dev/null || true
        ui_success "Clé générée : ${key_path/$HOME/~}"
    }
    echo ""; read -rp "  Entrée..."
}

_ssh_show_pubkey() {
    echo -ne "  ${C:-\e[36m}Fichier clé (sans .pub, défaut: id_ed25519) : ${NC:-\e[0m}"
    read -r key_name
    key_name="${key_name:-id_ed25519}"
    local pub="${SSH_KEYS_DIR}/${key_name}.pub"

    if [[ ! -f "$pub" ]]; then
        ui_error "Clé publique introuvable : $pub"; sleep 2; return
    fi

    printf "\n  ${Y:-\e[33m}Clé publique — %s :${NC:-\e[0m}\n\n" "$key_name"
    cat "$pub"
    echo ""; read -rp "  Entrée..."
}

_ssh_copy_pubkey() {
    echo -ne "  ${C:-\e[36m}Clé à copier (défaut: id_ed25519) : ${NC:-\e[0m}"
    read -r key_name
    key_name="${key_name:-id_ed25519}"
    local pub="${SSH_KEYS_DIR}/${key_name}.pub"

    [[ -f "$pub" ]] || { ui_error "Clé introuvable."; sleep 2; return; }

    if utils_clipboard_copy "$(cat "$pub")"; then
        ui_success "Clé copiée dans le presse-papier."
    else
        ui_warning "termux-api requis pour le presse-papier."
        printf "\n"; cat "$pub"; echo ""
    fi
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#  COPIER UNE CLÉ SUR UN SERVEUR (ssh-copy-id)
# ═══════════════════════════════════════════════════════════════════════

_ssh_copy_id() {
    _ssh_list
    echo -ne "  ${C:-\e[36m}Alias ou user@host : ${NC:-\e[0m}"; read -r target
    [[ -z "$target" ]] && return

    echo -ne "  ${C:-\e[36m}Clé à copier (défaut: id_ed25519) : ${NC:-\e[0m}"
    read -r key_name
    key_name="${key_name:-id_ed25519}"
    local pub="${SSH_KEYS_DIR}/${key_name}.pub"

    [[ -f "$pub" ]] || { ui_error "Clé publique introuvable."; sleep 2; return; }

    printf "\n  ${Y:-\e[33m}Copie de la clé publique sur %s...${NC:-\e[0m}\n\n" "$target"
    log_action "ssh-copy-id : $target" "ssh"
    log_security "Copie clé publique vers : $target" "ssh"

    if utils_cmd_exists ssh-copy-id; then
        ssh-copy-id -i "$pub" "$target" 2>&1
    else
        # Fallback manuel
        local pub_content
        pub_content=$(cat "$pub")
        ssh "$target" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
            echo '${pub_content}' >> ~/.ssh/authorized_keys && \
            chmod 600 ~/.ssh/authorized_keys" 2>&1
    fi
    echo ""; read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  MENU PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════

ssh_menu() {
    log_action "Module SSH ouvert" "ssh"

    while true; do
        clear
        _ssh_list

        printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}🔑 ACTIONS SSH${NC:-\e[0m}\n"
        printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[1]${NC:-\e[0m} Ajouter un hôte\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[2]${NC:-\e[0m} Se connecter\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[3]${NC:-\e[0m} Supprimer un hôte\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[4]${NC:-\e[0m} Gestion des clés SSH\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[5]${NC:-\e[0m} Copier clé publique sur serveur\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[0]${NC:-\e[0m} Retour\n"
        printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
        echo -ne "  ${C:-\e[36m}Choix : ${NC:-\e[0m}"; read -r choice

        case "$choice" in
            1) _ssh_add       ;;
            2) _ssh_connect   ;;
            3) _ssh_delete    ;;
            4) _ssh_keys_menu ;;
            5) _ssh_copy_id   ;;
            0|"") log_action "Module SSH fermé" "ssh"; return 0 ;;
            *) ui_warning "Choix invalide"; sleep 1 ;;
        esac
    done
}
