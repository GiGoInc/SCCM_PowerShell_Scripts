﻿# Compliance_File_Check_IF_Exists_Discovery.ps1
$PS1File = 'C:\!Powershell\Compliance_Scripts\Compliance_File_Content_Discovery--AutoGenerated.ps1'
'# File Content - Discovery script' | Add-Content $PS1File
'$Path1 = "$env:windir\Sun\Java\Deployment"' | Add-Content $PS1File
'$File2 = "deployment.config"' | Add-Content $PS1File
'$Text2 = "deployment.system.config=file:///C:/Windows/Sun/Java/Deployment/deployment.properties' | Add-Content $PS1File
'deployment.system.config.mandatory=true"' | Add-Content $PS1File
'$FilePath = "$Path1\$File2"' | Add-Content $PS1File
'if ((test-path $FilePath) -eq $true)' | Add-Content $PS1File
'{if ((($Text2 | Measure-Object -character -ignorewhitespace).Characters) -eq ((Get-content $FilePath | Measure-object -character -ignorewhitespace).Characters))' | Add-Content $PS1File
'{write-host "Compliant"}' | Add-Content $PS1File
'else' | Add-Content $PS1File
'{write-host "Not Compliant"}}' | Add-Content $PS1File