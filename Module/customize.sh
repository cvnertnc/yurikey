#!/system/bin/sh

TRICKY_DIR="/data/adb/tricky_store"
REMOTE_URL="https://raw.githubusercontent.com/dpejoh/yurikey/main/conf"
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

ui_print ""
ui_print "*********************************"
ui_print "*****Yuri Keybox Installer*******"
ui_print "*********************************"
ui_print ""

# Check for dependency: Tricky Store module
if [ ! -d "$DEPENDENCY_MODULE" ]; then
  ui_print "- Error: Tricky Store module not found!"
  ui_print "- Please install Tricky Store before using Yuri Keybox."
  exit 1
fi

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
      ui_print "- Using busybox wget"
      "$BUSYBOX_BIN" wget -qO- "$REMOTE_URL" | base64 -d > "$TMP_REMOTE"
      return 0
    elif "$BUSYBOX_BIN" curl --help >/dev/null 2>&1; then
      ui_print "- Using busybox curl"
      "$BUSYBOX_BIN" curl -fsSL "$REMOTE_URL" | base64 -d > "$TMP_REMOTE"
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
  return 1
}

update_keybox() {
  ui_print "- Fetching remote keybox..."
  if ! fetch_remote_keybox; then
    ui_print "- Failed to fetch remote keybox!"
    return
  fi

  if [ -f "$TARGET_FILE" ]; then
    if cmp -s "$TARGET_FILE" "$TMP_REMOTE"; then
      ui_print "- Existing Yuri Keybox found. No changes made."
      rm -f "$TMP_REMOTE"
      return
    else
      ui_print "- Existing keybox not by Yuri."
      ui_print "- Creating a backup..."
      mv "$TARGET_FILE" "$BACKUP_FILE"
    fi
  else
    ui_print "- No keybox found. Creating a new one."
  fi

  mv "$TMP_REMOTE" "$TARGET_FILE"
  ui_print "- keybox.xml successfully updated."
}

# Start logic
ui_print "- Checking if there is an Yuri Keybox..."
mkdir -p "$TRICKY_DIR"
update_keybox

sleep 2
am start -a android.intent.action.VIEW -d tg://resolve?domain=yuriiroot >/dev/null 2>&1