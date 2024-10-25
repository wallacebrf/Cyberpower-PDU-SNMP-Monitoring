#!/bin/bash
#Version 11/3/2023
#By Brian Wallace

###########################################
#USER VARIABLES
###########################################
lock_file="/volume1/web/logging/notifications/server_PDU_snmp.lock"
config_file="/volume1/web/config/config_files/config_files_local/server_PDU_config.txt"
last_time_email_sent="/volume1/web/logging/notifications/server_pdu_last_email_sent.txt"
email_contents="/volume1/web/logging/notifications/server_pdu_email_contents.txt"

#########################################################
#EMAIL SETTINGS USED IF CONFIGURATION FILE IS UNAVAILABLE
#These variables will be overwritten with new corrected data if the configuration file loads properly. 
email_address="email@email.com"
from_email_address="email@email.com"
#########################################################


#create a lock file in the ramdisk directory to prevent more than one instance of this script from executing  at once
if ! mkdir $lock_file; then
	echo "Failed to acquire lock.\n" >&2
	exit 1
fi
trap 'rm -rf $lock_file' EXIT #remove the lockdir on exit

#Metrics to capture, set to false if you want to skip that specific set
capture_system="true" #model information, temperature, update status, 

#reading in variables from configuration file
if [ -r "$config_file" ]; then
	#file is available and readable 
	read input_read < $config_file
	explode=(`echo $input_read | sed 's/,/\n/g'`)
	capture_interval=${explode[0]}
	nas_url=${explode[1]}
	nas_name=${explode[2]}
	ups_group="server"
	influxdb_host=${explode[3]}
	influxdb_port=${explode[4]}
	influxdb_name=${explode[5]}
	influxdb_user=${explode[6]}
	influxdb_pass=${explode[7]}
	script_enable=${explode[8]}
	AuthPass1=${explode[9]}
	PrivPass2=${explode[10]}
	snmp_privacy_protocol=${explode[11]}
	snmp_auth_protocol=${explode[12]}
	snmp_user=${explode[13]}
	target_available=0
	
