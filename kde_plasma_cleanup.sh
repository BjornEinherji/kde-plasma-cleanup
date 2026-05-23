#!/usr/bin/env bash
# =============================================================================
# kde_plasma_cleanup.sh
# Removes all remnants of KDE Plasma and SDDM (plasma-login-manager) left
# behind after a full package uninstall.
#
# Usage:
#   sudo bash kde_plasma_cleanup.sh            # interactive menu
#   sudo bash kde_plasma_cleanup.sh --dry-run  # preview only, no changes
# =============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Colour helpers
# ─────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m';    YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m';   BLUE='\033[0;34m';   MAGENTA='\033[0;35m'
BOLD='\033[1m';      DIM='\033[2m';        RESET='\033[0m'

info()    { echo -e "  ${CYAN}*${RESET} $*"; }
warn()    { echo -e "  ${YELLOW}!${RESET}  $*"; }
success() { echo -e "  ${GREEN}v${RESET}  $*"; }
die()     { echo -e "\n  ${RED}ERROR:${RESET} $*\n" >&2; exit 1; }
section() { echo -e "\n${BOLD}${BLUE}--- $* ---${RESET}"; }

# ─────────────────────────────────────────────────────────────────────────────
# Privilege check
# ─────────────────────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "This script must be run as root (sudo)."

# ─────────────────────────────────────────────────────────────────────────────
# Dry-run flag
# ─────────────────────────────────────────────────────────────────────────────
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

run() {
    if $DRY_RUN; then
        echo -e "    ${YELLOW}[DRY-RUN]${RESET} $*"
    else
        eval "$@"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Global state
# ─────────────────────────────────────────────────────────────────────────────
MODE=""           # "delete" | "backup"
BACKUP_ROOT=""    # e.g. /root/kde_backup_20250417_153012
BACKUP_LOG=""     # manifest file inside backup root

# ─────────────────────────────────────────────────────────────────────────────
# Banner
# ─────────────────────────────────────────────────────────────────────────────
print_banner() {
    clear
    echo -e "${BOLD}${MAGENTA}"
    echo    "  ============================================================"
    echo    "           KDE Plasma / SDDM Cleanup Utility"
    echo    "  ============================================================"
    echo -e "${RESET}"
    if $DRY_RUN; then
        echo -e "  ${YELLOW}${BOLD}[ DRY-RUN MODE - no files will be modified ]${RESET}\n"
    fi
}

# ═════════════════════════════════════════════════════════════════════════════
#  MENUS
# ═════════════════════════════════════════════════════════════════════════════

main_menu() {
    print_banner
    echo -e "  ${BOLD}Choose an action:${RESET}\n"
    echo -e "  ${GREEN}${BOLD}[1]${RESET}  ${BOLD}Delete${RESET}   -- permanently remove all KDE/SDDM remnants"
    echo -e "  ${CYAN}${BOLD}[2]${RESET}  ${BOLD}Backup${RESET}   -- archive remnants first, then remove them"
    echo -e "  ${YELLOW}${BOLD}[3]${RESET}  ${BOLD}Restore${RESET}  -- restore files from a previous backup"
    echo -e "  ${BLUE}${BOLD}[4]${RESET}  ${BOLD}Dry-run${RESET}  -- preview what would be removed; no changes"
    echo -e "  ${RED}${BOLD}[5]${RESET}  ${BOLD}Quit${RESET}\n"
    echo -n "  Your choice [1-5]: "
    read -r choice

    case "$choice" in
        1) MODE="delete" ; confirm_delete    ;;
        2) MODE="backup" ; backup_menu       ;;
        3)                 restore_menu      ;;
        4) DRY_RUN=true  ; MODE="delete"     ; run_all_sections ;;
        5) echo -e "\n  Aborted.\n"; exit 0  ;;
        *) warn "Invalid choice. Please enter 1–5."; sleep 1; main_menu ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Option 1 – Delete
# ─────────────────────────────────────────────────────────────────────────────
confirm_delete() {
    echo
    echo -e "  ${RED}${BOLD}WARNING${RESET}"
    echo -e "  This will ${RED}permanently delete${RESET} all KDE Plasma and SDDM"
    echo    "  configuration, cache, and leftover system files."
    echo    "  This action CANNOT be undone."
    echo
    echo -n "  Type YES to continue, or anything else to go back: "
    read -r answer
    if [[ "$answer" == "YES" ]]; then
        run_all_sections
    else
        info "Returning to menu..."; sleep 1; main_menu
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Option 2 – Backup
# ─────────────────────────────────────────────────────────────────────────────
backup_menu() {
    echo
    echo -e "  ${BOLD}${CYAN}Backup Options${RESET}\n"
    echo -e "  ${GREEN}${BOLD}[1]${RESET}  Use default location  ${DIM}(/root/kde_backup_<timestamp>)${RESET}"
    echo -e "  ${CYAN}${BOLD}[2]${RESET}  Specify a custom backup directory"
    echo -e "  ${RED}${BOLD}[3]${RESET}  Back to main menu\n"
    echo -n "  Your choice [1-3]: "
    read -r bchoice

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    case "$bchoice" in
        1)
            BACKUP_ROOT="/root/kde_backup_${timestamp}"
            confirm_backup
            ;;
        2)
            echo -n "  Enter full path for backup directory: "
            read -r custom_path
            custom_path="${custom_path%/}"
            if [[ -z "$custom_path" ]]; then
                warn "Path cannot be empty."; sleep 1; backup_menu; return
            fi
            BACKUP_ROOT="${custom_path}/kde_backup_${timestamp}"
            confirm_backup
            ;;
        3) main_menu ;;
        *) warn "Invalid choice."; sleep 1; backup_menu ;;
    esac
}

