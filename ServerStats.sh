#!/bin/bash
#####################################
##Release:
##Version 1.3
##Author: Luke Shirnia
####################################
#version 1.3 release notes:
#added total CPU usage for top process and all its threads
#added server uptime from /proc/uptime 
#load average now pulled from /proc/loadavg rather than 'w' (for compatibility)
#replaced 'free -m' with values from /proc/meminfo (for compatibility)
#####################################
#Version 1.2 Update Notes:
#Ram usage now in MB
#removed 'bc' commands and replaced with awk for compatibility reasons
#####################################
#####Colours######
ESC_SEQ="\x1b["
GREEN=$ESC_SEQ"32;01m"
RED=$ESC_SEQ"31;01m"
RESET=$ESC_SEQ"39;49;00m"
BLUE=$ESC_SEQ"34;01m"
#####Underline/bold#####
BOLD=$ESC_SEQ"\033[1m"
bold=$(tput bold)
UNDERLINE=$ESC_SEQ"\033[4m"
#####################################
neat="############################################"
#####################################
#Load Average
loadnow=$( cut /proc/loadavg -f1 -d\ ) #this gets the 1 min load average from /proc/loadavg
load15=$( cut /proc/loadavg -f3 -d\ ) #gets the 15 min load average from /proc/loadavg

#Ram Usage
totalc=$( grep MemTotal /proc/meminfo | awk '{print $2 / 1024 }') #gets the total available ram from /proc/meminfo
usedc=$( ps -Fe --sort:-rss --no-headers | awk '{totalram += $6}END{print totalram / 1024}' )
free=$( printf "%.2f\n" $( echo - | awk -v t=$totalc -v u=$usedc '{print t - u }'))
total=$( printf "%0.2f\n" $totalc )
used=$( printf "%0.2f\n" $usedc )

topramprocess=$(ps -Fe --sort:-rss --no-headers | head -1 | awk '{print $11}')
topramrss=$(ps -Fe --sort:-rss --no-headers | head -1 | awk '{print $6}')

#CPU Stuff
topprocess=$(ps -eo user,pcpu,pid,cmd --sort:-pcpu --no-headers | head -1 | awk '{print $4}' | sed 's/[][]//g' )
topcpu=$(ps -eo user,pcpu,pid,cmd --sort:-pcpu --no-headers | head -1 | awk '{print $2}')

serveruptime=$(awk '{print int($1/86400)"days "int($1%86400/3600)":"int(($1%3600)/60)":"int($1%60)}' /proc/uptime)
#######################################

echo $neat

#####Load Average#####
echo ""
echo "Server Uptime: "$serveruptime
echo ""
#1 min load check
loadcheck=$(echo - | awk -v lnow=$loadnow '{print ( lnow < 0.80 )}')
    if [ "$loadcheck" -ge 1 ]; then
       echo -e "Load Average: Current$GREEN "$loadnow$RESET
    elif [ "$loadcheck" -le 0 ]; then
       echo -e "Load Average: Current$RED "$loadnow$RESET
    fi

#15 min load check
loadcheck15test=$(echo - | awk -v l15=$load15 '{print ( l15 < 0.80 )}')
    if [ "$loadcheck15test" -ge 1 ]; then
    echo -e "Load Average: 15min Average$GREEN "$loadnow$RESET
    elif [ "$loadcheck15test" -le 0 ]; then
        echo -e "Load Average: 15min Average$RED "$loadnow$RESET
    fi

#####RAM#####
echo ""
echo ""
echo "###RAM usage###"

echo -e "Free Ram: "$free"MB" 
echo "Used RAM: "$used"MB"
ramtest=$( printf "%.0f\n" $(echo - | awk -v u=$used -v f=$free '{ print 100 - ( u / ( f + u ) ) * 100 }' ))


echo ""
echo $ramtest"% ram left"
        if [ $ramtest -gt 20 ]; then
            echo -e "RAM Usage:$GREEN Acceptable$RESET"
        elif [ $ramtest -le 20 ] && [ $ramtest -gt 10 ] ; then
            echo -e "RAM ALERT:$RED Low!$RESET "
        elif [ $ramtest -le 10 ]; then
            echo -e "RAM WARNING:$RED CRITICAL STATE!!$RESET"
        fi
echo ""  

topramMB=$( printf "%.2f\n" $(echo - | awk -v tp=$topramrss '{print tp / 1024}'))
ramtotalprocesses=$(ps -Fe --sort:-rss | grep -v grep | grep -ic $topramprocess)

echo -e "TOP RAM CONSUMER: ""$BLUE$topramprocess$RESET"
echo "RAM Usage (RSS): $topramMB MB"
echo "Total Number of RAM Processes: $ramtotalprocesses"


totalRAMall=$( printf "%.2f" $(ps -Fe --sort:-rss --no-headers | grep -v grep | grep $topramprocess | awk '{total += $6}END{print total / 1024 }'))
rampercentage=$( printf "%.2f\n" $( echo - | awk -v t=$total -v tra=$totalRAMall '{ print (tra / t) * 100 }'))

#command below checks total ram usage of top RAM consumer and ALL of its threads and compares to total RAM avaiable. If it is higher than the threshold of 70% then a warning is produced.
totalramcheck=$(echo - | awk -v ramp=$rampercentage '{print ( ramp < 70 )}')
if [ "$totalramcheck" -ge 1 ]; then
    echo -e "Total RAM Usage for all $BLUE$topramprocess$RESET processes = " $GREEN$totalRAMall" MB"$RESET
    echo -e $GREEN$rampercentage$RESET"% used by "$topramprocess
elif [ "$totalramcheck" -le 0 ]; then
    echo -e "Total RAM usage for all $BLUE$topramprocess$RESET processes = " $RED$totalRAMall" MB"$RESET
    echo -e $RED$rampercentage$RESET"% used by "$topramprocess
fi

#####CPU#####
echo ""
echo ""
echo "###CPU usage###"
echo -e "Top Process: " $BLUE$topprocess$RESET

cpuchecktest=$( echo - | awk -v topcpu=$topcpu '{print ( topcpu < 50 )}' )
    if [ "$cpuchecktest" -ge 1 ]; then
        echo -e "CPU % for SINGLE Top Process = " "$GREEN$topcpu$RESET"
    elif [ "$cpuchecktest" -le 0 ]; then
        echo -e "CPU % for SINGLE Top Process = " "$RED$topcpu$RESET"
    fi
    
threads=$( ps afx | grep -v grep | grep -ci $topprocess )
echo -e "number of processes this is running: $UNDERLINE$threads$RESET"

#add all of the processes up and then print the total:
totalcpu=$( ps aux | grep $topprocess | grep -v grep | awk '{total += $3}END{print total}' )


totalcpuchecktest=$( echo - | awk -v totalcpu=$totalcpu '{print ( totalcpu < 70 )}')
    if [ "$totalcpuchecktest" -ge 1 ]; then
        echo -e "Total CPU % for $BLUE$topprocess$RESET = " "$GREEN$totalcpu$RESET"
    elif [ "$totalcpuchecktest" -le 0 ]; then
        echo -e "Total CPU % for $BLUE$topprocess$RESET = " "$RED$totalcpu$RESET"
    fi


echo ""
echo $neat
#######################################