#########################################################
#this function pings google.com to confirm internet access is working prior to sending email notifications 
#########################################################
check_internet() {
ping -c1 "www.google.com" > /dev/null #ping google.com									
	local status=$?
	if ! (exit $status); then
		false
	else
		true
	fi
}
	
	if [ $script_enable -eq 1 ]
	then
	
		#let's make sure the target for SNMP walking is available on the network 
		ping -c1 $nas_url > /dev/null
		if [ $? -eq 0 ]
		then
				target_available=1 #network coms are good
		else
			#ping failed
			#since the ping failed, let's do just one more ping juts in case
			ping -c1 $nas_url > /dev/null
			if [ $? -eq 0 ]
			then
				target_available=1 #network coms are good
			else
				target_available=0 #network coms appear to be down, stop script
			fi
		fi

		if [ $target_available -eq 1 ]
		then

			#loop the script 
			total_executions=$(( 60 / $capture_interval))
			echo "Capturing $total_executions times"
			i=0
			while [ $i -lt $total_executions ]; do
				
				#Create empty URL
				post_url=

				#GETTING VARIOUS SYSTEM INFORMATION
				if (${capture_system,,} = "true"); then
					
					measurement="PDU_system"
					
					#get name of PDU
					name=`snmpwalk -v3 -l authPriv -u $snmp_user -a $snmp_auth_protocol -A $AuthPass1 -x $snmp_privacy_protocol -X $PrivPass2 $nas_url:161 1.3.6.1.4.1.3808.1.1.3.1.1.0 -Oqv`
					
					#get Firmware of PDU
					firmware=`snmpwalk -v3 -l authPriv -u $snmp_user -a $snmp_auth_protocol -A $AuthPass1 -x $snmp_privacy_protocol -X $PrivPass2 $nas_url:161 1.3.6.1.4.1.3808.1.1.3.1.3.0 -Oqv`
					
					#get Serial of PDU
					serial=`snmpwalk -v3 -l authPriv -u $snmp_user -a $snmp_auth_protocol -A $AuthPass1 -x $snmp_privacy_protocol -X $PrivPass2 $nas_url:161 1.3.6.1.4.1.3808.1.1.3.1.6.0 -Oqv`
					
					#get Load of PDU
					PDU_LOAD_RAW=`snmpwalk -v3 -l authPriv -u $snmp_user -a $snmp_auth_protocol -A $AuthPass1 -x $snmp_privacy_protocol -X $PrivPass2 $nas_url:161 1.3.6.1.4.1.3808.1.1.3.2.3.1.1.2 -Oqv`
					
					explode=(`echo $PDU_LOAD_RAW | sed 's/,/\n/g'`)
					ii=0
					while [ $ii -lt 3 ]; do
						PDU_LOAD[$ii]="${explode[$ii]//"\""}"
						let ii=ii+1
					done
					#PDU_LOAD[0] = Device Load (4=0.4 amps)
					#PDU_LOAD[1] = Bank1 Load (4=0.4 amps)
					#PDU_LOAD[2] = Bank2 Load (4=0.4 amps)
					
					
					#get State of PDU
					PDU_STATE_RAW=`snmpwalk -v3 -l authPriv -u $snmp_user -a $snmp_auth_protocol -A $AuthPass1 -x $snmp_privacy_protocol -X $PrivPass2 $nas_url:161 1.3.6.1.4.1.3808.1.1.3.2.3.1.1.2 -Oqv`
					
					explode=(`echo $PDU_STATE_RAW | sed 's/,/\n/g'`)
					ii=0
					while [ $ii -lt 3 ]; do
						PDU_STATE[$ii]="${explode[$ii]//"\""}"
						let ii=ii+1
					done
					#PDU_STATE[0] = Device State
					#PDU_STATE[1] = Bank1 State
					#PDU_STATE[2] = Bank2 State
					#loadNormal(1), loadLow(2), loadNearOverload(3), loadOverload(4)
					
					#get voltage of PDU
					voltage_raw=`snmpwalk -v3 -l authPriv -u $snmp_user -a $snmp_auth_protocol -A $AuthPass1 -x $snmp_privacy_protocol -X $PrivPass2 $nas_url:161 1.3.6.1.4.1.3808.1.1.3.2.3.1.1.6 -Oqv`
					
					explode=(`echo $voltage_raw | sed 's/,/\n/g'`)
					ii=0
					while [ $ii -lt 3 ]; do
						voltage[$ii]="${explode[$ii]//"\""}"
						let ii=ii+1
					done
					#voltage[0] = Device voltage (1209 = 120.9 volts)
					#voltage[1] = Bank1 voltage (1209 = 120.9 volts)
					#voltage[2] = Bank2 voltage (1209 = 120.9 volts)
					
					#get frequency of PDU (600 = 60.0)
					frequency=`snmpwalk -v3 -l authPriv -u $snmp_user -a $snmp_auth_protocol -A $AuthPass1 -x $snmp_privacy_protocol -X $PrivPass2 $nas_url:161 1.3.6.1.4.1.3808.1.1.3.5.8.0 -Oqv`
					
					#get active power of PDU
					active_power_raw=`snmpwalk -v3 -l authPriv -u $snmp_user -a $snmp_auth_protocol -A $AuthPass1 -x $snmp_privacy_protocol -X $PrivPass2 $nas_url:161 1.3.6.1.4.1.3808.1.1.3.2.3.1.1.7 -Oqv`
					
					explode=(`echo $active_power_raw | sed 's/,/\n/g'`)
					ii=0
					while [ $ii -lt 3 ]; do
						active_power[$ii]="${explode[$ii]//"\""}"
						let ii=ii+1
					done
					#active_power[0] = Device active power (watts)
					#active_power[1] = Bank1 active power (watts)
					#active_power[2] = Bank2 active power (watts)
					
					
					#get aparent power of PDU
					apparent_power_raw=`snmpwalk -v3 -l authPriv -u $snmp_user -a $snmp_auth_protocol -A $AuthPass1 -x $snmp_privacy_protocol -X $PrivPass2 $nas_url:161 1.3.6.1.4.1.3808.1.1.3.2.3.1.1.8 -Oqv`
					
					explode=(`echo $apparent_power_raw | sed 's/,/\n/g'`)
					ii=0
					while [ $ii -lt 3 ]; do
						apparent_power[$ii]="${explode[$ii]//"\""}"
						let ii=ii+1
					done
					#apparent_power[0] = Device apparent power (volt-Amps)
					#apparent_power[1] = Bank1 apparent power (always NULL)
					#apparent_power[2] = Bank2 apparent power (always NULL)
					
					#get power factor of PDU
					power_factor_raw=`snmpwalk -v3 -l authPriv -u $snmp_user -a $snmp_auth_protocol -A $AuthPass1 -x $snmp_privacy_protocol -X $PrivPass2 $nas_url:161 1.3.6.1.4.1.3808.1.1.3.2.3.1.1.9 -Oqv`
					
					explode=(`echo $power_factor_raw | sed 's/,/\n/g'`)
					ii=0
					while [ $ii -lt 3 ]; do
						power_factor[$ii]="${explode[$ii]//"\""}"
						let ii=ii+1
					done
					#power_factor[0] = Device power factor (PF) (60=0.6)
					#power_factor[1] = Bank1 power factor (always NULL)
					#power_factor[2] = Bank2 power factor (always NULL)
					
					
					#get "near overload threashold" for each outlet of PDU
					near_overload_raw=`snmpwalk -v3 -l authPriv -u $snmp_user -a $snmp_auth_protocol -A $AuthPass1 -x $snmp_privacy_protocol -X $PrivPass2 $nas_url:161 1.3.6.1.4.1.3808.1.1.3.3.4.3.1.5 -Oqv`
					
					explode=(`echo $near_overload_raw | sed 's/,/\n/g'`)
					ii=0
					while [ $ii -lt 16 ]; do
						near_overload[$ii]="${explode[$ii]//"\""}"
						let ii=ii+1
					done
					#near_overload[0] = outlet 1
					#near_overload[1] = outlet 2
					#near_overload[2] = outlet 3
					#near_overload[3] = outlet 4
					#near_overload[4] = outlet 5
					#near_overload[5] = outlet 6
					#near_overload[6] = outlet 7
					#near_overload[7] = outlet 8
					#near_overload[8] = outlet 9
					#near_overload[9] = outlet 10
					#near_overload[10] = outlet 11
					#near_overload[11] = outlet 12
					#near_overload[12] = outlet 13
					#near_overload[13] = outlet 14
					#near_overload[14] = outlet 15
					#near_overload[15] = outlet 16
					
					#get "overload threshold" for each outlet of PDU
					overload_raw=`snmpwalk -v3 -l authPriv -u $snmp_user -a $snmp_auth_protocol -A $AuthPass1 -x $snmp_privacy_protocol -X $PrivPass2 $nas_url:161 1.3.6.1.4.1.3808.1.1.3.3.4.3.1.6 -Oqv`
					
					explode=(`echo $overload_raw | sed 's/,/\n/g'`)
					ii=0
					while [ $ii -lt 16 ]; do
						overload[$ii]="${explode[$ii]//"\""}"
						let ii=ii+1
					done
					#overload[0] = outlet 1
					#overload[1] = outlet 2
					#overload[2] = outlet 3
					#overload[3] = outlet 4
					#overload[4] = outlet 5
					#overload[5] = outlet 6
					#overload[6] = outlet 7
					#overload[7] = outlet 8
					#overload[8] = outlet 9
					#overload[9] = outlet 10
					#overload[10] = outlet 11
					#overload[11] = outlet 12
					#overload[12] = outlet 13
					#overload[13] = outlet 14
					#overload[14] = outlet 15
					#overload[15] = outlet 16
					
					#get outlet load (amps) for each outlet of PDU
					outlet_amps_raw=`snmpwalk -v3 -l authPriv -u $snmp_user -a $snmp_auth_protocol -A $AuthPass1 -x $snmp_privacy_protocol -X $PrivPass2 $nas_url:161 1.3.6.1.4.1.3808.1.1.3.3.5.1.1.7 -Oqv`
					
					explode=(`echo $outlet_amps_raw | sed 's/,/\n/g'`)
					ii=0
					while [ $ii -lt 16 ]; do
						outlet_amps[$ii]="${explode[$ii]//"\""}"
						let ii=ii+1
					done
					#30=3.0 amps
					#outlet_amps[0] = outlet 1
					#outlet_amps[1] = outlet 2
					#outlet_amps[2] = outlet 3
					#outlet_amps[3] = outlet 4
					#outlet_amps[4] = outlet 5
					#outlet_amps[5] = outlet 6
					#outlet_amps[6] = outlet 7
					#outlet_amps[7] = outlet 8
					#outlet_amps[8] = outlet 9
					#outlet_amps[9] = outlet 10
					#outlet_amps[10] = outlet 11
					#outlet_amps[11] = outlet 12
					#outlet_amps[12] = outlet 13
					#outlet_amps[13] = outlet 14
					#outlet_amps[14] = outlet 15
					#outlet_amps[15] = outlet 16
					
					#get outlet load (watts) for each outlet of PDU
					outlet_watts_raw=`snmpwalk -v3 -l authPriv -u $snmp_user -a $snmp_auth_protocol -A $AuthPass1 -x $snmp_privacy_protocol -X $PrivPass2 $nas_url:161 1.3.6.1.4.1.3808.1.1.3.3.5.1.1.8 -Oqv`
					
					explode=(`echo $outlet_watts_raw | sed 's/,/\n/g'`)
					ii=0
					while [ $ii -lt 16 ]; do
						outlet_watts[$ii]="${explode[$ii]//"\""}"
						let ii=ii+1
					done
					#outlet_watts[0] = outlet 1
					#outlet_watts[1] = outlet 2
					#outlet_watts[2] = outlet 3
					#outlet_watts[3] = outlet 4
					#outlet_watts[4] = outlet 5
					#outlet_watts[5] = outlet 6
					#outlet_watts[6] = outlet 7
					#outlet_watts[7] = outlet 8
					#outlet_watts[8] = outlet 9
					#outlet_watts[9] = outlet 10
					#outlet_watts[10] = outlet 11
					#outlet_watts[11] = outlet 12
					#outlet_watts[12] = outlet 13
					#outlet_watts[13] = outlet 14
					#outlet_watts[14] = outlet 15
					#outlet_watts[15] = outlet 16
					
					#get outlet state (ON/OFF) for each outlet of PDU
					outlet_ON_OFF_raw=`snmpwalk -v3 -l authPriv -u $snmp_user -a $snmp_auth_protocol -A $AuthPass1 -x $snmp_privacy_protocol -X $PrivPass2 $nas_url:161 1.3.6.1.4.1.3808.1.1.3.3.5.1.1.4 -Oqv`
					
					explode=(`echo $outlet_ON_OFF_raw | sed 's/,/\n/g'`)
					ii=0
					while [ $ii -lt 16 ]; do
						outlet_ON_OFF[$ii]="${explode[$ii]//"\""}"
						let ii=ii+1
					done
					#1 = ON, 2 = OFF
					#outlet_ON_OFF[0] = outlet 1
					#outlet_ON_OFF[1] = outlet 2
					#outlet_ON_OFF[2] = outlet 3
					#outlet_ON_OFF[3] = outlet 4
					#outlet_ON_OFF[4] = outlet 5
					#outlet_ON_OFF[5] = outlet 6
					#outlet_ON_OFF[6] = outlet 7
					#outlet_ON_OFF[7] = outlet 8
					#outlet_ON_OFF[8] = outlet 9
					#outlet_ON_OFF[9] = outlet 10
					#outlet_ON_OFF[10] = outlet 11
					#outlet_ON_OFF[11] = outlet 12
					#outlet_ON_OFF[12] = outlet 13
					#outlet_ON_OFF[13] = outlet 14
					#outlet_ON_OFF[14] = outlet 15
					#outlet_ON_OFF[15] = outlet 16
					
					#get outlet names for each outlet of PDU
					outlet_names_raw=`snmpwalk -v3 -l authPriv -u $snmp_user -a $snmp_auth_protocol -A $AuthPass1 -x $snmp_privacy_protocol -X $PrivPass2 $nas_url:161 1.3.6.1.4.1.3808.1.1.3.3.3.1.1.2 -Oqv`
					
					explode=(`echo $outlet_names_raw | sed 's/,/\n/g'`)
					ii=0
					while [ $ii -lt 16 ]; do
						outlet_names[$ii]="${explode[$ii]//"\""}"
						let ii=ii+1
					done
					#1 = ON, 2 = OFF
					#outlet_names[0] = outlet 1
					#outlet_names[1] = outlet 2
					#outlet_names[2] = outlet 3
					#outlet_names[3] = outlet 4
					#outlet_names[4] = outlet 5
					#outlet_names[5] = outlet 6
					#outlet_names[6] = outlet 7
					#outlet_names[7] = outlet 8
					#outlet_names[8] = outlet 9
					#outlet_names[9] = outlet 10
					#outlet_names[10] = outlet 11
					#outlet_names[11] = outlet 12
					#outlet_names[12] = outlet 13
					#outlet_names[13] = outlet 14
					#outlet_names[14] = outlet 15
					#outlet_names[15] = outlet 16

					
					#System details to post
					post_url=$post_url"$measurement,nas_name=$nas_name name=$name,firmware=$firmware,serial=$serial,Device_load=${PDU_LOAD[0]},bank1_load=${PDU_LOAD[1]},bank2_load=${PDU_LOAD[2]},Device_State=${PDU_STATE[0]},bank1_State=${PDU_STATE[1]},bank2_State=${PDU_STATE[2]},Device_voltage=${voltage[0]},bank1_voltage=${voltage[1]},bank2_voltage=${voltage[2]},frequency=$frequency,Device_active_power=${active_power[0]},bank1_active_power=${active_power[1]},bank2_active_power=${active_power[2]},apparent_power=${apparent_power[0]},power_factor=${power_factor[0]},outlet1_nearoverload=${near_overload[0]},outlet2_nearoverload=${near_overload[1]},outlet3_nearoverload=${near_overload[2]},outlet4_nearoverload=${near_overload[3]},outlet5_nearoverload=${near_overload[4]},outlet6_nearoverload=${near_overload[5]},outlet7_nearoverload=${near_overload[6]},outlet8_nearoverload=${near_overload[7]},outlet9_nearoverload=${near_overload[8]},outlet10_nearoverload=${near_overload[9]},outlet11_nearoverload=${near_overload[10]},outlet12_nearoverload=${near_overload[11]},outlet13_nearoverload=${near_overload[12]},outlet14_nearoverload=${near_overload[13]},outlet15_nearoverload=${near_overload[14]},outlet16_nearoverload=${near_overload[15]},outlet1_overload=${overload[0]},outlet2_overload=${overload[1]},outlet3_overload=${overload[2]},outlet4_overload=${overload[3]},outlet5_overload=${overload[4]},outlet6_overload=${overload[5]},outlet7_overload=${overload[6]},outlet8_overload=${overload[7]},outlet9_overload=${overload[8]},outlet10_overload=${overload[9]},outlet11_overload=${overload[10]},outlet12_overload=${overload[11]},outlet13_overload=${overload[12]},outlet14_overload=${overload[13]},outlet15_overload=${overload[14]},outlet16_overload=${overload[15]},outlet1_amps=${outlet_amps[0]},outlet2_amps=${outlet_amps[1]},outlet3_amps=${outlet_amps[2]},outlet4_amps=${outlet_amps[3]},outlet5_amps=${outlet_amps[4]},outlet6_amps=${outlet_amps[5]},outlet7_amps=${outlet_amps[6]},outlet8_amps=${outlet_amps[7]},outlet9_amps=${outlet_amps[8]},outlet10_amps=${outlet_amps[9]},outlet11_amps=${outlet_amps[10]},outlet12_amps=${outlet_amps[11]},outlet13_amps=${outlet_amps[12]},outlet14_amps=${outlet_amps[13]},outlet15_amps=${outlet_amps[14]},outlet16_amps=${outlet_amps[15]},outlet1_watts=${outlet_watts[0]},outlet2_watts=${outlet_watts[1]},outlet3_watts=${outlet_watts[2]},outlet4_watts=${outlet_watts[3]},outlet5_watts=${outlet_watts[4]},outlet6_watts=${outlet_watts[5]},outlet7_watts=${outlet_watts[6]},outlet8_watts=${outlet_watts[7]},outlet9_watts=${outlet_watts[8]},outlet10_watts=${outlet_watts[9]},outlet11_watts=${outlet_watts[10]},outlet12_watts=${outlet_watts[11]},outlet13_watts=${outlet_watts[12]},outlet14_watts=${outlet_watts[13]},outlet15_watts=${outlet_watts[14]},outlet16_watts=${outlet_watts[15]},outlet1_ON_OFF=${outlet_ON_OFF[0]},outlet2_ON_OFF=${outlet_ON_OFF[1]},outlet3_ON_OFF=${outlet_ON_OFF[2]},outlet4_ON_OFF=${outlet_ON_OFF[3]},outlet5_ON_OFF=${outlet_ON_OFF[4]},outlet6_ON_OFF=${outlet_ON_OFF[5]},outlet7_ON_OFF=${outlet_ON_OFF[6]},outlet8_ON_OFF=${outlet_ON_OFF[7]},outlet9_ON_OFF=${outlet_ON_OFF[8]},outlet10_ON_OFF=${outlet_ON_OFF[9]},outlet11_ON_OFF=${outlet_ON_OFF[10]},outlet12_ON_OFF=${outlet_ON_OFF[11]},outlet13_ON_OFF=${outlet_ON_OFF[12]},outlet14_ON_OFF=${outlet_ON_OFF[13]},outlet15_ON_OFF=${outlet_ON_OFF[14]},outlet16_ON_OFF=${outlet_ON_OFF[15]}
			"
			
					
				else
					echo "Skipping system capture"
				fi
				
				
				
				

				curl -XPOST "http://$influxdb_host:$influxdb_port/api/v2/write?bucket=$influxdb_name&org=home" -H "Authorization: Token $influxdb_pass" --data-raw "$post_url"
				
				let i=i+1
				
				echo "Capture #$i complete"
				
				#Sleeping for capture interval unless its last capture then we dont sleep
				if (( $i < $total_executions)); then
					sleep $(( $capture_interval -1))
				fi
				
			done
		else
			#determine when the last time a general notification email was sent out. this will make sure we send an email only every x minutes
			current_time=$( date +%s )
			if [ -r "$last_time_email_sent" ]; then
				read email_time < $last_time_email_sent
				email_time_diff=$((( $current_time - $email_time ) / 60 ))
			else 
				echo "$current_time" > $last_time_email_sent
				email_time_diff=$(( $email_interval + 1 ))
			fi
			
			echo "Target device at $nas_url is unavailable, skipping script"
			now=$(date +"%T")
			if [ $email_time_diff -ge $email_interval ]; then
				if check_internet; then
					#send an email indicating script config file is missing and script will not run
					mailbody="$now - Warning PDU SNMP Monitoring Failed for device IP $nas_url - Target is Unavailable - script \"${0##*/}\" "
					echo "from: $from_email_address " > $email_contents
					echo "to: $email_address " >> $email_contents
					echo "subject: Warning PDU SNMP Monitoring Failed for device IP $nas_url - Target is Unavailable " >> $email_contents
					echo "" >> $email_contents
					echo $mailbody >> $email_contents
					
					if [[ "$email_address" == "" || "$from_email_address" == "" ]];then
						echo -e "\n\nNo email address information is configured, Cannot send an email indicating Target is Unavailable and script will not run"
					else
						if [ $sendmail_installed -eq 1 ]; then
							email_response=$(sendmail -t < $email_contents  2>&1)
							if [[ "$email_response" == "" ]]; then
								echo -e "\nEmail Sent Successfully indicating Target is Unavailable and script will not run" |& tee -a $email_contents
								current_time=$( date +%s )
								echo "$current_time" > $last_time_email_sent
								email_time_diff=0
							else
								echo -e "\n\nWARNING -- An error occurred while sending email. The error was: $email_response\n\n" |& tee $email_contents
							fi	
						else
							echo "Unable to send email, \"sendmail\" command is unavailable"
						fi
					fi
				else
					echo "Internet is not available, skipping sending email"
				fi
			else
				echo -e "\n\nAnother email notification will be sent in $(( $email_interval - $email_time_diff)) Minutes"
			fi
			exit 1
		fi
	else
		echo "Script Disabled"
	fi
