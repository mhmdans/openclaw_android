cat << 'EOF' > /data/data/com.termux/files/usr/bin/phone_control
#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# Phone Control CLI for Termux + Shizuku (Rish) / ADB
# Optimized for Android 10 (Realme UI / ColorOS) & AI Agent Automation
# ==============================================================================

CMD="$1"
shift

run_cmd() {
    if command -v rish &>/dev/null; then
        rish -c "$*"
    elif command -v adb &>/dev/null; then
        adb shell "$*"
    else
        eval "$*"
    fi
}

case "$CMD" in
# ==========================
# 1. UI Interactions
# ==========================
tap)
    [ -z "$2" ] && { echo "Usage: phone_control tap <x> <y>"; exit 1; }
    run_cmd "input tap $1 $2"
    ;;
swipe)
    [ -z "$4" ] && { echo "Usage: phone_control swipe <x1> <y1> <x2> <y2> [duration_ms]"; exit 1; }
    run_cmd "input swipe $1 $2 $3 $4 ${5:-300}"
    ;;
text)
    [ -z "$1" ] && { echo "Usage: phone_control text \"string\""; exit 1; }
    # Escape spaces for ADB input text
    ESCAPED_TEXT=$(echo "$1" | sed -e 's/ /%s/g' -e 's/&/\\&/g' -e 's/"/\\"/g' -e "s/'/\\\\'/g")
    run_cmd "input text \"$ESCAPED_TEXT\""
    ;;
enter) run_cmd "input keyevent 66" ;;
delete) run_cmd "input keyevent 67" ;;
space) run_cmd "input keyevent 62" ;;
tab) run_cmd "input keyevent 61" ;;

# ==========================
# 2. System & Apps
# ==========================
open-app)
    [ -z "$1" ] && { echo "Usage: phone_control open-app <package.name>"; exit 1; }
    # Android 10 foreground launch fix: use monkey with explicit intent flags or am start
    run_cmd "monkey -p $1 -c android.intent.category.LAUNCHER 1" > /dev/null 2>&1
    sleep 1
    ;;
open-telegram)
    # Direct explicit activity start for Telegram on Android 10 / ColorOS
    run_cmd "am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n org.telegram.messenger/org.telegram.ui.LaunchActivity"
    sleep 1
    ;;
telegram-msg)
    [ -z "$1" ] && { echo "Usage: phone_control telegram-msg \"username\" [message]"; exit 1; }
    USER="$1"
    MSG="$2"
    if [ -n "$MSG" ]; then
        ENCODED_MSG=$(echo "$MSG" | sed 's/ /%20/g')
        run_cmd "am start -a android.intent.action.VIEW -d \"https://t.me/$USER?text=$ENCODED_MSG\""
    else
        run_cmd "am start -a android.intent.action.VIEW -d \"tg://resolve?domain=$USER\""
    fi
    ;;
close-app)
    [ -z "$1" ] && { echo "Usage: phone_control close-app <package.name>"; exit 1; }
    run_cmd "am force-stop $1"
    ;;
clear-app)
    [ -z "$1" ] && { echo "Usage: phone_control clear-app <package.name>"; exit 1; }
    run_cmd "pm clear $1"
    ;;
list-apps)
    run_cmd "pm list packages | sed 's/package://'"
    ;;
current-app)
    run_cmd "dumpsys window | grep -E 'mCurrentFocus|mFocusedApp'"
    ;;
youtube-search)
    [ -z "$1" ] && { echo "Usage: phone_control youtube-search \"query\""; exit 1; }
    QUERY=$(echo "$1" | sed 's/ /+/g')
    run_cmd "am start -a android.intent.action.VIEW -d \"https://www.youtube.com/results?search_query=$QUERY\""
    ;;
open-url)
    [ -z "$1" ] && { echo "Usage: phone_control open-url \"https://url.com\""; exit 1; }
    run_cmd "am start -a android.intent.action.VIEW -d \"$1\""
    ;;

# ==========================
# 3. Hardware & Power
# ==========================
home) run_cmd "input keyevent 3" ;;
back) run_cmd "input keyevent 4" ;;
recent|recents) run_cmd "input keyevent 187" ;;
power) run_cmd "input keyevent 26" ;;
wake) run_cmd "input keyevent 224" ;;
volume-up) run_cmd "input keyevent 24" ;;
volume-down) run_cmd "input keyevent 25" ;;
media)
    [ -z "$1" ] && { echo "Usage: phone_control media [play|pause|next|previous]"; exit 1; }
    run_cmd "media dispatch $1"
    ;;

# ==========================
# 4. Toggles & Settings
# ==========================
wifi)
    [ "$1" = "on" ] && run_cmd "svc wifi enable" || run_cmd "svc wifi disable"
    ;;
data)
    [ "$1" = "on" ] && run_cmd "svc data enable" || run_cmd "svc data disable"
    ;;
bluetooth)
    [ "$1" = "on" ] && run_cmd "svc bluetooth enable" || run_cmd "svc bluetooth disable"
    ;;
notifications)
    run_cmd "cmd statusbar expand-notifications"
    ;;
quick-settings)
    run_cmd "cmd statusbar expand-settings"
    ;;
brightness)
    [ -z "$1" ] && { echo "Usage: phone_control brightness <0-255>"; exit 1; }
    run_cmd "settings put system screen_brightness $1"
    ;;

# ==========================
# 5. Inspection & Debugging
# ==========================
battery)
    run_cmd "dumpsys battery | grep level"
    ;;
screen-state)
    run_cmd "dumpsys power | grep mWakefulness"
    ;;
device-info)
    echo "Model: $(run_cmd getprop ro.product.model)"
    echo "Resolution: $(run_cmd wm size | grep -oE '[0-9]+x[0-9]+')"
    echo "Density: $(run_cmd wm density | grep -oE '[0-9]+')"
    ;;
ui-dump)
    FILE="${1:-/sdcard/window_dump.xml}"
    # Android 10 requires compressed dump flag to prevent accessibility timeouts
    run_cmd "uiautomator dump --compressed $FILE" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "UI Dump saved to $FILE"
    else
        # Fallback to standard dump if --compressed flag is rejected
        run_cmd "uiautomator dump $FILE"
        echo "UI Dump saved to $FILE"
    fi
    ;;
screenshot)
    FILE="${1:-/sdcard/screen.png}"
    run_cmd "screencap -p $FILE"
    echo "Screenshot saved to $FILE"
    ;;
*)
    echo "Available Commands:"
    echo "  UI:        tap, swipe, text, enter, delete, space, tab"
    echo "  Apps:      open-app, open-telegram, telegram-msg, close-app, clear-app, list-apps, current-app, youtube-search, open-url"
    echo "  Hardware:  home, back, recent, power, wake, volume-up, volume-down, media"
    echo "  Settings:  wifi, data, bluetooth, notifications, quick-settings, brightness"
    echo "  Inspect:   battery, screen-state, device-info, ui-dump, screenshot"
    ;;
esac
EOF

# Grant execute permissions
chmod +x /data/data/com.termux/files/usr/bin/phone_control