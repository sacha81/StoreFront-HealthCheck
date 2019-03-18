#==============================================================================================
# Created on: 06.2016 Version: 0.3
# Created by: Sacha Thomet sachathomet.ch
# File name: StoreFront-HealthCheck.ps1
#
# Description: This script checks a Citrix StoreFront 
# It generates a HTML output File which will be sent as Email.
#
# tested on StoreFront 3.5
#
# Prerequisite: None, must run on a StoreFront server in the first version
#
# Autor-internal: 
# Command to find out what are possibilities: 
# Get-Command *-STF* -Type Cmdlet | Sort-Object -Property Module | Select-Object -Property Name,Module | Format-Table -AutoSize
#
# Call by : Manual or by Scheduled Task, e.g. once a day
#=========== History ===========================================================================
# Version 0.1
# Initial Version
# - Added Check of Services: CitrixCredentialWalletSvC CitrixPeerResolutionSvC 
# Version 0.3
# Initial Version
# - Added Check of Services: WWWService
# - Add Check's in deployment: URLReachable LastSourceServer LastSyncStatus LastSyncTime 
#===============================================================================================

#==============================================================================================
if ((Get-PSSnapin "Citrix.*" -EA silentlycontinue) -eq $null) {
try { Add-PSSnapin Citrix.* -ErrorAction Stop }
catch { write-error "Error Get-PSSnapin Citrix.* Powershell snapin"; Return }
}
& "C:\Program Files\Citrix\Receiver StoreFront\Scripts\ImportModules.ps1"
# Change the below variables to suit your environment
#==============================================================================================
# Information about your Email infrastructure:      -------------------------------------------
# E-mail report details
# E-mail report details
$emailFrom = "email@company.ch"
$emailTo = "citrix@company.ch"#,"sacha.thomet@appcloud.ch"
$smtpServer = "mailrelay.company.ch"
$emailSubjectStart = "StoreFront Farm Report" 
$mailprio = "High"
$PerformSendMail = "no"
# 
#Don't change below here if you don't know what you are doing ... 
#==============================================================================================

$currentDir = Split-Path $MyInvocation.MyCommand.Path
$logfile = Join-Path $currentDir ("StorefrontHealthCheck.log")
$resultsHTM = Join-Path $currentDir ("StorefrontReport.htm")
$errorsHTM = Join-Path $currentDir ("StorefrontHealthCheckErrors.htm") 

#Header for Table 1 "DeploymentCheck Get-STFDeployment""
$DeploymentFirstHeaderName = "SiteId"
$DeploymentHeaderName = "HostbaseUrl", "URLReachable", "LastSourceServer","LastSyncStatus","LastSyncTime"
$DeploymentWidths = "4", "4", "4", "4", "4","4"
$DeploymentTableWidth  = 800

#Header for Table 2 "Clustermembers"
$ClusterMemberFirstFarmheaderName = "StoreFrontServer"
$ClusterMemberHeaderNames = "CitrixCredentialWalletSvC", "CitrixPeerResolutionSvC","WWWService","CFreespace","DFreespace","AvgCPU","MemUsg","EventsLogLast24h"
$ClusterMemberWidths = "4", "4", "4", "4", "4", "4", "4"
$ClusterMemberTablewidth  = 800


