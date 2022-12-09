# odroid-config

For your odroid do the following:

sudo apt-get update -y

sudo apt-get upgrade -y

sudo apt-get install git dos2unix



pay attention!!!
some files need a convertion from dos to unix. 
Like the auto_script.sh file, for those do the following:

sudo dos2unix auto_script.sh



If you get error's, then check all the config files that were applied. If the file is dos run the command: dos2unix FILENAME


There is a possibility that the iptables rules wont apply. This is because the odroid need a reboot. If so run the firewal_config.sh bash script.


If you can't ping google.com edit the following: sudo nano /etc/resolvconf/resolv.conf.d/head

add this:

nameserver 8.8.8.8
nameserver 8.8.4.4
