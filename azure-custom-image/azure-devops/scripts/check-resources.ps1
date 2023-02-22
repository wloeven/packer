<#
Check if imagedefinition already exists
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$imageVersion,
    [Parameter()]
    [string]$imageName    
)
Import-Module Az.Accounts -RequiredVersion 2.11.2
Import-Module az.compute -requiredVersion 5.4.0

$imageNameCombined = "$imageName-$imageVersion"
Write-Output "Checking if Image $resourcegroup \ $imageNameCombined exists."
if (Get-AzImage -ImageName $imageNameCombined -ResourceGroupName $resourceGroup) {
    Write-Output "##vso[task.setvariable variable=imageExists]True"
    Write-Output "Image $imageNameCombined already exists, skipping build fase."
} else {
    Write-Output "##vso[task.setvariable variable=imageExists]False"
    Write-Output "Image $imageNameCombined not found, continue with build."
}
