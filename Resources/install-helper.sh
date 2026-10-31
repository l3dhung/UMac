#!/bin/bash
# Cài / gỡ helper điều khiển sạc. Chạy bằng root (do shell script ... with administrator privileges).
#   install-helper.sh install <username> <smc_src> <helper_src>
#   install-helper.sh uninstall
set -euo pipefail
PATH=/usr/bin:/bin:/usr/sbin:/sbin

DEST_DIR="/Library/PrivilegedHelperTools/com.opensource.hypermac"
HELPER="$DEST_DIR/hypermac-power"
SUDOERS="/etc/sudoers.d/hypermac_power"

remove_legacy() {
    # Bản ≤ v1.6.0 cài sudoers "ALL ALL NOPASSWD" vào thư mục có thể ghi bằng user → gỡ bỏ.
    rm -f /etc/sudoers.d/displaycontrol_power
    rm -f /usr/local/bin/displaycontrol-power /usr/local/bin/displaycontrol-smc
}

case "${1:-}" in
    install)
        USER_NAME="${2:-}"
        SRC_SMC="${3:-}"
        SRC_HELPER="${4:-}"

        if ! [[ "$USER_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || ! id -u "$USER_NAME" >/dev/null 2>&1; then
            echo "Error: invalid user"
            exit 1
        fi
        if [ ! -f "$SRC_SMC" ] || [ ! -f "$SRC_HELPER" ]; then
            echo "Error: missing source files"
            exit 1
        fi

        remove_legacy

        mkdir -p /Library/PrivilegedHelperTools
        rm -rf "$DEST_DIR"
        mkdir -m 755 "$DEST_DIR"
        chown root:wheel "$DEST_DIR"
        install -m 755 -o root -g wheel "$SRC_SMC" "$DEST_DIR/smc"
        install -m 755 -o root -g wheel "$SRC_HELPER" "$HELPER"

        TMP_SUDOERS="$(mktemp /tmp/hypermac_sudoers.XXXXXX)"
        cat > "$TMP_SUDOERS" <<SUDO
$USER_NAME ALL = (root) NOPASSWD: $HELPER status, $HELPER charge-on, $HELPER charge-off
SUDO
        if ! visudo -cf "$TMP_SUDOERS" >/dev/null; then
            rm -f "$TMP_SUDOERS"
            echo "Error: sudoers validation failed"
            exit 1
        fi
        install -m 440 -o root -g wheel "$TMP_SUDOERS" "$SUDOERS"
        rm -f "$TMP_SUDOERS"
        ;;
    uninstall)
        remove_legacy
        rm -f "$SUDOERS"
        rm -rf "$DEST_DIR"
        ;;
    *)
        echo "Usage: $0 install <user> <smc> <helper> | uninstall"
        exit 1
        ;;
esac

echo "SUCCESS"
