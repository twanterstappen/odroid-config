#!/usr/bin/bash
# Setting echo colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;32m"
BLUE="\033[0;34m"
NOCOLOR="\033[0m"

sudo cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF

echo -e "${RED}"
read -p "Do you want to install iptables and update your system? Host need a restart after installing and updating(y/N)?" CONT
echo -e "${NOCOLOR}"
if [ "$CONT" = "y" ] ; then
    echo -e "${YELLOW}Updating system!${NOCOLOR}"
    sleep 3
    #sudo apt --fix-broken install
    sudo apt update -y
    sudo apt upgrade -y
    sudo apt install iptables -y
    echo ""
    echo -e "${YELLOW}Rebooting system!${NOCOLOR}"
    sleep 3
    sudo reboot now
fi

## Install packages
# Basic packages
sudo apt-get install man ifupdown ipset dnsutils -y
# Flask webserver packages
sudo apt-get install apache2 libapache2-mod-wsgi-py3 python3-pip mysql-server -y
# AP packages
sudo apt-get install dhcpcd5 dnsmasq hostapd -y
# Remaining packages
sudo apt-get install git dos2unix -y

# Installing silently iptables-persistent for save iptables
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
sudo apt-get -y install iptables-persistent
# Installing silently ipset-persistent for save ipset
echo iptables-persistent ipset-persistent/autosave boolean true | sudo debconf-set-selections
sudo apt-get -y install ipset-persistent
# Setting default DNS servers
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved
sudo unlink /etc/resolv.conf
sudo cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF



############################################################################
## Backup default config
# Check if backup is already made
backup_location=$(pwd)/backup
if [ -f "$backup_location/" ]; then
    echo "${YELLOW}There is already a backup of the default configs${NOCOLOR}"
fi

# make backup folder
sudo mkdir "$backup_location"

# backup all default config
sudo cp /etc/dhcpcd.conf "$backup_location"
sudo cp /etc/dnsmasq.conf "$backup_location"
sudo cp /etc/default/hostapd "$backup_location"
sudo cp /etc/sysctl.conf "$backup_location"
sudo cp /etc/rc.local "$backup_location"



############################################################################
### Installing Flask Webserver
# Set Python3 as default Python
sudo ln -sf /usr/bin/python3 /usr/bin/python

# Get git flask repository and move to correct directory
sudo git clone https://github.com/Twan2013/flask.git
sudo mv flask /var/www
# installing virtualenv package
sudo pip3 install virtualenv
# Create virtual environment
sudo virtualenv /var/www/flask/flaskr/venv
# Installing flask and mysql-connect module in virtual environment
sudo /var/www/flask/flaskr/venv/bin/pip install Flask
sudo /var/www/flask/flaskr/venv/bin/pip install mysql-connector-python

# Setting variable apache log for apache2 config, ignore this
APACHE_LOG_DIR='${APACHE_LOG_DIR}'
# Apache2 config for flask website
sudo cat > /etc/apache2/sites-available/flask80.conf << EOF
<VirtualHost *:80>
  ServerName corendon.local
  ServerAdmin corendon@noexisting.mail
  # WSGIScriptAlias / /var/www/flask/flask.wsgi

 # Redirects for the splash site
  RedirectMatch 302 /generate_204 https://192.168.0.1/
  RedirectMatch 302 /hotspot-detect.html https://192.168.0.1/
  RedirectMatch 302 /ncsi.txt https://192.168.0.1/
  RedirectMatch 302 /connecttest.txt https://192.168.0.1/
  Redirect permanent / https://192.168.0.1/

  <Directory /var/www/flask/flaskr/>
    Order allow,deny
    Allow from all
  </Directory>
  Alias /static /var/www/flask/flaskr/static
   <Directory /var/www/flask/flaskr/static/>
    Order allow,deny
    Allow from all
  </Directory>
  ErrorLog ${APACHE_LOG_DIR}/error.log
  LogLevel warn
  CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

sudo cat > /etc/apache2/sites-available/flask443.conf << EOF
<VirtualHost *:443>
  ServerName corendon.local
  ServerAdmin yourmail@email.com

  Protocols h2 http/1.1

  WSGIScriptAlias / /var/www/flask/flask.wsgi
  SSLEngine on
  SSLCertificateFile /etc/ssl/certs/apache-selfsigned.crt
  SSLCertificateKeyFile /etc/ssl/private/apache-selfsigned.key

  # Redirects for the splash site
  RedirectMatch 302 /generate_204 https://192.168.0.1/
  RedirectMatch 302 /hotspot-detect.html https://192.168.0.1/
  RedirectMatch 302 /ncsi.txt https://192.168.0.1/
  RedirectMatch 302 /connecttest.txt https://192.168.0.1/


  <Directory /var/www/flask/flaskr/>
    Order allow,deny
    Allow from all
  </Directory>
  Alias /static /var/www/flask/flaskr/static
   <Directory /var/www/flask/flaskr/static/>
    Order allow,deny
    Allow from all
  </Directory>
  ErrorLog ${APACHE_LOG_DIR}/error.log
  LogLevel warn
  CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# disabling default apache2 site and enabling flask site
