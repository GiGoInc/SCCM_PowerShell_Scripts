﻿# "Enterprise Mode" Remediation Script

try
{
    if ((test-path 'HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main\EnterpriseMode') -ne $true)
    {
        New-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main\EnterpriseMode' -Force
    }
    Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main\EnterpriseMode' -Name SiteList -Type String -Value "http://webserver/sites.xml" -Force
}
Catch
{
    $_.Exception.Message
}