#!/bin/bash

# exits immediately if any error has non-zero exit
set -e
# error the whole pipeline if a subcommand fails
set -o pipefail

# use tty7 for the graphical server by default
VT="7"

if [[ $? == 0 ]]; then
	PRIVILEGED=true
else
	PRIVILEGED=false
fi

function init_xdg() {
	if test -z "${XDG_RUNTIME_DIR}"; then
		XDG_RUNTIME_DIR=/tmp/$(id -u torizon)-runtime-dir
		export XDG_RUNTIME_DIR
	fi

	echo "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" >>/etc/environment

	if ! test -d "${XDG_RUNTIME_DIR}"; then
		mkdir -p "${XDG_RUNTIME_DIR}"
	fi

	chown torizon "${XDG_RUNTIME_DIR}"
	chmod 0700 "${XDG_RUNTIME_DIR}"

	# Create folder for XWayland Unix socket
	export X11_UNIX_SOCKET="/tmp/.X11-unix"
	if ! test -d "${X11_UNIX_SOCKET}"; then
		mkdir -p ${X11_UNIX_SOCKET}
	fi

	chown torizon:video ${X11_UNIX_SOCKET}
}

# the base stuff does not need to run privileged
function start_udev()
{
	if [ "$UDEV" == "on" ]; then
		if $PRIVILEGED; then
			if command -v udevd &>/dev/null; then
				unshare --net udevd --daemon &> /dev/null
			else
				unshare --net /lib/systemd/systemd-udevd --daemon &> /dev/null
			fi
			udevadm trigger &> /dev/null
		else
			echo "Unable to start udev, container must be run in privileged mode to start udev!"
		fi
	fi
}

function config_tty()
{
        # 🤨
        chmod 666 /dev/tty*
}

function vt_setup() {
	# Some applications may leave old VT in graphics mode which causes
	# applications like openvt and chvt to hang at VT_WAITACTIVE ioctl when they
	# try to switch to a new VT

	# grabs the current active VT, before possibly switching
	OLD_VT=$(cat /sys/class/tty/tty0/active)
	OLD_VT_MODE=$(kbdinfo -C /dev/"${OLD_VT}" getmode)
	if [ "$OLD_VT_MODE" = "graphics" ]; then
		/usr/bin/switchvt.pl "${OLD_VT:3}" text
	fi
}

UDEV=$(echo "$UDEV" | awk '{print tolower($0)}')

case "$UDEV" in
        '1' | 'true')
                UDEV='on'
        ;;
esac

# remove old dbus session bus
echo "Removing old dbus session bus ..."
rm -rf /tmp/dbus-session-bus

# remove the old x unix socket
echo "Removing old X11 unix socket ..."
rm -rf /tmp/.X*

config_tty
echo "Switching VT $(cat /sys/class/tty/tty0/active) to text mode if currently in graphics mode" && vt_setup
echo "Switching to VT ${VT}" && chvt "${VT}"

start_udev
init_xdg

# get all the arguments from this script and put in a variable
# so we can pass it to the torizon-entry.sh
ARGS="$@"
export ARGS

# we are in a imx6?
# if so, we need to rm the /usr/share/X11/xorg.conf.d/10-dri.conf
# because it is not compatible with the imx6
if [ -d /proc/device-tree ]; then
	MODEL=$(tr -d '\0' </proc/device-tree/model)
	if [[ $MODEL == *"iMX6"* ]]; then
		rm -f /usr/share/X11/xorg.conf.d/10-dri.conf
	fi
fi

# now we can execute the torizon-entry.sh
# as torizon user
su torizon -c "/usr/bin/torizon-entry.sh $ARGS"
