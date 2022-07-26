#Requires -Version 3.0

<#
    .SYNOPSIS
        Exports a Task Sequence as an XML file

    .DESCRIPTION 
        Exports a Task Sequence as an XML file as used by ConfigMgr 2007 and older.
        
        ConfigMgr 2012 and above use a different format for the default export via the ConfigMgr console
        which consists of several files and folders compressed into an archive which can also contain copies 
        of the referenced packages. This script creates only a XML file which can only get imported back 
        using the corresponding "Import-TaskSequence.ps1" script.

    .EXAMPLE
        .\Export-TaskSequence.ps1 -Path "%Temp%\Export" -ID "TST00001"
    
        Export a Task Sequence to a subfolder with incrementing suffix.

    .EXAMPLE
        .\Export-TaskSequence.ps1 -Path "%Temp%\Export" -ID "TST00001" -Filename "#ID.xml" -Force
    
        Export a Task Sequence and overwrite the last exported file.

    .EXAMPLE
        .\Export-TaskSequence.ps1 -Path "%Temp%\Export" -ID "TST00001", "TST00002", "TST00003" -NoProgress
    
        Export several Task Sequences without progress information. E.g. as regular backup task.

    .EXAMPLE
        .\Export-TaskSequence.ps1 -Path "%Temp%\Export" -ID "TST00001" -ProviderServer TSTCM01 -SiteCode TST -Credentials (Get-Credential)
        
        Export a Task Sequence using different credentials and Provider server settings

    .LINK
        http://maikkoster.com/
        https://github.com/MaikKoster/ConfigMgr/blob/master/TaskSequence/Export-TaskSequence.ps1

    .NOTES
        Copyright (c) 2016 Maik Koster

        Author:  Maik Koster
        Version: 1.0
        Date:    31.03.2016

        Version History:
            1.0 - 31.03.2016 - Published script
            
