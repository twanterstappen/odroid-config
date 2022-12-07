#! /usr/bin/bash

current_location=$(pwd)
config_location=$(pwd)/odroid-config/
backup_location=$(pwd)/backup/


sudo apt-get update -y
sudo apt-get upgrade -y

sudo apt-get install man ifupdown iptables apache2 libapache2-mod-wsgi-py3 dhcpcd5 dnsmasq hostapd -y
sudo systemctl stop dnsmasq
sudo systemctl stop hostapd

# make backup folder
sudo mkdir $current_location



# DHCPCD
# backup default dhcpcd file
sudo cp /etc/dhcpcd.conf $backup_location

# copy the config file to dhcpcd.conf
sudo cat $config_location/dhcpcd_conf.txt > /etc/dhcpcd.conf
sudo systemctl restart dhcpcd




# DNSMASQ
# backup default dnsmasq file
sudo cp /etc/dnsmasq.conf $backup_location

# copy the config file to dnsmasq.conf
sudo cat $config_location/dnsmasq_conf.txt > /etc/dnsmasq.conf

sudo systemctl start dnsmasq




# HOSTAPD
# backup default hostapd file
sudo cp /etc/default/hostapd $backup_location

# edit the DEAMON parameters
sudo sed -i 's,#DAEMON_CONF="",DAEMON_CONF="/etc/hostapd/hostapd.conf",' /etc/default/hostapd

# copy the config file to hostapd.conf
sudo cat $config_location/hostapd_conf.txt > /etc/hostapd/hostapd.conf

sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl start hostapd


# ROUTING
# backup sysctl.conf file
sudo cp /etc/sysctl.conf $backup_location

# edit the ip_forward lines
sudo sed -i 's,#net.ipv4.ip_forward=1,net.ipv4.ip_forward=1,' /etc/sysctl.conf
#sudo sed -i 's,#net.ipv6.conf.all.forwarding=1,net.ipv6.conf.all.forwarding=1,' /etc/sysctl.conf

# iptable rules
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT

# save iptable rules
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"
iptable-save

# backup /etc/rc.local file
sudo mv /etc/rc.local $backup_location

# set config to boot
sudo cp $config_location/rc.local_config.txt /etc/rc.local

