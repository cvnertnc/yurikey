#!/system/bin/sh

# Define important paths and file names
TRICKY_DIR="/data/adb/tricky_store"
REMOTE_URL="https://raw.githubusercontent.com/dpejoh/yurikey/main/conf"
TARGET_FILE="$TRICKY_DIR/keybox.xml"
BACKUP_FILE="$TRICKY_DIR/keybox.xml.bak"
TMP_REMOTE="$TRICKY_DIR/remote_keybox.tmp"
SCRIPT_REMOTE="$TRICKY_DIR/remote_script.sh"
DEPENDENCY_MODULE="/data/adb/modules/tricky_store"

# For detailed logs
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') [YURI_KEYBOX] $1"
}

log_message "Start"

# Remove old module if legacy path exists (lowercase 'yurikey')
if [ -d "/data/adb/modules/yurikey" ]; then
  touch /data/adb/modules/yurikey/remove
fi

# Detect module install location for bin/busybox (Magisk 24+ may use modules_update)
if [ -d "/data/adb/modules/Yurikey" ]; then
  MODPATH="/data/adb/modules/Yurikey"
elif [ -d "/data/adb/modules_update/Yurikey" ]; then
  MODPATH="/data/adb/modules_update/Yurikey"
else
  log_message "Error: Yurikey module path not found!"
  exit 1
fi

# Check if Tricky Store module is installed (required dependency)
if [ ! -d "$DEPENDENCY_MODULE" ]; then
  log_message "Error: Tricky Store module not found!"
  log_message "Please install Tricky Store before using Yuri Keybox."
  exit 1
fi

# Ensure all busybox binaries inside /bin/ are executable
find "$MODPATH/bin" -type f -name busybox -exec chmod 755 {} \;

# Detect device CPU architecture to choose correct busybox binary
ARCH=$(getprop ro.product.cpu.abi)
case "$ARCH" in
  arm64*)   BUSYBOX_BIN="$MODPATH/bin/arm64-v8a/busybox" ;;
  armeabi*) BUSYBOX_BIN="$MODPATH/bin/armeabi-v7a/busybox" ;;
  *)        BUSYBOX_BIN="" ;; # Fallback if unknown architecture
esac

# Function to download the remote keybox using busybox or system tools
fetch_remote_keybox() {
  # Try using busybox's wget or curl first (preferred)
  if [ -x "$BUSYBOX_BIN" ]; then
    if "$BUSYBOX_BIN" wget --help >/dev/null 2>&1; then
      "$BUSYBOX_BIN" wget -qO- "$REMOTE_URL" | base64 -d > "$TMP_REMOTE"
      return 0
    elif "$BUSYBOX_BIN" curl --help >/dev/null 2>&1; then
      "$BUSYBOX_BIN" curl -fsSL "$REMOTE_URL" | base64 -d > "$TMP_REMOTE"
      return 0
    fi
  fi

  # If busybox tools are not available, fall back to system curl or wget
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$REMOTE_URL" | base64 -d > "$TMP_REMOTE"
    return 0
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$REMOTE_URL" | base64 -d > "$TMP_REMOTE"
    return 0
  fi

  # If nothing is available, exit with error
  log_message "Error: No curl or wget available (busybox or system)."
  return 1
}

# Function to update the keybox file
update_keybox() {
  log_message "Writing"
  if ! fetch_remote_keybox; then
    log_message "Failed to Writing remote keybox!"
    return
  fi

  # Check if keybox already exists
  if [ -f "$TARGET_FILE" ]; then
    # If the new one is identical, skip update
    if cmp -s "$TARGET_FILE" "$TMP_REMOTE"; then
      rm -f "$TMP_REMOTE"
      return
    else
      # If the file differs, back up the old one
      mv "$TARGET_FILE" "$BACKUP_FILE"
    fi
  fi

  # Move the downloaded keybox into place
  mv "$TMP_REMOTE" "$TARGET_FILE"
}

# Start main logic
mkdir -p "$TRICKY_DIR" # Make sure the directory exists
update_keybox          # Begin the update process

log_message "Finish"
