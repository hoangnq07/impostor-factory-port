#!/bin/bash
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR=/$directory/ports/impostorfactory
BINARY=mkxp-freebird.${DEVICE_ARCH}

CONFDIR="$GAMEDIR/conf/"
mkdir -p "$GAMEDIR/conf"
cd $GAMEDIR

> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

export XDG_DATA_HOME="$CONFDIR"
export LD_LIBRARY_PATH="$GAMEDIR/libs.${DEVICE_ARCH}:$LD_LIBRARY_PATH"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

WOG_FILE=$(ls impostor_factory*.sh 2> /dev/null | head -n 1)

if [ -f "$WOG_FILE" ]; then
    unzip -o "$WOG_FILE"
    if [ -d "data/noarch/game" ]; then
        $ESUDO mv -f data/noarch/game/* "$GAMEDIR/gamedata/" || { pm_message "Failed to move game directory."; sleep 5; exit 1; }
    else
        pm_message "Game directory not found after extraction."
        sleep 5
        exit 1
    fi
    $ESUDO rm -rf data/ meta/ scripts/
    rm -f "$WOG_FILE"
fi

[ -d gamedata/lib64 ] && $ESUDO rm -rf gamedata/lib64

# Auto-recovery if user copied files into $GAMEDIR/data instead of $GAMEDIR/gamedata
if [ -d "$GAMEDIR/data" ] && [ ! -f "$GAMEDIR/gamedata/Game.ini" ]; then
    echo "Found game data in $GAMEDIR/data, moving to gamedata..."
    if [ -f "$GAMEDIR/data/Game.ini" ]; then
        $ESUDO cp -rf "$GAMEDIR/data/"* "$GAMEDIR/gamedata/"
    elif [ -d "$GAMEDIR/data/noarch/game" ]; then
        $ESUDO cp -rf "$GAMEDIR/data/noarch/game/"* "$GAMEDIR/gamedata/"
    fi
fi

# Auto-recovery if user extracted game into a subfolder inside gamedata
for subdir in "$GAMEDIR/gamedata"/*/; do
    if [ -f "${subdir}Game.ini" ] && [ ! -f "$GAMEDIR/gamedata/Game.ini" ]; then
        echo "Found game data nested in $subdir, moving to gamedata root..."
        $ESUDO cp -rf "${subdir}"* "$GAMEDIR/gamedata/"
    fi
done

[ -f "$BINARY" ] && $ESUDO mv "$BINARY" "gamedata/$BINARY"
if [ -f gamedata/mkxp.conf ]; then
    # Performance tuning: skip frames instead of slowing down, no vsync stalls with the fixed 40fps game loop
    sed -i 's/^frameSkip=.*/frameSkip=false/' gamedata/mkxp.conf
    sed -i 's/^vsync=.*/vsync=false/' gamedata/mkxp.conf
    sed -i 's/^smoothScaling=.*/smoothScaling=false/' gamedata/mkxp.conf
    sed -i 's/#fullscreen=true/fullscreen=true/' gamedata/mkxp.conf
fi

# Verify game files exist
if [ ! -f "gamedata/Game.ini" ] && [ ! -f "gamedata/Data/Scripts.rxdata" ]; then
    pm_message "Game data not found in impostorfactory/gamedata/! Please check your game files."
    sleep 5
    exit 1
fi

cd gamedata

# Make sure everything in gamedata is readable by the user running the game
$ESUDO chmod -R a+rX "$GAMEDIR/gamedata" 2>/dev/null

# Recreate Game.ini if it is missing/empty/unreadable (mkxp aborts with
# "FAILED to open Game.ini" otherwise)
if [ ! -s "$GAMEDIR/gamedata/Game.ini" ] || [ ! -r "$GAMEDIR/gamedata/Game.ini" ]; then
    echo "Game.ini missing or unreadable, regenerating..."
    $ESUDO rm -f "$GAMEDIR/gamedata/Game.ini"
    printf '[Game]\r\nLibrary=RGSS104E.dll\r\nScripts=Data\\Scripts.rxdata\r\nTitle=Impostor Factory\r\nRTP1=\r\nRTP2=\r\nRTP3=\r\n' > "$GAMEDIR/gamedata/Game.ini"
