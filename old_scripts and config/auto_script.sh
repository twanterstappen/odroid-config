#!/bin/bash
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;32m"
BLUE="\033[0;34m"
NOCOLOR="\033[0m"

current_location=$(pwd)
if [[ "$PWD" =~ odroid-config ]]; then
    config_location=$(pwd)/config
else
    config_location=$(pwd)/odroid-config/config
fi
backup_location=$(pwd)/backup

echo -e "${RED}"
read -p "Do you want to update your system? Host need a restart after updating (y/N)?" CONT
echo -e "${NOCOLOR}"
if [ "$CONT" = "y" ]; then
    echo -e "${YELLOW}Updating system!${NOCOLOR}"
    sleep 3

    sudo apt-get update -y
    sudo apt-get upgrade -y
    sudo apt-get autoremove -y
    echo ""
    echo -e "${YELLOW}Rebooting system!${NOCOLOR}"
    sleep 3
    sudo reboot now
fi

echo -e "${RED}"
read -p "Do you want to install iptables and nftables? Host need a restart after install (y/N)?" CONT
echo -e "${NOCOLOR}"
if [ "$CONT" = "y" ]; then
    echo -e "${YELLOW}Installing packages!${NOCOLOR}"
    sleep 3

    sudo apt-get iptables -y
    sudo apt-get nftables -y
    echo ""
    echo -e "${YELLOW}Rebooting system!${NOCOLOR}"
    sleep 3
    sudo reboot now
fi

sudo apt-get install man ifupdown network-manager dos2unix iptables-persistent nftables-persistent apache2 libapache2-mod-wsgi-py3 dhcpcd5 dnsmasq hostapd -y
sudo systemctl stop dnsmasq
sudo systemctl stop hostapd

# make backup folder
sudo mkdir $backup_location

# backup of all folders
sudo cp /etc/dhcpcd.conf $backup_location
sudo cp /etc/dnsmasq.conf $backup_location
sudo cp /etc/default/hostapd $backup_location
sudo cp /etc/sysctl.conf $backup_location
sudo cp /etc/rc.local $backup_location

# DNSservers install on host
# WORK IN PROGRESS!
# sudo cat $config_location/dns_settings.txt >> /etc/resolvconf/resolv.conf.d/head

# IP config for interfaces
sudo cat $config_location/interfaces.txt >> /etc/network/interfaces


# create file execution parameter
if [ -f "$backup_location/used_script.txt" ]; then
    echo 'code is already used. Script will be closed.'
    echo 'Delete used_script.txt to before executing this script'    
    exit
else
    sudo echo '# execute_checker' > $backup_location/used_script.txt
fi


# DHCPCD
# copy the config file to dhcpcd.conf
sudo cat $config_location/dhcpcd_conf.txt >> /etc/dhcpcd.conf
sudo systemctl restart dhcpcd




# DNSMASQ
# copy the config file to dnsmasq.conf
sudo cat $config_location/dnsmasq_conf.txt >> /etc/dnsmasq.conf

sudo systemctl start dnsmasq




# HOSTAPD
# edit the DEAMON parameters
sudo sed -i 's,#DAEMON_CONF="",DAEMON_CONF="/etc/hostapd/hostapd.conf",' /etc/default/hostapd

# copy the config file to hostapd.conf
sudo cat $config_location/hostapd.conf > /etc/hostapd/hostapd.conf
sudo dos2unix /etc/hostapd/hostapd.conf

sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl start hostapd


# ROUTING
# edit the ip_forward lines
sudo sed -i 's,#net.ipv4.ip_forward=1,net.ipv4.ip_forward=1,' /etc/sysctl.conf
#sudo sed -i 's,#net.ipv6.conf.all.forwarding=1,net.ipv6.conf.all.forwarding=1,' /etc/sysctl.conf

# iptable rules
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT

# save iptable rules
sudo sh -c "iptables-save >> /etc/iptables.ipv4.nat"



# set config to boot
sudo cat $config_location/rc.local_config.txt > /etc/rc.local
sudo dos2unix /etc/rc.local
