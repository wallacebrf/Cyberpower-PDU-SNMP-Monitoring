<?php
///////////////////////////////////////////////////
//User Defined Variables
///////////////////////////////////////////////////

$config_file="/volume1/web/config/config_files/config_files_local/server_PDU_config.txt";
$use_login_sessions=true; //set to false if not using user login sessions
$form_submittal_destination="index.php?page=6&config_page=pdu"; //set to the destination the HTML form submit should be directed to
$page_title="Server Room Power Distribution Unit Logging Configuration Settings";

///////////////////////////////////////////////////
//Beginning of configuration page
///////////////////////////////////////////////////
if($use_login_sessions){
	if($_SERVER['HTTPS']!="on") {

	$redirect= "https://".$_SERVER['HTTP_HOST'].$_SERVER['REQUEST_URI'];

	header("Location:$redirect"); } 

	// Initialize the session
	if(session_status() !== PHP_SESSION_ACTIVE) session_start();
	 
	$current_time=time();

	if(!isset($_SESSION["session_start_time"])){
		$expire_time=$current_time-60;
	}else{
		$expire_time=$_SESSION["session_start_time"]+3600; #un-refreshed session will only be good for 1 hour
	}


	// Check if the user is logged in, if not then redirect him to login page
	if(!isset($_SESSION["loggedin"]) || $_SESSION["loggedin"] !== true || $current_time > $expire_time || !isset($_SESSION["session_user_id"])){
		// Unset all of the session variables
		$_SESSION = array();
		// Destroy the session.
		session_destroy();
		header("location: ../login.php");
		exit;
	}else{
		$_SESSION["session_start_time"]=$current_time; //refresh session start time
	}
}
error_reporting(E_NOTICE);
include $_SERVER['DOCUMENT_ROOT']."/functions.php";
$email_error="";
$email_interval_error="";
$PDU_url_error="";
$PDU_name_error="";
$ups_group_error="";
$influxdb_host_error="";
$influxdb_port_error="";
$influxdb_name_error="";
$influxdb_user_error="";
$influxdb_pass_error="";
$generic_error="";
$from_email_error="";
$auth_pass_error="";
$priv_pass_error="";
$snmp_user_error="";
		

if(isset($_POST['submit_server_PDU'])){
	if (file_exists("".$config_file."")) {
		$data = file_get_contents("".$config_file."");
		$pieces = explode(",", $data);
	}
		   
	[$script_enable, $generic_error] = test_input_processing($_POST['script_enable'], "", "checkbox", 0, 0);
	
	[$capture_interval, $generic_error] = test_input_processing($_POST['capture_interval'], $pieces[0], "numeric", 10, 60);
	
	[$PDU_url, $PDU_url_error] = test_input_processing($_POST['PDU_url'], $pieces[1], "ip", 0, 0);
	
	[$PDU_name, $PDU_name_error] = test_input_processing($_POST['PDU_name'], $pieces[2], "name", 0, 0);
	
	[$ups_group, $ups_group_error] = test_input_processing($_POST['ups_group'], $pieces[3], "name", 0, 0);
	
	[$influxdb_host, $influxdb_host_error] = test_input_processing($_POST['influxdb_host'], $pieces[4], "ip", 0, 0);	

	[$influxdb_port, $influxdb_port_error] = test_input_processing($_POST['influxdb_port'], $pieces[5], "numeric", 0, 65000);		
		  
	[$influxdb_name, $influxdb_name_error] = test_input_processing($_POST['influxdb_name'], $pieces[6], "name", 0, 0);			  
		  
	[$influxdb_user, $influxdb_user_error] = test_input_processing($_POST['influxdb_user'], $pieces[7], "name", 0, 0);		

	[$influxdb_pass, $influxdb_pass_error] = test_input_processing($_POST['influxdb_pass'], $pieces[8], "password", 0, 0);	

	[$auth_pass, $auth_pass_error] = test_input_processing($_POST['auth_pass'], $pieces[10], "password", 0, 0);
	
	[$priv_pass, $priv_pass_error] = test_input_processing($_POST['priv_pass'], $pieces[11], "password", 0, 0);
	
	if ($_POST['snmp_privacy_protocol']=="AES" || $_POST['snmp_privacy_protocol']=="DES"){
		[$snmp_privacy_protocol, $generic_error] = test_input_processing($_POST['snmp_privacy_protocol'], $pieces[12], "name", 0, 0);
	}else{
		$snmp_privacy_protocol=$pieces[12];
	}
		   

	if ($_POST['snmp_auth_protocol']=="MD5" || $_POST['snmp_auth_protocol']=="SHA"){
		[$snmp_auth_protocol, $generic_error] = test_input_processing($_POST['snmp_auth_protocol'], $pieces[13], "name", 0, 0);
	}else{
		$snmp_auth_protocol=$pieces[13];
	}
	
	[$snmp_user, $snmp_user_error] = test_input_processing($_POST['snmp_user'], $pieces[14], "name", 0, 0);

	
		  
	$put_contents_string="".$capture_interval.",".$PDU_url.",".$PDU_name.",".$ups_group.",".$influxdb_host.",".$influxdb_port.",".$influxdb_name.",".$influxdb_user.",".$influxdb_pass.",".$script_enable.",".$auth_pass.",".$priv_pass.",".$snmp_privacy_protocol.",".$snmp_auth_protocol.",".$snmp_user."";
		  
	if (file_put_contents("".$config_file."",$put_contents_string )==FALSE){
		print "<font color=\"red\">Error - could not save configuration</font>";
	}
		  
}else{
	if (file_exists("".$config_file."")) {
		$data = file_get_contents("".$config_file."");
		$pieces = explode(",", $data);
		$capture_interval=$pieces[0];
		$PDU_url=$pieces[1];
		$PDU_name=$pieces[2];
		$ups_group=$pieces[3];
		$influxdb_host=$pieces[4];
		$influxdb_port=$pieces[5];
		$influxdb_name=$pieces[6];
		$influxdb_user=$pieces[7];
		$influxdb_pass=$pieces[8];
		$script_enable=$pieces[9];
		$auth_pass=$pieces[10];
		$priv_pass=$pieces[11];
		$snmp_privacy_protocol=$pieces[12];
		$snmp_auth_protocol=$pieces[13];
		$snmp_user=$pieces[14];
	}else{
		$capture_interval=60;
		$PDU_url="localhost";
		$PDU_name="";
		$ups_group="NAS";
		$influxdb_host=0;
		$influxdb_port=8086;
		$influxdb_name="db";
		$influxdb_user="admin";
		$influxdb_pass="password";
		$script_enable=0;
		$auth_pass="password2";
		$priv_pass="password3";
		$snmp_privacy_protocol="DES";
		$snmp_auth_protocol="MD5";
		$snmp_user="user";
		
		
		$put_contents_string="".$capture_interval.",".$PDU_url.",".$PDU_name.",".$ups_group.",".$influxdb_host.",".$influxdb_port.",".$influxdb_name.",".$influxdb_user.",".$influxdb_pass.",".$script_enable.",".$auth_pass.",".$priv_pass.",".$snmp_privacy_protocol.",".$snmp_auth_protocol.",".$snmp_user."";
			  
		if (file_put_contents("".$config_file."",$put_contents_string )==FALSE){
			print "<font color=\"red\">Error - could not save configuration</font>";
		}
	}
}
	   
	   print "
