<#
.SYNOPSIS
   SQLService account password change utility tool
.DESCRIPTION
    PowerShell utility to change password of SQL service account on (n) servers using remoting
.PARAMETER Path
    $servers : List of Server(s) separated by comma
    $AccountName : Name of the account with which SQL service is running and whose password needs to be changed
.EXAMPLE
    cd "E:\Utilities\ServiceAccount";
    .\SQLServiceAccount.ps1 -Servers "s1","s2" -accountName "domain\svcSQLServiceAccountDev"
.NOTES
    Author: r1111111r@gmail.com
    Date : 15/01/2014
    Version : 1.01
    You must be having access to the servers.
    This should be run only from systems having PowerShell V3. Destination servers may have V2/V3.
    # Script should be run on systems having PowerShell V3 installed.
    # Run PowerShell as ADMINISTRATOR.
    # Remoting must be enabled on destination servers using "Enable-PSRemoting -Force"
    # In case of errors, please try running this command on local machine : gwmi win32_bios -comp "server1" where "server1" is the machine for which you get error. This should run fine for utility to proceed.
.INPUTS
    List of servers and account name
    Then password when prompted
.OUTPUTS
    On Screen and file-logging.
    It logs into the directory from which it's invoked/called.
#>

param(
    [cmdletBinding()]
    # Seprate list by commas eg. "ser1","ser2"
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
    [string[]] $Servers,
    # eg. "domain\account"
    [Parameter(Mandatory=$true)] [ValidatePattern("(\w+)\\(\w+)")]
    [string] $AccountName
    )

# Bail-out in case of any error
$ErrorActionPreference = "Stop"

# Generic helper function
function ConvertTo-ScriptBlock
(
    [Parameter(Mandatory=$true)] [ValidateNotNullOrEmpty()]
    [string] $ScriptString
)
{
    $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($ScriptString)
    Return $ScriptBlock
}