#>
[CmdLetBinding(SupportsShouldProcess,DefaultParameterSetName="ID")]
PARAM (
    # Specifies the path for the exported Task Sequence xml file.
    [Parameter(Mandatory, ParameterSetName="ID")]
    [Parameter(Mandatory, ParameterSetName="Name")]
    [Alias("FilePath")]
    [string]$Path,

    # Specifies the template for the filename. 
    # Default is "#ID\#ID.xml", where #ID will be replaced with the PackageID and an incrementing number will be added.
    # Additional options that will be replaced automatically are:
    #     - #ID -> Task Sequence PackageID
    #     - #Name -> Task Sequence Name
    #     - #0, #00, #000, #0000, ... -> incrementing number based on the same name
    # If no incrementing number is specified, the parameter Force need to be set 
    # to overwrite an existing file.
    [string]$Filename = "#ID\#ID_#000.xml",

    # Specifies the Task Sequence ID (PackageID).
    # Use either ID or Name to select the Task Sequence.
    [Parameter(Mandatory, ParameterSetName="ID")]
    [ValidateNotNullOrEmpty()]
    [Alias("PackageID", "TaskSequenceID")]
    [string[]]$ID,

    # Specifies the Task Sequence Name.
    # Use either Name or ID to select the Task Sequence.
    [Parameter(Mandatory, ParameterSetName="Name")]
    [ValidateNotNullOrEmpty()]
    [string[]]$Name,

    # Specifies if secret information (some passwords and product keys) shall be kept in the XML file.
    [switch]$KeepSecretInformation,

    # Overrides the restriction that prevent the command from succeeding.
    # On default, any existing file will not be overwritten.
    [switch]$Force,

    # Enables the Progress output. 
    [switch]$ShowProgress,

    # Specifies if the script should pass through the path to the export file
    [switch]$PassThru,

    # Specifies the ConfigMgr Provider Server name. 
    # If no value is specified, the script assumes to be executed on the Site Server.
    [Alias("SiteServer", "ServerName")]
    [string]$ProviderServer = $env:COMPUTERNAME,

    # Specifies the ConfigMgr provider Site Code. 
    # If no value is specified, the script will evaluate it from the Site Server.
    [string]$SiteCode,

    # Specifies the credentials to connect to the ConfigMgr Provider Server.
    [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty
)

Process {

    ###############################################################################
    # Start Script
    ###############################################################################
    
    # Ensure this isn't processed when dot sourced by e.g. Pester Test trun
    if ($MyInvocation.InvocationName -ne '.') {

        # Create a connection to the ConfigMgr Provider Server
        if (!($ShowProgress.IsPresent)) {Write-Progress -Id 1 -Activity "Exporting Task Sequences .." -Status "Connecting to ConfigMgr ProviderServer" -PercentComplete 0}
        $ConnParams = @{ServerName = $ProviderServer;SiteCode = $SiteCode;}

        if ($PSBoundParameters["Credential"]) {$connParams.Credential = $Credential}
        
        New-CMConnection @ConnParams

        # Prepare parameters for splatting
        $ExportParams = @{Path = $Path; Filename = $Filename}
        if ($KeepSecretInformation.IsPresent) {$ExportParams.KeepSecretInformation = $true}
        if ($Force.IsPresent) {$ExportParams.Force = $true}
        if ($ShowProgress.IsPresent) {$ExportParams.ShowProgress = $true}
        if ($PassThru.IsPresent) {$ExportParams.PassThru = $true}

        # Start export based on parameter set
        $Count = 0        
        switch ($PSCmdLet.ParameterSetName) {
            "ID" {
                    ForEach ($TSID In $ID) {
                        Set-Progress -ShowProgress:($ShowProgress.IsPresent) -Activity "Exporting Task Sequences .." -Status "Processing Task Sequence $TSID .." -TotalSteps $ID.Count -Step $Count
                        Start-Export -ID $TSID @ExportParams
                        $Count++
                    }
                }
            "Name" {
                    Foreach ($TSName In $Name) {
                        Set-Progress -ShowProgress:($ShowProgress.IsPresent) -Activity "Exporting Task Sequences .." -Status "Processing Task Sequence $TSName .." -TotalSteps $Name.Count -Step $Count
                        Start-Export -Name $TSName @ExportParams
                        $Count++
                    }
                }
        }
    }
}

Begin {
Function Test-CMConnection {

    if ( ([string]::IsNullOrWhiteSpace($global:CMProviderServer)) -or 
            ([string]::IsNullOrWhiteSpace($global:CMSiteCode)) -or 
            ([string]::IsNullOrWhiteSpace($global:CMNamespace)) -or 
            ($global:CMSession -eq $null)) {

        New-CMConnection
        $true
    } else {
        $true
    }
}

Function Invoke-CimCommand {

    PARAM(
        # Specifies the Cim based Command that shall be executed
        [Parameter(Mandatory)]
        [scriptblock]$Command
    )

    $RetryCount = 0
    Do {
        $Retry = $false

        Try {
            & $Command
        } Catch {
            if ($_.Exception -ne $null) {
                if (($_.Exception.HResult -eq -2147023169 ) -or ($_.Exception.ErrorData.error_Code -eq 2147944127)) {
                    if ($RetryCount -ge 3) {
                        $Retry = $false
                    } else {
                        $RetryCount += 1
                        $Retry = $true
                        Write-Verbose "CIM/WMI command failed with Error 2147944127 (HRESULT 0x800706bf)."
                        Write-Verbose "Common RPC error, retry on default. Current retry count $RetryCount"
                    }
                } else {
                    throw $_.Exception
                } 
            } else {
                throw 
            }
        }
    } While ($Retry)
}

Function Get-CMInstance {

    [CmdletBinding()]
    PARAM (
        # Specifies the ConfigMgr WMI provider Class Name
        [Parameter(Mandatory)] 
        [ValidateNotNullOrEmpty()]
        [string]$ClassName, 

        # Specifies the Where clause to filter the specified ConfigMgr WMI provider class.
        # If no filter is supplied, all objects will be returned.
        [string]$Filter,

        # Specifies if the lazy properties shall be fetched as well.
        # On default, lazy properties won't be included in the result.
        [switch]$IncludeLazy
    )

    Begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState 
    }

    Process {
        if ([string]::IsNullOrWhiteSpace($ClassName)) { throw "Class is not specified" }

        # Ensure ConfigMgr Provider information is available
        if (Test-CMConnection) {

            if ($Filter.Contains(" JOIN ")) {
                Write-Verbose "Fall back to WMI cmdlets"                
                $WMIParams = @{
                    ComputerName = $global:CMProviderServer;
                    Namespace = $CMNamespace;
                    Class = $ClassName;
                    Filter = $Filter
                }
                if ($global:CMCredential -ne [System.Management.Automation.PSCredential]::Empty) {
                    $WMIParams.Credential = $CMCredential
                }
                Invoke-CimCommand {Get-WmiObject @WMIParams -ErrorAction Stop}
            } else {
                $InstanceParams = @{
                    CimSession = $global:CMSession
                    Namespace = $global:CMNamespace
                    ClassName = $ClassName
                }
                if ($Filter -ne "") {
                    $InstanceParams.Filter = $Filter
                }

                $Result = Invoke-CimCommand {Get-CimInstance @InstanceParams -ErrorAction Stop}

                if ($IncludeLazy.IsPresent) {
                    $Result = Invoke-CimCommand {$Result | Get-CimInstance -ErrorAction Stop}
                }

                $Result
            }
        }
    }
}

Function Get-CMSession {

    [CmdLetBinding()]
    PARAM (
        # Specifies the ComputerName to connect to. 
        [Parameter(Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName = $env:COMPUTERNAME,
            
        # Specifies the credentials to connect to the Provider Server.
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty
    )

    Begin {

        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState 

        $Opt = New-CimSessionOption -Protocol Dcom

        $SessionParams = @{
            ErrorAction = 'Stop'
        }

        if ($PSBoundParameters['Credential']) {
            $SessionParams.Credential = $Credential
        }
    }

    Process {
        # Check if there is an already existing session to the specified computer
        $Session = Get-CimSession | Where-Object { $_.ComputerName -eq $ComputerName} | Select-Object -First 1

        if ($Session -eq $null) {
            
            $SessionParams.ComputerName = $ComputerName

            $WSMan = Test-WSMan -ComputerName $ComputerName -ErrorAction SilentlyContinue

            if (($WSMan -ne $null) -and ($WSMan.ProductVersion -match 'Stack: ([3-9]|[1-9][0-9]+)\.[0-9]+')) {
                try {
                    Write-Verbose -Message "Attempt to connect to $ComputerName using the WSMAN protocol."
                    $Session = New-CimSession @SessionParams
                } catch {
                    Write-Verbose "Unable to connect to $ComputerName using the WSMAN protocol. Test DCOM ..."
                        
                }
            } 

            if ($Session -eq $null) {
                $SessionParams.SessionOption = $Opt
 
                try {
                    Write-Verbose -Message "Attempt to connect to $ComputerName using the DCOM protocol."
                    $Session = New-CimSession @SessionParams
                } catch {
                    Write-Error -Message "Unable to connect to $ComputerName using the WSMAN or DCOM protocol. Verify $ComputerName is online or credentials and try again."
                }
            }
                
            If ($Session -eq $null) {
                $Session = Get-CimSession | Where-Object { $_.ComputerName -eq $ComputerName} | Select-Object -First 1
            }
        }

        Return $Session
    }
}

Function Get-CallerPreference {

    <#
    .Synopsis
        Fetches "Preference" variable values from the caller's scope.
    .DESCRIPTION
        Script module functions do not automatically inherit their caller's variables, but they can be
        obtained through the $PSCmdlet variable in Advanced Functions.  This function is a helper function
        for any script module Advanced Function; by passing in the values of $ExecutionContext.SessionState
        and $PSCmdlet, Get-CallerPreference will set the caller's preference variables locally.
    .PARAMETER Cmdlet
        The $PSCmdlet object from a script module Advanced Function.
    .PARAMETER SessionState
        The $ExecutionContext.SessionState object from a script module Advanced Function.  This is how the
        Get-CallerPreference function sets variables in its callers' scope, even if that caller is in a different
        script module.
    .PARAMETER Name
        Optional array of parameter names to retrieve from the caller's scope.  Default is to retrieve all
        Preference variables as defined in the about_Preference_Variables help file (as of PowerShell 4.0)
        This parameter may also specify names of variables that are not in the about_Preference_Variables
        help file, and the function will retrieve and set those as well.
    .EXAMPLE
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        Imports the default PowerShell preference variables from the caller into the local scope.
    .EXAMPLE
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState -Name 'ErrorActionPreference','SomeOtherVariable'

        Imports only the ErrorActionPreference and SomeOtherVariable variables into the local scope.
    .EXAMPLE
        'ErrorActionPreference','SomeOtherVariable' | Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        Same as Example 2, but sends variable names to the Name parameter via pipeline input.
    .INPUTS
        String
    .OUTPUTS
        None.  This function does not produce pipeline output.
    .LINK
        about_Preference_Variables
    #>

    [CmdletBinding(DefaultParameterSetName = 'AllVariables')]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({ $_.GetType().FullName -eq 'System.Management.Automation.PSScriptCmdlet' })]
        $Cmdlet,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.SessionState]
        $SessionState,

        [Parameter(ParameterSetName = 'Filtered', ValueFromPipeline = $true)]
        [string[]]
        $Name
    )

    Begin {
        $filterHash = @{}
    }
    
    Process {
        if ($null -ne $Name) {
            foreach ($string in $Name) {
                $filterHash[$string] = $true
            }
        }
    }

    End {
        # List of preference variables taken from the about_Preference_Variables help file in PowerShell version 4.0

        $vars = @{
            'ErrorView' = $null
            'FormatEnumerationLimit' = $null
            'LogCommandHealthEvent' = $null
            'LogCommandLifecycleEvent' = $null
            'LogEngineHealthEvent' = $null
            'LogEngineLifecycleEvent' = $null
            'LogProviderHealthEvent' = $null
            'LogProviderLifecycleEvent' = $null
            'MaximumAliasCount' = $null
            'MaximumDriveCount' = $null
            'MaximumErrorCount' = $null
            'MaximumFunctionCount' = $null
            'MaximumHistoryCount' = $null
            'MaximumVariableCount' = $null
            'OFS' = $null
            'OutputEncoding' = $null
            'ProgressPreference' = $null
            'PSDefaultParameterValues' = $null
            'PSEmailServer' = $null
            'PSModuleAutoLoadingPreference' = $null
            'PSSessionApplicationName' = $null
            'PSSessionConfigurationName' = $null
            'PSSessionOption' = $null

            'ErrorActionPreference' = 'ErrorAction'
            'DebugPreference' = 'Debug'
            'ConfirmPreference' = 'Confirm'
            'WhatIfPreference' = 'WhatIf'
            'VerbosePreference' = 'Verbose'
            'WarningPreference' = 'WarningAction'
        }

        foreach ($entry in $vars.GetEnumerator()) {
            if (([string]::IsNullOrEmpty($entry.Value) -or -not $Cmdlet.MyInvocation.BoundParameters.ContainsKey($entry.Value)) -and
                ($PSCmdlet.ParameterSetName -eq 'AllVariables' -or $filterHash.ContainsKey($entry.Name))) {
                $variable = $Cmdlet.SessionState.PSVariable.Get($entry.Key)
                
                if ($null -ne $variable) {
                    if ($SessionState -eq $ExecutionContext.SessionState) {
                        Set-Variable -Scope 1 -Name $variable.Name -Value $variable.Value -Force -Confirm:$false -WhatIf:$false
                    } else {
                        $SessionState.PSVariable.Set($variable.Name, $variable.Value)
                    }
                }
            }
        }

        if ($PSCmdlet.ParameterSetName -eq 'Filtered') {
            foreach ($varName in $filterHash.Keys) {
                if (-not $vars.ContainsKey($varName)) {
                    $variable = $Cmdlet.SessionState.PSVariable.Get($varName)
                
                    if ($null -ne $variable) {
                        if ($SessionState -eq $ExecutionContext.SessionState) {
                            Set-Variable -Scope 1 -Name $variable.Name -Value $variable.Value -Force -Confirm:$false -WhatIf:$false
                        } else {
                            $SessionState.PSVariable.Set($variable.Name, $variable.Value)
                        }
                    }
                }
            }
        }
    } # end
}

