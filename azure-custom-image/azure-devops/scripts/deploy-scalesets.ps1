#Deploy scalesets

[CmdletBinding()]
param (
    [Parameter()]
    [string]$location,
    [Parameter()]
    [string]$templateFile,
    [Parameter()]
    [string]$resourceGroup,
    [Parameter()]
    [string]$imageGallery,
    [Parameter()]
    [string]$imageName
)
import-module az.network -RequiredVersion 5.4.0 -verbose
$vmss = Get-Content -Path "$PSScriptRoot/../parameters/vmscalesets.json" | ConvertFrom-Json

foreach ($set in $vmss) {
    $imageId = $(Get-AzGalleryImageDefinition -ResourceGroupName $resourceGroup -GalleryName $imageGallery -Name $imageName).id
    $subnetId = $(Get-AzVirtualNetwork -Name $($set.scalesets).vnetName | Get-AzVirtualNetworkSubnetConfig -Name $($set.scalesets).subnetName).id

    Write-Output "Deploying $($set.scalesets.name) with imageid`n$imageId`n$subnetId"

    $bicepDeploymentParameters = @{
        location                   = $location
        virtualMachineScaleSetName = $set.scalesets.name
        subnetId                   = $subnetId
        adminUsername              = $set.scalesets.adminUser
        deploymentResourceGroup    = $resourceGroup
        adminPassword              = "WillemLoeven123!!"
        imageDefinitionId          = "$imageId"
    }
    New-AzDeployment -Location $location -TemplateFile $templateFile -TemplateParameterObject $bicepDeploymentParameters -Verbose
}