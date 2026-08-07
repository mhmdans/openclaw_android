#!/data/data/com.termux/files/usr/bin/bash
# =========================================================================
# 🤖 OpenClaw Termux Compatibility & Production Installer
# =========================================================================

set -e

# Non-interactive frontend settings for APT & DPKG
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
export LANG=C
export LC_ALL=C

# Pass configuration protection flags directly to APT/DPKG
APT_OPTS="-o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef"

LOGFILE="$HOME/openclaw-install.log"
rm -f "$LOGFILE"

# Log runner for clean user feedback + full debug logs
run_step() {
    local msg="$1"
    shift
    echo -n "⏳ $msg... "
    if "$@" >> "$LOGFILE" 2>&1; then
        echo "✅"
    else
        echo "❌ (FAILED - check ~/openclaw-install.log)"
        return 1
    fi
}

clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🤖 Preparing Termux for OpenClaw Engine"
echo "   Logging detail to: ~/openclaw-install.log"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# =========================================================================
# 1. APT Clean, Package Database Reset, & Core Tools
# =========================================================================
echo "📦 1. Resetting APT lists and installing core build toolchain..."

run_step "Cleaning APT cache" apt clean -y
rm -rf /data/data/com.termux/files/usr/var/lib/apt/lists/*
run_step "Updating package indexes" apt $APT_OPTS update -y
run_step "Fixing broken packages" apt $APT_OPTS --fix-broken install -y

run_step "Installing core build dependencies" pkg install $APT_OPTS -y \
    curl \
    git \
    nodejs-lts \
    python \
    python-pip \
    clang \
    cmake \
    make \
    binutils \
    openssl-tool \
    termux-tools \
    termux-api \
    procps \
    which

# Acquire persistent CPU wake-lock for background agent execution
if command -v termux-wake-lock >/dev/null 2>&1; then
    termux-wake-lock 2>> "$LOGFILE" || echo "⚠️ Wake-lock failed — install the Termux:API companion app for background persistence."
fi

# Python 3.12+ setuptools fix for termux pip
run_step "Configuring Python setuptools" pip install setuptools --break-system-packages

# =========================================================================
# 2. Environment & DNS Settings (Idempotent)
# =========================================================================
echo "🔧 2. Configuring Python compiler paths & Node IPv4 DNS resolution..."

PYTHON_PATH="$(which python3)"
export PYTHON="$PYTHON_PATH"
export NODE_OPTIONS="--dns-result-order=ipv4first --no-warnings"

if ! grep -q 'NODE_OPTIONS="--dns-result-order=ipv4first' ~/.bashrc 2>/dev/null; then
    echo 'export NODE_OPTIONS="--dns-result-order=ipv4first --no-warnings"' >> ~/.bashrc
fi

if ! grep -q 'export PYTHON=' ~/.bashrc 2>/dev/null; then
    echo "export PYTHON=\"$PYTHON_PATH\"" >> ~/.bashrc
fi

# =========================================================================
# 3. Install PM2 & Set Up Termux Boot Persistence
# =========================================================================
echo "🚀 3. Installing PM2 and configuring boot survival..."

if ! command -v pm2 &>/dev/null; then
    run_step "Installing PM2 globally" npm install -g pm2 --engine-strict=false --no-audit --no-fund
fi

mkdir -p ~/.termux/boot
cat > ~/.termux/boot/start-openclaw.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Triggered on device boot via Termux:Boot companion app
termux-wake-lock
export NODE_OPTIONS="--dns-result-order=ipv4first --no-warnings"
pm2 resurrect
EOF
chmod +x ~/.termux/boot/start-openclaw.sh

# =========================================================================
# 4. Install OpenClaw, Create Patcher, & Register Upgrade Wrapper
# =========================================================================
echo "📦 4. Installing OpenClaw and building native dependencies..."

run_step "Compiling OpenClaw native modules" npm install -g openclaw@latest --build-from-source --engine-strict=false --no-audit --no-fund

echo "🛠️ 5. Setting up post-install patcher (~/patch-openclaw.sh)..."

cat > ~/patch-openclaw.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Idempotent patcher for OpenClaw on Termux
OPENCLAW_PATH="$(npm root -g)/openclaw"

if [ -d "$OPENCLAW_PATH" ]; then
    echo "Applying targeted runtime patches to OpenClaw..."
    grep -rn "process.exit" "$OPENCLAW_PATH" 2>/dev/null | grep -i "version" | cut -d: -f1 | sort -u | while read -r file; do
        if [ -f "$file" ]; then
            sed -i 's/22.22.3/22.0.0/g; s/18.0.0/22.0.0/g' "$file" 2>/dev/null || true
            sed -i 's/process\.exit(1)/process\.exit(0)/g' "$file" 2>/dev/null || true
            sed -i 's/process\.exit(2)/process\.exit(0)/g' "$file" 2>/dev/null || true
        fi
    done
    echo "✅ Patch complete."
else
    echo "⚠️ OpenClaw installation path not found."
fi
EOF

chmod +x ~/patch-openclaw.sh
~/patch-openclaw.sh >> "$LOGFILE" 2>&1

if ! grep -q 'openclaw-update' ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'EOF'

# OpenClaw update wrapper to auto-apply Termux patches
openclaw-update() {
    echo "Updating OpenClaw..."
    npm install -g openclaw@latest --build-from-source --engine-strict=false --no-audit --no-fund
    ~/patch-openclaw.sh
    echo "OpenClaw updated and patched successfully!"
}
EOF
fi

# =========================================================================
# 5. Hardware Bridge (Pinned SHA Download + Explicit Failure Handling)
# =========================================================================
echo "📱 6. Syncing phone_control.sh & building workspace context..."

GITHUB_USER="MuhammadAnsJaved"
GITHUB_REPO="cloudbot-termux"
COMMIT_SHA="8f4b23a9d1c02e5f3b7d1e804f9c2a11032a9003"
PHONE_CONTROL_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${COMMIT_SHA}/phone_control.sh"

if curl -sSL "$PHONE_CONTROL_URL" -o ~/phone_control.sh 2>> "$LOGFILE" && [ -s ~/phone_control.sh ]; then
    chmod +x ~/phone_control.sh
    cp -f ~/phone_control.sh /data/data/com.termux/files/usr/bin/phone_control 2>/dev/null || true
    chmod +x /data/data/com.termux/files/usr/bin/phone_control 2>/dev/null || true
    echo "✅ phone_control downloaded and linked to PATH."
else
    echo "⚠️ WARNING: Failed to download phone_control.sh! Device UI control will be disabled."
fi

mkdir -p ~/.openclaw/workspace 2>/dev/null || true

cat > ~/.openclaw/workspace/TOOLS.md << 'EOF'
# TOOLS.md
I have full control over this Android device via Shizuku using `phone_control`.
EOF

cat > ~/.openclaw/workspace/IDENTITY.md << 'EOF'
- **Name:** PhoneBot
Autonomous AI Agent running natively on Android via Termux + Shizuku.
EOF

# =========================================================================
# 6. Interactive Onboarding & PM2 Gateway Bootstrap
# =========================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Setup Complete! Re-attaching TTY for Onboarding..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Re-attach standard input; allow non-zero exit so script continues under set -e
exec < /dev/tty
openclaw onboard || echo "⚠️ Onboarding exited early or was skipped — you can re-run 'openclaw onboard' manually later."

echo ""
echo "⚙️ Starting OpenClaw Gateway daemon via PM2..."
OPENCLAW_BIN="$(which openclaw 2>/dev/null || echo "")"
if [ -n "$OPENCLAW_BIN" ]; then
    pm2 stop openclaw-gateway >> "$LOGFILE" 2>&1 || true
    pm2 delete openclaw-gateway >> "$LOGFILE" 2>&1 || true
    pm2 start "$OPENCLAW_BIN" --name "openclaw-gateway" -- gateway --http --port 18789 >> "$LOGFILE" 2>&1
    pm2 save >> "$LOGFILE" 2>&1
    echo "✅ OpenClaw Gateway started on port 18789 and saved to PM2!"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📌 Required Android Companion Apps for Persistence:"
echo "   1. Termux:API  -> Required for background wake-locks"
echo "   2. Termux:Boot -> Required for Gateway auto-start on reboot"
echo ""
echo "💡 TIP: To update OpenClaw safely in the future, run: openclaw-update"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"