Function Invoke-CMMethod {

    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName="ClassName")]
    PARAM (
        # Specifies the ConfigMgr WMI provider Class Name
        # Needs to be supplied for static class methods
        [Parameter(Mandatory,ParameterSetName="ClassName")] 
        [ValidateNotNullOrEmpty()]
        [string]$ClassName,
            
        # Specifies the ConfigMgr WMI provider object
        # Needs to be supplied for instance methods
        [Parameter(Mandatory,ParameterSetName="ClassInstance")] 
        [ValidateNotNullOrEmpty()]
        [object]$ClassInstance,  

        # Specifies the Method Name
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$MethodName,

        # Specifies the Arguments to be supplied to the method.
        # Should be a hashtable with key/name pairs.
        [hashtable]$Arguments,

        # If set, ReturnValue will not be evaluated
        # Usefull if ReturnValue does not indicated successfull execution
        [switch]$SkipValidation
    )

    Begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState 
    }
        
    Process {
        if ($PSCmdlet.ShouldProcess("$CMProviderServer", "Invoke $MethodName")) {  
            # Ensure ConfigMgr Provider information is available
            if (Test-CMConnection) {

                    if ($ClassInstance -ne $null) {
                        $Result = Invoke-CimCommand {Invoke-CimMethod -InputObject $ClassInstance -MethodName $MethodName -Arguments $Arguments -ErrorAction Stop}
                    } else {
                        $Result = Invoke-CimCommand {Invoke-CimMethod -CimSession $global:CMSession -Namespace $CMNamespace -ClassName $ClassName -MethodName $MethodName -Arguments $Arguments  -ErrorAction Stop}
                    }

                    if ((!($SkipValidation.IsPresent)) -and ($Result -ne $null)) {
                        if ($Result.ReturnValue -eq 0) {
                            Write-Verbose "Successfully invoked $MethodName on $CMProviderServer."
                        } else {
                            Write-Verbose "Failed to invoked $MethodName on $CMProviderServer. ReturnValue: $($Result.ReturnValue)"
                        }
                    } 

                Return $Result
            }
        }
    }
}