else
	#determine when the last time a general notification email was sent out. this will make sure we send an email only every x minutes
	current_time=$( date +%s )
	if [ -r "$last_time_email_sent" ]; then
		read email_time < $last_time_email_sent
		email_time_diff=$((( $current_time - $email_time ) / 60 ))
	else 
		echo "$current_time" > $last_time_email_sent
		email_time_diff=0
	fi
	
	now=$(date +"%T")
	echo "Configuration file for script \"${0##*/}\" is missing, skipping script and will send alert email every 60 minuets"
	if [ $email_time_diff -ge 60 ]; then
		if check_internet; then
			#send an email indicating script config file is missing and script will not run
			mailbody="$now - Warning PDU Monitoring Failed for script \"${0##*/}\" - Configuration file is missing "
			echo "from: $from_email_address " > $email_contents
			echo "to: $email_address " >> $email_contents
			echo "subject: Warning PDU Monitoring Failed for script \"${0##*/}\" - Configuration file is missing " >> $email_contents
			echo "" >> $email_contents
			echo $mailbody >> $email_contents
			
			if [[ "$email_address" == "" || "$from_email_address" == "" ]];then
				echo -e "\n\nNo email address information is configured, Cannot send an email indicating script \"${0##*/}\" config file is missing and script will not run"
			else
				if [ $sendmail_installed -eq 1 ]; then
					email_response=$(sendmail -t < $email_contents  2>&1)
					if [[ "$email_response" == "" ]]; then
						echo -e "\nEmail Sent Successfully indicating script \"${0##*/}\" config file is missing and script will not run" |& tee -a $email_contents
						current_time=$( date +%s )
						echo "$current_time" > $last_time_email_sent
						email_time_diff=0
					else
						echo -e "\n\nWARNING -- An error occurred while sending email. The error was: $email_response\n\n" |& tee $email_contents
					fi	
				else
					echo "Unable to send email, \"sendmail\" command is unavailable"
				fi
			fi
		else
			echo "Internet is not available, skipping sending email"
		fi
	else
		echo -e "\n\nAnother email notification will be sent in $(( 60 - $email_time_diff)) Minutes"
	fi
	exit 1
fi
