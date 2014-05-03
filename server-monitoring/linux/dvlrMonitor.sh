#!/bin/bash

#
# Parameter
# $1 = key
#

#
# DEVELERA SERVER KEY
#
if [ -z "$1" ]
then
  echo "Key not set"
  exit 1
fi
DEVELERASERVERKEY=$1


#
# DEVELERA API URL
#
url='http://cdata.develera.com/v1/serverinfo'
urlPS='http://cdata.develera.com/v1/ps'

#
# SERVER INFO
#
queryBuilder='?key='$DEVELERASERVERKEY
queryBuilder=$queryBuilder'&os='$(lsb_release -d | awk '/Description:/ {$1=""; print $0}'| sed -e 's/^ *//' -e 's/ *$//')
queryBuilder=$queryBuilder'&ip='$(curl ipecho.net/plain)
queryBuilder=$queryBuilder'&tz='$(date +%z)
queryBuilder=$queryBuilder'&bt='$(cat /proc/stat | grep btime | awk '{ print $2 }')
queryBuilder=$queryBuilder'&hostname='$(uname -n)


#
# MEMORY INFO
#
memRaw=$(cat /proc/meminfo)
queryBuilder=$queryBuilder'&mem='$(echo -e "$memRaw" | awk '/MemTotal/ {print $2}')
queryBuilder=$queryBuilder'&memfree='$(echo -e "$memRaw" | awk '/MemFree/ {print $2}')
queryBuilder=$queryBuilder'&membuff='$(echo -e "$memRaw" | awk '/Buffers/ {print $2}')
queryBuilder=$queryBuilder'&memcached='$(echo -e "$memRaw" | awk '/^Cached:/ {print $2}')
queryBuilder=$queryBuilder'&swap='$(echo -e "$memRaw" | awk '/SwapTotal/ {print $2}')
queryBuilder=$queryBuilder'&swapfree='$(echo -e "$memRaw" | awk '/SwapFree/ {print $2}')
memRaw=''


#
# CPU INFO
#
cpuRaw=$(cat /proc/cpuinfo)
queryBuilder=$queryBuilder'&cpumodel='$(echo -e "$cpuRaw" | awk '/model name/' | cut -d':' -f2 | sed -e 's/^ *//' -e 's/ *$//')
queryBuilder=$queryBuilder'&cpumhz='$(echo -e "$cpuRaw" | awk '/cpu MHz/' | cut -d':' -f2 | tr -d ' ')
queryBuilder=$queryBuilder'&cpucache='$(echo -e "$cpuRaw" | awk '/cache size/' | cut -d':' -f2 | tr -d ' ')
queryBuilder=$queryBuilder'&cpucores='$(grep -c processor /proc/cpuinfo)
queryBuilder=$queryBuilder'&cpuload5='$(uptime | awk -F"average:" '{print $2}' | cut -d "," -f2 | sed -e 's/^ *//' -e 's/ *$//')
cpuRaw=''


#
# DISK INFO
#
hddArray=$(df -lh --block-size=KB | awk '/^\/dev/')
i=0
quHdd=''
while read -r line; do
let i=i+1
  hddName=$(echo -e "$line" | awk '{ print $1 }' | head -1 | cut -d'%' -f1 | sed "s/kB$//")
  hddTotal=$(echo -e "$line" | awk '{ print $2 }' | head -1 | cut -d'%' -f1 | sed "s/kB$//")
  hddUsed=$(echo -e "$line" | awk '{ print $3 }' | head -1 | cut -d'%' -f1 | sed "s/kB$//")
  hddFree=$(echo -e "$line" | awk '{ print $4 }' | head -1 | cut -d'%' -f1 | sed "s/kB$//")
  quHdd=$quHdd'&hdd[hdd'$i'][name]='$hddName'&hdd[hdd'$i'][total]='$hddTotal'&hdd[hdd'$i'][used]='$hddUsed'&hdd[hdd'$i'][free]='$hddFree
done <<< "$hddArray"
quHdd=${quHdd//]/\\]}
quHdd=${quHdd//[/\\[}
queryBuilder=$queryBuilder$quHdd
hddName=''
hddTotal=''
hddUsed=''
hddFree=''
hddArray=''


#
# NETWORK INFO
# only if vnstat installed (e.g. apt-get install vnstat)
#
vnstatcheck=$( command -v vnstat >/dev/null 2>&1 || echo 0)
if [ "$vnstatcheck" != 0 ]
then
  befHour=$(date --date='-1 hour' +"%H" | sed 's/^0*//');
  nowHour=$(date +"%H" | sed 's/^0*//');
  eths=$(netstat -i -v | awk '/eth/ { print $1}' | sed -e 's/^ *//' -e 's/ *$//')
  vndata=''
  while read -r eth; do
    vnstatdataAkt='&vnstat\['$eth'\]='$(vnstat -i eth0 -h --dumpdb | awk '/h;'$nowHour'/')
    vnstatdataBef='&vnstat\['$eth'\]='$(vnstat -i eth0 -h --dumpdb | awk '/h;'$befHour'/')
    vndata=$vndata$vnstatdataAkt$vnstatdataBef
  done <<< "$eths"
  vndata=${vndata//;/\-}
  queryBuilder=$queryBuilder$vndata
  vndata=''
  befHour=''
  nowHour=''
  eths=''
  vnstatcheck=''
  vnstatdataAkt=''
  vnstatdataBef=''
fi


#
# SEND TO DEVELERA
#
queryBuilder=${queryBuilder// /%20}
curl -s $url$queryBuilder
url=''
queryBuilder=''

#
# GET AND SEND PROCESS INFO
#
processraw=$(ps aux| sort -k 4 -r | sed -n '1!p')
psdata=''
while read -r line; do
  psuser=$(echo -e "$line" | awk '{print $1}')
  pspid=$(echo -e "$line" | awk '{print $2}')
  pscpu=$(echo -e "$line" | awk '{print $3}')
  psmem=$(echo -e "$line" | awk '{print $4}')
  pscom=$(echo -e "$line" | awk '{print $11}')
  psdata=$psdata',{"ps":"'$psuser';'$pspid';'$pscpu';'$psmem';'$pscom'"}'
done <<< "$processraw"
if [ "$psdata" != '' ]
then
  psdata=$(echo -e "$psdata" | sed 's/^.//')
  curl -X POST $urlPS'?key='$DEVELERASERVERKEY --data '{"data":['$psdata']}' -H "Content-Type: application/json"
fi
processraw=''
psdata=''
psuser=''
pspid=''
pscpu=''
psmem=''
pscom=''
urlPS=''
DEVELERASERVERKEY=''