Function Convert-TaskSequenceToXML {

    [CmdletBinding(SupportsShouldProcess)]
    PARAM (
        # PackageID
        [Parameter(Mandatory)] 
        [ValidateNotNullOrEmpty()]
        $TaskSequence,

        [switch]$KeepSecretInformation
    )

    Begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState 
    }

    Process {
        if ($TaskSequence -ne $null) {
            Write-Verbose "Convert Task Sequence WMI object to xml object."
            $Result = Invoke-CMMethod -ClassName "SMS_TaskSequence" -MethodName "SaveToXml" -Arguments @{TaskSequence=$TaskSequence} -SkipValidation

            if ($Result -ne $null) {
                $TaskSequenceString = $Result.ReturnValue
            }

            if ($KeepSecretInformation.IsPresent) {
                $TaskSequenceXML = [xml]$TaskSequenceString
            } else {
                $Result = Invoke-CMMethod -ClassName "SMS_TaskSequence" -MethodName "ExportXml" -Arguments @{Xml=$TaskSequenceString} -SkipValidation

                if ($Result -ne $null) {
                    $TaskSequenceXML = [xml]($Result.ReturnValue)
                }
            }

            $TaskSequenceXML
        } else {
            Write-Verbose "Task Sequence object not supplied."
        }
    }
}

