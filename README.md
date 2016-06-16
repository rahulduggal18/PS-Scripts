# PS-Scripts

Collection of multiple scripts, utilities and tools under one directory.

## 1. SystemInventory

A Power Shell script/tool that collects critical info about servers and emails the report.

The following information is gathered :

* Computer Information like RAM, OS, Processor (with Pie-Chart)
* Top 10 Running Processes
* List of Shared Folders
* Disk-Info showing disks having Low Disk space (less than 20%,configurable)
* List of Services that are Automatic but Stopped.

The initial source of the script is <i>https://www.simple-talk.com/content/article.aspx?article=1459.</i>

However, this script is <b>optimised using PowerShell remoting </b>, so it gives very good performance. 
Also, it has Error Handling and some other features.

### Future Features   (Please Contribute)

* Currently logged-in users
* Users who have access to servers but are not in our defined TRUST list
* Pending Patches / Windows Updates 
* Color <b><i>Highlight Low-Disk Space</b></i> warnings in email report


### Usage
#### Help
`Get-Help .\SystemsReport.ps1 -Full`

#### Help
Create a file having the list of servers of which report needs to be generated. Enter one server name in one line. See Example file : ServerNames.txt
` .\SystemsReport.ps1 -ConfigPath .\ServerNames.txt`

Also, set the following variables as per environment :

```
#region Variables and Arguments
$fromemail = "youremail@yourcompany.com"
$users = "boss@company.com" # List of users to email this report to (separate by comma)
$server = "yourmailserver.yourcompany.com" #enter SMTP server DNS name / IP address here

$computers = Get-Content $ConfigPath #grab the names of the servers/computers to check from the config file

# Alternatively, set below variable
<b># $Computers = "Server1", "Server2"</b>

# Set free disk space threshold below in percent (default at 20%)
$thresholdspace = 20
[int]$ProccessNumToFetch = 10
$ListOfAttachments = @()
$Report = @()
$CurrentTime = Get-Date
#endregion
```

