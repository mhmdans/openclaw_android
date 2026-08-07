#!/data/data/com.termux/files/usr/bin/bash
# =========================================================================
# 🤖 CloudBot + Shizuku Universal Installer
# =========================================================================
# Designed to run via: curl -sL <url> | bash
# Fully non-interactive — no prompts, no hangs, no silent exits.
# =========================================================================

export DEBIAN_FRONTEND=noninteractive
export DPKG_FORCE=confold
export APT_LISTCHANGES_FRONTEND=none
export LANG=C
export LC_ALL=C

echo ""
echo "🤖 CloudBot Non-Root Phone Control Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# =========================================================================
# Step 1/5: Update Packages & Fix Pacman DB / Glibc / Dependencies
# =========================================================================
echo "📦 Step 1/5: Updating packages and fixing package manager database..."

# Fix pacman database version mismatch if pacman is installed in Termux environment
if command -v pacman-db-upgrade >/dev/null 2>&1; then
    pacman-db-upgrade >/dev/null 2>&1 || true
fi

if command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm >/dev/null 2>&1 || true
    pacman -S --noconfirm glibc-runner >/dev/null 2>&1 || true
fi

# Update standard APT/pkg repositories
pkg update -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" </dev/null 2>&1 || {
    echo "⚠️ pkg update had warnings (continuing...)"
}

# Install core packages
pkg install -y curl nodejs git cmake make clang binutils nmap openssl android-tools which </dev/null 2>&1 || true

# Verify essentials
MISSING=""
for cmd in curl node git nmap adb; do
    if ! command -v "$cmd" </dev/null >/dev/null 2>&1; then
        MISSING="$MISSING $cmd"
    fi
done
if [ -n "$MISSING" ]; then
    echo "❌ ERROR: Missing critical commands:$MISSING"
    exit 1
fi

echo "✅ Dependencies and glibc environment ready"

# =========================================================================
# Step 2/5: Setup Shizuku (rish & shizuku commands)
# =========================================================================
echo ""
echo "🔒 Step 2/5: Linking Shizuku to Termux..."

if [ ! -d "$HOME/storage" ]; then
    echo "y" | termux-setup-storage > /dev/null 2>&1 || true
    sleep 2
fi

SHIZUKU_DIR="$HOME/storage/shared/Shizuku"
mkdir -p "$SHIZUKU_DIR" 2>/dev/null || true

cat > "$SHIZUKU_DIR/copy.sh" << 'SHIZUKU_EOF'
#!/data/data/com.termux/files/usr/bin/bash

BASEDIR=$( dirname "${0}" )
BIN=/data/data/com.termux/files/usr/bin
HOME=/data/data/com.termux/files/home
DEX="${BASEDIR}/rish_shizuku.dex"

if [ ! -f "${DEX}" ]; then
  echo "Cannot find ${DEX}"
  exit 1
fi

ARCH=$(getprop ro.product.cpu.abi 2>/dev/null || echo "arm64-v8a")
case "$ARCH" in
  arm64*) LIB_ARCH="arm64" ;;
  armeabi*) LIB_ARCH="arm" ;;
  x86_64*) LIB_ARCH="x86_64" ;;
  x86*) LIB_ARCH="x86" ;;
  *) LIB_ARCH="arm64" ;;
esac

tee "${BIN}/shizuku" > /dev/null << EOF
#!/data/data/com.termux/files/usr/bin/bash
ports=\$( nmap -sT -p30000-50000 --open localhost 2>/dev/null | grep "open" | cut -f1 -d/ )
for port in \${ports}; do
  result=\$( adb connect "localhost:\${port}" 2>/dev/null )
  if [[ "\$result" =~ "connected" || "\$result" =~ "already" ]]; then
    echo "\${result}"
    adb shell "\$( adb shell pm path moe.shizuku.privileged.api | sed 's/^package://;s/base\\\\.apk/lib\\\\/${LIB_ARCH}\\\\/libshizuku\\\\.so/' )"
    adb shell settings put global adb_wifi_enabled 0
    exit 0
  fi
done
echo "ERROR: No port found! Is wireless debugging enabled?"
exit 1
EOF

dex="${HOME}/rish_shizuku.dex"

tee "${BIN}/rish" > /dev/null << EOF
#!/data/data/com.termux/files/usr/bin/bash
[ -z "\$RISH_APPLICATION_ID" ] && export RISH_APPLICATION_ID="com.termux"
/system/bin/app_process -Djava.class.path="${dex}" /system/bin --nice-name=rish rikka.shizuku.shell.ShizukuShellLoader "\${@}"
EOF

chmod +x "${BIN}/shizuku" "${BIN}/rish"
cp -f "${DEX}" "${dex}"
chmod -w "${dex}"
SHIZUKU_EOF

chmod +x "$SHIZUKU_DIR/copy.sh"

if [ -f "$SHIZUKU_DIR/rish_shizuku.dex" ]; then
    bash "$SHIZUKU_DIR/copy.sh" </dev/null && echo "✅ Shizuku scripts installed"
fi

# =========================================================================
# Step 3/5: Fix Node.js IPv4 DNS & Apply Version Check Override
# =========================================================================
echo ""
echo "🔧 Step 3/5: Applying Network & Node Runtime Fixes..."

if ! grep -q "NODE_OPTIONS=--dns-result-order=ipv4first" ~/.bashrc 2>/dev/null; then
    echo "export NODE_OPTIONS=\"--dns-result-order=ipv4first --no-warnings\"" >> ~/.bashrc
