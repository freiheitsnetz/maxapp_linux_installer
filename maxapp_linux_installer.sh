#!/bin/sh
#
# Painless installation script for the original Max! Home Automation software.
#
# The Max! software is written in java, but the manufacturer only provides 
# a win and mac os installation package. This script downloads the mac package,
# extracts the java code, adjusts the startup script and provides a .desktop
# file for a seamless desktop environment integration.
#
# This Max! system is sold by elv. For more infromation see:
# 	- https://www.max-portal.elv.de/
#	- http://www.elv.de/forum/max-funk-heizungsregler-system.html
#
# This script is tested successfully on:
#	- (l)ubuntu 16.04
#	- debian 8
#
# License: MIT
# Copyright: Tobias Farrenkopf tf@emptyset.de

##############################
# Global vars

URL=""
MAX_INST_DIR="/opt/MAX_APP"
MAX_DESKTOP_FILE="/usr/share/applications/max-app.desktop"
TEMPDIR="/tmp/maxapp_installer"
MOUNTPOINT="/${TEMPDIR}/max_img_$$"
BASE_SYSTEM=""

##############################
# Functions

define_app_url() {
	echo "Please define from where you want to download the Application."
	echo "It differs dependent on the shop you purchased the Cube and is "
	echo "given in the short manual."
	echo
	echo "Enter either \"elv\" for the ELV version (from www.max-portal.elv.de)"
	echo "of the app or \"eq-3\" for the eq-3 version (from max.eq-3.de)."
	read -r	 response
	if [ "$response" = "elv" ]; then
		URL="http://www.max-portal.elv.de:8181/downloadELV/MAXApp_ELV.dmg"
		echo "Using http://www.max-portal.elv.de:8181/downloadELV/MAXApp_ELV.dmg"
	elif [ "$response" = "eq-3" ]; then
		URL="http://max.eq-3.de:8181/downloadEQ3/MAXApp_eQ3.dmg"
		echo "Using http://max.eq-3.de:8181/downloadEQ3/MAXApp_eQ3.dmg"
	else
		echo "No valid input. Exit setup. Please start again."
		exit 1
	fi
	
}

check_base_system() {
	if [ -f /etc/debian_version ]; then
		echo "This is a debian based distribution."
		BASE_SYSTEM="debian"
	elif [ -f /etc/redhat-release ]; then
		echo "This is a redhat based distribution."
		BASE_SYSTEM="redhat"
	else
		echo "This is something else."
		echo "This script is (most probably) not working with your distribution."
		exit 1
	fi
}

check_program() {
	if [ "$BASE_SYSTEM" = "debian" ]; then
		dpkg-query -W "$1" > /dev/null 2>&1
		installed="$?"
	elif [ "$BASE_SYSTEM" = "redhat" ]; then
		rpm -q "$1" > /dev/null 2>&1
		installed="$?"
	else
		exit 1
	fi
	if  [ "$installed" -ne 0 ]; then
		echo
		echo "Dependency \"$1\" is missing." 
		echo "Should I try to install it? [y/N]"
		read -r response 
		case $response in 
		[yY][eE][sS]|[yY]) 
			echo "Installing \"$1\"..."
			if [ "$BASE_SYSTEM" = "debian" ]; then
				sudo apt-get install "$1" || exit 1
			elif [ "$BASE_SYSTEM" = "redhat" ]; then
				sudo dnf install "$1" || exit 1
			else
				exit 1
			fi
			;;
		*)
			echo "Dependencies not fulfilled."
			echo "Leaving..."
			exit 1
			;;
		esac
	fi
}

usage() {
	echo "Usage:"
	echo "$(basename $0) {--install|--remove}"
	echo
	echo "--install  This will install the MAX! software under ${MAX_INST_DIR}"
	echo "           and creates a max.desktop entry under ${MAX_DESKTOP_FILE}"
	echo
	echo "--remove   Uninstalls the software and the max.desktop file"
}

dependency_checks() {
	check_program wget
	check_program sudo
	check_program dmg2img
	if [ "$BASE_SYSTEM" = "debian" ]; then
		check_program hfsplus
		check_program icnsutils
		check_program default-jre
	elif [ "$BASE_SYSTEM" = "redhat" ]; then
		check_program hfsplus-tools
		check_program libicns-utils
		check_program java-1.8.0-openjdk
	fi
}
	
install_maxapp() {
	mkdir -p "$TEMPDIR" || exit 1
	cd "$TEMPDIR"

	echo
	echo "Downloading the MAX! App..."
	echo
	wget --show-progress -q -O mac.dmg "$URL" 

	echo
	echo "Installing..."
	echo

	dmg2img mac.dmg mac.img >/dev/null
	
	mkdir -p "$MOUNTPOINT" || exit 1
	
	sudo mkdir -p "$MAX_INST_DIR/icons"
	sudo mount -t hfsplus -o loop mac.img $MOUNTPOINT
	sudo cp -r "${MOUNTPOINT}/MAX!.app/Contents/Java" "$MAX_INST_DIR"
	sudo icns2png -o "${MAX_INST_DIR}/icons" -x "${MOUNTPOINT}/MAX!.app/Contents/Resources/maxicon.icns" >/dev/null
	sudo umount "$MOUNTPOINT"
	
	rmdir "$MOUNTPOINT"
	rm -f mac.img
	rm -f mac.dmg
	cd -
	rmdir "$TEMPDIR"
	
	sudo tee "${MAX_INST_DIR}/start.sh" >/dev/null <<EOF
#!/bin/sh
cd "${MAX_INST_DIR}/Java"
java -jar MaxLocalApp.jar
EOF

	sudo chmod 755 "${MAX_INST_DIR}/Java/webapp"
	sudo chmod +x "${MAX_INST_DIR}/start.sh"
	
	sudo tee "$MAX_DESKTOP_FILE" >/dev/null <<EOF
[Desktop Entry]
Name=MAX App
Name[de]=MAX App
Comment=MAX Software
Comment[de]=MAX Software
Exec=${MAX_INST_DIR}/start.sh
Icon=${MAX_INST_DIR}/icons/maxicon_32x32x32.png
Terminal=false
Type=Application
StartupNotify=false
Categories=Utility;
EOF
}

remove_maxapp() {
	echo
	echo "Removing the MAX! App.."
	echo
	sudo rm -rf "$MAX_INST_DIR"
	sudo rm -f "$MAX_DESKTOP_FILE"
}


##############################
# Main program


if [ -z "$1" ]; then
	usage
	exit 1
fi

define_app_url
check_base_system
dependency_checks

if [ "$1" = "--install" ]; then
	install_maxapp
elif [ "$1" = "--remove" ]; then
	remove_maxapp
else
	usage
	exit 1
fi

echo
echo "Done."
exit 0
