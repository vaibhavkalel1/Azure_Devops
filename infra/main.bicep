@description('Name of the Ubuntu VM')
param vmName string

@description('Admin username for the VM')
param adminUsername string

@secure()
@description('SSH public key')
param sshPublicKey string

@description('Location for all resources')
param location string

@description('Size of VM')
param vmSize string

@description('OS disk size in GB')
param osDiskSizeGb int

// Virtual network
resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: '${vmName}-vnet'
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ '10.0.0.0/16' ] }
    subnets: [
      {
        name: 'default'
        properties: { addressPrefix: '10.0.0.0/24' }
      }
    ]
  }
}

// Public IP
resource publicIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${vmName}-pip'
  location: location
  sku: { name: 'Basic' }
  properties: { publicIPAllocationMethod: 'Dynamic' }
}

// Network interface
resource nic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: vnet.properties.subnets[0].id }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: { id: publicIP.id }
        }
      }
    ]
  }
}

// Ubuntu Linux VM
resource vm 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: osDiskSizeGb
        managedDisk: { storageAccountType: 'Standard_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [ { id: nic.id } ]
    }
  }
}

// Output the public IP
output publicIPAddress string = publicIP.properties.ipAddress
