#!/bin/bash

#
# DEVELERA SERVER KEY
#
DEVELERAHOSTINGKEY='your-develera-server-key'


#
# DEVELERA API URL
#
url='http://cdata.develera.com/v1/serverinfo'
urlPS='http://cdata.develera.com/v1/ps'


#
# SERVER INFO
#
host=$(lsb_release -d | awk '/Description:/ {$1=""; print $0}'| sed -e 's/^ *//' -e 's/ *$//')
timezone=$(date +%z)
boottime=$(cat /proc/stat | grep btime | awk '{ print $2 }')
hostname=$(uname -n)
query=$url'?key='$DEVELERAHOSTINGKEY'&hostname='$hostname'&tz='$timezone
queryHost='&os='$host'&bt='$boottime


#
# MEMORY INFO
#
memRaw=$(cat /proc/meminfo)
totalMem=$(echo -e "$memRaw" | awk '/MemTotal/ {print $2}')
totalFree=$(echo -e "$memRaw" | awk '/MemFree/ {print $2}')
totalBuffers=$(echo -e "$memRaw" | awk '/Buffers/ {print $2}')
totalCached=$(echo -e "$memRaw" | awk '/^Cached:/ {print $2}')
totalSwap=$(echo -e "$memRaw" | awk '/SwapTotal/ {print $2}')
totalSwapFree=$(echo -e "$memRaw" | awk '/SwapFree/ {print $2}')
queryMem='&mem='$totalMem'&memfree='$totalFree'&membuff='$totalBuffers'&memcached='$totalCached'&swap='$totalSwap'&swapfree='$totalSwapFree


#
# CPU INFO
#
cpuRaw=$(cat /proc/cpuinfo)
cpuModelName=$(echo -e "$cpuRaw" | awk '/model name/' | cut -d':' -f2 | sed -e 's/^ *//' -e 's/ *$//')
cpuMhz=$(echo -e "$cpuRaw" | awk '/cpu MHz/' | cut -d':' -f2 | tr -d ' ')
cpuCacheSize=$(echo -e "$cpuRaw" | awk '/cache size/' | cut -d':' -f2 | tr -d ' ')
cpuCores=$(grep -c processor /proc/cpuinfo)
cpuLoad5Min=$(uptime | awk -F"average:" '{print $2}' | cut -d "," -f2 | sed -e 's/^ *//' -e 's/ *$//')
queryCpu='&cpumodel='$cpuModelName'&cpumhz='$cpuMhz'&cpucache='$cpuCacheSize'&cpucores='$cpuCores'&cpuload5='$cpuLoad5Min


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
fi


#
# SEND TO DEVELERA
#
complete=$query$queryMem$queryCpu$queryHdd$queryHost$quHdd$vndata
complete=${complete// /%20}
curl $complete



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
  curl -X POST $urlPS'?key='$DEVELERAHOSTINGKEY --data '{"data":['$psdata']}' -H "Content-Type: application/json"
fi