<br>
<fieldset>
	<legend>
		<h3>".$page_title."</h3>
	</legend>
	<table border=\"0\">
		<tr>
			<td>";
		if ($script_enable==1){
			print "<font color=\"green\"><h3>Script Status: Active</h3></font>";
		}else{
			print "<font color=\"red\"><h3>Script Status: Inactive</h3></font>";
		}
print "		</td>
		</tr>
		<tr>
			<td align=\"left\">
				<form action=\"".$form_submittal_destination."\" method=\"post\">
					<p><input type=\"checkbox\" name=\"script_enable\" value=\"1\" ";
					   if ($script_enable==1){
							print "checked";
					   }
print "					>Enable Entire Script?
					</p><br>
					<b>INFLUXDB SETTINGS</b>
					<p>->IP of Influx DB: <input type=\"text\" name=\"influxdb_host\" value=".$influxdb_host."> ".$influxdb_host_error."</p>
					<p>->PORT of Influx DB: <input type=\"text\" name=\"influxdb_port\" value=".$influxdb_port."> ".$influxdb_port_error."</p>
					<p>->Database to use within Influx DB: <input type=\"text\" name=\"influxdb_name\" value=".$influxdb_name."> ".$influxdb_name_error."</p>
					<p>->User Name of Influx DB: <input type=\"text\" name=\"influxdb_user\" value=".$influxdb_user."> ".$influxdb_user_error." </p>
					<p>->Password of Influx DB: <input type=\"text\" name=\"influxdb_pass\" value=".$influxdb_pass."> ".$influxdb_pass_error."</p>
					<br>
					<b>SNMP SETTINGS</b>
					<p>->IP of PDU to gather SNMP Information from: <input type=\"text\" name=\"PDU_url\" value=".$PDU_url."> ".$PDU_url_error."</p>
					<p>->Name of PDU: <input type=\"text\" name=\"PDU_name\" value=".$PDU_name."> ".$PDU_name_error."</p>
					<p>->SNMP user: <input type=\"text\" name=\"snmp_user\" value=".$snmp_user."> ".$snmp_user_error."</p>
					<p>->SNMP Authorization Password: <input type=\"text\" name=\"auth_pass\" value=".$auth_pass."> ".$auth_pass_error."</p>
					<p>->SNMP Privacy Password: <input type=\"text\" name=\"priv_pass\" value=".$priv_pass."> ".$priv_pass_error."</p>
					<p>->Authorization Protocol: <select name=\"snmp_auth_protocol\">";
					if ($snmp_auth_protocol=="MD5"){
						print "<option value=\"MD5\" selected>MD5</option>
						<option value=\"SHA\">SHA</option>";
					}else if ($snmp_auth_protocol=="SHA"){
						print "<option value=\"MD5\">MD5</option>
						<option value=\"SHA\" selected>SHA</option>";
					}
print "				</select></p>
					<p>->Privacy Protocol: <select name=\"snmp_privacy_protocol\">";
					if ($snmp_privacy_protocol=="AES"){
						print "<option value=\"AES\" selected>AES</option>
						<option value=\"DES\">DES</option>";
					}else if ($snmp_privacy_protocol=="DES"){
						print "<option value=\"AES\">AES</option>
						<option value=\"DES\" selected>DES</option>";
					}
print "				</select></p>
					<center><input type=\"submit\" name=\"submit_server_PDU\" value=\"Submit\" /></center>
				</form>
			</td>
		</tr>
	</table>
</fieldset>";
?>