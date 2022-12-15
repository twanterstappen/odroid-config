#!/bin/bash
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;32m"
BLUE="\033[0;34m"
NOCOLOR="\033[0m"


echo -e "${RED}"
read -p "Do you want to update your system? Host need a restart after updating ${NOCOLOR}(y/N)?" CONT
echo -e ""
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

# Install apache2, wsgi, pip3 and git
sudo apt-get install apache2 libapache2-mod-wsgi-py3 python3-pip git -y
# enable apache2 module wsgi
sudo a2enmod wsgi
# Set Python3 as default Python
sudo ln -sf /usr/bin/python3 /usr/bin/python

# Get git flask repository and move to correct directory
sudo git clone https://github.com/Twan2013/flask.git
sudo mv flask /var/www
# Create virtual environment
sudo virtualenv /var/www/flask/flaskr/venv
# Installing flask and mysql module in venv
sudo /var/www/flask/flaskr/venv/bin/pip install Flask
 sudo /var/www/flask/flaskr/venv/bin/pip install mysql-connector-python

APACHE_LOG_DIR='${APACHE_LOG_DIR}'

# Apache2 config for wsgi and flask site
sudo cat >> /etc/apache2/sites-available/flask.conf << EOF
<VirtualHost *:80>
  ServerName yourdomain.com
  ServerAdmin youemail@email.com
  WSGIScriptAlias / /var/www/flask/flask.wsgi
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
sudo a2ensite flask


# WSGI config file
sudo cat >> /var/www/flask/flask.wsgi << EOF
#!/usr/bin/python
import sys
import logging
logging.basicConfig(stream=sys.stderr)
sys.path.insert(0,"/var/www/flask/")

from flaskr import create_app
application = create_app()
application.secret_key = 'something super SUPER secret'
EOF

# Reload apache2 to load the right config
sudo systemctl reload apache2

echo -e "${GREEN}Your website is installed and configured${NOCOLOR}"

sleep 3
