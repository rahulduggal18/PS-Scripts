# PowerShell Systems Report
# Example usage: . .\SystemsReport.ps1 .\ServersDEV.txt
# Remember that config is the file containing a list of Server names to get information.

<#
.SYNOPSIS
    PowerShell Systems Report
.DESCRIPTION
    PowerShell Inventory Report to monitor servers
.PARAMETER Path
    $ConfigPath : The path to the the file containing a list of Server names to get information.
.EXAMPLE
    cd "E:\Tools\SystemInventory";
    . .\SystemsReport.ps1 .\ServersDEV.txt
.NOTES
    Author: r1111111r@gmail.com
    You must be having access to the servers for which report is to be gathered.
.INPUTS
    ConfigFilePath containing the list of servers
.OUTPUTS
    Emails Report to the given user
#>

[CmdletBinding()]
param (
[Parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
[ValidateScript({ Test-Path $_ -PathType Leaf })]
[String]$ConfigPath
)
#region Variables and Arguments
$fromemail = "youremail@yourcompany.com"
$users = "boss@company.com" # List of users to email this report to (separate by comma)
$server = "yourmailserver.yourcompany.com" #enter SMTP server DNS name / IP address here

$computers = Get-Content $ConfigPath #grab the names of the servers/computers to check from the config file

# Alternatively, set below variable
# $Computers = "Server1", "Server2"

# Set free disk space threshold below in percent (default at 20%)
$thresholdspace = 20
[int]$ProccessNumToFetch = 10
$ListOfAttachments = @()
$Report = @()
$CurrentTime = Get-Date
#endregion

# Future Features
    ## Currently logged-in people
    ## People who have access to servers but are not in our TRUST list
    ## Pending Patches / Windows Updates
    ## Color Highlight Low-Disk Space warnings in email report

############################################################
#  Functions which are getting called
############################################################

Function Get-DiskInfo ( $thresholdspace = 20) {
    $DiskInfo = Get-WMIObject Win32_LogicalDisk -Filter "DriveType=3" | Where-Object{ ($_.freespace/$_.Size)*100 -lt $thresholdspace} `
    | Select-Object SystemName, Name, @{n='Size (GB)';e={"{0:n2}" -f ($_.size/1gb)}}, @{n='FreeSpace (GB)';e={"{0:n2}" -f ($_.freespace/1gb)}}, @{n='PercentFree';e={"{0:n2}" -f ($_.freespace/$_.size*100)}} | ConvertTo-HTML -fragment | Out-String

    $DiskInfo = $DiskInfo -replace ("<table>","<table border='2' cellspacing='0' cellpadding='7'>")
    return $DiskInfo
}

Function Get-HostUptime {
    $Uptime = Get-WmiObject -Class Win32_OperatingSystem
    $LastBootUpTime = $Uptime.ConvertToDateTime($Uptime.LastBootUpTime)
    $Time = (Get-Date) - $LastBootUpTime
    return '{0:00} Days, {1:00} Hours, {2:00} Minutes, {3:00} Seconds' -f $Time.Days, $Time.Hours, $Time.Minutes, $Time.Seconds
}

Function Get-Processes($ProccessNumToFetch = 10) {
    $TopProcesses = Get-Process  | Sort WS -Descending | Select ProcessName, Id, Description ,ProductVersion, @{Name="Memory Used (MB)"; Expression = {[int]($_.WS/1MB)}} -First $ProccessNumToFetch | ConvertTo-Html -Fragment | Out-String
    $TopProcesses = $TopProcesses -replace ("<table>","<table border='2' cellspacing='0' cellpadding='7'>")
    return $TopProcesses
}

Function Create-PieChart() {
    param([string]$FileName)

    [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")

    #Create our chart object 
    $Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart 
    $Chart.Width = 300
    $Chart.Height = 290 
    $Chart.Left = 10
    $Chart.Top = 10

    #Create a chartarea to draw on and add this to the chart 
    $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
    $Chart.ChartAreas.Add($ChartArea) 
    [void]$Chart.Series.Add("Data") 

    #Add a datapoint for each value specified in the arguments (args) 
    foreach ($value in $args[0]) {
        Write-Host "Now processing chart value: " + $value
        $datapoint = new-object System.Windows.Forms.DataVisualization.Charting.DataPoint(0, $value)
        $datapoint.AxisLabel = "Value" + "(" + $value + " GB)"
        $Chart.Series["Data"].Points.Add($datapoint)
    }

    $Chart.Series["Data"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Pie
    $Chart.Series["Data"]["PieLabelStyle"] = "Outside"
    $Chart.Series["Data"]["PieLineColor"] = "Black"
    $Chart.Series["Data"]["PieDrawingStyle"] = "Concave"
    ($Chart.Series["Data"].Points.FindMaxByValue())["Exploded"] = $true

    #Set the title of the Chart to the current date and time 
    $Title = New-Object System.Windows.Forms.DataVisualization.Charting.Title 
    $Chart.Titles.Add($Title) 
    $Chart.Titles[0].Text = "RAM Usage Chart (Used/Free)"

    #Save the chart to a file
    $Chart.SaveImage($FileName + ".png","png")
}


# Assemble the HTML Header and CSS for our Report
$HTMLHeader = @"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
<html><head><title>My Systems Report</title>
<style type="text/css">
<!--
body {
font-family: Verdana, Geneva, Arial, Helvetica, sans-serif;
}

    #report { width: 835px; }

    table{
    border-collapse: collapse;
    border: none;
    font: 10pt Verdana, Geneva, Arial, Helvetica, sans-serif;
    color: black;
    margin-bottom: 10px;
}

    table td{
    font-size: 12px;
    padding-left: 0px;
    padding-right: 20px;
    text-align: left;
}

    table th {
    font-size: 12px;
    font-weight: bold;
    padding-left: 0px;
    padding-right: 20px;
    text-align: left;
}

h2{ clear: both; font-size: 130%; }

h3{
    clear: both;
    font-size: 115%;
    margin-left: 20px;
    margin-top: 30px;
}

p{ margin-left: 20px; font-size: 12px; }

table.list{ float: left; }

    table.list td:nth-child(1){
    font-weight: bold;
    border-right: 1px grey solid;
    text-align: right;
}

table.list td:nth-child(2){ padding-left: 7px; }
table tr:nth-child(even) td:nth-child(even){ background: #CCCCCC; }
table tr:nth-child(odd) td:nth-child(odd){ background: #F2F2F2; }
table tr:nth-child(even) td:nth-child(odd){ background: #DDDDDD; }
table tr:nth-child(odd) td:nth-child(even){ background: #E5E5E5; }
div.column { width: 320px; float: left; }
div.first{ padding-right: 20px; border-right: 1px  grey solid; }
div.second{ margin-left: 30px; }
table{ margin-left: 20px; }
-->
</style>
</head>
<body>

"@

# Assemble the closing HTML for our report.
$HTMLEnd = @"
</div>
</body>
</html>
"@

############################################################
#  This is the main area from where function calls are made
############################################################
Try
{
foreach ($computer in $computers) {

    Write-Host Creating report for $computer -Fore Green

    # Create a remote connection
    $session = New-PSSession -ComputerName $computer
    If($session.State -eq "Opened") { Write-Host Successfully connected to $computer }
    Else {Write-Host "Could not connect to $computer"; continue;}

    Write-Host "Getting Disk-Info for $computer" -fore Yellow

    $DiskInfo = Invoke-Command -Session $session -ScriptBlock ${function:Get-DiskInfo} -ArgumentList $thresholdspace

    Write-Host "Getting List of Shared Folders on $computer" -fore Yellow
    $SharedFolders = Invoke-Command -Session $session -ScriptBlock { Get-WmiObject Win32_Share -Filter "Type = 0"  | Select-Object Name,Status,Path,Caption  | ConvertTo-HTML -fragment | Out-String }
    $SharedFolders = $SharedFolders -replace ("<table>","<table border='2' cellspacing='0' cellpadding='7'>")

    Write-Host "Getting Memory-Info for $computer" -fore Yellow
    #region System Info
    $OS = Invoke-Command -Session $session -ScriptBlock {(Get-WmiObject Win32_OperatingSystem).Caption}
    $SystemInfo = Invoke-Command -Session $session -ScriptBlock {Get-WmiObject Win32_OperatingSystem | Select-Object Name, TotalVisibleMemorySize, FreePhysicalMemory}
    $TotalRAM = $SystemInfo.TotalVisibleMemorySize/1MB
    $FreeRAM = $SystemInfo.FreePhysicalMemory/1MB
    $UsedRAM = $TotalRAM - $FreeRAM
    $RAMPercentFree = ($FreeRAM / $TotalRAM) * 100
    $TotalRAM = [Math]::Round($TotalRAM, 2)
    $FreeRAM = [Math]::Round($FreeRAM, 2)
    $UsedRAM = [Math]::Round($UsedRAM, 2)
    $RAMPercentFree = [Math]::Round($RAMPercentFree, 2)
    #endregion

    Write-Host "Getting Processor Info of $computer" -fore Yellow
    $ProcessorInfo = Invoke-Command -Session $session -ScriptBlock { Get-WmiObject Win32_Processor | Select-Object Name,NumberOfCores,Caption -Unique  | ConvertTo-HTML -fragment | Out-String }
    $ProcessorInfo = ($ProcessorInfo.Trim()) -replace ("<table>","<table border='2' cellspacing='0' cellpadding='7'>")
    
    Write-Host "Getting Top-processes for $computer" -fore Yellow
    $TopProcesses = Invoke-Command -Session $session -ScriptBlock ${function:Get-Processes} -ArgumentList $ProccessNumToFetch
    

    Write-Host "Getting List of Services that are Automatic but Stopped for $computer" -fore Yellow
    #region Services Report
    $ServicesReport = @()
    $Services = Invoke-Command -Session $session -ScriptBlock {Get-WmiObject -Class Win32_Service -Filter "StartMode = 'Auto' and State = 'Stopped' "}

    foreach ($Service in $Services) {
        $row = New-Object -Type PSObject -Property @{
               Name = $Service.Name
            Status = $Service.State
            StartMode = $Service.StartMode
        }
        
    $ServicesReport += $row
    
    }
    
    $ServicesReport = $ServicesReport | ConvertTo-Html -Fragment | Out-String
    $ServicesReport = $ServicesReport -replace ("<table>","<table border='2' cellspacing='0' cellpadding='7'>")

    #endregion

    # Create the chart using our Chart Function
    Write-Host "Creating Pie-Chart" -fore Yellow
    Create-PieChart -FileName ((Get-Location).Path + "\chart-$computer") $FreeRAM, $UsedRAM
    $ListOfAttachments += "chart-$computer.png"
    #region Uptime
    # Fetch the Uptime of the current system using our Get-HostUptime Function.
    Write-Host "Getting System-Up time for $computer" -fore Yellow
    $SystemUptime = Invoke-Command -Session $session -ScriptBlock ${function:Get-HostUptime}
    #endregion

    Write-Host "Creating HTML report $computer" -fore Yellow
    # Create HTML Report for the current System being looped through
    $CurrentSystemHTML = @"
    <hr noshade size=3 width="100%">
    <div id="report">
    <p><h2>$computer Report</p></h2>
    <h3>System Info</h3>
    <table class="list">
    <tr>
    <td>System Uptime</td>
    <td>$SystemUptime</td>
    </tr>
    <tr>
    <td>OS</td>
    <td>$OS</td>
    </tr>
    <tr>
    <td>Total RAM (GB)</td>
    <td>$TotalRAM</td>
    </tr>
    <tr>
    <td>Free RAM (GB)</td>
    <td>$FreeRAM</td>
    </tr>
    <tr>
    <td>Percent free RAM</td>
    <td>$RAMPercentFree</td>
    </tr>
    </table>

    <IMG SRC="chart-$computer.png" ALT="$computer Chart">

    <h3>Processor Info</h3>
    <table class="normal">$ProcessorInfo</table>
    <br></br>
        
    <h3>Disk Info</h3>
    <p>Drive(s) listed below have less than $thresholdspace % free space. Drives above this threshold will not be listed.</p>
    <table class="normal">$DiskInfo</table>
    <br></br>

    <h3>Shared Folders</h3>
    <p>These are the list of all the folders shared on $computer for shared-type : <b>"Disk Drive"</b> </p>
    <p> This list may not be complete. </p>
    <table class="normal">$SharedFolders</table>
    <br></br>
    
    <div class="first column">
    <h3>System Processes - Top $ProccessNumToFetch Highest Memory Usage</h3>
    <p>The following $ProccessNumToFetch processes are those consuming the highest amount of Working Set (WS) Memory (MB) on $computer</p>
    <table class="normal">$TopProcesses</table>
    </div>
    <div class="second column">
    
    <h3>System Services - Automatic Startup but not Running</h3>
    <p>The following services are those which are set to Automatic startup type, yet are currently not running on $computer</p>
    <table class="normal">
    $ServicesReport
    </table>
    </div>
"@
    # Add the current System HTML Report into the final HTML Report body
    $HTMLMiddle += $CurrentSystemHTML
    
    # Clear sessions to save memory
    Get-PSSession | Remove-PSSession
    }


$CurrentTime = Get-Date -Format ddMMyyyy
# Assemble the final report from all our HTML sections
$HTMLmessage = $HTMLHeader + $HTMLMiddle + $HTMLEnd

# Save the report out to a file in the current path
$HTMLmessage | Out-File ((Get-Location).Path + "\report-$CurrentTime.html") -Force

# Email report out
Write-Host "Sending mail to $users" -fore Yellow
Send-MailMessage -From $fromemail -To $users -Subject "System Report for $computers (Powered By PowerShell)" -Attachments $ListOfAttachments -BodyAsHTML -Body $HTMLmessage -Priority Normal -SmtpServer $server

}
Catch
{
    Write-Host $Error[0].Message -ForegroundColor Red
}
Finally
{
# This is a potentially risky code. It removes all sessions for target computer, which
# may affect other activities that maybe using the server.
 Get-PSSession | Remove-PSSession
}

