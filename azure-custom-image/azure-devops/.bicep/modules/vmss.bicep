param location string
param subnetId string
param virtualMachineScaleSetName string
param adminUsername string
param imageDefinitionId string
@secure()
param adminPassword string
var namingInfix = toLower(substring(virtualMachineScaleSetName, 0, 9))


resource vmSS 'Microsoft.Compute/virtualMachineScaleSets@2022-11-01' = {
  name: virtualMachineScaleSetName
  location: location
  sku: {
    name: 'Standard_D2_v2'
    tier: 'Standard'
    capacity: 2
  }
  properties: {
    singlePlacementGroup: true
    overprovision: true
    constrainedMaximumCapacity: true
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      storageProfile: {
        imageReference: {
          id: imageDefinitionId
        }
      }
      osProfile: {
        computerNamePrefix: namingInfix
        adminUsername: adminUsername
        adminPassword: adminPassword
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'nic1'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: '${virtualMachineScaleSetName}-ip1'
                  properties: {
                    subnet: {
                      id: subnetId
                    }
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}