fi

# Diagnostics (end up in log.txt)
echo "PWD: $(pwd)"
ls -la "$GAMEDIR/gamedata/Game.ini" "$GAMEDIR/gamedata/mkxp.conf" "$GAMEDIR/gamedata/Data/Scripts.rxdata" 2>&1

chmod +x "$GAMEDIR/gamedata/$BINARY"

# Detect if system glibc is older than 2.34 (e.g. ArkOS legacy based on Ubuntu 19.10)
USE_BUNDLED_GLIBC=0
if [ -f "$GAMEDIR/glibc/ld-linux-aarch64.so.1" ]; then
    if ! grep -q "GLIBC_2.34" /lib/aarch64-linux-gnu/libc.so.6 2>/dev/null && \
       ! grep -q "GLIBC_2.34" /lib/libc.so.6 2>/dev/null && \
       ! grep -q "GLIBC_2.34" /usr/lib/aarch64-linux-gnu/libc.so.6 2>/dev/null; then
        echo "ArkOS legacy detected (system glibc < 2.34). Using bundled glibc 2.35 runtime..."
        USE_BUNDLED_GLIBC=1
        chmod +x "$GAMEDIR/glibc/ld-linux-aarch64.so.1"
        # gptokeyb2 (Select+Start exit) kills the process by name "mkxp-freebird".
        # A process started through ld.so is named after the loader, so run it via a
        # copy of the loader carrying the expected name (symlinks aren't available on FAT/exFAT).
        LOADER="$GAMEDIR/glibc/mkxp-freebird"
        if ! cmp -s "$GAMEDIR/glibc/ld-linux-aarch64.so.1" "$LOADER"; then
            cp -f "$GAMEDIR/glibc/ld-linux-aarch64.so.1" "$LOADER"
        fi
        chmod +x "$LOADER"
        [ -x "$LOADER" ] || LOADER="$GAMEDIR/glibc/ld-linux-aarch64.so.1"
    fi
fi

$GPTOKEYB2 "mkxp-freebird" -c "$GAMEDIR/impostorfactory.ini" &

pm_platform_helper "$GAMEDIR/gamedata/$BINARY"

# Boost CPU/GPU governors while playing (restored afterwards)
OLD_CPU_GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
GPU_GOV_FILE=$(ls /sys/class/devfreq/*/governor 2>/dev/null | grep -i gpu | head -n 1)
OLD_GPU_GOV=""
[ -n "$GPU_GOV_FILE" ] && OLD_GPU_GOV=$(cat "$GPU_GOV_FILE" 2>/dev/null)
if [ -n "$OLD_CPU_GOV" ]; then
    for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo performance | $ESUDO tee "$g" > /dev/null 2>&1
    done
fi
[ -n "$OLD_GPU_GOV" ] && echo performance | $ESUDO tee "$GPU_GOV_FILE" > /dev/null 2>&1

if [ "$USE_BUNDLED_GLIBC" -eq 1 ]; then
    GLIBC_LIB_PATH="$GAMEDIR/glibc:$GAMEDIR/libs.${DEVICE_ARCH}:$LD_LIBRARY_PATH:/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu:/usr/lib:/lib"
    "$LOADER" --library-path "$GLIBC_LIB_PATH" "$GAMEDIR/gamedata/$BINARY" --gameFolder="$GAMEDIR/gamedata" --preloadScript="preload/ruby18_comp.rb" --preloadScript="preload/win32_wrap.rb" --preloadScript="$GAMEDIR/patches/ums_name_fix.rb"
else
    ./$BINARY --gameFolder="$GAMEDIR/gamedata" --preloadScript="preload/ruby18_comp.rb" --preloadScript="preload/win32_wrap.rb" --preloadScript="$GAMEDIR/patches/ums_name_fix.rb"
fi

# Restore governors
if [ -n "$OLD_CPU_GOV" ]; then
    for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "$OLD_CPU_GOV" | $ESUDO tee "$g" > /dev/null 2>&1
    done
fi
[ -n "$OLD_GPU_GOV" ] && echo "$OLD_GPU_GOV" | $ESUDO tee "$GPU_GOV_FILE" > /dev/null 2>&1

pm_finish