Function Get-TaskSequencePackage {

    [CmdletBinding(SupportsShouldProcess,DefaultParameterSetName="ID")]
    PARAM (
        # PackageID
        [Parameter(Mandatory,ParameterSetName="ID")] 
        [ValidateNotNullOrEmpty()]
        [string]$ID,

        # PackageName
        [Parameter(Mandatory,ParameterSetName="Name")] 
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Alias("IncludeLazyProperties")]
        [switch]$IncludeLazy

    )
        
    Begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState 
    }

    Process{
        if (!([string]::IsNullOrEmpty($ID))) {
            Write-Verbose "Get Task Sequence Package by PackageID '$ID'."
            Get-CMInstance -ClassName "SMS_TaskSequencePackage" -Filter "PackageID='$ID'" -IncludeLazy:($IncludeLazy.IsPresent)
        } elseif (!([string]::IsNullOrEmpty($Name))) {
            Write-Verbose "Get Task Sequence Package by Name '$Name'."
            Get-CMInstance -ClassName "SMS_TaskSequencePackage" -Filter "Name='$Name'" -IncludeLazy:($IncludeLazy.IsPresent)
        } 
    }
}

Function New-CMConnection {

    [CmdletBinding()]
    PARAM (
        # Specifies the ConfigMgr Provider Server name. 
        # If no value is specified, the script assumes to be executed on the Site Server.
        [Alias("ServerName", "Name")]
        [string]$ProviderServerName = $env:COMPUTERNAME,

        # Specifies the ConfigMgr provider Site Code. 
        # If no value is specified, the script will evaluate it from the Site Server.
        [string]$SiteCode,

        # Specifies the Credentials to connect to the Provider Server.
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty
    )

    Begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState 
    }

    Process {        
        # Get or Create session object to connect to currently provided Providerservername
        # Ensure processing stops if it fails to create a session
        $SessionParams = @{
            ErrorAction = "Stop"
            ComputerName = $ProviderServerName
        }

        if ($PSBoundParameters["Credential"]) {
            $SessionParams.Credential = $Credential
        }
        
        $CMSession = Get-CMSession @SessionParams

        # Get Provider location
        if ($CMSession -ne $null) {
            $ProviderLocation = $null
            if ($SiteCode -eq $null -or $SiteCode -eq "") {
                Write-Verbose "Get provider location for default site on server $ProviderServerName"
                $ProviderLocation = Invoke-CimCommand {Get-CimInstance -CimSession $CMSession -Namespace "root\sms" -ClassName SMS_ProviderLocation -Filter "ProviderForLocalSite = true" -ErrorAction Stop}
            } else {
                Write-Verbose "Get provider location for site $SiteCode on server $ProviderServerName"
                $ProviderLocation = Invoke-CimCommand {Get-CimInstance -CimSession $CMSession -Namespace "root\sms" -ClassName SMS_ProviderLocation -Filter "SiteCode = '$SiteCode'" -ErrorAction Stop}
            }

            if ($ProviderLocation -ne $null) {
                # Split up the namespace path
                $Parts = $ProviderLocation.NamespacePath -split "\\", 4
                Write-Verbose "Provider is located on $($ProviderLocation.Machine) in namespace $($Parts[3])"

                # Set Script variables used by ConfigMgr related functions
                $global:CMProviderServer = $ProviderLocation.Machine
                $global:CMNamespace = $Parts[3]
                $global:CMSiteCode = $ProviderLocation.SiteCode
                $global:CMCredential = $Credential

                # Create and store session if necessary
                if ($global:CMProviderServer -ne $ProviderServerName) {
                    $SessionParams.ComputerName = $global:CMProviderServer
                    $CMSession = Get-CMSession @SessionParams
                }

                if ($CMSession -eq $null) {
                    Throw "Unable to establish CIM session to $global:CMProviderServer"
                } else {
                    $global:CMSession = $CMSession
                }
            } else {
                # Clear global variables
                $global:CMProviderServer = [string]::Empty
                $global:CMNamespace = [string]::Empty
                $global:CMSiteCode = [string]::Empty
                $global:CMCredential = $null

                Throw "Unable to connect to specified provider"
            }
        } else {
            # Clear global variables
            $global:CMProviderServer = [string]::Empty
            $global:CMNamespace = [string]::Empty
            $global:CMSiteCode = [string]::Empty
            $global:CMCredential = $null

            Throw "Unable to create CIM session to $ProviderServerName"
        }
    }
}

