//Parameter set for module
param location string
param owner string
param createdBy string
param resourceGroupName string

//Scope of the module
targetScope = 'subscription'

//Module resources
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: {
    Owner: owner
    Createdby: createdBy
    DeploymentMethod: 'DevOps'
  }
}
output resourceGroupName string = rg.name
output resourceGroupId string = rg.id
