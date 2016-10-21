[CmdletBinding()]
param(
    [string]$server,
    [string]$appPoolName,
    [string]$domainUser,
    [string]$domainPass
)

Import-Module "Microsoft.TeamFoundation.DistributedTask.Task.Internal"
Import-Module "Microsoft.TeamFoundation.DistributedTask.Task.Common"

Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
Write-Verbose "Parameter Values"
$PSBoundParameters.Keys | % { Write-HOST "  ${_} = $(if ($_ -eq 'domainPass'){"********"}else{ $PSBoundParameters[$_]})" }
$command = {
    param(
        [string]$appPoolName,
        [string]$domainUser,
        [string]$domainPass
    )
    Import-Module WebAdministration
    Write-Host "Create Application Pool Task: Started"
    $appPoolPath = "IIS:\AppPools\$AppPoolName"
    Write-Host "Checking for application pool: '$appPoolName'"
    if(-Not (Test-Path $appPoolPath)) {
        Write-Host "Creating Application Pool with default settings"
        New-Item –Path $appPoolPath
        Write-Host "Application Pool created."
    } else {
        Write-Host "Application Pool exist."
    }
    Write-Host "Updating Application Pool settings..."
    Set-ItemProperty -Path $appPoolPath -Name managedRuntimeVersion -Value 'v4.0'
    Set-ItemProperty -Path $appPoolPath -Name managedPipelineMode -Value 'Integrated'
    if ([string]::IsNullOrEmpty($domainUser)){
        Write-Host "Running under ApplicationPoolIdentity."
        Set-ItemProperty -Path $appPoolPath -Name ProcessModel -value @{identitytype=4}
    }else{
        Write-Host "Running under $domainUser."
        Set-ItemProperty $appPoolPath -name processModel -value @{userName=$domainUser;password=$domainPass;identitytype=3}
    }
	$ApplicationPoolStatus = Get-WebAppPoolState $appPoolName
    if ($ApplicationPoolStatus.Value -eq "Started")
	{
        Write-Host "Restarting application pool..."
		Stop-WebAppPool -Name $appPoolName
		Start-WebAppPool -Name $appPoolName
	} else {
        Write-Host "Application pool left in stopped state."
    }
    Write-Host "Create Application Pool Task Completed."
}

Invoke-Command -ComputerName $server $command -ArgumentList $appPoolName,$domainUser,$domainPass