@description('Resource Id of the existing Managed Image')
param existingManagedImageID string

@description('Name of the Azure Compute Gallery.')
param existingGalleryName string

@description('Name of the Image Definition.')
param existingGalleryImageDefinitionName string

@description('Name of the Image Version - should follow <MajorVersion>.<MinorVersion>.<Patch>.')
param galleryImageVersionName string

@description('Location of the Azure Compute Gallery.')
param location string = resourceGroup().location

resource existingGalleryName_existingGalleryImageDefinitionName_galleryImageVersion 'Microsoft.Compute/galleries/images/versions@2020-09-30' = {
  name: '${existingGalleryName}/${existingGalleryImageDefinitionName}/${galleryImageVersionName}'
  location: location
  properties: {
    publishingProfile: {
      replicaCount: 1
      targetRegions: [
        {
          name: location
        }
      ]
    }
    storageProfile: {
      source: {
        id: existingManagedImageID
      }
      osDiskImage: {
        hostCaching: 'ReadWrite'
      }
    }
  }
}

output existingGalleryName string = existingGalleryName
output galleryImageVersion string = galleryImageVersionName
output existingGalleryImageDefinitionName string = existingGalleryImageDefinitionName