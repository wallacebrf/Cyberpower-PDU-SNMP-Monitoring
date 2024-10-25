# Cyberpower-PDU-SNMP-Monitoring
<div id="top"></div>
<!--
*** comments....
-->

<!-- PROJECT LOGO -->
<br />

<h3 align="center">Cyberpower Power Distribution Unit (PDU) SNMP data Logging to InfluxDB version 2</h3>

  <p align="center">
    This project is comprised of a shell script that runs once per minute collecting data from Cyberpower Power PDU and placing it into InfluxDB version 2. 
    <br />
    <a href="https://github.com/wallacebrf/Cyberpower-PDU-SNMP-Monitoring"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/wallacebrf/Cyberpower-PDU-SNMP-Monitoring/issues">Report Bug</a>
    ·
    <a href="https://github.com/wallacebrf/Cyberpower-PDU-SNMP-Monitoring/issues">Request Feature</a>
  </p>
</div>



<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#About_the_project_Details">About The Project</a>
      <ul>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#roadmap">Road map</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
### About_the_project_Details

The script gathers different SNMP based details from a Cyberpower PDUs using SNMP version 3 (much more secure than version 2) such as the following and saves them to InfluxDb version 2. 

<p align="right">(<a href="#top">back to top</a>)</p>


<!-- GETTING STARTED -->
## Getting Started

This project is written around Cyberpower pdu8xxxx serise specific SNMP OIDs and MIBs. 

### Prerequisites

1. this script is designed to be executed every 60 seconds
  
2. this script only supports SNMP V3. This is because lower versions are less secure 
	
		SNMP must be enabled on the host NAS for the script to gather the NAS NAME
		the SNMP settings for the NAS can all be entered into the web administration page
		
3. This script should be run through CRONTAB. Directly edit the crontab at /etc/crontab ONLY AFTER THE SCRIPT HAS BEEN TESTED AND CONFIRMED TO WORK. updating crontab is also detailed at the end of this readme
		details on crontab can be found here: https://man7.org/linux/man-pages/man5/crontab.5.html

4. This project requires a PHP server to be installed and configured to allow the web-administrative page to be available. This read-me does explain how to configure the needed read/write permissions, but does not otherwise explain how to setup a website on a Synology NAS through web-station


### Installation

Note: this assumes InfluxDB version 2 and Grafana are already installed and properly configured. This read-me does NOT explain how to install and configure InfluxDB nor Grafana. 

1. Create the following directories on the NAS

```
1. %PHP_Server_Root%/config
2. %PHP_Server_Root%/logging
3. %PHP_Server_Root%/logging/notifications
```

note: ```%PHP_Server_Root%``` is what ever shared folder location the PHP web server root directory is configured to be.

2. Place the ```functions.php``` file in the root of the PHP web server running on the NAS

3. Place the ```PDU_snmp.sh``` file in the ```/logging``` directory

4. Place the ```PDU_config.php``` file in the ```/config``` directory

5. Create a scheduled task on boot up in Crontab to add the following line

		mount -t tmpfs -o size=1% ramdisk $notification_file_location

		where "$notification_file_location" is the location created above "%PHP_Server_Root%/logging/notifications"

### Configuration "PDU_snmp.sh"

1. Open the ```PDU_snmp.sh``` file in a text editor. 
2. the script contains the following configuration variables 
```
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
```

3. for the variables above, ensure the "/volume1/web" is the correct location for the root of the PHP web server, correct as required

4. edit the following lines so if the script cannot load the configuration file it can still send an email

```
#########################################################
#EMAIL SETTINGS USED IF CONFIGURATION FILE IS UNAVAILABLE
#These variables will be overwritten with new corrected data if the configuration file loads properly. 
email_address="email@email.com"
from_email_address="email@email.com"
########################################################
```

### Configuration "PDU_config.php"

1. Open the ```PDU_config.php``` file in a text editor
2. the script contains the following configuration variables
```
$config_file="/volume1/web/config/config_files/config_files_local/server_PDU_config.txt";
$use_login_sessions=true; //set to false if not using user login sessions
$form_submittal_destination="index.php?page=6&config_page=pdu"; //set to the destination the HTML form submit should be directed to
$page_title="Server Room Power Distribution Unit Logging Configuration Settings";
```

ENSURE THE VALUES FOR ```$config_file``` ARE THE SAME AS THAT CONFIGURED IN [Configuration "PDU_snmp.sh"] FOR THE VARIABLE ```config_file_location```

the ```form_submit_location``` can either be set to the name of the "PDU_config.php" file itself, or if the "PDU_config.php" file is embedded in another PHP file using an "include_once" then the location should be to that php file

the variable ```page_title``` controls the title of the page when viewing it in a browser. 

the PDU_config.php file by default automatically redirects from HTTP to HTTPS. if this behavior is not required or desired change ```use_login_sessions``` to flase 

### Configuration of crontab

NOTE: ONLY EDIT THE CRONTAB FILE AFTER IT IS CONFIRMED THE SCRIP AND PHP FILES ARE INSTALLED AND WORKING PER INSTRUCTIONS ABOVE

Directly edit the crontab at /etc/crontab using ```vi /etc/crontab``` 
	
add the following line: 
```	*	*	*	*	*	root	$path_to_file/$filename```

details on crontab can be found here: https://man7.org/linux/man-pages/man5/crontab.5.html

<!-- CONTRIBUTING -->
## Contributing

based on the script found here by user kernelkaribou
https://github.com/kernelkaribou/synology-monitoring

<p align="right">(<a href="#top">back to top</a>)</p>



<!-- LICENSE -->
## License

This is free to use code, use as you wish

<p align="right">(<a href="#top">back to top</a>)</p>



<!-- CONTACT -->
## Contact

Your Name - Brian Wallace - wallacebrf@hotmail.com

Project Link: [https://github.com/wallacebrf/synology_snmp)

<p align="right">(<a href="#top">back to top</a>)</p>



<!-- ACKNOWLEDGMENTS -->
## Acknowledgments


<p align="right">(<a href="#top">back to top</a>)</p>
