#!/system/bin/sh

TRICKY_DIR="/data/adb/tricky_store"
REMOTE_URL="https://raw.githubusercontent.com/dpejoh/yurikey/main/conf"
VERSION_URL="https://raw.githubusercontent.com/dpejoh/yurikey/main/version"
TARGET_FILE="$TRICKY_DIR/keybox.xml"
BACKUP_FILE="$TRICKY_DIR/keybox.xml.bak"
TMP_REMOTE="$TRICKY_DIR/remote_keybox.tmp"
SCRIPT_REMOTE="$TRICKY_DIR/remote_script.sh"
DEPENDENCY_MODULE="/data/adb/modules/tricky_store"

if [ -d "/data/adb/modules/Yurikey" ]; then
  MODPATH="/data/adb/modules/Yurikey"
elif [ -d "/data/adb/modules_update/Yurikey" ]; then
  MODPATH="/data/adb/modules_update/Yurikey"
else
  echo "- Error: Yurikey module path not found!"
  exit 1
fi

log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') [YURI_KEYBOX] $1"
}

# Check for dependency: Tricky Store module
if [ ! -d "$DEPENDENCY_MODULE" ]; then
  log_message "Error: Tricky Store module not found!"
  log_message "Please install Tricky Store before using Yuri Keybox."
  exit 1
fi

version() {
  log_message "Checking latest available keybox..."

  if command -v curl >/dev/null 2>&1; then
    VERSION=$(curl -fsSL "$VERSION_URL")
    log_message "$VERSION version available."
  elif command -v wget >/dev/null 2>&1; then
    VERSION=$(wget -qO- "$VERSION_URL")
    log_message "$VERSION version available."
  else
    VERSION=""
    log_message "Failed to fetch version info."
  fi
}

find "$MODPATH/bin" -type f -name busybox -exec chmod 755 {} \;

ARCH=$(getprop ro.product.cpu.abi)
case "$ARCH" in
  arm64*)   BUSYBOX_BIN="$MODPATH/bin/arm64-v8a/busybox" ;;
  armeabi*) BUSYBOX_BIN="$MODPATH/bin/armeabi-v7a/busybox" ;;
  *)        BUSYBOX_BIN="" ;;
esac

fetch_remote_keybox() {
  if [ -x "$BUSYBOX_BIN" ]; then
    if "$BUSYBOX_BIN" wget --help >/dev/null 2>&1; then
      log_message "- Using busybox wget"
      "$BUSYBOX_BIN" wget -qO- "$REMOTE_URL" | base64 -d > "$TMP_REMOTE"
      return 0
    elif "$BUSYBOX_BIN" curl --help >/dev/null 2>&1; then
      log_message "- Using busybox curl"
      "$BUSYBOX_BIN" curl -fsSL "$REMOTE_URL" | base64 -d > "$TMP_REMOTE"
      return 0
    fi
  fi

  if command -v curl >/dev/null 2>&1; then
    log_message "- Using system curl"
    curl -fsSL "$REMOTE_URL" | base64 -d > "$TMP_REMOTE"
    return 0
  elif command -v wget >/dev/null 2>&1; then
    log_message "- Using system wget"
    wget -qO- "$REMOTE_URL" | base64 -d > "$TMP_REMOTE"
    return 0
  fi

  log_message "- Error: No curl or wget available (busybox or system)."
  return 1
}

update_keybox() {
  log_message "- Fetching remote keybox..."
  if ! fetch_remote_keybox; then
    log_message "- Failed to fetch remote keybox!"
    return
  fi

  if [ -f "$TARGET_FILE" ]; then
    if cmp -s "$TARGET_FILE" "$TMP_REMOTE"; then
      log_message "- Existing Yuri Keybox found. No changes made."
      rm -f "$TMP_REMOTE"
      return
    else
      log_message "- Existing keybox not by Yuri."
      log_message "- Creating a backup..."
      mv "$TARGET_FILE" "$BACKUP_FILE"
    fi
  else
    log_message "- No keybox found. Creating a new one."
  fi

  mv "$TMP_REMOTE" "$TARGET_FILE"
  log_message "- keybox.xml successfully updated."
}

# Start logic
log_message "Checking if there is an Yuri Keybox..."
mkdir -p "$TRICKY_DIR"
version
update_keybox
