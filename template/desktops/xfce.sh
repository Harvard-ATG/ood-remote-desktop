#!/bin/bash

this_script="template/desktops/rosgazebo.sh"

log() {
    echo -e "[$(date -Iseconds)][${this_script}] $1"
}

export XDG_RUNTIME_DIR="${HOME}/.cache/dconf"

# log "BEGIN ENV VARS IN CONTAINER"
# printenv
# log "END ENV VARS IN CONTAINER"

set -e

# Extract the real cookie from the VNC X server
MCOOKIE=$(xauth -f ${HOME}/.Xauthority list | grep "^$(hostname)/unix:2" | awk '{print $3}')
if [ -z "$MCOOKIE" ]; then
    # VNC might use a different hostname format
    MCOOKIE=$(xauth -f ${HOME}/.Xauthority list | grep ":2" | head -1 | awk '{print $3}')
fi

# If still no cookie, get it directly from the X server
if [ -z "$MCOOKIE" ]; then
    xauth extract - $DISPLAY | xauth merge -
fi

log "MCOOKIE is ${MCOOKIE}"

if [ -n "$MCOOKIE" ]; then
    # Add the cookie to container's xauth
    xauth add ${DISPLAY} . ${MCOOKIE}
    xauth add $(hostname)${DISPLAY} . ${MCOOKIE}
    xauth add $(hostname)/unix${DISPLAY} . ${MCOOKIE}
else
    log "WARNING: No cookie found, disabling X auth"
    unset XAUTHORITY
fi

# Preserve DISPLAY variable
export DISPLAY="${DISPLAY:-:2}"
echo "DISPLAY is set to: $DISPLAY"

echo "=== INSIDE CONTAINER DEBUG ==="
echo "1. Checking /tmp/.X11-unix directory:"
ls -la /tmp/.X11-unix/ 2>&1 || echo "ERROR: /tmp/.X11-unix not accessible"

echo "2. Checking X2 socket specifically:"
ls -la /tmp/.X11-unix/X2 2>&1 || echo "ERROR: X2 socket not found"

echo "3. Checking socket permissions:"
stat /tmp/.X11-unix/X2 2>&1 || echo "ERROR: Cannot stat socket"

echo "4. Testing with xdpyinfo:"
xdpyinfo -display "${DISPLAY}" 2>&1 | head -20 || echo "ERROR: xdpyinfo failed"

echo "5. Checking if xdpyinfo exists:"
which xdpyinfo

echo "6. Checking X11 client libraries:"
ldconfig -p | grep X11

echo "==========================="

# Verify X access works
if ! xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
    echo "ERROR: Cannot access X server ${DISPLAY}"
    exit 1
fi

# Start dbus daemon
export $(dbus-launch)

# Remove any preconfigured monitors
if [[ -f "${HOME}/.config/monitors.xml" ]]; then
  mv "${HOME}/.config/monitors.xml" "${HOME}/.config/monitors.xml.bak"
fi
log "removed any preconfigured monitors"

# Copy over default panel if doesn't exist, otherwise it will prompt the user
PANEL_CONFIG="${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
if [[ ! -e "${PANEL_CONFIG}" ]]; then
  mkdir -p "$(dirname "${PANEL_CONFIG}")"
  cp "/etc/xdg/xfce4/panel/default.xml" "${PANEL_CONFIG}"
fi
log "Copied default panel config"

# Disable startup services
xfconf-query -c xfce4-session -p /startup/ssh-agent/enabled -n -t bool -s false
xfconf-query -c xfce4-session -p /startup/gpg-agent/enabled -n -t bool -s false
log "Disabled startup services"

# Turn off power saving measures that turn off the display
# See https://github.com/Harvard-ATG/ood-remote-desktop/pull/4
# for additional context on these options
xfconf-query \
    --channel xfce4-power-manager \
    --property /xfce4-power-manager/dpms-enabled \
    --create \
    --type bool \
    --set true

xfconf-query \
    --channel xfce4-power-manager \
    --property /xfce4-power-manager/dpms-on-ac-off \
    --create \
    --set 0 \
    --type uint

xfconf-query \
    --channel xfce4-power-manager \
    --property /xfce4-power-manager/dpms-on-ac-sleep \
    --create \
    --set 0 \
    --type uint

xfconf-query \
    --channel xfce4-power-manager \
    --property /xfce4-power-manager/blank-on-ac \
    --create \
    --set 0 \
    --type int

# Show the power management settings in output
echo "xfconf-query settings for xfce-power-manager:"
xfconf-query --channel xfce4-power-manager --list --verbose

# Disable useless services on autostart
AUTOSTART="${HOME}/.config/autostart"
rm -fr "${AUTOSTART}"    # clean up previous autostarts
mkdir -p "${AUTOSTART}"
for service in "pulseaudio" "rhsm-icon" "spice-vdagent" "tracker-extract" "tracker-miner-apps" "tracker-miner-user-guides" "xfce4-power-manager" "xfce-polkit"; do
  echo -e "[Desktop Entry]\nHidden=true" > "${AUTOSTART}/${service}.desktop"
done
log "Disabled useless services"

# Run Xfce4 Terminal as login shell (sets proper TERM)
TERM_CONFIG="${HOME}/.config/xfce4/terminal/terminalrc"
if [[ ! -e "${TERM_CONFIG}" ]]; then
  mkdir -p "$(dirname "${TERM_CONFIG}")"
  sed 's/^ \{4\}//' > "${TERM_CONFIG}" << EOL
    [Configuration]
    CommandLoginShell=TRUE
EOL
else
  sed -i \
    '/^CommandLoginShell=/{h;s/=.*/=TRUE/};${x;/^$/{s//CommandLoginShell=TRUE/;H};x}' \
    "${TERM_CONFIG}"
fi

log "Setup complete, starting xfce session"
# Start up xfce desktop (block until user logs out of desktop)
xfce4-session
