# uverse_sfp_vdsl
Notes and software for using your own vdsl modem on AT&amp;T's VDSL2-based Uverse service

find out what version your Unifi Security Gateway is running:

```admin@UniFiUSGPro:/etc$ cat /etc/os-release
admin@UniFiUSGPro:/etc$ cat /etc/os-release
PRETTY_NAME="Debian GNU/Linux 7 (wheezy)"
NAME="Debian GNU/Linux"
VERSION_ID="7"
VERSION="7 (wheezy)"
ID=debian
ANSI_COLOR="1;31"
HOME_URL="http://www.debian.org/"
SUPPORT_URL="http://www.debian.org/support/"
BUG_REPORT_URL="http://bugs.debian.org/"111

Here we are running Debian 7 Wheezy. Ubiquiti has said later updates may udpate the OS version, so check your OS version before continuing because using the wrong package repository will brick your machine.

