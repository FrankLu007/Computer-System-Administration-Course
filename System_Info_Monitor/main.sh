#!/bin/bash

trap "clear; exit 1" 2
while :
do
	exec 3>&1
	result=$(dialog --menu 'SYS INFO' 100 100 80 '1' 'CPU INFO' '2' 'MEMORY INFO' '3' 'NETWORK INFO' '4' 'FILE BROWSER' '5' 'CPU Usage' 2>&1 1>&3)
	exitcode=$?
	exec 3>&-
	if [ "$exitcode" -eq "1" ]
	then
		clear
		exit 0
	fi
	if [ "$result" = "1" ] 
	then
		echo -en "CPU INFO\n\nCPU Model:" > cpu_info.txt
		lscpu | grep 'Model name' | awk '{$1=$2=""; print $0 "\n"}' >> cpu_info.txt
		echo -en "CPU Machine:" >> cpu_info.txt
		lscpu | grep 'Architecture' | awk '{$1=""; print $0 "\n"}' >> cpu_info.txt
		echo -en "CPU Core:" >> cpu_info.txt
		lscpu | grep 'CPU(s)' | head -n 1 | awk '{$1=""; print $0 "\n"}' >> cpu_info.txt
		dialog --msgbox "$(cat cpu_info.txt)" 100 100
		rm cpu_info.txt
	elif [ "$result" = "2" ]
	then
		while :
		do
			MEMINFO="Memory INFO and Usage\n\nTotal: $(free -h | grep Mem: | awk '{print $2}')B\nUsed: $(free -h | grep Mem: | awk '{print $3}')B\nFree: $(free -h | grep Mem: | awk '{print $4}')B\n"
			TOTAL=$(free -h | grep Mem: | awk '{print $2}')
			TOTAL=${TOTAL::-1}
			USED=$(free -h | grep Mem: | awk '{print $3}')
			dialog --mixedgauge "$MEMINFO" 100 100 $( echo "100 * $USED / $TOTAL" | bc )
			read -n 1 -t 3
			if [ $? -eq 0 ]; then
				input=`printf '%d' "'$REPLY"`
				input=`echo -e "$input"`
				if [ $input -eq 0 ]; then
					break
				fi
			fi
		done
	elif [ "$result" = "3" ]
	then
		while :
		do
			dialog_array=""
			ip a | grep '<' | awk '{print $2}' > array_device.txt
			readarray NET_ARRAY < array_device.txt
			rm array_device.txt
			for((i=0; i<${#NET_ARRAY[@]}; i++))
			do
				dialog_array[i*2]="${NET_ARRAY[i]::-2}"
				dialog_array[i*2+1]='*'
			done
			exec 3>&1
			NET=$(dialog --menu 'Network Interfaces' 100 100 80 "${dialog_array[@]}" 2>&1 1>&3)
			exitcode=$?
			exec 3>&-
			unset dialog_array
			if [ "$exitcode" -eq "1" ]
			then
				break
			fi
			echo -en "Interface Name: $NET\n\nIPv4___: " > net.txt
			for((i=1; i<=${#NET_ARRAY[@]}; i++))
			do
				if [ "$NET" = "${NET_ARRAY[i-1]::-2}" ]
				then
					ip a | grep 'inet ' | head -n $i | tail -n 1 | awk '{print $2}' | cut -d"/" -f 1 >> net.txt
					echo -ne "Netmask: 0x" >> net.txt
					TMP=$(ip a | grep 'inet ' | head -n $i | tail -n 1 | awk '{print $2}' | cut -d"/" -f 2)
					for((j=0; j < 8 ; j++))
					do
						if [[ $TMP -ge 4 ]]
						then
							TMP=$(($TMP - "4"))
							echo -n "f" >> net.txt
						else
							if [[ $TMP -eq 0 ]]
							then
								echo -n "0" >> net.txt
							elif [[ $TMP -eq 1 ]] 
							then
								echo -n "8" >> net.txt
							elif [[ $TMP -eq 2 ]]
							then
								echo -n "c" >> net.txt
							else
								echo -n "e" >> net.txt
							fi
							TMP=0
						fi
					done
					echo -ne "\nMac____: " >> net.txt 
					ip a | grep 'link/' | head -n $i | tail -n 1 | awk '{print $2}' >> net.txt
					dialog --msgbox "$(cat net.txt)" 100 100
					rm net.txt
					break
				fi
			done
		done
	elif [ "$result" = "4" ]
	then
		CUR_PATH="$PWD"
		while :
		do
			FILE_LIST="$(ls -la $CUR_PATH | awk '{print $9}')"
			echo "${FILE_LIST[@]}" > file_list.txt
			readarray FILE < file_list.txt
			rm file_list.txt
			dialog_array=""
			for((i=1; i<${#FILE[@]}; i++))
			do
				dialog_array[i*2-2]="${FILE[i]::-1}"
				dialog_array[i*2-1]="$(file --mime-type $CUR_PATH/${FILE[i]} | awk '{print $2}')"
			done
			exec 3>&1
			FILE=$(dialog --clear --menu "File Browser: $CUR_PATH" 100 100 80 "${dialog_array[@]}" 2>&1 1>&3)
			exitcode=$?
			exec 3>&-
			unset dialog_array
			if [ "$exitcode" -eq "1" ]
			then
				break
			fi
			if [ -f "$CUR_PATH/${FILE}" ]
			then
				while :
				do
					echo -e "<File Name>: $FILE\n<File INFO>:$(file $CUR_PATH/$FILE | awk '{$1=""; print $0}')" > file_info.txt
					echo "<File Size>: $(ls -lah $CUR_PATH/$FILE | awk '{$1=""; print $5}')B" >> file_info.txt
					if [ -z "$(file $CUR_PATH/$FILE | awk '{$1=""; print $0}' | grep 'text')" ]
					then
						dialog --msgbox "$(cat file_info.txt)" 100 100
						break
					else
						dialog --no-label "edit" --yesno "$(cat file_info.txt)" 100 100 
						if [ "$?" -eq 1 ]
						then
							${EDITOR:-"vim"} "$CUR_PATH/${FILE}"
						else
							break
						fi	
					fi
					rm file_info.txt
				done
			else
				if [ "$FILE" == "." ]
				then
					continue
				elif [ "$FILE" == ".." ]
				then
					CUR_PATH="$(echo $CUR_PATH | rev | cut -d '/' -f 1 --complement | rev)"
					if [ "$CUR_PATH" = "" ]
					then
						CUR_PATH="/"
					fi
				else
					if [ "$CUR_PATH" = "/" ]
					then
						CUR_PATH="$CUR_PATH$FILE"
					else
						CUR_PATH="$CUR_PATH/$FILE"
					fi
				fi
			fi
		done
	else
		while :
		do
			echo -e "CPU Loading" > cpu.txt
			LINE=2
			CPUID=0
			while :
			do

				if [ "cpu$CPUID" == "$(cat /proc/stat | grep cpu | head -n $LINE | tail -n 1 | awk '{print $1}')" ]
				then
					echo -n "CPU$CPUID: USER: " >> cpu.txt
					TOTAL=0

					TOTAL="$(($TOTAL + $(cat /proc/stat | grep cpu | head -n $LINE | tail -n 1 | awk '{print $2}')))"
					TOTAL="$(($TOTAL + $(cat /proc/stat | grep cpu | head -n $LINE | tail -n 1 | awk '{print $3}')))"
					TOTAL="$(($TOTAL + $(cat /proc/stat | grep cpu | head -n $LINE | tail -n 1 | awk '{print $4}')))"
					TOTAL="$(($TOTAL + $(cat /proc/stat | grep cpu | head -n $LINE | tail -n 1 | awk '{print $5}')))"
					TOTAL="$(($TOTAL + $(cat /proc/stat | grep cpu | head -n $LINE | tail -n 1 | awk '{print $6}')))"
					TOTAL="$(($TOTAL + $(cat /proc/stat | grep cpu | head -n $LINE | tail -n 1 | awk '{print $7}')))"
					TOTAL="$(($TOTAL + $(cat /proc/stat | grep cpu | head -n $LINE | tail -n 1 | awk '{print $8}')))"
					# echo $TOTAL
					USER_T=$(cat /proc/stat | grep cpu | head -n $LINE | tail -n 1 | awk '{print $2}')
					SYS_T=$(cat /proc/stat | grep cpu | head -n $LINE | tail -n 1 | awk '{print $4}')
					IDLE_T=$(cat /proc/stat | grep cpu | head -n $LINE | tail -n 1 | awk '{print $5}')
					printf "%.1lf" "$(echo "scale=1; 100 * $USER_T / $TOTAL" | bc)"  >> cpu.txt
					echo -n "% SYST: " >> cpu.txt
					printf "%.1lf" "$(echo "scale=1; 100 * $SYS_T / $TOTAL" | bc)"  >> cpu.txt
					echo -n "% IDLE: " >> cpu.txt
					printf "%.1lf" "$(echo "scale=1; 100 * $IDLE_T / $TOTAL" | bc)"  >> cpu.txt
					echo "%" >> cpu.txt
				else
					break
				fi
				LINE=$((LINE + 1))
				CPUID=$((CPUID + 1))
			done
			TOTAL="$(($TOTAL + $(cat /proc/stat | grep cpu | head -n 1 | awk '{print $2}')))"
			TOTAL="$(($TOTAL + $(cat /proc/stat | grep cpu | head -n 1 | awk '{print $3}')))"
			TOTAL="$(($TOTAL + $(cat /proc/stat | grep cpu | head -n 1 | awk '{print $4}')))"
			TOTAL="$(($TOTAL + $(cat /proc/stat | grep cpu | head -n 1 | awk '{print $5}')))"
			TOTAL="$(($TOTAL + $(cat /proc/stat | grep cpu | head -n 1 | awk '{print $6}')))"
			TOTAL="$(($TOTAL + $(cat /proc/stat | grep cpu | head -n 1 | awk '{print $7}')))"
			TOTAL="$(($TOTAL + $(cat /proc/stat | grep cpu | head -n 1 | awk '{print $8}')))"
			dialog --mixedgauge "$(cat cpu.txt)" 100 100 "$( echo "100 * $(cat /proc/stat | grep cpu | head -n 1 | awk '{print $2}') / $TOTAL" | bc )"
			rm cpu.txt
			read -n 1 -t 3
			if [ $? -eq 0 ]; then
				input=`printf '%d' "'$REPLY"`
				input=`echo -e "$input"`
				if [ $input -eq 0 ]; then
					break
				fi
			fi
		done
	fi


done