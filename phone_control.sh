#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
# Phone Control CLI for Termux + Shizuku (Rish) / ADB
# ==============================================================================

CMD="$1"
shift

# Function to route commands via rish (Shizuku) or fallback ADB/native
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
    battery)
        run_cmd dumpsys battery | grep level
        ;;
    tap)
        if [ -z "$1" ] || [ -z "$2" ]; then
            echo "Usage: phone_control.sh tap <x> <y>"
            exit 1
        fi
        run_cmd input tap $1 $2
        ;;
    swipe)
        if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
            echo "Usage: phone_control.sh swipe <x1> <y1> <x2> <y2> [duration_ms]"
            exit 1
        fi
        DURATION="${5:-300}"
        run_cmd input swipe $1 $2 $3 $4 $DURATION
        ;;
    text)
        if [ -z "$1" ]; then
            echo "Usage: phone_control.sh text \"your text here\""
            exit 1
        fi
        # Escape spaces for ADB input
        ESCAPED_TEXT=$(echo "$1" | sed 's/ /%s/g')
        run_cmd input text "$ESCAPED_TEXT"
        ;;
    screenshot)
        FILE="${1:-/sdcard/screen.png}"
        run_cmd screencap -p "$FILE"
        echo "Screenshot saved to $FILE"
        ;;
    open-app)
        if [ -z "$1" ]; then
            echo "Usage: phone_control.sh open-app <package.name>"
            exit 1
        fi
        run_cmd monkey -p $1 -c android.intent.category.LAUNCHER 1
        ;;
    youtube-search)
        if [ -z "$1" ]; then
            echo "Usage: phone_control.sh youtube-search \"query\""
            exit 1
        fi
        QUERY=$(echo "$1" | sed 's/ /+/g')
        run_cmd am start -a android.intent.action.VIEW "https://www.youtube.com/results?search_query=$QUERY"
        ;;
    wifi)
        if [ "$1" = "on" ]; then
            run_cmd svc wifi enable
        elif [ "$1" = "off" ]; then
            run_cmd svc wifi disable
        else
            echo "Usage: phone_control.sh wifi [on|off]"
        fi
        ;;
    home)
        run_cmd input keyevent 3
        ;;
    back)
        run_cmd input keyevent 4
        ;;
    recent|recents)
        run_cmd input keyevent 187
        ;;
    power)
        run_cmd input keyevent 26
        ;;
    volume-up)
        run_cmd input keyevent 24
        ;;
    volume-down)
        run_cmd input keyevent 25
        ;;
    ui-dump)
        FILE="${1:-/sdcard/window_dump.xml}"
        run_cmd uiautomator dump "$FILE"
        echo "UI Dump saved to $FILE"
        ;;
    *)
        echo "Usage: $0 {battery|tap|swipe|text|screenshot|open-app|youtube-search|wifi|home|back|recent|power|volume-up|volume-down|ui-dump}"
        ;;
esac