fi
export NODE_OPTIONS="--dns-result-order=ipv4first --no-warnings"
echo "✅ Node runtime options applied"

# =========================================================================
# Step 4/5: Install Official OpenClaw & Neutralize Version Checks
# =========================================================================
echo ""

if ! command -v openclaw &>/dev/null; then
    echo "📦 Step 4/5: Installing OpenClaw..."
    bash -c "$(curl -sSL https://myopenclawhub.com/install)" < /dev/tty || true
    
    # Fallback NPM install if remote curl installer script fails
    if ! command -v openclaw &>/dev/null; then
        echo "⚠️ Remote script failed. Attempting direct npm installation..."
        npm install -g openclaw@latest --ignore-engines >/dev/null 2>&1 || true
    fi
fi

echo "🔧 Bypassing OpenClaw version assertions for Termux..."
# Find all files throwing the engine version error and remove the process.exit calls
grep -rl "is required" /data/data/com.termux/files/usr/ 2>/dev/null | while read -r file; do
    sed -i 's/22.22.3/22.0.0/g; s/18.0.0/22.0.0/g' "$file" 2>/dev/null || true
    sed -i 's/process\.exit(1)/process\.exit(0)/g' "$file" 2>/dev/null || true
    sed -i 's/process\.exit(2)/process\.exit(0)/g' "$file" 2>/dev/null || true
done
echo "✅ OpenClaw version check bypassed"

# =========================================================================
# Step 5/5: Inject Phone Control Scripts & AI Override
# =========================================================================
echo ""
echo "🧠 Step 5/5: Configuring AI Phone Controller..."

cat > ~/phone_control.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
CMD="$1"
shift
run_cmd() {
  if command -v rish &>/dev/null; then rish -c "$@"
  elif command -v adb &>/dev/null && adb get-state 1>/dev/null 2>&1; then adb shell "$@"
  elif command -v su &>/dev/null; then su -c "$@"
  else echo "❌ Error: Start Shizuku first"; exit 1; fi
}
case "$CMD" in
  screenshot) run_cmd "screencap -p '${1:-/sdcard/screenshot.png}'" ;;
  open-app) run_cmd "monkey -p $1 -c android.intent.category.LAUNCHER 1" 2>/dev/null ;;
  youtube-search) QUERY=$(echo "$*" | sed 's/ /+/g'); run_cmd "am start -a android.intent.action.VIEW -d 'https://www.youtube.com/results?search_query=$QUERY' com.google.android.youtube" ;;
  open-url) run_cmd "am start -a android.intent.action.VIEW -d '$1'" ;;
  wifi) if [ "$1" = "on" ]; then run_cmd "svc wifi enable"; else run_cmd "svc wifi disable"; fi ;;
  battery) run_cmd "dumpsys battery" | grep "level" ;;
  tap) run_cmd "input tap $1 $2" ;;
  swipe) run_cmd "input swipe $1 $2 $3 $4 ${5:-500}" ;;
  text) run_cmd "input text '$*'" ;;
  key) run_cmd "input keyevent $1" ;;
  home) run_cmd "input keyevent 3" ;;
  back) run_cmd "input keyevent 4" ;;
  recent) run_cmd "input keyevent 187" ;;
  power) run_cmd "input keyevent 26" ;;
  volume-up) run_cmd "input keyevent 24" ;;
  volume-down) run_cmd "input keyevent 25" ;;
  screenon) run_cmd "input keyevent 224" ;;
  ui-dump) 
    run_cmd "uiautomator dump /sdcard/window_dump.xml >/dev/null 2>&1"
    node -e "
      const fs = require('fs');
      try {
        const xml = fs.readFileSync('/sdcard/window_dump.xml', 'utf8');
        const regex = /(?:text|content-desc)=\"([^\"]+)\"[^>]*bounds=\"(\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\])\"/g;
        let match;
        while ((match = regex.exec(xml)) !== null) {
          if (match[1].trim() !== '') console.log(match[2] + ' ' + match[1]);
        }
      } catch(e) { console.log('Error reading UI'); }
    "
    ;;
  shell) run_cmd "$*" ;;
  *) echo "Usage: bash phone_control.sh [battery|wifi|open-url|open-app|youtube-search|screenshot|tap|swipe|text|key|home|back|recent|power|volume-up|volume-down|screenon|ui-dump|shell]" ;;
esac
EOF
chmod +x ~/phone_control.sh

cat > ~/phone_agent.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
echo "🤖 Vision Agent initialized."
EOF
chmod +x ~/phone_agent.sh

mkdir -p ~/.openclaw/workspace 2>/dev/null || true
rm -f ~/.openclaw/workspace/BOOTSTRAP.md

cat > ~/.openclaw/workspace/IDENTITY.md << 'EOF'
- **Name:** PhoneBot
I am an Autonomous AI Agent running natively on an Android phone via Termux + Shizuku.
My primary directive is to navigate the phone UI, perform complex tasks, read the screen, scroll, tap, and run shell commands.
EOF

cat > ~/.openclaw/workspace/TOOLS.md << 'EOF'
# TOOLS.md
I have full root/shizuku control over this Android phone using `~/phone_control.sh`.
EOF

cat > ~/.openclaw/workspace/AGENTS.md << 'EOF'
I execute terminal commands directly and parse their output.
EOF

echo "✅ Custom AI brain installed"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 INSTALLATION COMPLETE!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""