Function Get-TaskSequence {

    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName="ID")]
    PARAM (
        # Specifies the Task Sequence PackageID
        [Parameter(Mandatory,ParameterSetName="ID")] 
        [ValidateNotNullOrEmpty()]
        [string]$ID,
            
        # Specifies the Task Sequence Package Name
        [Parameter(Mandatory,ParameterSetName="Name")] 
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        # Specifies the Task Sequence Package
        [Parameter(Mandatory,ParameterSetName="Package")]
        [ValidateNotNullOrEmpty()]
        $TaskSequencePackage,

        # If set, the full result object from method invocation will be returned,
        # rather than the extracted Task Sequence.
        # Use this option if you need to do the evaluation on the result object yourself.
        [switch]$PassThru
    )

    Begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState 
    }

    Process {

        if ($TaskSequencePackage -eq $null) {
            if (!([string]::IsNullOrEmpty($ID))) {
                $TaskSequencePackage = Get-TaskSequencePackage -ID $ID
            } else {
                $TaskSequencePackage = Get-TaskSequencePackage -Name $Name
            }
        }

        if ($TaskSequencePackage -ne $null) {
            Write-Verbose "Get Task Sequence from Task Sequence Package $($TaskSequencePackage.PackageID)"
            $Result = Invoke-CMMethod -ClassName "SMS_TaskSequencePackage" -MethodName "GetSequence" -Arguments @{TaskSequencePackage=$TaskSequencePackage}

            if ($Result -ne $null) {
                if ($Result.ReturnValue -eq 0) {
                    if ($PassThru.IsPresent) {
                        Write-Verbose "Return Result object."
                        $Result
                    } else {
                        Write-Verbose "Return Task Sequence."
                        $TaskSequence = $Result.TaskSequence

                        $TaskSequence
                    }
                } else {
                    Write-Verbose "Failed to execute GetSequence. ReturnValue $($Result.ReturnValue)"
                    if ($PassThru.IsPresent) {
                        $Result
                    } else {
                        $null
                    }
                }
            } else {
                Write-Verbose "Failed to get Task Sequence"
            }
        } else {
            Write-Verbose "TaskSequencePackage not supplied."
        }
    }
}


    Set-StrictMode -Version Latest
    
    # Starts the Export process. 
    # Moved to separate function to properly test the execution using Pester.
    Function Start-Export {
        [CmdLetBinding(SupportsShouldProcess)]
        PARAM(
            # Specifies the path for the exported Task Sequence xml file.
            [Parameter(Mandatory,ParameterSetName="ID")]
            [Parameter(Mandatory,ParameterSetName="Name")]
            [Alias("FilePath")]
            [string]$Path,

            # Specifies the template for the filename. 
            # Default is "#ID\#ID.xml", where #ID will be replaced with the PackageID.
            # Additional options that will be replaced automatically are:
            #     - #ID -> Task Sequence PackageID
            #     - #Name -> Task Sequence Name
            #     - #0, #00, #000, #0000, ... -> incrementing number based on the same name
            # More complex option could be e.g. "#ID\#ID_#000.xml"
            # If no incrementing number is specified, the parameter Force need to be set 
            # to overwrite an existing file.
            [string]$Filename = "#ID\#ID_#000.xml",

            # Specifies the Task Sequence ID (PackageID).
            # Use either ID or Name to select the Task Sequence
            [Parameter(Mandatory,ParameterSetName="ID",ValueFromPipelineByPropertyName)]
            [ValidateNotNullOrEmpty()]
            [Alias("PackageID", "TaskSequenceID")]
            [string]$ID,

            # Specifies the Task Sequence Name.
            # Use either Name or ID to select the Task Sequence
            [Parameter(Mandatory,ParameterSetName="Name",ValueFromPipelineByPropertyName)]
            [ValidateNotNullOrEmpty()]
            [string]$Name,

            # Specifies if secret information (mainly passwords and product keys) shall be kept in the XML file
            [switch]$KeepSecretInformation,

            # Overrides the restriction that prevent the command from succeeding.
            # On default, any existing file will not be overwritten.
            [switch]$Force,

            # Specifies the ID of the parent progress 
            [int]$ParentProgressID = -1,

            # Enables the Progress output. 
            [switch]$ShowProgress,

            # Specifies if the script should pass through the path to the export file
            [switch]$PassThru
        )

        Begin {
            $ProgressParams = @{
                TotalSteps = 6
                ShowProgress = $ShowProgress.IsPresent
            }

            if (($ParentProgressID -ne $null) -and ($ParentProgressID -gt 0)) {
                $ProgressParams.ParentId = $ParentProgressID
                $ProgressParams.Id = $ParentProgressID + 1
            }
        }

        Process {
            # Get Task Sequence Package
            $ProgressParams.Activity = "Exporting Task Sequence $ID$Name"
            Set-Progress @ProgressParams -Status "Getting Task Sequence Package" -Step 1
            if (!([string]::IsNullOrEmpty("ID"))) {
                Write-Verbose "Start Export Process for Task Sequence Package $ID."
                $TaskSequencePackage = Get-TaskSequencePackage -ID $ID -IncludeLazy
            } else {
                Write-Verbose "Start Export Process for Task Sequence Package '$Name'."
                $TaskSequencePackage = Get-TaskSequencePackage -Name $Name -IncludeLazy
            }

            # Get Task Sequence
            if ($TaskSequencePackage -ne $null){
                $ProgressParams.Activity = "Exporting Task Sequence '$($TaskSequencePackage.Name)' ($($TaskSequencePackage.PackageID))"
                #if (!($NoProgress.IsPresent) -and ($ParentProgressID -gt 0)) {Write-Progress -Id $ParentProgressID -Status "Processing Task Sequence $($TaskSequencePackage.Name) ($($TaskSequencePackage.PackageID)) .."}
                Set-Progress @ProgressParams -Status "Getting Task Sequence from Task Sequence Package" -Step 2
                $TaskSequence = Get-TaskSequence -TaskSequencePackage $TaskSequencePackage
            }

            if ($TaskSequence -ne $null) {
                # Convert to xml
                Set-Progress @ProgressParams -Status "Converting Task Sequence to XML" -Step 3
                $TaskSequenceXML = [xml](Convert-TaskSequenceToXML -TaskSequence $TaskSequence -KeepSecretInformation:$KeepSecretInformation)

                if ($TaskSequenceXML -ne $null) {
                    Set-Progress @ProgressParams -Status "Adding Package properties to XML" -Step 4
                    $Result = Add-PackageProperties -TaskSequencePackage $TaskSequencePackage -TaskSequenceXML $TaskSequenceXML
                    Set-Progress @ProgressParams -Status "Saving xml file to $Path" -Step 5

                    $TSFilename = Get-Filename -Path $Path -Filename $Filename -PackageID $TaskSequencePackage.PackageID -PackageName $TaskSequencePackage.Name

                    # Ensure Path exits
                    $FullName = Join-Path -Path $Path -ChildPath $TSFilename
                    $ParentPath = Split-Path $FullName -Parent
                    if (!(Test-path($ParentPath))) { New-Item -ItemType Directory -Force -Path $ParentPath | Out-Null}

                    # Save XML file
                    if ($PSCmdLet.ShouldProcess("Write Task Sequence xml to file '$FullName'.", "Write XML File")) {
                        Write-Verbose "Write Task Sequence xml to file '$Fullname'."
                        if ((Test-Path($FullName)) -and (-not ($Force.IsPresent))) {
                            Write-Warning "File '$Fullname' exists already and Force isn't set. Won't overwrite existing file."
                        } else {
                            $Result.Save($FullName)
                        }
                        Set-Progress @ProgressParams -Status "Done" -Step 6
                    }
                    if ($PassThru.IsPresent) {$FullName}
                }
            }
        }
    }

    # Extends the Task Sequence xml document with some default properties of the Task Sequence Package
    Function Add-PackageProperties {
        [CmdLetBinding(SupportsShouldProcess)]
        PARAM (
            # Specifies the Task Sequence Package. 
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [object]$TaskSequencePackage,

            # Specifies the Task Sequence xml document
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [xml]$TaskSequenceXML
        )

        # Generate a new xml file
        # To ease the job, lets create a string first

        $Output = "<SmsTaskSequencePackage><BootImageID>"
        $Output += $TaskSequencePackage.BootImageID
        $Output += "</BootImageID><Category>"
        $Output += $TaskSequencePackage.Category
        $Output += "</Category><DependentProgram>"
        $Output += $TaskSequencePackage.DependentProgram
        $Output += "</DependentProgram><Description>"
        $Output += $TaskSequencePackage.Description
        $Output += "</Description><Duration>"
        $Output += $TaskSequencePackage.Duration
        $Output += "</Duration><Name>"
        $Output += $TaskSequencePackage.Name
        $Output += "</Name><ProgramFlags>"
        $Output += $TaskSequencePackage.ProgramFlags
        $Output += "</ProgramFlags><SequenceData>"
        $Output += $TaskSequenceXML.sequence.OuterXml
        $Output += "</SequenceData><SourceDate>"
        $Output += $TaskSequencePackage.SourceDate.ToString("yyyy-MM-ddThh:mm:ss")
        $Output += "</SourceDate><SupportedOperatingSystems>"
        #TODO Implement support for SupportedOperatingSystems
        #$Output += $TaskSequencePackageWMI.SupportedOperatingSystems
        $Output += "</SupportedOperatingSystems><IconSize>"
        $Output += $TaskSequencePackage.IconSize
        $Output += "</IconSize></SmsTaskSequencePackage>"

        return [xml]$Output
    }

    # Generates a file name for the Task Sequence xml file
    Function Get-Filename {
        [CmdLetBinding()]
        PARAM(
            # Specifies the path for the exported Task Sequence xml file.
            [string]$Path,

            # Specifies the template for the filename.
            [string]$Filename,

            # Specifies the Task Sequence PackageID
            [string]$PackageID,

            # Specifies the Task Sequence name
            [string]$PackageName
        )

        # Build Filename
        # Replace #ID and #Name
        $TSFilename = $Filename.Replace("#ID", ($PackageID)).Replace("#Name", ($Name))

        # Replace #0... if necessary
        if ($TSFilename.Contains("#0")) {
            # Get amount of 0
            $StartPos = $TSFilename.IndexOf("#0")
            $MaxLength = $TSFilename.Length - $StartPos - 1
            $ZeroCount = 1
            for ($Count = 1; $Count -le $MaxLength; $Count++) {
                $ZeroCount = $Count
                if ($TSFilename.Substring($StartPos+$Count,1) -ne "0") {
                    $ZeroCount--
                    Break
                }
            }

            # Get files that match the pattern
            $Pattern = $TSFilename.Replace($TSFilename.Substring($StartPos,$ZeroCount + 1), "*")
            $TSFiles = @(Get-ChildItem -Path $Path -Filter $Pattern -ErrorAction SilentlyContinue)

            if ($TSFiles -ne $null) {
                $TSFileCount = $TSFiles.Count
            } else {
                $TSFileCount = 0
            }
            $TSFileCount ++

            # Generate Filename
            # escape certain characters for formatting
            $TSFilename = $TSFilename.Replace("0.", "0'.'").Replace("\","'\'").Replace("#0", "0")
            $TSFilename = "{0:$TSFilename}" -f $TSFileCount
        }

        $TSFilename
    }

    # Wraps the Write-Progress CmdLet
    Function Set-Progress {
        [CmdLetBinding()]
        PARAM(
            # Specifies the current ID of the Progress output
            [int]$ID = 1,

            # Specifies the Parent ID of the Progress output
            [int]$ParentID = -1,

            # Specifies the total amount of steps
            [int]$TotalSteps,

            # Specifies the current step
            [int]$Step = 1,

            # Specifies the current status
            [string]$Status,

            # Specifies the current Activity
            [string]$Activity,

            # Specifies if Progress shall be shown
            [bool]$ShowProgress = $False
        )

        if ($ShowProgress) {
            $PercentComplete = (100/$TotalSteps*$Step)
            if ($ParentID -gt 0) {
                Write-Progress -ParentId $ParentID -Id $ID -Status $Status -Activity $Activity -PercentComplete $PercentComplete
            } else {
                Write-Progress -Id $ID -Status $Status -Activity $Activity -PercentComplete $PercentComplete
            }
        }
    }
}