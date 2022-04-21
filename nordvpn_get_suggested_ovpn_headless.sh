#!/bin/sh

###############################
##  nordvpn_get_suggested_ovpn_headless.sh  
###############################
#  headlessly visits the webpage https://nordvpn.com/servers/tools/
#  using xvfb and firefox and then gets the recommended nord vpn
#  server config file for udp, or tcp, depending on the parameter
#  entered, and modifies it.

#  usage:
#    nordvpn_get_suggested_ovpn_headless.sh tcp
#    nordvpn_get_suggested_ovpn_headless.sh udp

#  Requirements: linux, xclip, xvfb, xautomation, scrot 0.8-18+,
#  openvpn-systemd-resolved, python 3, firefox

#  Note: This script is not authorized by NordVPN, but works.
#   Although, it will kill any running firefox sessions.  You may need
#   create the directory /etc/openvpn/scripts and put your
#   update-systemd-resolved script there.  The files
#   'append_this_to_end_of_ovpn_file.txt' and 'template_startvpn' need
#   to be placed in the directory with all your ovpn files.  Also, the
#   name of the directory with all your ovpn files and your nordvpn
#   password file must be provided in the below variables VPN_DIR, and
#   VPN_PASSWD_FILE, respectively.

VPN_DIR=/opt/scripts/vpn
VPN_PASSWD_FILE=nordvpn.auth

# WARNING: THE BELOW DIRS WILL BE DELETED
CACHEDIR=/tmp/temp-disk-cache-dir
XVFB_DIR=/tmp/xvfb_dir

addr=https://nordvpn.com/servers/tools/

SCRIPT=`realpath $0`
sCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
WEBROWSER=firefox

if [ -z $1 ]; then
    echo Either udp or tcp must be specified, as first parameter, to specify which ovpn file to get from nordvpn.
    exit 1
fi

if !([ $1 = 'tcp' ] || [ $1 = 'udp' ]); then
    echo Please enter udp or tcp as first parameter, to specify which ovpn file to get from nordvpn.
    exit 1
fi


## This function takes as a parameter the first part of the name of the udp file to get from nordvpn, and gets it.
wget_udp() {
cd /tmp
wget https://downloads.nordcdn.com/configs/files/ovpn_legacy/servers/$1.nordvpn.com.udp1194.ovpn
}


## This function takes as a parameter the first part of the name of the tcp file to get from nordvpn, and gets it.
wget_tcp() {
cd /tmp
wget https://downloads.nordcdn.com/configs/files/ovpn_legacy/servers/$1.nordvpn.com.tcp443.ovpn
}

kill_xvfb() {
    PROCEXISTS=`ps -ef | grep $XVFB_DIR | wc | awk '{print $1}'`
    if  [ ! $PROCEXISTS = 1 ]; then
	PROCNUM=`ps -ef | grep $XVFB_DIR | awk 'NR==1{print $2}'`
	kill -9 $PROCNUM
    fi
}
is_display_free() {
    xdpyinfo -display $1 >/dev/null 2>&1 && echo 0 || echo 1
}

find_free_display() {
    DSP_NUM=99
    while [ $(is_display_free ":$DSP_NUM") -eq 0 ]; do
	DSP_NUM=$(( $DSP_NUM - 1 ))
    done
    echo ":$DSP_NUM"
}

DSP=$(find_free_display)
echo using DISPLAY $DSP

rnd() {
python -S -c "import random; print( random.randrange($1,$2))"
}

rnd_offset() {
python -S -c "import random; print(random.randrange($1,$(($1 + $2))))"
}

rm -f "$TMP_RESULTS_FILE"
rm -rf "$CACHEDIR"
mkdir -p "$CACHEDIR" 
rm -rf "$XVFB_DIR"
mkdir -p  "$XVFB_DIR"
rm /tmp/*.ovpn 

# We have to start out by killing any opened firefox sessions or the script will try to use an already opened session.
pkill $WEBROWSER
kill_xvfb
sleep 1
rm -rf "$XVFB_DIR"
mkdir -p "$XVFB_DIR"
Xvfb $DSP -fbdir "$XVFB_DIR" &
sleep 1 


DISPLAY=$DSP $WEBROWSER $addr &
#DISPLAY=$DSP $WEBROWSER --user-data-dir="$CACHEDIR" --disk-cache-dir="$CACHEDIR" --profile-directory="Profile 3" $addr &
  
        
sleep 10

##  Sleep until screen stops changing  
    MAX_SLEEP_ITERATIONS=20
    sleep_iteration=0
    rm -f /tmp/screen_stops_changing.ppm
    DISPLAY=$DSP scrot /tmp/screen_stops_changing.ppm
    lastmd5=`md5sum /tmp/screen_stops_changing.ppm | awk '{print $1}'`
#    echo screen changing $md5
    tmpmd5="tmpmd5"
    sleep 2
    until [ $tmpmd5 = $lastmd5 ] || [ $sleep_iteration = $MAX_SLEEP_ITERATIONS ]; do 
	rm -f /tmp/screen_stops_changing.ppm
	DISPLAY=$DSP scrot /tmp/screen_stops_changing.ppm
	lastmd5=$tmpmd5
	tmpmd5=`md5sum /tmp/screen_stops_changing.ppm | awk '{print $1}'`
#	echo screen changing $tmpmd5
	echo -n .
	sleep_iteration=$(($sleep_iteration + 1))
	sleep 2
    done
    echo .
    rm -f /tmp/screen_stops_changing.ppm

#  The following block of code uses xautomation to control-c copy all the text from the browser, and grep it for the first part of the ovpn file name.
DISPLAY=$DSP xte 'keydown Control_L' 'str a' 'usleep 1000000' 'str c' 'usleep 300000' 'keyup Control_L' "usleep $(rnd 2000000 5000000)" 
line=`DISPLAY=$DSP xclip -o | grep -n 'Flag' | cut -d':' -f1`
line=$(( $line + 1 ))
str1="NR=="$line
str2='{print $1}'
cmd="DISPLAY=$DSP xclip -o | awk '"$str1$str2"'"
ovpn_name=`eval $cmd`
ovpn_name=`echo $ovpn_name | cut -d'.' -f1`

if [ $1 = 'tcp' ]; then
    $(wget_tcp $ovpn_name)
fi

if [ $1 = 'udp' ]; then
    $(wget_udp $ovpn_name)
fi

sleep 1

#  Assume that there is only 1 .ovpn file in the /tmp directory, and its the one that we just downloaded.
ovpn_file=`ls /tmp/*.ovpn`
if [ -z $ovpn_file ]; then
    echo no ovpn file download.  Aborting
    exit 1
fi

#  Modify ovpn file
ovpn_file_basename=`basename $ovpn_file`
cat ${VPN_DIR}/append_this_to_end_of_ovpn_file.txt >> $ovpn_file
vpn_dir_escaped_forward_slashes=$(echo "$VPN_DIR" | sed 's/\//\\\//g')
perl -pi -e "s/auth-user-pass/auth-user-pass ${vpn_dir_escaped_forward_slashes}\/${VPN_PASSWD_FILE}/g;" $ovpn_file

#  Create run_startvpn file
cp $ovpn_file ${VPN_DIR}/
cp ${VPN_DIR}/template_startvpn ${VPN_DIR}/run_startvpn
perl -pi -e "s/TEMPLATE_STARTVPN/$ovpn_file_basename/g;" ${VPN_DIR}/run_startvpn
sleep 1
sudo cp ${VPN_DIR}/run_startvpn /usr/local/bin/

kill_xvfb
echo "ok"

