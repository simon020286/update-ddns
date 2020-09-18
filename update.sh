# !/bin/bash

# https://blog.sleeplessbeastie.eu/2019/11/11/how-to-parse-ini-configuration-file-using-bash/
# Get INI section
ReadINISections(){
  local filename="$1"
  gawk '{ if ($1 ~ /^\[/) section=tolower(gensub(/\[(.+)\]/,"\\1",1,$1)); configuration[section]=1 } END {for (key in configuration) { print key} }' ${filename}
}

# Get/Set all INI sections
GetINISections(){
  local filename="$1"

  sections="$(ReadINISections $filename)"
  for section in $sections; do
    array_name="configuration_${section}"
    declare -g -A ${array_name}
  done
  eval $(gawk -F= '{ 
                    if ($1 ~ /^\[/) 
                      section=tolower(gensub(/\[(.+)\]/,"\\1",1,$1)) 
                    else if ($1 !~ /^$/ && $1 !~ /^;/) {
                      gsub(/^[ \t]+|[ \t]+$/, "", $1); 
                      gsub(/[\[\]]/, "", $1);
                      gsub(/^[ \t]+|[ \t]+$/, "", $2); 
                      if (configuration[section][$1] == "")  
                        configuration[section][$1]=$2
                      else
                        configuration[section][$1]=configuration[section][$1]" "$2} 
                    } 
                    END {
                      for (section in configuration)    
                        for (key in configuration[section]) { 
                          section_name = section
                          gsub( "-", "_", section_name)
                          print "configuration_" section_name "[\""key"\"]=\""configuration[section][key]"\";"                        
                        }
                    }' ${filename}
        )


}

GetINISections $1

DIRECTORY=$(cd `dirname $0` && pwd)

filename="$DIRECTORY/currentip.txt"

if [[ ! -e $filename ]]; then
    touch $filename
fi

oldip=$(cat $filename)
currentip=$(curl -s 'http://ip1.dynupdate.no-ip.com/')

if [ "$2" == "--force" ]; then
  oldip="" 
fi

updateNoIp() {
  if [ -n "${configuration_noip["domains"]}" ]; then
    domains=${configuration_noip["domains"]}
    username=${configuration_noip["username"]}
    password=${configuration_noip["password"]}
    urlnoip="https://dynupdate.no-ip.com/nic/update?hostname=$domains&myip=$currentip"
    echo $(curl -s --user $username:$password $urlnoip)
  fi
}

updateDuckDns() {
  if [ -n "${configuration_duckdns["domains"]}" ]; then
    domains=${configuration_duckdns["domains"]}
    token=${configuration_duckdns["token"]}
    urlduckdns="https://www.duckdns.org/update?domains=$domains&token=$token&ip=$currentip"
    echo $(curl -s $urlduckdns)
  fi
}

if [ "$oldip" != "$currentip" ]; then
  updateNoIp
  updateDuckDns
  echo $currentip > $filename
else
  echo 'Not changed'
fi