sudo a2dissite 000-default
sudo a2ensite flask80
sudo a2ensite flask443

# Enabling SSL encryption
sudo a2enmod ssl

# Creating a Self-Signed SSL Certificate
sudo openssl req -newkey rsa:4096 \
            -x509 \
            -sha256 \
            -days 365 \
            -nodes \
            -out /etc/ssl/certs/apache-selfsigned.crt \
            -keyout /etc/ssl/private/apache-selfsigned.key \
            -subj "/C=NL/ST=Noord-Holland/L=Amsterdam/O=Corendon/OU=Corendon Flights/CN=www.corendon.local"


# WSGI config file for flask website
sudo cat > /var/www/flask/flask.wsgi << EOF
#!/usr/bin/python
import sys
import logging

activate_this = '/var/www/flask/flaskr/venv/bin/activate_this.py'
with open(activate_this) as file_:
    exec(file_.read(), dict(__file__=activate_this))

logging.basicConfig(stream=sys.stderr)
sys.path.insert(0,"/var/www/flask/")

from flaskr import create_app
application = create_app()
application.secret_key = 'something super SUPER secret'
EOF

# Creating Database
echo "CREATE DATABASE Corendon;" | sudo mysql
# Create user
echo "CREATE USER 'cp_user'@'%' IDENTIFIED BY 'Welkom123!';" | sudo mysql
# Set privileges
echo "GRANT SELECT ON Corendon.* to 'cp_user'@'%';" | sudo mysql
# Reload all privileges
echo "FLUSH PRIVILEGES;" | sudo mysql
# Creating Table and inserting data into it
sudo mysql Corendon << EOF
USE Corendon
CREATE TABLE Corendon.Passenger (id INT NOT NULL AUTO_INCREMENT, firstname VARCHAR(70) NOT NULL, prefix VARCHAR(45) NULL, lastname VARCHAR(70) NOT NULL, email VARCHAR(200) NOT NULL, PRIMARY KEY (id));
CREATE TABLE Corendon.Flight (id INT NOT NULL AUTO_INCREMENT, flightnumber CHAR(6) NOT NULL, destination VARCHAR(45) NOT NULL, PRIMARY KEY (id));
CREATE TABLE Corendon.Ticket (id INT NOT NULL AUTO_INCREMENT, ticketnumber VARCHAR(45) NOT NULL, passenger_id INT NOT NULL, flight_id INT NOT NULL, PRIMARY KEY (id), INDEX fk_Ticket_Passagier_idx (passenger_id ASC) VISIBLE, INDEX fk_Ticket_Vlucht1_idx (flight_id ASC) VISIBLE, CONSTRAINT fk_Ticket_Passagier FOREIGN KEY (passenger_id) REFERENCES Corendon.Passenger (id) ON DELETE NO ACTION ON UPDATE NO ACTION, CONSTRAINT fk_Ticket_Vlucht FOREIGN KEY (flight_id) REFERENCES Corendon.Flight (id) ON DELETE NO ACTION ON UPDATE NO ACTION);

INSERT INTO Passenger VALUES (NULL, 'Twan', NULL, 'Terstappen', 'twanterstappen@mail.com');
INSERT INTO Passenger VALUES (NULL, 'Nilas', NULL, 'Meeder', 'nilasmeeder@mail.com');
INSERT INTO Passenger VALUES (NULL, 'Justin', 'van', 'Olderen', 'justinvanolderen@mail.com');
INSERT INTO Passenger VALUES (NULL, 'Tarik', NULL, 'Ünver', 'tarikünver@mail.com');
INSERT INTO Passenger VALUES (NULL, 'Ertan', NULL, 'Karabas', 'ertankarabas@mail.com');
INSERT INTO Passenger VALUES (NULL, 'Wessel', NULL, 'Stam', 'wesselstam@mail.com');
INSERT INTO Passenger VALUES (NULL, 'Patrick', NULL, 'Kuin', 'patrickkuin@mail.com');
INSERT INTO Passenger VALUES (NULL, 'Karel', 'van der', 'Linden', 'karelvanderlinden@mail.com');
INSERT INTO Passenger VALUES (NULL, 'Maarten', NULL, 'Bonsema', 'maartenbonsema@mail.com');
INSERT INTO Passenger VALUES (NULL, 'Dick', NULL, 'Veerman', 'dickveerman@mail.com');
INSERT INTO Passenger VALUES (NULL, 'Tim', NULL, 'Langstraat', 'timlangstraat@mail.com');
INSERT INTO Passenger VALUES (NULL, 'Berke', NULL, 'Duman', 'berkeduman@mail.com');
INSERT INTO Passenger VALUES (NULL, 'John', NULL, 'Doe', 'johndoe@mail.com');

INSERT INTO Flight VALUES (NULL, 'DE6257', 'Germany');
INSERT INTO Flight VALUES (NULL, 'NL4625', 'Netherlands');
INSERT INTO Flight VALUES (NULL, 'ID6257', 'Indonesia');
INSERT INTO Flight VALUES (NULL, 'US2761', 'United States');
INSERT INTO Flight VALUES (NULL, 'AU9375', 'Austria');

