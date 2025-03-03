#!/bin/bash

######################################################################################
#
# Description:
# ------------
#       This script adds ULA addresses for all interfaces in order to enable easy
#       IPv6 firewall rule management when dynamic IPv6 prefixes are to be used.
#		As IPv6 ULAs may be reseted whenever network config  is changed in GUI,
#       this file should be executed regularly via cron (see 99-setup-cron.sh) to 
#		ensure that firewall is permanently activated.
#
######################################################################################

######################################################################################
#
# Configuration
#

# check and try to restore IPv6 connection
check_v6=true

# IPv6 hosts used to test IPv6 connection
host1="facebook.de"
host2="google.de"
host3="apple.com"
host4="microsoft.com"

# set ULA on lan interfaces?
lan_ula=true

# set ULA on guest interfaces?
guest_ula=false

# set ULA on explicitly include interfaces?
custom_ula=true

# ULA prefix to be used
ula_prefix="fd00:2:0:"

# interfaces listed in include will explicitly be assigned IPv6 ULAs
# Multiple interfaces are to be separated by spaces.
include="br105"

# interfaces listed in exclude will not be assigned any IPv6 ULAs
# Multiple interfaces are to be separated by spaces.
exclude="br0"

#
# No further changes should be necessary beyond this line.
#
######################################################################################

# set scriptname
me=$(basename $0)

# include local configuration if available
[ -e "$(dirname $0)/${me%.*}.conf" ] && source "$(dirname $0)/${me%.*}.conf"

# Get list of WAN interfacess
wan_if=$(/usr/sbin/iptables --list-rules | /usr/bin/awk '/^-A UBIOS_FORWARD_IN_USER.*-j UBIOS_WAN_IN_USER/ { print $4 }')

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# check ipv6 connection
#
if [ $check_v6 == "true" ]; then
	# If IPv6 connection is available nothing to do 
	if ( ping -6 -c 1 $host1 || ping -6 -c 1 $host2 || 
		ping -6 -c 1 $host3 || ping -6 -c 1 $host4 ); then 
		logger "$me: IPv6 working as expected. Nothing to do."
		echo "$me: IPv6 working as expected. Nothing to do."
	else    
		logger "$me: IPv6 connection lost."
		echo "$me: IPv6 connection lost."
		for w in $wan_if; do
			if ip -6 addr show dev $w | grep inet6; then
				logger "$me: Resetting interface $w."
				ifconfig $w down; ifconfig $w up
			fi
		done
	fi
fi

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# ULAs for LAN interfaces
#

if [ $lan_ula == "true" ]; then
	# Get list of relevant LAN interfaces and total number of interfaces
	lan_if=$(iptables --list-rules UBIOS_FORWARD_IN_USER | awk '/-j UBIOS_LAN_IN_USER/ { print $4 }')

	# Add ULAs to all LAN interfaces except the ones listed in $exclude
	for i in $lan_if; do
		case "$exclude " in
			*"$i "*)
				logger "$me: Excluding $i from ULA assignment as requested in config."
				;;

			*)
				ip -6 addr show dev $i | grep "$ula_prefix" &> /dev/null ||
					ip -6 addr add "${ula_prefix}${i:2}::1/64" dev $i
				;;
		esac
	done
fi

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# ULAs for guest interfaces
#

if [ $guest_ula == "true" ]; then
	# Get list of relevant guest interfaces and total number of interfaces
	guest_if=$(iptables --list-rules UBIOS_FORWARD_IN_USER | awk '/-j UBIOS_GUEST_IN_USER/ { print $4 }')

	# Add ULAs to all LAN interfaces except the ones listed in $exclude
	for i in $guest_if; do
		case "$exclude " in
			*"$i "*)
				logger "$me: Excluding $i from ULA assignment as requested in config."
				;;

			*)
				ip -6 addr show dev $i | grep "$ula_prefix" &> /dev/null ||
					ip -6 addr add "${ula_prefix}${i:2}::1/64" dev $i
				;;
		esac
	done
fi

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# ULAs for custom interfaces
#

if [ $custom_ula == "true" ]; then
	# Add ULAs to all custom interfaces listed in $include except the ones listed in $exclude
	for i in $include; do
		case "$exclude " in
			*"$i "*)
				logger "$me: Excluding $i from ULA assignment as requested in config."
				;;

			*)
				ip -6 addr show dev $i | grep "$ula_prefix" &> /dev/null ||
					ip -6 addr add "${ula_prefix}${i:2}::1/64" dev $i
				;;
		esac
	done
fi