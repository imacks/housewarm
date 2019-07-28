#!/bin/sh

#########################################################################
# 15-computer-info
#
# .SYNOPSIS
#     Prints common information about the computer
#
# .DESCRIPTION
#    This bash script is a mod of `/etc/update-motd.d/10-help-text` that 
#    comes with Ubuntu distributions. It displays useful stats of the running 
#    system when the user signs in.
#
# .DEPENDENCY
#    /bin/sh
#    cat, date, cut, grep, awk, head, tr, sed, tail, free, df,
#    hostname, expr
#
# .NOTES
#     Copyright (C) 2017 Lizoc Inc.
#
#     Authors: Lizoc Cloud Developers <cloud@lizoc.com>,
#              Team Spark <spark@lizoc.com>
#
#     MIT License. Refer to our website at www.lizoc.com/legal for terms of 
#     use.
#
#########################################################################

HOSTNAME=$(hostname -f)

LOCAL_TIME=$(date)
UPTIME=$(cat /proc/uptime | cut -d '.' -f1)
UPTIME_DAYS=$(expr $UPTIME % 31556926 / 86400)
UPTIME_HOURS=$(expr $UPTIME % 31556926 % 86400 / 3600)
UPTIME_MINUTES=$(expr $UPTIME % 31556926 % 86400 % 3600 / 60)

CPU_MODEL=$(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d':' -f2 | tr -s ' ' | sed 's/^[ ]//g')
CPU_LOAD=$(cat /proc/loadavg | awk '{print "[1] " $1 "      " "[5] " $2 "      " "[10] " $3}')
CPU_CORES=$(cat /proc/cpuinfo | awk '/^processor/{print $3}' | wc -l)

PROCESS_ROOT_USER=$(ps -u root | wc -l)
PROCESS_TOTAL=$(ps aux | wc -l)

PRIVATE_IP=$(hostname -I | cut -d' ' -f1)
PRIMARY_DNS=$(cat /etc/resolv.conf | grep -i '^nameserver' | head -n1 | cut -d' ' -f2)

RAM_USED=$(expr `free -m | head -n 2 | tail -n 1 | awk {'print $3'}`)
RAM_TOTAL=$(expr `free -m | head -n 2 | tail -n 1 | awk {'print $2'}`)
SWAP_USED=$(expr `free -m | tail -n 1 | awk {'print $3'}`)
SWAP_TOTAL=$(expr `free -m | tail -n 1 | awk {'print $2'}`)

DISK_USED=$(df -h / | awk '{ a = $3 } END { print a }')
DISK_TOTAL=$(df -h / | awk '{ a = $2 } END { print a }')
DISK_USED_PERCENT=$(df -h / | awk '{ a = $5 } END { print a }')

printf "\n    \e[37mHost\e[0m   \e[32m:\e[0m \e[91m$HOSTNAME\e[0m"
printf "\n    \e[37mTime\e[0m   \e[32m:\e[0m \e[91m$LOCAL_TIME\e[0m"
printf "\n    \e[37mUptime\e[0m \e[32m:\e[0m \e[91m%s \e[37mdays \e[91m%s \e[37mhours \e[91m%s \e[37mminutes\e[0m" "$UPTIME_DAYS" "$UPTIME_HOURS" "$UPTIME_MINUTES"
printf "\n"
printf "\n    \e[32m--- [\e[0m \e[33mSYSTEM INFO\e[0m \e[32m] -----------------------------------------\e[0m"
printf "\n    \e[37mCPU\e[0m     \e[32m:\e[0m \e[91m$CPU_CORES \e[37mx\e[91m $CPU_MODEL\e[0m"
printf "\n              \e[91m$CPU_LOAD\e[0m"
printf "\n    \e[37mMemory\e[0m  \e[32m:\e[0m \e[91m$RAM_USED\e[0m \e[37m/ \e[91m$RAM_TOTAL \e[37mMB used\e[0m"
printf "\n    \e[37mSwap\e[0m    \e[32m:\e[0m \e[91m$SWAP_USED\e[0m \e[37m/ \e[91m$SWAP_TOTAL \e[37mMB used\e[0m"
printf "\n    \e[37mDisk\e[0m    \e[32m:\e[0m \e[91m%s\e[0m \e[37m/ \e[91m%s \e[37m(\e[91m%s \e[37mused)\e[0m" "$DISK_USED" "$DISK_TOTAL" "$DISK_USED_PERCENT"
printf "\n    \e[37mProcess\e[0m \e[32m:\e[0m \e[91m$PROCESS_ROOT_USER\e[0m \e[37m/ \e[91m$PROCESS_TOTAL \e[37mby root\e[0m"
printf "\n"
printf "\n    \e[32m--- [\e[0m \e[33mNETWORK\e[0m \e[32m] ---------------------------------------------\e[0m"
printf "\n    \e[37mPrivate IP\e[0m \e[32m:\e[0m \e[91m$PRIVATE_IP\e[0m"
printf "\n    \e[37mDNS Server\e[0m \e[32m:\e[0m \e[91m$PRIMARY_DNS\e[0m"
printf "\n"
printf "\n"
printf "\n"
