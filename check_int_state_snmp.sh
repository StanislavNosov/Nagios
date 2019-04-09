#!/bin/sh
# AUTHOR -|
# 	 Stas 
# NAME -|
#	 check_int_state_snmp
# DESCRIPTION -|
# 	 This check is written only for SNMP v3 but could be modified easily. Check ifAperStatus & ifAdminStatus

NAGIOSPLUGSDIR=/usr/local/libexec/nagios
#snmpwalk -v 3 -u <USERNAME>  -l authPriv -a SHA -A '<auth_pass>' -x AES -X '<priv_pass>'  <ip_address>
COMM="-P 3 -U <USERNAME> -L authPriv -a SHA -A <auth_pass> -x AES -X <priv_pass>"

HOST=$1
INDEX=$2
MATCH=$3

if [ $# -lt 3 ] || [ $MATCH -gt 3 -o $MATCH -lt 1 ]; then
        echo "Usage: $0 <hostname> <int-index> <match> 1 2 or 3"
        exit 127
fi

IntName() {
        $NAGIOSPLUGSDIR/check_snmp -H $HOST $COMM -o ifName.$INDEX
}

CheckSt() {
        $NAGIOSPLUGSDIR/check_snmp -H $HOST $COMM -o $1.$INDEX -r $2
}

Parser() {
        echo $4 | sed 's/["*]//g'
}

# Get the ifName
INT=$(IntName)
RES=$?

# Check snmp Status...
if [ $RES = 0 ]; then
        ifOPER=.1.3.6.1.2.1.2.2.1.8
        ifADMIN=.1.3.6.1.2.1.2.2.1.7

#if Match
        if [ $MATCH = 1 ]; then
                MATCH_ADM=1
                MATCH_OPER=1
        elif [ $MATCH = 2 ]; then
                MATCH_ADM=2
                MATCH_OPER=2
        else
                MATCH_ADM=1
                MATCH_OPER=2
                fi
#Parse int name...
        INT=$(Parser $INT)
else
        echo "SNMP problem. No data received from host."
        exit 3
fi

if [ $MATCH_ADM = 2 -a $MATCH_OPER = 2 ]; then
        STATE_ifADMIN=$(Parser $(CheckSt $ifADMIN $MATCH_ADM))
        if [ $STATE_ifADMIN = 2 ]; then
                echo "$INT shutdown"
                exit 0
        fi
        STATE_ifOPER=$(Parser $(CheckSt $ifOPER $MATCH_OPER))
        if [ $STATE_ifOPER = 2 ]; then
                echo "$INT no shutdown was entered"
                exit 1
        fi
        echo "$INT - link up, cord was plugged"
        exit 2
fi

if [ $MATCH_ADM = 1 -a $MATCH_OPER = 2 ]; then
        STATE_ifADMIN=$(Parser $(CheckSt $ifADMIN $MATCH_ADM))
        if [ $STATE_ifADMIN = 2 ]; then
                echo "$INT shutdown was entered"
                exit 1
        fi
        STATE_ifOPER=$(Parser $(CheckSt $ifOPER $MATCH_OPER))
        if [ $STATE_ifOPER = 2 ]; then
                echo "$INT down"
                exit 0
        fi
        echo "$INT - link up, cord was plugged"
        exit 2
fi

if [ $MATCH_ADM = 1 -a $MATCH_OPER = 1 ]; then
        STATE_ifADMIN=$(Parser $(CheckSt $ifADMIN $MATCH_ADM))
        if [ $STATE_ifADMIN = 2 ]; then
                echo "$INT was admin shutdown"
                exit 2
        fi
        STATE_ifOPER=$(Parser $(CheckSt $ifOPER $MATCH_OPER))
        if [ $STATE_ifOPER = 1 ]; then
                echo "$INT up"
                exit 0
        fi
        echo "$INT - link down, cord was unplugged"
        exit 2
fi