INSERT INTO Ticket VALUES (NULL, '7945080392', 1, 4);
INSERT INTO Ticket VALUES (NULL, '4771012116', 2, 4);
INSERT INTO Ticket VALUES (NULL, '9444033415', 3, 3);
INSERT INTO Ticket VALUES (NULL, '9412999566', 4, 2);
INSERT INTO Ticket VALUES (NULL, '4215785086', 5, 2);
INSERT INTO Ticket VALUES (NULL, '0622439176', 6, 1);
INSERT INTO Ticket VALUES (NULL, '2550994756', 7, 5);
INSERT INTO Ticket VALUES (NULL, '0864497648', 8, 3);
INSERT INTO Ticket VALUES (NULL, '7805586114', 9, 5);
INSERT INTO Ticket VALUES (NULL, '4012471273', 10, 4);
INSERT INTO Ticket VALUES (NULL, '9594805471', 11, 1);
INSERT INTO Ticket VALUES (NULL, '9594805471', 12, 2);
INSERT INTO Ticket VALUES (NULL, '4799235446', 13, 2);
EOF

# Give the apache2 sudo rights, for IPSet commands
echo "www-data ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/www-data



# Reload apache2 to load the right config
sudo systemctl reload apache2
echo -e "${GREEN}Your website is installed and configured${NOCOLOR}"
sleep 3



############################################################################
### Configure the Access point and Captive Portal
## Configure DHCPCD
sudo cat > /etc/dhcpcd.conf << EOF
interface wlan0
    static ip_address=192.168.0.1/24
    denyinterfaces eth0
    denyinterfaces wlan0
    nohook wpa_supplicant
EOF
# Apply changes
sudo systemctl restart dhcpcd

## Set the correct interfaces config
sudo cat > /etc/network/interfaces << EOF
auto eth0
iface eth0 inet dhcp

auto wlan0
iface wlan0 inet static
    address 192.168.0.1
    network 192.168.0.0
    netmask 255.255.255.0
EOF


## Configure DNSMASQ
sudo cat > /etc/dnsmasq.conf << EOF
# Set listening address
listen-address=192.168.0.1
# Set the domain
domain=corendon.local
# Set the wifi interface
interface=wlan0
# Set the ip range that can be given to clients and lease time
dhcp-range=192.168.0.10,192.168.0.100,12h
# Set the gateway IP address
dhcp-option=3,192.168.0.1
# Set dns server address
dhcp-option=6,192.168.0.1,6.6.6.6


# Redirect all requests to the flask website
# address=/#/192.168.0.1
# Redirect the specific splash sites pings to the flask website
address=/connectivitycheck.gstatic.com/192.168.0.1
address=/connectivitycheck.android.com/192.168.0.1
address=/captive.apple.com/192.168.0.1
address=/msftconnecttest.com/192.168.0.1
# Redirect request to google.com
server=/#/8.8.8.8
EOF

# Apply changes
sudo systemctl start dnsmasq

## Configure HOSTAPD
# setting config path for HOSTAPD
sudo sed -i 's,#DAEMON_CONF="",DAEMON_CONF="/etc/hostapd/hostapd.conf",' /etc/default/hostapd

# Config for HOSTAPD
sudo cat > /etc/hostapd/hostapd.conf << EOF
interface=wlan0
driver=nl80211
ssid=Temporary_WiFi_corendon
hw_mode=g
channel=6
wmm_enabled=0
ignore_broadcast_ssid=0
EOF

# Get HOSTAPD ready to run
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl start hostapd

## ROUTING
# Enabling IPv4 forwarding
sudo sed -i 's,#net.ipv4.ip_forward=1,net.ipv4.ip_forward=1,' /etc/sysctl.conf

## IPTables rules and IPSet
# Creating IPSet
sudo ipset create ip-whitelist hash:ip
# Enable IPSet
sudo systemctl enable ipset
sudo systemctl start ipset
# Enable ITables
sudo systemctl enable iptables
sudo systemctl start iptables

# Checking if IP is in the IPSet otherwise it will drop the package
sudo iptables -t filter -A FORWARD -i wlan0 -m set ! --match-set ip-whitelist src -j DROP
sudo iptables -t nat -I PREROUTING -i wlan0 -m set --match-set ip-whitelist src -j ACCEPT

# Rerouting all the website traffic from the accesspoint to the flask website
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 80 -j DNAT  --to-destination  192.168.0.1:80
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 443 -j DNAT --to-destination  192.168.0.1:443

# NAT routing
sudo iptables -t nat -A POSTROUTING -j MASQUERADE

# Save the IPTables rules
sudo iptables-save
sudo ipset save
sudo netfilter-persistent save



## Editing the startup config
sudo cat > /etc/rc.local << EOF
#!/bin/bash


if [ -f /aafirstboot ]; then /aafirstboot start ; fi
systemctl restart hostapd
exit 0
EOF

echo -e "${GREEN}Your captive portal is installed and configured${NOCOLOR}"
sleep 3