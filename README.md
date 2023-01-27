# odroid-config
#
For your odroid do the following:
#
#
#
script.sh is for setup and installing a sbc with Ubuntu 20.04 on it.
#
Copy the script to your sbc using:
#
#
#
########
Sudo nano script.sh
Then copy and paste the script into script.sh
Run the script with: sudo bash ./script.sh
#######
#
#
#######
When prompt, first run of the script chose: y
SBC will update and reboot itself. This is needed because of the iptables.
When SBC is reboted, rerun the script and when prompt, chose the option: n
#######
#
#
#
#
There is a possibility that the iptables rules wont apply. This is because the odroid need a reboot. If so, reboot and rerun the script.
