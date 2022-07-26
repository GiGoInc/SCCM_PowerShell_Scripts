﻿C:
CD 'C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin'
Import-Module ".\ConfigurationManager.psd1"
Set-Location SS1:

$Deets = 'Win10 Driver - D15 Dock;\\cmcontent\DriversSource\Win10-D15-Dock', `
         'Win10 Driver - Dell Latitude 5290 2n1 -- A07;\\cmcontent\DriversSource\Win10_Dell_5290--2n1--A07', `
         'Win10 Driver - Dell Latitude 5480 -- A10;\\cmcontent\DriversSource\Win10_Dell_5480--A10', `
         'Win10 Driver - Dell Latitude 5540 -- A03;\\cmcontent\DriversSource\Win10_Dell_5540--A03', `
         'Win10 Driver - Dell Latitude 5580 -- A10;\\cmcontent\DriversSource\Win10_Dell_5580--A10', `
         'Win10 Driver - Dell Latitude 5590 -- A06;\\cmcontent\DriversSource\Win10_Dell_5590--A06', `
         'Win10 Driver - Dell Latitude 7390 -- A09;\\cmcontent\DriversSource\Win10_Dell_Latitude_7390-WIN10-A09', `
         'Win10 Driver - Dell Latitude 7400 -- A02;\\cmcontent\DriversSource\Win10_Dell_Latitude_7400-WIN10-A02', `
         'Win10 Driver - Dell Latitude 7450 All-In-One -- A10;\\cmcontent\DriversSource\Win10_Dell_7450--AIO--A10', `
         'Win10 Driver - Dell Latitude 7470 -- A11;\\cmcontent\DriversSource\Win10_Dell_7470--A11', `
         'Win10 Driver - Dell Latitude 7480 -- A10;\\cmcontent\DriversSource\Win10_Dell_7480--A10', `
         'Win10 Driver - Dell Latitude E5500 -- A02;\\cmcontent\DriversSource\Win10_Dell_Latitude_E5500-WIN10-A02', `
         'Win10 Driver - Dell Latitude E5540 -- A03;\\cmcontent\DriversSource\Win10_Dell_Latitude_E5540-WIN10-A03', `
         'Win10 Driver - Dell Latitude E5550 -- A08;\\cmcontent\DriversSource\Win10_Dell_Latitude_E5550_5550-WIN10-A08', `
         'Win10 Driver - Dell Latitude E5570 -- A15;\\cmcontent\DriversSource\Win10_Dell_Latitude_E5570-WIN10-A15', `
         'Win10 Driver - Dell Latitude E7440 -- A04;\\cmcontent\DriversSource\Win10_Dell_Latitude_E7440-WIN10-A04', `
         'Win10 Driver - Dell Optiplex 7010 -- A01;\\cmcontent\DriversSource\Win10_Dell_Optiplex_7010-A01', `
         'Win10 Driver - Dell Optiplex 7040 -- A13;\\cmcontent\DriversSource\Win10_Dell_7040--A13', `
         'Win10 Driver - Dell Optiplex 7050 -- A10;\\cmcontent\DriversSource\Win10_Dell_7050--A10', `
         'Win10 Driver - Dell Optiplex 7060 -- A04;\\cmcontent\DriversSource\Win10_Dell_7060--A04', `
         'Win10 Driver - Dell Optiplex 7070 -- A00;\\cmcontent\DriversSource\Win10_Dell_Optiplex_7070-A00', `
         'Win10 Driver - Dell Optiplex 9020 -- A05;\\cmcontent\DriversSource\Win10_Dell_Optiplex_9020-WIN10-A05', `
         'Win10 Driver - Dell XPS 13 (9365) -- A10;\\cmcontent\DriversSource\Win10_Dell_9365--A10', `
         'Win10 Driver - Dell XPS 15 (9575) 2n1 -- A05;\\cmcontent\DriversSource\Win10_Dell_9575--2n1--A05', `
         'Win10 Driver - NewLine;\\cmcontent\DriversSource\WIN10-NewLine', `
         'WINPE 10.0 Driver -- A15;\\cmcontent\DriversSource\WINPE10.0-DRIVERS-A15-FYCJR'

ForEach ($Item in $Deets)
{
    $Name = $item.split(';')[0]
    $Path = $item.split(';')[1]
    New-CMPackage -Name $Name -Path $Path
    $PKGID = $(Get-CMPackage -Name $Name).packageID
    Set-CMPackage -Name $Name -EnableBinaryDeltaReplication $True -MulticastAllow $True
    Move-CMObject -FolderPath "SS1:\Package\Driver Packages" -ObjectId $PKGID

    $DPs = 'SCCMPXE1.Domain.Com','SCCMSERVER.Domain.Com','SCCM01.Domain.Com','PXE1.Domain.Com'
    ForEach ($DP in $DPs){Start-CMContentDistribution -PackageId "$PKGID" -DistributionPointName $DP}
}


<#
    $Packages = 'SS1006E4','SS1006E5','SS1006E1','SS1006E6','SS1006E7','SS1006E8','SS1006E9','SS1006EA','SS1006EB','SS1006EC','SS1006ED','SS1006EE','SS1006EF','SS1006F0','SS1006F1','SS1006F2','SS1006F3','SS1006F4','SS1006F5','SS1006F6','SS1006F7','SS1006F8','SS1006F9','SS1006FA','SS1006FB','SS1006FC'
    ForEach ($Package in $Packages)
    {
        # $PKG = Get-CMPackage -Id $Package
        Remove-CMPackage -ID $Package -Force
        "$package"
    }
#>