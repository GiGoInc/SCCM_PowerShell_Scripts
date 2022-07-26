[System.Reflection.Assembly]::LoadFrom((Join-Path (Get-Item $env:SMS_ADMIN_UI_PATH).Parent.FullName "Microsoft.ConfigurationManagement.ApplicationManagement.dll")) | Out-Null
[System.Reflection.Assembly]::LoadFrom((Join-Path (Get-Item $env:SMS_ADMIN_UI_PATH).Parent.FullName "Microsoft.ConfigurationManagement.ApplicationManagement.Extender.dll")) | Out-Null
[System.Reflection.Assembly]::LoadFrom((Join-Path (Get-Item $env:SMS_ADMIN_UI_PATH).Parent.FullName "Microsoft.ConfigurationManagement.ApplicationManagement.MsiInstaller.dll")) | Out-Null
 
$SiteServer = "SCCMSERVER"
$SiteCode = "SS1"
	#$CurrentContentPath = "\\\\<name_of_server_where_the_content_was_stored_previously\\<folder>\\<folder>"
	#$UpdatedContentPath = "\\<name_of_the_server_where_the_content_is_stored_now\<folder>\<folder>"
 
$Applications = Get-WmiObject -ComputerName $SiteServer -Namespace root\SMS\site_$SiteCode -class SMS_Application | Where-Object {$_.IsLatest -eq $True}
$ApplicationCount = $Applications.Count

Write-Host "`n"
Write-Host "INFO: There is a total of $($ApplicationCount) applications`n"

$Applications | ForEach-Object {
    $CheckApplication = [wmi]$_.__PATH
    $CheckApplicationXML = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::DeserializeFromString($CheckApplication.SDMPackageXML,$True)
		##Write-Host -ForegroundColor Yellow "XML = $CheckApplicationXML"
        foreach ($CheckDeploymentType in $CheckApplicationXML.DeploymentTypes)
        {
			#Write-Host "INFO: Current content path for $($_.LocalizedDisplayName):"
			Write-Host "Deployment Title = $($CheckDeploymentType.Title)" -ForegroundColor Green 
			#Write-Host -ForegroundColor Yellow "$($_.LocalizedDisplayName) Rule = $($CheckDeploymentType.Requirements.Rule.Annotation.DisplayName)"
		#	
		#	
        #    $CheckInstaller = $CheckDeploymentType.Requirements
		#		foreach ($Rule in $CheckInstaller.Rule) {
		#			Write-Host -ForegroundColor Yellow "Rule = $($Rule)"
		#		}
	
	
	#$oOperands = Microsoft.ConfigurationManagement.DesiredConfigurationManagement.CustomCollection``1[[Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.RuleExpression]]			
	#$oOperands = Microsoft.ConfigurationManagement.DesiredConfigurationManagement.CustomCollection``1[[Microsoft.SystemsManagementServer.DesiredConfigurationManagement.Expressions.RuleExpression]]	

	#$Rule = $($CheckDeploymentType.Requirements)
				#Write-Host -ForegroundColor Green "$($_.LocalizedDisplayName) Rule = $Rule"				
			
			#Write-Host -ForegroundColor Green "$($_.LocalizedDisplayName) Rule = $($CheckDeploymentType.Requirements.Rule.Title)"			
			##Write-Host -ForegroundColor Yellow "$($_.LocalizedDisplayName) Rules = $($CheckDeploymentType.Requirements.Rules)"
			#Write-Host -ForegroundColor Green "$($_.LocalizedDisplayName) Rules.Rule = $($CheckDeploymentType.Requirements.Rules.Rule)"
			#Write-Host -ForegroundColor Yellow "$($_.LocalizedDisplayName) Requirements = $($CheckDeploymentType.Requirements.Rules.Rule.Annotation.DisplayName.Text)"
			#Write-Host -ForegroundColor Yellow "$($_.LocalizedDisplayName) Requirements = $($CheckDeploymentType.Requirements.Rules.Rule.Annotation.DisplayName.Text)"
			#Write-Host -ForegroundColor Yellow "$($_.LocalizedDisplayName) Requirements = $($CheckDeploymentType.Requirements.Rules.Rule.Annotation.DisplayName.Text)"
	}
}
