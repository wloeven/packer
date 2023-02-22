@description('Name of the Shared Image Gallery.')
param galleryName string
param location string = resourceGroup().location

resource gallery 'Microsoft.Compute/galleries@2019-12-01' = {
  name: galleryName
  location: location
  properties: {
    description: 'LC image gallery'
  }
  tags: {
    owner: 'Loevencloud'
    createdBy: 'Willem Loeven'
  }
}

output galleryName string = galleryName
