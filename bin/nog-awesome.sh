#!/bin/bash
JUNEST="$HOME/.local/share/junest/bin/junest"
U=$(id -u)

BINDS="--bind /sgoinfre /sgoinfre --bind /goinfre /goinfre --bind /dev/shm /dev/shm --dev-bind /dev/dri /dev/dri --dev-bind /dev/snd /dev/snd --bind /run /run --bind /tmp/.X11-unix /tmp/.X11-unix --bind /usr /host/usr --bind /opt /opt"

MONITOR_PID=$(pgrep -u "$USER" -f "gnome-session-ctl --monitor")
BINARY_PIDS=$(pgrep -u "$USER" -f "gnome-session-binary")

kill -STOP $MONITOR_PID
for pid in $BINARY_PIDS; do kill -STOP $pid; done

killall -9 gnome-shell 2>/dev/null

"$JUNEST" -b "$BINDS" -- env \
    VK_DRIVER_FILES="/usr/share/vulkan/icd.d/radeon_icd.json:/usr/share/vulkan/icd.d/intel_icd.json" \
    DISPLAY="${DISPLAY:-:0}" \
    XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}" \
    XDG_RUNTIME_DIR="/run/user/$U" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$U/bus" \
    PULSE_SERVER="unix:/run/user/$U/pulse/native" \
    PATH="$PATH:/host/usr/bin:/host/usr/local/bin" \
    XDG_DATA_DIRS="$HOME/.local/share:/host/usr/share:/host/usr/local/share:/usr/share" \
    XDG_DATA_HOME="$HOME/.local/share" \
    DOCKER_CLI_PLUGINS_EXTRA_DIRS="/host/usr/libexec/docker/cli-plugins" \
    awesome

for pid in $BINARY_PIDS; do kill -CONT $pid; done
kill -CONT $MONITOR_PID