confirm_backup() {
    echo
    echo -e "  ${CYAN}${BOLD}Backup location:${RESET}  $BACKUP_ROOT"
    echo -e "  All found KDE/SDDM files will be ${CYAN}copied there${RESET}, then ${RED}deleted${RESET}."
    echo
    echo -n "  Type YES to continue, or anything else to go back: "
    read -r answer
    if [[ "$answer" == "YES" ]]; then
        if ! $DRY_RUN; then
            mkdir -p "$BACKUP_ROOT"
            BACKUP_LOG="$BACKUP_ROOT/manifest.txt"
            {
                echo "# KDE Plasma/SDDM Cleanup Backup"
                echo "# Created: $(date)"
                echo "# Host:    $(hostname)"
                echo "---"
            } > "$BACKUP_LOG"
        fi
        run_all_sections
    else
        info "Returning to menu..."; sleep 1; main_menu
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Option 3 – Restore
# ─────────────────────────────────────────────────────────────────────────────
restore_menu() {
    print_banner
    echo -e "  ${BOLD}${YELLOW}Restore from Backup${RESET}\n"

    # ── Auto-detect backups in common locations ──────────────────────────────
    local -a found_backups=()
    while IFS= read -r -d '' d; do
        # Must contain a manifest to be considered a valid backup
        [[ -f "$d/manifest.txt" ]] && found_backups+=("$d")
    done < <(find /root /home -maxdepth 2 -type d -name 'kde_backup_*' -print0 2>/dev/null | sort -z)

    if [[ ${#found_backups[@]} -gt 0 ]]; then
        echo -e "  ${BOLD}Backups found automatically:${RESET}\n"
        local i=1
        for b in "${found_backups[@]}"; do
            local created
            created=$(grep '^# Created:' "$b/manifest.txt" 2>/dev/null \
                      | sed 's/# Created: //' || echo "unknown date")
            local count
            count=$(grep -c '^/' "$b/manifest.txt" 2>/dev/null || echo "0")
            echo -e "  ${GREEN}${BOLD}[$i]${RESET}  $b"
            echo -e "       ${DIM}Created : $created${RESET}"
            echo -e "       ${DIM}Files   : $count entries${RESET}"
            ((i++))
        done
        echo
        echo -e "  ${CYAN}${BOLD}[$i]${RESET}  Enter a path manually"
        echo -e "  ${RED}${BOLD}[$((i+1))]${RESET}  Back to main menu\n"
        echo -n "  Your choice [1-$((i+1))]: "
        read -r rchoice

        if [[ "$rchoice" =~ ^[0-9]+$ ]]; then
            if (( rchoice >= 1 && rchoice <= ${#found_backups[@]} )); then
                BACKUP_ROOT="${found_backups[$((rchoice-1))]}"
                confirm_restore
                return
            elif (( rchoice == i )); then
                _restore_manual_path
                return
            elif (( rchoice == i+1 )); then
                main_menu; return
            fi
        fi
        warn "Invalid choice."; sleep 1; restore_menu
    else
        echo -e "  ${DIM}No kde_backup_* directories found automatically.${RESET}\n"
        _restore_manual_path
    fi
}

_restore_manual_path() {
    echo -n "  Enter full path to backup directory: "
    read -r rpath
    rpath="${rpath%/}"
    if [[ -z "$rpath" ]]; then
        warn "Path cannot be empty."; sleep 1; restore_menu; return
    fi
    if [[ ! -d "$rpath" ]]; then
        warn "Directory not found: $rpath"; sleep 1; restore_menu; return
    fi
    if [[ ! -f "$rpath/manifest.txt" ]]; then
        warn "No manifest.txt found in $rpath — is this a valid backup?"
        echo -n "  Continue anyway? [y/N]: "
        read -r yn
        [[ "$yn" =~ ^[Yy]$ ]] || { restore_menu; return; }
    fi
    BACKUP_ROOT="$rpath"
    confirm_restore
}

confirm_restore() {
    echo
    echo -e "  ${YELLOW}${BOLD}Restore Preview${RESET}"
    echo -e "  Source : ${BOLD}$BACKUP_ROOT${RESET}"
    echo

    # Show manifest entries if available
    if [[ -f "$BACKUP_ROOT/manifest.txt" ]]; then
        local count
        count=$(grep -c '^/' "$BACKUP_ROOT/manifest.txt" 2>/dev/null || echo "0")
        echo -e "  ${DIM}$count file/directory entries recorded in manifest.${RESET}"
    fi

    echo
    echo -e "  ${BOLD}Restore options:${RESET}\n"
    echo -e "  ${GREEN}${BOLD}[1]${RESET}  Restore from manifest  -- only files listed in manifest.txt"
    echo -e "  ${CYAN}${BOLD}[2]${RESET}  Restore full tree      -- copy everything from the backup directory"
    echo -e "  ${RED}${BOLD}[3]${RESET}  Back\n"
    echo -n "  Your choice [1-3]: "
    read -r rmode

    case "$rmode" in
        1)
            [[ -f "$BACKUP_ROOT/manifest.txt" ]] || {
                warn "No manifest.txt found — cannot use manifest mode."
                sleep 2; confirm_restore; return
            }
            _do_restore "manifest"
            ;;
        2) _do_restore "tree" ;;
        3) restore_menu ;;
        *) warn "Invalid choice."; sleep 1; confirm_restore ;;
    esac
}

_do_restore() {
    local mode="$1"
    local restored=0 skipped=0 failed=0

    echo
    echo -e "  ${YELLOW}${BOLD}WARNING${RESET}"
    echo    "  This will OVERWRITE existing files at their original locations."
    echo -n "  Type YES to continue, or anything else to go back: "
    read -r answer
    [[ "$answer" == "YES" ]] || { info "Returning..."; sleep 1; confirm_restore; return; }

    section "Restoring files from $BACKUP_ROOT"

    if [[ "$mode" == "manifest" ]]; then
        # Restore only paths listed in manifest
        while IFS= read -r orig_path; do
            # Skip comment/header lines
            [[ "$orig_path" =~ ^# ]] && continue
            [[ "$orig_path" == "---" ]] && continue
            [[ -z "$orig_path" ]] && continue

            local src="${BACKUP_ROOT}${orig_path}"
            local dst_parent
            dst_parent=$(dirname "$orig_path")

            if [[ ! -e "$src" && ! -L "$src" ]]; then
                warn "Backup source missing, skipping: $src"
                ((skipped++)) || true
                continue
            fi

            if $DRY_RUN; then
                echo -e "    ${YELLOW}[DRY-RUN]${RESET} would restore: $src  ->  $orig_path"
                ((restored++)) || true
            else
                mkdir -p "$dst_parent"
                if cp -a -- "$src" "$dst_parent/"; then
                    info "Restored: $orig_path"
                    ((restored++)) || true
                else
                    warn "Failed to restore: $orig_path"
                    ((failed++)) || true
                fi
            fi
        done < "$BACKUP_ROOT/manifest.txt"

    else
        # Full tree restore: mirror backup directory structure back to /
        while IFS= read -r -d '' src; do
            # Strip the BACKUP_ROOT prefix to get the original absolute path
            local orig_path="${src#"$BACKUP_ROOT"}"
            [[ -z "$orig_path" ]] && continue
            [[ "$orig_path" == "/manifest.txt" ]] && continue

            local dst_parent
            dst_parent=$(dirname "$orig_path")

            if $DRY_RUN; then
                echo -e "    ${YELLOW}[DRY-RUN]${RESET} would restore: $src  ->  $orig_path"
                ((restored++)) || true
            else
                mkdir -p "$dst_parent"
                if cp -a -- "$src" "$dst_parent/"; then
                    info "Restored: $orig_path"
                    ((restored++)) || true
                else
                    warn "Failed to restore: $orig_path"
                    ((failed++)) || true
                fi
            fi
        # Use find depth=1 on dirs/files directly inside BACKUP_ROOT/* to avoid
        # recursing into manifest; actual cp -a handles recursion for each entry
        done < <(find "$BACKUP_ROOT" -mindepth 2 -maxdepth 2 \
                    ! -name 'manifest.txt' -print0 2>/dev/null)
    fi

    _print_restore_summary "$restored" "$skipped" "$failed"
}

_print_restore_summary() {
    local restored=$1 skipped=$2 failed=$3
    echo
    echo -e "${BOLD}${GREEN}============================================================${RESET}"
    echo -e "${BOLD}${GREEN}                    Restore Complete                       ${RESET}"
    echo -e "${BOLD}${GREEN}============================================================${RESET}"
    echo
    if $DRY_RUN; then
        echo -e "  ${YELLOW}${BOLD}Dry-run only -- no files were written.${RESET}"
    else
        success "Restored : $restored"
        [[ $skipped -gt 0 ]] && warn    "Skipped  : $skipped (source missing in backup)"
        [[ $failed  -gt 0 ]] && warn    "Failed   : $failed  (check permissions)"
    fi
    echo
    warn "You may need to reinstall KDE Plasma packages before the"
    warn "restored configuration takes effect."
    echo
    echo -n "  Return to main menu? [Y/n]: "
    read -r again
    [[ "$again" =~ ^[Nn]$ ]] || main_menu
}

# ─────────────────────────────────────────────────────────────────────────────
# Core path handler  --  backup OR delete based on MODE
# ─────────────────────────────────────────────────────────────────────────────
handle_path() {
    local p="$1"
    [[ -e "$p" || -L "$p" ]] || return 0

    if [[ "$MODE" == "backup" ]]; then
        local dest="${BACKUP_ROOT}${p}"
        local dest_parent
        dest_parent=$(dirname "$dest")
        if $DRY_RUN; then
            echo -e "    ${YELLOW}[DRY-RUN]${RESET} backup+remove: $p  ->  $dest"
        else
            mkdir -p "$dest_parent"
            if cp -a -- "$p" "$dest_parent/" 2>/dev/null; then
                echo "$p" >> "$BACKUP_LOG"
                info "Backed up & removing: $p"
            else
                warn "Could not back up: $p  (skipping delete too)"
                return 0
            fi
            rm -rf -- "$p"
        fi
    else
        if $DRY_RUN; then
            echo -e "    ${YELLOW}[DRY-RUN]${RESET} would delete: $p"
        else
            info "Removing: $p"
            rm -rf -- "$p"
        fi
    fi
}

# ═════════════════════════════════════════════════════════════════════════════
#  CLEANUP SECTIONS
# ═════════════════════════════════════════════════════════════════════════════

run_all_sections() {
    echo
    section "1  Residual package removal (apt / dnf / pacman)"
    purge_packages

    section "2  Systemd services & unit files"
    cleanup_systemd

    section "3  Display-manager configuration"
    cleanup_display_manager

    section "4  System-wide config & data directories"
    cleanup_system_paths

    section "5  Per-user KDE / Plasma config & cache"
    cleanup_user_homes

    section "6  Per-user KDE state files (~/.local/state)"
    cleanup_user_state

    section "7  Autostart entries"
    cleanup_autostart

    section "8  Shared memory & runtime artefacts"
    cleanup_runtime

    section "9  Icon, theme & font cache"
    cleanup_themes

    section "10  DBus service files"
    cleanup_dbus

    section "11  Final housekeeping"
    final_housekeeping

    print_cleanup_summary
}

# ─── 1 · Packages ────────────────────────────────────────────────────────────
purge_packages() {
    if   command -v apt-get &>/dev/null; then _purge_apt
    elif command -v dnf     &>/dev/null; then _purge_dnf
    elif command -v pacman  &>/dev/null; then _purge_pacman
    else warn "No recognised package manager -- skipping package purge."
    fi
}

_purge_apt() {
    info "apt-based system -- scanning for residual KDE/SDDM packages ..."
    local pkgs
    pkgs=$(dpkg -l 2>/dev/null \
        | awk '/^ii/{print $2}' \
        | grep -E '^(kde|plasma|sddm|kdeconnect|kwin|kf[0-9]|kscreenlocker|polkit-kde|kded|breeze|dolphin|konsole|kate|okular|ark|gwenview|kmail|kontact|akonadi|baloo|kio|solid|kwayland|kpackage|knotify|kauth|kconfig|kcoreaddons|kwidgets|kxmlgui|kparts|kglobalaccel|kcrash|kdbusaddons|ktextwidgets|kiconthemes|kitemviews|kcompletion|kcodecs|kjobwidgets|kwindowsystem|karchive|kcmutils|kdecoration|kdesu|kde-spectacle|phonon)' \
        || true)
    if [[ -n "$pkgs" ]]; then
        # shellcheck disable=SC2086
        run apt-get purge -y --autoremove $pkgs
    else
        info "No residual apt packages found."
    fi
}

_purge_dnf() {
    info "dnf-based system -- scanning for residual KDE/SDDM packages ..."
    local pkgs
    pkgs=$(dnf list installed 2>/dev/null \
        | awk 'NR>1{print $1}' | sed 's/\..*//' \
        | grep -E '^(kde|plasma|sddm|kdeconnect|kwin|breeze|dolphin|konsole|kate|okular|ark|gwenview|baloo|akonadi|kf[0-9])' \
        || true)
    if [[ -n "$pkgs" ]]; then
        # shellcheck disable=SC2086
        run dnf remove -y $pkgs
    else
        info "No residual dnf packages found."
    fi
}

_purge_pacman() {
    info "pacman-based system -- scanning for residual KDE/SDDM packages ..."

    local KDE_PATTERN='^(kde|plasma|sddm|kdeconnect|kwin|breeze|dolphin|konsole|kate|okular|ark|gwenview|baloo|akonadi|kf[0-9]|kscreen|kwayland|kpipewire|polkit-kde|layer-shell-qt|libkscreen|libplasma|xdg-desktop-portal-kde)'

    # All installed KDE/SDDM packages
    local all_kde
    all_kde=$(pacman -Qq 2>/dev/null | grep -E "$KDE_PATTERN" || true)

    if [[ -z "$all_kde" ]]; then
        info "No residual pacman packages found."
        return 0
    fi

    info "Found KDE/SDDM packages:"
    echo "$all_kde" | sed 's/^/      /'
    echo

    # ── Build lookup: which packages are in our removal set ──────────────────
    declare -A kde_set
    while IFS= read -r p; do [[ -n "$p" ]] && kde_set["$p"]=1; done <<< "$all_kde"

    # ── Classify each package as safe or blocked ──────────────────────────────
    # Blocked = at least one requirer is NOT in our removal set (non-KDE needs it)
    local safe_pkgs=()
    local blocked_pkgs=()
    local blocked_reasons=()

    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue

        # Parse 'Required By' from pacman -Qi
        local required_by
        required_by=$(pacman -Qi "$pkg" 2>/dev/null \
            | awk '/^Required By[[:space:]]*:/{
                    sub(/^Required By[[:space:]]*:[[:space:]]*/,""); print; p=1; next
                  }
                  p && /^[A-Z]/{p=0}
                  p{print}' \
            | tr ' ' '\n' \
            | grep -v -E '^(None|)$' \
            || true)

        local outside_deps=""
        for req in $required_by; do
            [[ -z "$req" ]] && continue
            if [[ -z "${kde_set[$req]+x}" ]]; then
                outside_deps+="$req "
            fi
        done

        if [[ -n "$outside_deps" ]]; then
            blocked_pkgs+=("$pkg")
            blocked_reasons+=("  ${YELLOW}!${RESET}  $pkg  <--  still needed by: ${outside_deps% }")
        else
            safe_pkgs+=("$pkg")
        fi
    done <<< "$all_kde"

    # ── Report blocked packages upfront ──────────────────────────────────────
    if [[ ${#blocked_pkgs[@]} -gt 0 ]]; then
        warn "Skipping ${#blocked_pkgs[@]} package(s) still required by non-KDE software:"
        for reason in "${blocked_reasons[@]}"; do
            echo -e "$reason"
        done
        echo
        warn "These shared libraries will remain installed until the packages"
        warn "that depend on them (e.g. partitionmanager) are also removed."
        warn "Afterwards you can clean them up with:  pacman -Rns <package>"
        echo
    fi

    # ── Pass 1: remove safe packages as a group (pacman resolves the graph) ──
    if [[ ${#safe_pkgs[@]} -gt 0 ]]; then
        info "Pass 1: removing ${#safe_pkgs[@]} safe KDE package(s) ..."
        if $DRY_RUN; then
            echo -e "    ${YELLOW}[DRY-RUN]${RESET} pacman -Rns --noconfirm ${safe_pkgs[*]}"
        else
            pacman -Rns --noconfirm "${safe_pkgs[@]}" 2>&1 || {
                warn "Batch removal failed -- retrying one-by-one with -Rs ..."
                for pkg in "${safe_pkgs[@]}"; do
                    pacman -Rs --noconfirm "$pkg" 2>/dev/null \
                        && info "  Removed: $pkg" \
                        || warn "  Could not remove: $pkg (may already be gone)"
                done
            }
        fi
    fi

    # ── Pass 2: re-check after pass 1; some blocked pkgs may now be removable
    local remaining
    remaining=$(pacman -Qq 2>/dev/null | grep -E "$KDE_PATTERN" || true)

    # Filter out packages we know are still hard-blocked
    local pass2_pkgs=()
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        local still_blocked=false
        for b in "${blocked_pkgs[@]}"; do
            [[ "$b" == "$pkg" ]] && still_blocked=true && break
        done
        $still_blocked || pass2_pkgs+=("$pkg")
    done <<< "$remaining"

    if [[ ${#pass2_pkgs[@]} -gt 0 ]]; then
        info "Pass 2: removing ${#pass2_pkgs[@]} newly unblocked KDE package(s) ..."
        if $DRY_RUN; then
            echo -e "    ${YELLOW}[DRY-RUN]${RESET} pacman -Rns --noconfirm ${pass2_pkgs[*]}"
        else
            pacman -Rns --noconfirm "${pass2_pkgs[@]}" 2>&1 || {
                warn "Pass 2 failed -- retrying one-by-one ..."
                for pkg in "${pass2_pkgs[@]}"; do
                    pacman -Rs --noconfirm "$pkg" 2>/dev/null \
                        && info "  Removed: $pkg" \
                        || warn "  Could not remove: $pkg"
                done
            }
        fi
    fi

    # ── Orphan hint ───────────────────────────────────────────────────────────
    if ! $DRY_RUN; then
        local orphans
        orphans=$(pacman -Qdtq 2>/dev/null || true)
        if [[ -n "$orphans" ]]; then
            echo
            warn "Orphaned packages remain (deps no longer needed by anything):"
            echo "$orphans" | sed 's/^/      /'
            warn "Clean them up with:  sudo pacman -Rns \$(pacman -Qdtq)"
        fi
    fi
}

# ─── 2 · Systemd ─────────────────────────────────────────────────────────────
cleanup_systemd() {
    local KDE_SERVICES=(
        sddm.service sddm-autologin.service
        plasma-plasmashell.service plasma-ksmserver.service
        plasma-kwin_x11.service plasma-kwin_wayland.service
        kdeconnect.service baloo_file.service
        akonadi.service akonadiserver.service
        plasma-xdg-desktop-portal-kde.service obexd.service
    )

    for svc in "${KDE_SERVICES[@]}"; do
        if systemctl list-unit-files "$svc" 2>/dev/null | grep -q "$svc"; then
            info "Disabling & masking: $svc"
            run "systemctl disable --now \"$svc\" 2>/dev/null || true"
            run "systemctl mask \"$svc\" 2>/dev/null || true"
        fi
    done

    for dir in /etc/systemd/system /usr/lib/systemd/system \
               /usr/lib/systemd/user /etc/systemd/user; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' f; do
            handle_path "$f"
        done < <(find "$dir" -maxdepth 2 \
            \( -name 'sddm*' -o -name 'plasma*' -o -name 'kde*' \
               -o -name 'kwin*' -o -name 'baloo*' -o -name 'akonadi*' \
               -o -name 'kdeconnect*' \) -print0 2>/dev/null)
    done

    run "systemctl daemon-reload 2>/dev/null || true"
}

# ─── 3 · Display manager ─────────────────────────────────────────────────────
cleanup_display_manager() {
    local DM_FILE=/etc/X11/default-display-manager
    if [[ -f "$DM_FILE" ]] && grep -qi sddm "$DM_FILE"; then
        warn "SDDM is still set as the default DM in $DM_FILE"
        warn "Set a replacement before rebooting:"
        warn "  Debian/Ubuntu : dpkg-reconfigure <gdm3|lightdm|...>"
        warn "  Fedora        : systemctl enable gdm.service"
        warn "  Arch          : systemctl enable lightdm.service"
    fi

    handle_path /etc/sddm.conf
    handle_path /etc/sddm.conf.d

    for dir in /usr/share/xsessions /usr/share/wayland-sessions; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' f; do
            handle_path "$f"
        done < <(find "$dir" -maxdepth 1 \
            \( -name 'plasma*' -o -name 'kde*' \) -print0 2>/dev/null)
    done
}

# ─── 4 · System-wide paths ───────────────────────────────────────────────────
cleanup_system_paths() {
    local SYSTEM_PATHS=(
        /usr/share/plasma       /usr/share/kde4         /usr/share/kde
        /usr/share/kservices5   /usr/share/kservicetypes5
        /usr/share/knotifications5  /usr/share/kxmlgui5
        /usr/share/kdeglobals   /usr/share/sddm
        /etc/kde  /etc/kde4
        /var/lib/sddm  /var/log/sddm.log  /run/sddm
    )
    for p in "${SYSTEM_PATHS[@]}"; do
        handle_path "$p"
    done
}

# ─── 5 · Per-user homes ──────────────────────────────────────────────────────
cleanup_user_homes() {
    mapfile -t HOME_DIRS < <(
        awk -F: '$3 >= 1000 && $3 < 65534 && $6 ~ /^\// {print $6}' /etc/passwd \
        | sort -u
    )
    HOME_DIRS+=(/root)

    local USER_RELATIVE_PATHS=(
        .config/plasma-org.kde.plasma.desktop-appletsrc
        .config/plasmarc               .config/plasma-localerc
        .config/plasmashellrc          .config/kwinrc
        .config/kwinrulesrc            .config/kdeglobals
        .config/kdedefaults            .config/kded5rc                .config/kded6rc
        .config/kded_device_automounterrc
        .config/kactivitymanagerdrc    .config/kactivitymanagerd
        .config/klipperrc              .config/kwalletrc
        .config/kwalletd5rc            .config/kwalletd6rc
        .config/kglobalshortcutsrc     .config/khotkeysrc
        .config/kscreenlockerrc        .config/ksmserverrc
        .config/klaunchrc              .config/ktimezonedrc
        .config/ksplashrc              .config/krunnerrc
        .config/kiorc                  .config/kdeconnect
        .config/dolphinrc              .config/konsolebookmarks
        .config/konsolerc              .config/katerc
        .config/katevirc               .config/okularrc
        .config/gwenviewrc             .config/arkrc
        .config/kmailrc                .config/akonadi
        .config/baloofilerc            .config/baloosearchrc
        .config/systemsettingsrc       .config/kinfocenterrc
        .config/spectaclerc            .config/kfontinstallerrc
        # Additional KDE application/daemon configs
        .config/bluedevilglobalrc      # KDE Bluetooth
        .config/kalarmrc               # KAlarm
        .config/kconf_updaterc         # KDE config update daemon
        .config/kgpgrc                 # KGPG
        .config/powermanagementprofilesrc  # KDE power management
        # NOTE: .config/QtProject.conf and .config/Trolltech.conf are intentionally
        # NOT removed -- they are written by Qt itself and used by ALL Qt apps
        # (not just KDE), including non-KDE software like VLC, OBS, etc.
        # NOTE: .config/gtkrc and .config/gtkrc-2.0 are also intentionally kept --
        # they may have been written by KDE's GTK theming but are used by all GTK apps.
        # NOTE: .config/kritarc and .config/kritadisplayrc are intentionally kept --
        # Krita is a standalone creative app with its own user data independent of Plasma.
        .local/share/plasma            .local/share/plasmashell
        .local/share/plasma_engine_weather
        .local/share/plasmalogin
        .local/share/kwin              .local/share/kscreen
        .local/share/sddm              .local/share/kdeconnect
        .local/share/dolphin           .local/share/konsole
        .local/share/kate              .local/share/okular
        .local/share/gwenview          .local/share/akonadi
        .local/share/baloo             .local/share/kmail2
        .local/share/kmail             .local/share/kpackage
        .local/share/kservices5        .local/share/knewstuff3
        .local/share/knotifications5
        .local/share/kactivitymanagerd
        .local/share/kded6
        .local/share/klipper
        .local/share/kwalletd
        .local/share/libkunitconversion
        # user-places.xbel is shared with GNOME/Nautilus and must NOT be removed,
        # but the .tbcache sidecar is written exclusively by KDE's bookmark engine.
        .local/share/user-places.xbel.tbcache
        .cache/plasma                  .cache/plasmashell
        .cache/kwin                    .cache/kscreenlocker_greet
        .cache/krunner                 .cache/dolphin
        .cache/konsole                 .cache/kate
        .cache/baloo                   .cache/akonadi
        .cache/kdeconnect              .cache/ksycoca5
        .cache/kactivitymanagerd       .cache/kded6
        .cache/kwalletd                .cache/klipper
        .cache/icon-cache.kcache
        # Additional KDE cache dirs/files seen in the wild
        .cache/discover                # KDE Discover package manager
        .cache/drkonqi                 # KDE crash reporter
        .cache/kcrash-metadata         # KDE crash handler
        .cache/ksplash                 # KDE splash screen
        .cache/org.kde.unitconversion  # KDE unit conversion
        .cache/polkit-kde-authentication-agent-1
        .cache/spectacle               # KDE screenshot tool
        .cache/systemsettings          # KDE System Settings
        .cache/ksvg-elements           # KDE SVG render cache
        # ksycoca6 is a generated filename -- handled by wildcard sweep below
        # qtshadercache is Qt-wide (not KDE-exclusive) -- intentionally left alone
        .kde  .kde4  .sddm-greeter-shm
    )

    for home in "${HOME_DIRS[@]}"; do
        [[ -d "$home" ]] || continue
        info "Processing home: $home"
        for rel in "${USER_RELATIVE_PATHS[@]}"; do
            handle_path "$home/$rel"
        done
        for base in "$home/.config" "$home/.local/share" "$home/.cache"; do
            [[ -d "$base" ]] || continue
            while IFS= read -r -d '' entry; do
                handle_path "$entry"
            done < <(find "$base" -maxdepth 1 \
                \( -iname 'kde*'            -o -iname 'plasma*' \
                   -o -iname 'kwin*'        -o -iname 'baloo*' \
                   -o -iname 'akonadi*'     -o -iname 'kdeconnect*' \
                   -o -iname 'kf[0-9]*'     -o -iname 'klipper*' \
                   -o -iname 'kwallet*'     -o -iname 'kactivity*' \
                   -o -iname 'kded[0-9]*'   -o -iname 'libkunit*' \
                   -o -iname 'plasmalogin*' -o -iname 'kscreen*' \
                   -o -iname 'krunner*'     -o -iname 'knotify*' \
                   -o -iname 'ksycoca[0-9]*' \
                   -o -iname 'ksvg*'        -o -iname 'kcrash*' \
                   -o -iname 'ksplash*'     -o -iname 'drkonqi*' \
                   -o -iname 'org.kde.*'    -o -iname 'polkit-kde*' \
                   -o -iname 'spectacle*'   -o -iname 'systemsettings*' \
                   -o -iname 'discover'     -o -iname 'bluedevil*' \) \
                -print0 2>/dev/null)
        done
    done
}

# ─── 6 · Per-user state directory ────────────────────────────────────────────
cleanup_user_state() {
    mapfile -t HOME_DIRS < <(
        awk -F: '$3 >= 1000 && $3 < 65534 && $6 ~ /^\// {print $6}' /etc/passwd \
        | sort -u
    )
    HOME_DIRS+=(/root)

    # Explicit state files/dirs seen in the wild
    local STATE_RELATIVE_PATHS=(
        .local/state/discovernotifierstaterc
        .local/state/discoverstaterc
        .local/state/kactivitymanagerdstaterc
        .local/state/kickerstaterc
        .local/state/plasmashellstaterc
        .local/state/UserFeedback.org.kde.discover
        .local/state/UserFeedback.org.kde.plasmashell
        .local/state/UserFeedback.org.kde.plasma-welcome
        .local/state/showtime
    )

    for home in "${HOME_DIRS[@]}"; do
        [[ -d "$home/.local/state" ]] || continue
        info "Processing state dir: $home/.local/state"

        # Explicit paths
        for rel in "${STATE_RELATIVE_PATHS[@]}"; do
            handle_path "$home/$rel"
        done

        # wireplumber state -- created by Plasma sessions via PipeWire.
        # Only remove if no other desktop environment (GNOME etc.) is active,
        # since wireplumber is shared infrastructure. We check for a GNOME
        # session marker as a safeguard before touching it.
        local wp_state="$home/.local/state/wireplumber"
        if [[ -d "$wp_state" ]]; then
            if [[ -f "$home/.local/state/gnome-session@gnome.state" ]] || \
               [[ -d "$home/.local/share/gnome-shell" ]]; then
                warn "Skipping $wp_state -- GNOME session detected; wireplumber is shared."
            else
                handle_path "$wp_state"
            fi
        fi

        # Wildcard sweep for anything else KDE-named in ~/.local/state
        while IFS= read -r -d '' entry; do
            handle_path "$entry"
        done < <(find "$home/.local/state" -maxdepth 1 \
            \( -iname 'kde*'          -o -iname 'plasma*' \
               -o -iname 'kwin*'      -o -iname 'baloo*' \
               -o -iname 'kactivity*' -o -iname 'kicker*' \
               -o -iname 'discover*'  -o -iname 'UserFeedback.org.kde.*' \
               -o -iname 'kwallet*'   -o -iname 'kscreen*' \
               -o -iname 'showtime'   -o -iname 'krunner*' \) \
            -print0 2>/dev/null)
    done
}

# ─── 7 · Autostart ───────────────────────────────────────────────────────────
cleanup_autostart() {
    mapfile -t HOME_DIRS < <(
        awk -F: '$3 >= 1000 && $3 < 65534 && $6 ~ /^\// {print $6}' /etc/passwd \
        | sort -u
    )
    HOME_DIRS+=(/root)

    for home in "${HOME_DIRS[@]}"; do
        [[ -d "$home/.config/autostart" ]] || continue
        while IFS= read -r -d '' f; do
            handle_path "$f"
        done < <(find "$home/.config/autostart" -maxdepth 1 \
            \( -name 'kde*' -o -name 'plasma*' -o -name 'kdeconnect*' \
               -o -name 'org.kde.*' -o -name 'baloo*' \) \
            -print0 2>/dev/null)
    done

    for dir in /etc/xdg/autostart /usr/share/autostart; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' f; do
            handle_path "$f"
        done < <(find "$dir" -maxdepth 1 \
            \( -name 'kde*' -o -name 'plasma*' -o -name 'kdeconnect*' \
               -o -name 'org.kde.*' -o -name 'baloo*' \) \
            -print0 2>/dev/null)
    done
}

# ─── 7 · Runtime artefacts ───────────────────────────────────────────────────
cleanup_runtime() {
    while IFS= read -r -d '' f; do
        handle_path "$f"
    done < <(find /tmp -maxdepth 2 \
        \( -name 'kwin*' -o -name 'plasma*' -o -name 'sddm*' \
           -o -name '.kde*' \) -print0 2>/dev/null)

    for p in /run/sddm /run/user/*/sddm; do
        handle_path "$p"
    done

    for shm in /dev/shm/sddm* /dev/shm/plasma* /dev/shm/kwin* /dev/shm/kde*; do
        handle_path "$shm"
    done
}

# ─── 8 · Themes & icons ──────────────────────────────────────────────────────
cleanup_themes() {
    for dir in /usr/share/icons /usr/share/themes; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' d; do
            handle_path "$d"
        done < <(find "$dir" -maxdepth 1 \
            \( -iname 'breeze*' -o -iname 'oxygen*' \
               -o -iname 'plasma*' -o -iname 'kde*' \) \
            -print0 2>/dev/null)
    done
}

# ─── 9 · DBus ────────────────────────────────────────────────────────────────
cleanup_dbus() {
    for dir in /usr/share/dbus-1/services /usr/share/dbus-1/system-services \
               /etc/dbus-1/system.d /etc/dbus-1/session.d; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' f; do
            handle_path "$f"
        done < <(find "$dir" -maxdepth 1 \
            \( -name 'org.kde.*' -o -name 'org.freedesktop.sddm*' \
               -o -name 'plasma*' -o -name 'kdeconnect*' \
               -o -name 'baloo*' \) -print0 2>/dev/null)
    done
}

# ─── 10 · Final housekeeping ─────────────────────────────────────────────────
final_housekeeping() {
    run "systemctl daemon-reload 2>/dev/null || true"
    command -v gtk-update-icon-cache &>/dev/null && \
        run "gtk-update-icon-cache -f -t /usr/share/icons 2>/dev/null || true"
    command -v update-desktop-database &>/dev/null && \
        run "update-desktop-database /usr/share/applications 2>/dev/null || true"
}

# ─────────────────────────────────────────────────────────────────────────────
# Cleanup summary
# ─────────────────────────────────────────────────────────────────────────────
print_cleanup_summary() {
    echo
    echo -e "${BOLD}${GREEN}============================================================${RESET}"
    echo -e "${BOLD}${GREEN}                    Cleanup Complete                       ${RESET}"
    echo -e "${BOLD}${GREEN}============================================================${RESET}"
    echo

    if $DRY_RUN; then
        echo -e "  ${YELLOW}${BOLD}Dry-run only -- no files were modified.${RESET}"
    elif [[ "$MODE" == "backup" ]]; then
        success "All KDE/SDDM remnants backed up to:"
        echo    "      ${BOLD}$BACKUP_ROOT${RESET}"
        success "Manifest written to:"
        echo    "      ${BOLD}$BACKUP_LOG${RESET}"
        echo
        echo -e "  ${DIM}To restore later, run this script again and choose option [3] Restore.${RESET}"
        echo -e "  ${DIM}To delete the backup when satisfied:  rm -rf $BACKUP_ROOT${RESET}"
    else
        success "All KDE Plasma and SDDM remnants removed."
    fi

    echo
    warn "If SDDM was your display manager, set a replacement before rebooting:"
    warn "  Debian/Ubuntu : dpkg-reconfigure <gdm3|lightdm|...>"
    warn "  Fedora        : systemctl enable gdm.service"
    warn "  Arch          : systemctl enable lightdm.service"
    echo
}

# ═════════════════════════════════════════════════════════════════════════════
#  Entry point
# ═════════════════════════════════════════════════════════════════════════════
if $DRY_RUN; then
    MODE="delete"
    run_all_sections
else
    main_menu
fi