#==============================================================================================
#log function
function LogMe() {
Param(
[parameter(Mandatory = $true, ValueFromPipeline = $true)] $logEntry,
[switch]$display,
[switch]$error,
[switch]$warning,
[switch]$progress
)

if ($error) {
$logEntry = "[ERROR] $logEntry" ; Write-Host "$logEntry" -Foregroundcolor Red}
elseif ($warning) {
Write-Warning "$logEntry" ; $logEntry = "[WARNING] $logEntry"}
elseif ($progress) {
Write-Host "$logEntry" -Foregroundcolor Green}
elseif ($display) {
Write-Host "$logEntry" }

#$logEntry = ((Get-Date -uformat "%D %T") + " - " + $logEntry)
$logEntry | Out-File $logFile -Append
}
#==============================================================================================
function Ping([string]$hostname, [int]$timeout = 200) {
$ping = new-object System.Net.NetworkInformation.Ping #creates a ping object
try {
$result = $ping.send($hostname, $timeout).Status.ToString()
} catch {
$result = "Failure"
}
return $result
}
#==============================================================================================
# The function will check the processor counter and check for the CPU usage. Takes an average CPU usage for 5 seconds. It check the current CPU usage for 5 secs.
Function CheckCpuUsage() 
{ 
	param ($hostname)
	Try { $CpuUsage=(get-counter -ComputerName $hostname -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 5 -ErrorAction Stop | select -ExpandProperty countersamples | select -ExpandProperty cookedvalue | Measure-Object -Average).average
   	$CpuUsage = "{0:N1}" -f $CpuUsage; return $CpuUsage
	} Catch { "Error returned while checking the CPU usage. Perfmon Counters may be fault" | LogMe -error; return 101 } 
}
#============================================================================================== 
# The function check the memory usage and report the usage value in percentage
Function CheckMemoryUsage() 
{ 
	param ($hostname)
   Try 
	{   $SystemInfo = (Get-WmiObject -computername $hostname -Class Win32_OperatingSystem -ErrorAction Stop | Select-Object TotalVisibleMemorySize, FreePhysicalMemory)
   	$TotalRAM = $SystemInfo.TotalVisibleMemorySize/1MB 
   	$FreeRAM = $SystemInfo.FreePhysicalMemory/1MB 
   	$UsedRAM = $TotalRAM - $FreeRAM 
   	$RAMPercentUsed = ($UsedRAM / $TotalRAM) * 100 
   	$RAMPercentUsed = "{0:N0}" -f $RAMPercentUsed
   	return $RAMPercentUsed
	} Catch { "Error returned while checking the Memory usage. Perfmon Counters may be fault" | LogMe -error; return 101 } 
}
#==============================================================================================
Function writeHtmlHeader
{
param($title, $fileName)
$date = ( Get-Date -format R)
$head = @"
<html>
<head>
<meta http-equiv='Content-Type' content='text/html; charset=iso-8859-1'>
<title>$title</title>
<STYLE TYPE="text/css">
<!--
td {
font-family: Tahoma;
font-size: 11px;
border-top: 1px solid #999999;
border-right: 1px solid #999999;
border-bottom: 1px solid #999999;
border-left: 1px solid #999999;
padding-top: 0px;
padding-right: 0px;
padding-bottom: 0px;
padding-left: 0px;
overflow: hidden;
}
body {
margin-left: 5px;
margin-top: 5px;
margin-right: 0px;
margin-bottom: 10px;
table {
table-layout:fixed; 
border: thin solid #000000;
}
-->
</style>
</head>
<body>
<table width='1200'>
<tr bgcolor='#CCCCCC'>
<td colspan='7' height='48' align='center' valign="middle">
<font face='tahoma' color='#003399' size='4'>
<strong>$title - $date</strong></font>
</td>
</tr>
</table>
"@
$head | Out-File $fileName
}
# ==============================================================================================
Function writeTableHeader
{
param($fileName, $firstheaderName, $headerNames, $headerWidths, $tablewidth)
$tableHeader = @"
<table width='$tablewidth'><tbody>
<tr bgcolor=#CCCCCC>
<td width='6%' align='center'><strong>$firstheaderName</strong></td>
"@
$i = 0
while ($i -lt $headerNames.count) {
$headerName = $headerNames[$i]
$headerWidth = $headerWidths[$i]
$tableHeader += "<td width='" + $headerWidth + "%' align='center'><strong>$headerName</strong></td>"
$i++
}
$tableHeader += "</tr>"
$tableHeader | Out-File $fileName -append
}
# ==============================================================================================
Function writeTableFooter
{
param($fileName)
"</table><br/>"| Out-File $fileName -append
}
#==============================================================================================
Function writeData
{
param($data, $fileName, $headerNames)

$data.Keys | sort | foreach {
$tableEntry += "<tr>"
$computerName = $_
$tableEntry += ("<td bgcolor='#CCCCCC' align=center><font color='#003399'>$computerName</font></td>")
#$data.$_.Keys | foreach {
$headerNames | foreach {
#"$computerName : $_" | LogMe -display
try {
if ($data.$computerName.$_[0] -eq "SUCCESS") { $bgcolor = "#387C44"; $fontColor = "#FFFFFF" }
elseif ($data.$computerName.$_[0] -eq "WARNING") { $bgcolor = "#FF7700"; $fontColor = "#FFFFFF" }
elseif ($data.$computerName.$_[0] -eq "ERROR") { $bgcolor = "#FF0000"; $fontColor = "#FFFFFF" }
else { $bgcolor = "#CCCCCC"; $fontColor = "#003399" }
$testResult = $data.$computerName.$_[1]
}
catch {
$bgcolor = "#CCCCCC"; $fontColor = "#003399"
$testResult = ""
}

$tableEntry += ("<td bgcolor='" + $bgcolor + "' align=center><font color='" + $fontColor + "'>$testResult</font></td>")
}

$tableEntry += "</tr>"


}

$tableEntry | Out-File $fileName -append
}
# ==============================================================================================
Function writeHtmlFooter
{
param($fileName)
@"
<table>
<table width='1200'>
<tr bgcolor='#CCCCCC'>
<td colspan='7' height='25' align='left'>
<br>
<font face='courier' color='#000000' size='2'><strong>Retry Threshold =</strong></font><font color='#003399' face='courier' size='2'> $retrythresholdWarning<tr></font><br>
<tr bgcolor='#CCCCCC'>
</td>
</tr>
<tr bgcolor='#CCCCCC'>
</tr>
</table>
</body>
</html>
"@ | Out-File $FileName -append
}


function DeploymentCheck {
# =======  Check ====================================================================
"Read some Deployment Parameters" | LogMe -display -progress
" " | LogMe -display -progress

$global:DeploymentResults = @{}
$STFDeployment = Get-STFDeployment

$global:DeploymentSiteId = $STFDeployment.SiteId 
"StoreFront Deployment SiteId: $global:DeploymentSiteId" | LogMe -display -progress

$STFDeploymenttests = @{}

$DeploymentHostbaseUrl = $STFDeployment | %{ $_.HostbaseUrl}
$STFDeploymenttests.HostbaseUrl = "NEUTRAL", $DeploymentHostbaseUrl
"StoreFront HostbaseUrl: $DeploymentHostbaseUrl" | LogMe -display -progress

#HTTP Check
# => currently not working
#   $HTTP_Request = [System.Net.WebRequest]::Create($DeploymentHostbaseUrl)
#   $httpstatus = $HTTP_Request.HaveResponse
#   $httpstatus = $HTTP_Request.GetResponse() | select StatusCode
#   $httpstatus.StatusCode

#Edit by JKU

#by Alain Assaf to enable TLS 1.2 instead 1.0 - if you use TLS1.0 remove next line
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$httpstatus = (Invoke-WebRequest -Uri $DeploymentHostbaseUrl)

if ($httpstatus.StatusDescription -ne "OK") { $STFDeploymenttests.URLReachable = "ERROR", $httpstatus.StatusCode }
else { $STFDeploymenttests.URLReachable = "SUCCESS", $httpstatus.StatusCode}`


#ReplicationChecks (Registry)
$ConfigurationReplicationSource = (Get-ItemProperty  HKLM:\SOFTWARE\Citrix\DeliveryServices\ConfigurationReplication -Name LastSourceServer).LastSourceServer
$syncsctate = (Get-ItemProperty  HKLM:\SOFTWARE\Citrix\DeliveryServices\ConfigurationReplication -Name LastUpdateStatus).LastUpdateStatus
$endsyncdate = (Get-ItemProperty  HKLM:\SOFTWARE\Citrix\DeliveryServices\ConfigurationReplication -Name LastEndTime).LastEndTime

$STFDeploymenttests.LastSourceServer = "NEUTRAL", $ConfigurationReplicationSource
if ($syncsctate -ne "Complete") { $STFDeploymenttests.LastSyncStatus = "ERROR", $syncsctate }
else { $STFDeploymenttests.LastSyncStatus = "SUCCESS", $syncsctate}
$STFDeploymenttests.LastSyncTime = "NEUTRAL", $endsyncdate



$global:DeploymentResults.$global:DeploymentSiteId = $STFDeploymenttests
}


function ClusterMemberCheck {
# =======  Check ====================================================================
"Read some Deployment Parameters" | LogMe -display -progress
" " | LogMe -display -progress

$global:ClusterMemberResults = @{}
$Clustermembers = Get-DSClusterMembersName
$hostnames = $clustermembers | %{ $_.Hostnames }

foreach($STFServerName in $hostnames){
$ClusterMembertests = @{}

$STFServerName
"StoreFront-Server: $STFServerName " | LogMe -display -progress


# Ping server 
$result = Ping $STFServerName  100
"Ping: $result" | LogMe -display -progress
if ($result -ne "SUCCESS") { $ClusterMembertests.Ping = "ERROR", $result }
else { $ClusterMembertests.Ping = "SUCCESS", $result 

# Check services
		if ((Get-Service -Name "Citrix Credential Wallet" -ComputerName $STFServerName).Status -Match "Running") {
			"CitrixCredentialWalletSvC running..." | LogMe
			$ClusterMembertests.CitrixCredentialWalletSvC = "SUCCESS", "Success"
		} else {
			"CitrixCredentialWalletSvC service stopped"  | LogMe -display -error
			$ClusterMembertests.CitrixCredentialWalletSvC = "ERROR", "Error"
		}
			
		if ((Get-Service -Name "Citrix Peer Resolution Service" -ComputerName $STFServerName).Status -Match "Running") {
			"Citrix Peer Resolution Service running..." | LogMe
			$ClusterMembertests.CitrixPeerResolutionSvC = "SUCCESS","Success"
		} else {
			"Citrix Peer Resolution Service service stopped"  | LogMe -display -error
			$ClusterMembertests.CitrixPeerResolutionSvC = "ERROR","Error"
		}


			if ((Get-Service -Name "W3SVC" -ComputerName $STFServerName).Status -Match "Running") {
			"World Wide Web Publishing Service service running..." | LogMe
			$ClusterMembertests.WWWService = "SUCCESS","Success"
		} else {
			"CWorld Wide Web Publishing Service stopped"  | LogMe -display -error
			$ClusterMembertests.WWWService = "ERROR","Error"
		}




		#==============================================================================================
		#               CHECK CPU AND MEMORY USAGE 
		#==============================================================================================

       # Check the AvgCPU value for 5 seconds
       $AvgCPUval = CheckCpuUsage ($STFServerName)
		if( [int] $AvgCPUval -lt 75) { "CPU usage is normal [ $AvgCPUval % ]" | LogMe -display; $ClusterMembertests.AvgCPU = "SUCCESS", "$AvgCPUval %" }
		elseif([int] $AvgCPUval -lt 85) { "CPU usage is medium [ $AvgCPUval % ]" | LogMe -warning; $ClusterMembertests.AvgCPU = "WARNING", "$AvgCPUval %" }   	
		elseif([int] $AvgCPUval -lt 95) { "CPU usage is high [ $AvgCPUval % ]" | LogMe -error; $ClusterMembertests.AvgCPU = "ERROR", "$AvgCPUval %" }
		elseif([int] $AvgCPUval -eq 101) { "CPU usage test failed" | LogMe -error; $ClusterMembertests.AvgCPU = "ERROR", "Err" }
       else { "CPU usage is Critical [ $AvgCPUval % ]" | LogMe -error; $ClusterMembertests.AvgCPU = "ERROR", "$AvgCPUval %" }   
		$AvgCPUval = 0

       # Check the Physical Memory usage       
       $UsedMemory = CheckMemoryUsage ($STFServerName)
       if( [int] $UsedMemory -lt 75) { "Memory usage is normal [ $UsedMemory % ]" | LogMe -display; $ClusterMembertests.MemUsg = "SUCCESS", "$UsedMemory %" }
		elseif([int] $UsedMemory -lt 85) { "Memory usage is medium [ $UsedMemory % ]" | LogMe -warning; $ClusterMembertests.MemUsg = "WARNING", "$UsedMemory %" }   	
		elseif([int] $UsedMemory -lt 95) { "Memory usage is high [ $UsedMemory % ]" | LogMe -error; $ClusterMembertests.MemUsg = "ERROR", "$UsedMemory %" }
		elseif([int] $UsedMemory -eq 101) { "Memory usage test failed" | LogMe -error; $ClusterMembertests.MemUsg = "ERROR", "Err" }
       else { "Memory usage is Critical [ $UsedMemory % ]" | LogMe -error; $ClusterMembertests.MemUsg = "ERROR", "$UsedMemory %" }   
		$UsedMemory = 0  

       # Check C Disk Usage 
		$ClusterMembertests.CFreespace = "NEUTRAL", "N/A" 
       $HardDisk = Get-WmiObject Win32_LogicalDisk -ComputerName $STFServerName -Filter "DeviceID='C:'" | Select-Object Size,FreeSpace 
       $DiskTotalSize = $HardDisk.Size 
       $DiskFreeSpace = $HardDisk.FreeSpace 
       $frSpace=[Math]::Round(($DiskFreeSpace/1073741824),2)

       $PercentageDS = (($DiskFreeSpace / $DiskTotalSize ) * 100); $PercentageDS = "{0:N2}" -f $PercentageDS 

       If ( [int] $PercentageDS -gt 15) { "Disk Free is normal [ $PercentageDS % ]" | LogMe -display; $ClusterMembertests.CFreespace = "SUCCESS", "$frSpace GB" } 
		ElseIf ([int] $PercentageDS -lt 15) { "Disk Free is Low [ $PercentageDS % ]" | LogMe -warning; $ClusterMembertests.CFreespace = "WARNING", "$frSpace GB" }     
		ElseIf ([int] $PercentageDS -lt 5) { "Disk Free is Critical [ $PercentageDS % ]" | LogMe -error; $ClusterMembertests.CFreespace = "ERROR", "$frSpace GB" } 
		ElseIf ([int] $PercentageDS -eq 0) { "Disk Free test failed" | LogMe -error; $ClusterMembertests.CFreespace = "ERROR", "Err" } 
       Else { "Disk Free is Critical [ $PercentageDS % ]" | LogMe -error; $ClusterMembertests.CFreespace = "ERROR", "$frSpace GB" }   
       $PercentageDS = 0     


		 # Check D Disk Usage 
		$ClusterMembertests.DFreespace = "NEUTRAL", "N/A" 
       $HardDisk = Get-WmiObject Win32_LogicalDisk -ComputerName $STFServerName -Filter "DeviceID='D:'" | Select-Object Size,FreeSpace 
       $DiskTotalSize = $HardDisk.Size 
       $DiskFreeSpace = $HardDisk.FreeSpace 
       $frSpace=[Math]::Round(($DiskFreeSpace/1073741824),2)

       $PercentageDS = (($DiskFreeSpace / $DiskTotalSize ) * 100); $PercentageDS = "{0:N2}" -f $PercentageDS 

       If ( [int] $PercentageDS -gt 15) { "Disk Free is normal [ $PercentageDS % ]" | LogMe -display; $ClusterMembertests.DFreespace = "SUCCESS", "$frSpace GB" } 
		ElseIf ([int] $PercentageDS -lt 15) { "Disk Free is Low [ $PercentageDS % ]" | LogMe -warning; $ClusterMembertests.DFreespace = "WARNING", "$frSpace GB" }     
		ElseIf ([int] $PercentageDS -lt 5) { "Disk Free is Critical [ $PercentageDS % ]" | LogMe -error; $ClusterMembertests.DFreespace = "ERROR", "$frSpace GB" } 
		ElseIf ([int] $PercentageDS -eq 0) { "Disk Free test failed" | LogMe -error; $ClusterMembertests.DFreespace = "ERROR", "Err" } 
       Else { "Disk Free is Critical [ $PercentageDS % ]" | LogMe -error; $ClusterMembertests.DFreespace = "ERROR", "$frSpace GB" }   
       $PercentageDS = 0     
		
		#==============================================================================================
		#               CHECK EventLog Last 24 h
		#==============================================================================================
		$LogEventsLast24 = ""
		$LogEventsLast24 = Invoke-Command -ComputerName $STFServerName -ScriptBlock {Get-EventLog 'Citrix Delivery Services' -After (Get-Date).AddHours(-24)}
		$ClusterMembertests.EventsLogLast24h = "NEUTRAL", $LogEventsLast24.Count  

			
		
	}


$global:ClusterMemberResults.$STFServerName = $ClusterMembertests
}
}


#==============================================================================================
#HTML function
function WriteHTML() {

# ======= Write all results to an html file =================================================
Write-Host ("Saving results to html report: " + $resultsHTM)
writeHtmlHeader "StoreFront  Report " $resultsHTM

writeTableHeader $resultsHTM $DeploymentFirstHeaderName $DeploymentHeaderName $DeploymentWidths $DeploymentTableWidth
$global:DeploymentResults | sort-object -property SiteId | % { writeData $DeploymentResults $resultsHTM $DeploymentHeaderName}
writeTableFooter $resultsHTM


writeTableHeader $resultsHTM $ClusterMemberFirstFarmheaderName $ClusterMemberHeaderNames $ClusterMemberWidths $ClusterMemberTablewidth
$global:DeploymentResults | sort-object -property STFServerName | % { writeData $ClusterMemberResults $resultsHTM $ClusterMemberHeaderNames}
writeTableFooter $resultsHTM


writeHtmlFooter $resultsHTM
#send email
$emailSubject = ("$emailSubjectStart - StoreFront - " + (Get-Date -format R))
$global:mailMessageParameters = @{
From = $emailFrom
To = $emailTo
Subject = $emailSubject
SmtpServer = $smtpServer
Body = (gc $resultsHTM) | Out-String
Attachment = $resultsHTM
}
}
#==============================================================================================
#Mail function
# Send mail 
function SendMail() {
Send-MailMessage @global:mailMessageParameters -BodyAsHtml -Priority $mailprio
}



#==============================================================================================
# == MAIN SCRIPT ==
#==============================================================================================
$scriptstart = Get-Date
rm $logfile -force -EA SilentlyContinue
"Begin with Citrix StoreFront HealthCheck" | LogMe -display -progress
" " | LogMe -display -progress

DeploymentCheck
ClusterMemberCheck
WriteHTML

if ($PerformSendMail -eq "yes") {
"Initiate send of Email " | LogMe
SendMail
} else {
"send of Email  skipped" | LogMe
}

$scriptend = Get-Date
$scriptruntime =  $scriptend - $scriptstart | select TotalSeconds
$scriptruntimeInSeconds = $scriptruntime.TotalSeconds
#Write-Host $scriptruntime.TotalSeconds
"Script was running for $scriptruntimeInSeconds " | LogMe -display -progress
