# nordvpn_get_suggested_ovpn_headless
gets the suggested tcp or udp ovpn file from nordvpn.com


 This script headlessly visits the webpage
 https://nordvpn.com/servers/tools/ using xvfb and firefox and then
 gets the recommended nord vpn server config file for udp, or tcp,
 depending on the parameter entered, and modifies it.

 usage: </br>
    nordvpn_get_suggested_ovpn_headless.sh tcp</br>
    nordvpn_get_suggested_ovpn_headless.sh udp

 Requirements: linux, xclip, xvfb, xautomation, scrot 0.8-18+,
 openvpn-systemd-resolved, python 3, firefox

 Note: This script is not authorized by NordVPN, but works.  Although,
  it will kill any running firefox sessions.  You may need create the
  directory /etc/openvpn/scripts and put your update-systemd-resolved
  script there.  The files 'append_this_to_end_of_ovpn_file.txt' and
  'template_startvpn' need to be placed in the directory with all your
  ovpn files.  Also, the name of the directory with all your ovpn
  files and your nordvpn password file must be provided in the
  variables VPN_DIR, and VPN_PASSWD_FILE, respectively.