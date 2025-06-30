#!/system/bin/sh

# Define important paths and file names
TRICKY_DIR="/data/adb/tricky_store"
REMOTE_URL="https://raw.githubusercontent.com/dpejoh/yurikey/main/conf"
TARGET_FILE="$TRICKY_DIR/keybox.xml"
BACKUP_FILE="$TRICKY_DIR/keybox.xml.bak"
TMP_REMOTE="$TRICKY_DIR/remote_keybox.tmp"
SCRIPT_REMOTE="$TRICKY_DIR/remote_script.sh"
DEPENDENCY_MODULE="/data/adb/modules/tricky_store"

# Show UI banner
ui_print ""
ui_print "*********************************"
ui_print "*****Yuri Keybox Installer*******"
ui_print "*********************************"
ui_print ""

# Detect module install location for bin/busybox (Magisk 24+ may use modules_update)
if [ -d "/data/adb/modules/Yurikey" ]; then
  MODPATH="/data/adb/modules/Yurikey"
elif [ -d "/data/adb/modules_update/Yurikey" ]; then
  MODPATH="/data/adb/modules_update/Yurikey"
else
  ui_print "- Error: Yurikey module path not found!"
  exit 1
fi

# Check if Tricky Store module is installed (required dependency)
if [ ! -d "$DEPENDENCY_MODULE" ]; then
  ui_print "- Error: Tricky Store module not found!"
  ui_print "- Please install Tricky Store before using Yuri Keybox."
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
  ui_print "- Error: No curl or wget available (busybox or system)."
  return 1
}

# Function to update the keybox file
update_keybox() {
  ui_print "- Fetching remote keybox..."
  if ! fetch_remote_keybox; then
    ui_print "- Failed to fetch remote keybox!"
    return
  fi

  # Check if keybox already exists
  if [ -f "$TARGET_FILE" ]; then
    # If the new one is identical, skip update
    if cmp -s "$TARGET_FILE" "$TMP_REMOTE"; then
      ui_print "- Existing Yuri Keybox found. No changes made."
      rm -f "$TMP_REMOTE"
      return
    else
      # If the file differs, back up the old one
      ui_print "- Existing keybox not by Yuri."
      ui_print "- Creating a backup..."
      mv "$TARGET_FILE" "$BACKUP_FILE"
    fi
  else
    ui_print "- No keybox found. Creating a new one."
  fi

  # Move the downloaded keybox into place
  mv "$TMP_REMOTE" "$TARGET_FILE"
  ui_print "- keybox.xml successfully updated."
}

# Start main logic
ui_print "- Checking if there is an Yuri Keybox..."
mkdir -p "$TRICKY_DIR" # Make sure the directory exists
update_keybox          # Begin the update process

# Open Telegram channel at the end
sleep 2
am start -a android.intent.action.VIEW -d tg://resolve?domain=yuriiroot >/dev/null 2>&1
