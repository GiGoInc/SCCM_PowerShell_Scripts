#	$CollName = "Test - Isaac's VMs"
#	$CollID = "SS100176"
#	$File = "E:\Packages\Powershell_Scripts\applist.txt"


#Get current working paths
$CurrentDirectory = split-path $MyInvocation.MyCommand.Path

C:
CD 'C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin'
Import-Module ".\ConfigurationManager.psd1"
Set-Location SS1:
CD SS1:


$File = Get-Content ("$CurrentDirectory\!Direct_PC_addition_to_Device_Collection_PCList.txt")
ForEach ($item in $File)
{
    $CollID = $Item.Split(',')[0]
    $PCName = $Item.Split(',')[1]
    $RES = Get-CMDevice -Name $PCName | Select $_.ResourceID
    $ResourceID = $RES.ResourceID

    $Comm = "Deployment from POWERSHELL - adding $PCName into $CollID via Direct Membership"


    $DeploymentHash = @{
                        CollectionId = $CollID
                        ResourceID = $ResourceID
                        }
    Write-Output "$Comm"
    Add-CMDeviceCollectionDirectMembershipRule @DeploymentHash
    #Add-CMDeviceCollectionDirectMembershipRule -CollectionId SS100642 -ResourceID 16795598
}



<#

#  Start-CMApplicationDeployment PARAMETERS
#  -CollectionName <String>					I.E. - "All Systems"
#  -Name <String>							I.E. - "Adobe Reader 11.07"
#  -AppRequiresApproval	<Boolean>			I.E. - True | False
#  -AvaliableDate <DateTime>				I.E. - YYYY/MM/DD - 2014/07/28  (same format as DeadlineDate)
#  -AvaliableTime <DateTime>				I.E. - HH:MM (24hr) - 13:05  (same format as DeadlineTime)
#  -Comment <String>						I.E. - "Your comment here"
#  -DeadlineDate <DateTime>					I.E. - YYYY/MM/DD - 2014/07/28 (same format as AvaliableDate)
#  -DeadlineTime <DateTime>					I.E. - HH:MM (24hr) - 13:05 (same format as AvaliableTime)
#  -DeployAction <DeployActionType>			I.E. - Install | Uninstall
#  -DeployPurpose <DeployPurposeType>		I.E. - Available | Required
#  -EnableMomAlert <Boolean>				I.E. - True | False
#  -FailParameterValue <Int32>				I.E. - 	
#  -OverrideServiceWindow <Boolean>			I.E. - True | False
#  -PersistOnWriteFilterDevice <Boolean>	I.E. - True/False
#  -PostponeDate <DateTime>					I.E. - YYYY/MM/DD - 2014/07/28 (same format as AvaliableDate)
#  -PostponeTime <DateTime>					I.E. - HH:MM (24hr) - 13:05 (same format as AvaliableTime)
#  -PreDeploy <Boolean>						I.E. - True | False
#  -RaiseMomAlertsOnFailure <Boolean>		I.E. - True | False
#  -RebootOutsideServiceWindow <Boolean>	I.E. - True | False
#  -SendWakeUpPacket <Boolean>				I.E. - True | False
#  -SuccessParameterValue <Int32>			I.E. - 
#  -TimeBaseOn <TimeType>					I.E. - LocalTime | UTC
#  -UseMeteredNetwork <Boolean>				I.E. - True | False
#  -UserNotification <UserNotificationType>	I.E. - DisplayAll | DisplaySoftwareCenterOnly | HideAll
#  -Confirm									I.E. - 
#  -WhatIf									I.E. - CommonParameters

#>