@description('Name of the Azure Compute Gallery.')
param galleryName string

@description('Name of the Image Definition.')
param galleryImageDefinitionName string

@description('Location of the Azure Compute Gallery.')
param location string = resourceGroup().location

resource galleryName_galleryImageDefinition 'Microsoft.Compute/galleries/images@2019-12-01' = {
  name: '${galleryName}/${galleryImageDefinitionName}'
  location: location
  properties: {
    description: 'Custom Image definition'
    osType: 'Linux'
    osState: 'Generalized'
    endOfLifeDate: '2030-01-01'
    identifier: {
      publisher: 'loevencloud'
      offer: 'customImage'
      sku: 'devopsagent'
    }
    recommended: {
      vCPUs: {
        min: 1
        max: 64
      }
      memory: {
        min: 2048
        max: 307720
      }
    }
  }
}