function Get-ScriptDirectory
{
    # Look up this script file's path
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

# This function writes the input Msg into the console window
function Log
(
    [string] $Msg = $(throw "Msg parameter not specified!")
    # Define the foreground color in which to log; if not specified, default provided
   ,[string] $Fore = "cyan"
)
{
    Write-Host (Get-Date -format "yyyy-MM-dd hh:mm:ss") $Msg `n`r -fore $Fore
}

Log "Account specified is $accountName"
# Get password from the user and store it as  a "Secure String"
# UserName, Message parameters are available only in V3
$pass = (Get-Credential -UserName $accountName -Message "Enter password for account")
If($pass -eq $null) {Log "Password not specified"; throw}

# get alias name from domain\alias e.g. domain\alias will return alias
$account = ($accountName.Split("\")[1])

$path = (Get-ScriptDirectory)
if(!(Test-Path $path)) {Log "Invalid log path $path" -Fore Red ; throw}

# Checks whether Transcript is in progress
function Test-Transcribing {
    $externalHost = $host.gettype().getproperty("ExternalHost",
        [reflection.bindingflags]"NonPublic,Instance").getvalue($host, @())

    try {
        $externalHost.gettype().getproperty("IsTranscribing",
    [reflection.bindingflags]"NonPublic,Instance").getvalue($externalHost, @())
    } catch {
             Write-Warning "This host does not support transcription."
         }
}

# The function that stops services (including dependent services), changes password & starts them again
function Change-ServiceAccount()
{
    # This is the code to fetch the services for SQL server including SSIS, OLAP
    $services = Get-WmiObject -Class Win32_Service -Filter "DisplayName LIKE '%SQL%'"
    Log "Total SQL services are :  $($services.Count)"
    
    foreach($service in $services)
    {
        Log "Processing service : $($service.Name)"

        # Need services that are run by the account specified
        if($service.StartName -match "$account")
        {
        $serviceName = $service.Name
        Log "Service is running under : $($service.StartName)" -Fore Yellow
                
        Log "Stopping service : $serviceName"
        # Stop All services so that "Dependent Services" are not running
        # It's better and simpler than $service.Stop() as the later does not stop dependent services by default

        Get-Service -Name $serviceName | Stop-Service -Force -Verbose

        Log "Changing password for $serviceName"

        # uint32 Change(DisplayName,PathName,ServiceType,ErrorControl,StartMode,DesktopInteract,StartName,StartPassword,LoadOrderGroup,LoadOrderGroupDependencies,ServiceDependencies);
        $RetCode = $service.Change($null,$null,$null,$null,$null,$null,$null,$pass)

        # Get error message from return code
        $msg = RetCodes -Code ($RetCode.ReturnValue)
        if($RetCode.ReturnValue -ne 0) { throw "Error : $msg" }

        Start-Sleep 2
        Log "Starting service : $serviceName"

        $RetCode = $service.StartService()

        $msg = RetCodes -Code ($RetCode.ReturnValue)
        if($RetCode.ReturnValue -ne 0) { throw "Error : $msg" }
       
        }
        else
        {
            Log "Skipping Service : $($service.Name)" -Fore White
        }
   }
}

# These are the list of return codes of Change() function which changes password
function RetCodes ([int] $Code)
{
    switch ($Code)
    {
        0 { "Success" }
        1 { "Not Supported" }
        2 { "Access Denied"}
        3 { "Dependent Services Running"}
        4 { "Invalid Service Control"}
        5 { "Service Cannot Accept Control"}
        6 { "Service Not Active"}
        7 { "Service Request Timeout"}
        8 { "Unknown Failure"}
        9 { "Path Not Found"}
        10 { "Service Already Running"}
        11 { "Service Database Locked"}
        12 { "Service Dependency Deleted"}
        13 { "Service Dependency Failure"}
        14 { "Service Disabled"}
        15 { "Service Logon Failure"}
        16 { "Service Marked For Deletion"}
        17 { "Service No Thread"}
        18 { "Status Circular Dependency"}
        19 { "Status Duplicate Name"}
        20 { "Status Invalid Name"}
        21 { "Status Invalid Parameter"}
        22 { "Status Invalid Service Account"}
        23 { "Status Service Exists"}
        24 { "Service Already Paused"}
        default {"Invalid return code"}
    }
}

# Make function calls from here
try
{
   # Read local function and make scriptblocks to create them on remote session
   $RetFunction = (Get-Content Function:\RetCodes)
   $RetFunction = "Function RetCodes {" + $RetFunction + "}"
   $RetScriptBlock = (ConvertTo-ScriptBlock -ScriptString $RetFunction)

   $LogFunction = (Get-Content Function:\Log)
   $LogFunction = "Function Log {" + $LogFunction + "}"
   $LogScriptBlock = (ConvertTo-ScriptBlock -ScriptString $LogFunction)

    #Create log file to store execution result
    $StartTime = Get-Date -Format "yyyyMMdd_hhmm"
    $logFile = "$path\ServiceAccount_$StartTime.log"
    Start-Transcript $logFile

 foreach( $server in $servers)
   {
   # Check Server is valid and alive
   Log "Testing Connection to $server"

   If(Test-Connection -ComputerName $server -Quiet)
   {
        Log "Creating Connection to $server"
        $session = New-PSSession -ComputerName $server

        If($session.State -eq "Opened") { Log "Successfully connected to : $server"  -Fore "Yellow"}
    
        # Create function RetCodes in remote session
        Invoke-Command -Session $session -ScriptBlock $RetScriptBlock

        # Create function Log in remote session
        Invoke-Command -Session $session -ScriptBlock $LogScriptBlock

        # Pass local variable to remote session
        Invoke-Command -Session $session -ScriptBlock {param($account)} -ArgumentList $account
        Invoke-Command -Session $session -ScriptBlock {param($pass)} -ArgumentList $pass.GetNetworkCredential().Password

        # Call local function in remote session
        Invoke-Command -Session $session -ScriptBlock ${function:Change-ServiceAccount}
    }
    else
    {
        Log "Server : $server is not valid/available, skipping it" -Fore "Red"
    }
   }

}

catch 
{ 
    Log "$($Error[0])" -Fore Red
    Log "Please check `"http://msdn.microsoft.com/en-us/library/aa384901(v=vs.85).aspx`" for error details"
    #Start-Process "http://msdn.microsoft.com/en-us/library/aa384901(v=vs.85).aspx" -ErrorAction SilentlyContinue
}

finally
{
    Log "Clearing Sessions" -Fore "Yellow"
    Get-PSSession | Remove-PSSession
    if(Test-Transcribing) { Stop-Transcript }
}
