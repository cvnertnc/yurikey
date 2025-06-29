#!/system/bin/sh

MODPATH="${0%/*}"
TRICKY_DIR="/data/adb/tricky_store"
REMOTE_URL="https://raw.githubusercontent.com/dpejoh/yurikey/main/conf"
VERSION_URL="https://raw.githubusercontent.com/dpejoh/yurikey/main/version"
TARGET_FILE="$TRICKY_DIR/keybox.xml"
BACKUP_FILE="$TRICKY_DIR/keybox.xml.bak"
TMP_REMOTE="$TRICKY_DIR/remote_keybox.tmp"
SCRIPT_REMOTE="$TRICKY_DIR/remote_script.sh"
DEPENDENCY_MODULE="/data/adb/modules/tricky_store"

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

ARCH=$(getprop ro.product.cpu.abi)
if [ "$ARCH" = "arm64-v8a" ]; then
  BUSYBOX_BIN="$MODPATH/bin/arm64-v8a/busybox"
else
  BUSYBOX_BIN="$MODPATH/bin/armeabi-v7a/busybox"
fi

[ -f "$BUSYBOX_BIN" ] && chmod +x "$BUSYBOX_BIN"

fetch_remote_keybox() {
  ui_print "- Detecting busybox/system curl/wget..."

  if [ -x "$BUSYBOX_BIN" ]; then
    if "$BUSYBOX_BIN" curl --version >/dev/null 2>&1; then
      ui_print "- Using busybox curl"
      "$BUSYBOX_BIN" curl -fsSL "$REMOTE_URL" | base64 -d > "$TMP_REMOTE"
      return 0
    elif "$BUSYBOX_BIN" wget --version >/dev/null 2>&1; then
      ui_print "- Using busybox wget"
      "$BUSYBOX_BIN" wget -qO- "$REMOTE_URL" | base64 -d > "$TMP_REMOTE"
      return 0
    fi
  fi

  if command -v curl >/dev/null 2>&1; then
    ui_print "- Using system curl"
    curl -fsSL "$REMOTE_URL" | base64 -d > "$TMP_REMOTE"
    return 0
  elif command -v wget >/dev/null 2>&1; then
    ui_print "- Using system wget"
    wget -qO- "$REMOTE_URL" | base64 -d > "$TMP_REMOTE"
    return 0
  fi

  ui_print "- Error: No curl or wget available (busybox or system)."
  ui_print "- Cannot fetch remote keybox."
  return 1
}

update_keybox() {
  log_message "Fetching remote keybox..."
  if ! fetch_remote_keybox; then
    return
  fi

  if [ -f "$TARGET_FILE" ]; then
    if cmp -s "$TARGET_FILE" "$TMP_REMOTE"; then
      log_message "Existing Yuri Keybox found. No changes made."
      rm -f "$TMP_REMOTE"
      return
    else
      log_message "Existing keybox not by Yuri."
      log_message "Creating a backup..."
      mv "$TARGET_FILE" "$BACKUP_FILE"
    fi
  else
    log_message "No keybox found. Creating a new one."
  fi

  mv "$TMP_REMOTE" "$TARGET_FILE"
  log_message "keybox.xml successfully updated."
}

# Start logic
log_message "Checking if there is an Yuri Keybox..."
mkdir -p "$TRICKY_DIR"
version
update_keybox
