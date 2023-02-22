#Deploy infrastructure

[CmdletBinding()]
param (
    [Parameter()]
    [string]$location,
    [Parameter()]
    [string]$templateFile,
    [Parameter()]
    [string]$subscriptionId,
    [Parameter()]
    [string]$resourceGroup,
    [Parameter()]
    [string]$imageDefinitionName,
    [Parameter()]
    [string]$imageVersion,
    [Parameter()]
    [string]$imageName,
    [Parameter()]
    [string]$imageGallery,
    [Parameter()]
    [string]$owner = "willem@willemloeven.nl"    
)

$bicepDeploymentParameters = @{
    subscriptionId          = $subscriptionId
    location                = $location
    owner                   = $owner
    deploymentResourceGroup = $resourceGroup
    imageDefinitionName     = $imageDefinitionName
    imageID                 = $(Get-AzImage -Name "$imageName-$imageVersion").id
    imageVersion            = $imageVersion
    imageGallery            = $imageGallery
}

New-AzDeployment -Location $location -TemplateFile $templateFile -subscriptionid $subscriptionId -TemplateParameterObject $bicepDeploymentParameters -Verbose