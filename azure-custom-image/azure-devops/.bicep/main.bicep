//Parameters
param subscriptionId string
param location string
param owner string
param deploymentResourceGroup string
param imageDefinitionName string
param imageID string
param imageVersion string
param imageGallery string

// Scope of the deployment
targetScope = 'subscription'

// Deploy using modules for generic resource deployments, modules are available in /global/bicep/modules.
module rg_general 'modules/resourcegroup.bicep' = {
  scope: subscription(subscriptionId)
  name: 'Deploy_Resource_group'
  params: {
    resourceGroupName: deploymentResourceGroup
    location: location
    createdBy: 'Azure DevOps'
    owner: owner
  }
}
module sig_general 'modules/computegallery.bicep' = {
  scope: resourceGroup(deploymentResourceGroup)
  name: 'Deploy_image_gallery'
  params: {
    location: location
    galleryName: imageGallery
  }
  dependsOn: [
    rg_general
  ]
}

module sig_definition 'modules/imagedefinition.bicep' = {
  scope: resourceGroup(deploymentResourceGroup)
  name: 'create_image_definition'
  params: {
    location: location
    galleryName: sig_general.outputs.galleryName
    galleryImageDefinitionName: imageDefinitionName
  }
  dependsOn: [
    sig_general
  ]
}

module sig_version 'modules/imageversion.bicep' = {
  scope: resourceGroup(deploymentResourceGroup)
  name: 'create_image_version' 
  params: {
    location: location
    existingGalleryImageDefinitionName: imageDefinitionName
    existingGalleryName: sig_general.outputs.galleryName
    existingManagedImageID: imageID
    galleryImageVersionName: imageVersion
  }
  dependsOn: [
    sig_general
    sig_definition
  ]
}
