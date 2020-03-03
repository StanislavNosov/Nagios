#!/bin/sh
#snmpwalk -v 3 -u <USERNAME>  -l <auth> -a SHA -A '<pass1>' -x AES -X '<pass2>'  <ip_address>
#COMM="-P 3 -U <USERNAME> -L <auth> -a SHA -A <pass1> -x AES -X <pass2>"

HOST=$1
COMM="-P 3 -U <USERNAME> -L <auth> -a SHA -A <pass1> -x AES -X <pass2>"
NAGIOSPLUGSDIR=/usr/local/libexec/nagios
HOSTNAME="$(host $HOST | awk '{print $5}' | rev | cut -d. -f4- | rev)"

if [ $HOSTNAME == "3(NXDOMAIN)" ]; then
        echo "create a record"
        exit 3
fi

#HrdDev() {
#       snmpwalk $COMM -On $HOST .1.3.6.1.2.1.47.1.1.1.1.2.1
#}

#Parser() {
#        echo $1 | sed 's/["*]//g'
#}
#HRD=$(HrdDev)

RES=$?

# Check snmp Status...
if [ $RES != 0 ]; then
        echo $RES
        echo "SNMP problem. No data received from host."
        exit 3
#elif grep -q "Switch" <<< "$HRD"; then
#       echo "SNMP no problem. data received from host."
#       exit 0
#else
#       echo "Not match"
#       exit 0
fi

snmpwalk $COMM -On $HOST ifName | grep '\(Gi\|Te\|Fa\)' | sed 's/.1.3.6.1.2.1.31.1.1.1.1.//g' | awk '{print $1" "$4}' > n.tmp
snmpwalk $COMM -On $HOST .1.3.6.1.2.1.2.2.1.7 | sed -e 's/.1.3.6.1.2.1.2.2.1.7.//g' -e s/" = INTEGER: "/" "/g -e 's/[downup()]//g' | grep -E '[[:digit:]]{5}' |  grep -Ev '(^2....)' |  grep -Ev '(14501)' > 7.tmp
snmpwalk $COMM -On $HOST .1.3.6.1.2.1.2.2.1.8 | sed -e 's/.1.3.6.1.2.1.2.2.1.8.//g' -e s/" = INTEGER: "/" "/g -e 's/[downup()]//g' | grep -E '[[:digit:]]{5}' |  grep -Ev '(^2....)' |  grep -Ev '(14501)' > 8.tmp
awk 'FNR==NR{a[$1]=$2 FS $3;next}{ print $0, a[$1]}' n.tmp 7.tmp  > fs.tmp
awk 'FNR==NR{a[$1]=$2 FS $3;next}{ print $0, a[$1]}' fs.tmp 8.tmp  > ls.tmp
#awk 'NR==FNR{a[FNR]=$0; next} {a[FNR] = a[FNR] OFS $2} END{for (i=1;i<=FNR;i++) print a[i]}' n.tmp 7.tmp 8.tmp > ls1.tmp

cat ls.tmp | awk -v HOSTNAME="$HOSTNAME" '{
{print("define service{");}
{print("\t""use""\t""\t""\t""generic-switch-service");}
{print("\t""host_name""\t""\t"HOSTNAME);}
{print("\t""service_description""\t""Port "$4);}
if ($2 == $3)
 {print("\t""check_command ""\t" "intst_snmp!"$1"!"$2);}
if ($2 != $3)
 {print("\t""check_command ""\t" "intst_snmp!"$1"!"$2+$3);}
 {print("}");}
}' > sw.conf

rm -f *.tmp
cat sw.conf >> ../objects/network/$HOSTNAME.newcfg
