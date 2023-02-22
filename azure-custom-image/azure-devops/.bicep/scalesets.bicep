param location string
param subnetId string
param virtualMachineScaleSetName string
param adminUsername string
param imageDefinitionId string
param deploymentResourceGroup string
@secure()
param adminPassword string

targetScope = 'subscription'

module vmscaleset 'modules/vmss.bicep' = {
  name: 'Deploy_Scaleset_${virtualMachineScaleSetName}'
  scope: resourceGroup(deploymentResourceGroup)
  params: {
    location: location
    adminPassword: adminPassword
    adminUsername: adminUsername
    imageDefinitionId: imageDefinitionId
    subnetId: subnetId
    virtualMachineScaleSetName: virtualMachineScaleSetName
  }
}
