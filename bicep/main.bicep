@description('Name of the resource group')
param rgName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Virtual machine name')
param vmName string

@description('Admin username')
param vmAdminUsername string

@description('SSH public key')
param sshPublicKey string

// Public IP
resource publicIP 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: '${vmName}-pip'
  location: location
  sku: { name: 'Basic' }
  properties: { publicIPAllocationMethod: 'Dynamic' }
}

// Virtual Network with one subnet
resource vnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: '${vmName}-vnet'
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ '10.0.0.0/16' ] }
    subnets: [
      {
        name: 'default'
        properties: { addressPrefix: '10.0.1.0/24' }
      }
    ]
  }
}

// Network Security Group with SSH, HTTP, HTTPS inbound; all outbound
resource nsg 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: '${vmName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-Inbound'
        properties: {
          protocol: 'Tcp'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
        }
      }
      {
        name: 'Allow-HTTP-Inbound'
        properties: {
          protocol: 'Tcp'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1010
        }
      }
      {
        name: 'Allow-HTTPS-Inbound'
        properties: {
          protocol: 'Tcp'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1020
        }
      }
      {
        name: 'Allow-All-Outbound'
        properties: {
          protocol: '*'
          direction: 'Outbound'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
        }
      }
    ]
  }
}

// Network Interface, associated to subnet and NSG
resource nic 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    networkSecurityGroup: { id: nsg.id }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: { id: publicIP.id }
          subnet: { id: vnet.properties.subnets[0].id }
        }
      }
    ]
  }
}

// Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B1s' }
    osProfile: {
      computerName: vmName
      adminUsername: vmAdminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${vmAdminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
    networkProfile: { networkInterfaces: [ { id: nic.id } ] }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: { createOption: 'FromImage' }
    }
  }
}
