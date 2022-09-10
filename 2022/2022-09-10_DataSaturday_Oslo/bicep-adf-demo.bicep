param location string = 'WestEurope'

var dataFactoryName = 'adf-bicep-${uniqueString(resourceGroup().id)}'
var keyVaultName = 'kv-oslo-${uniqueString(resourceGroup().id)}'

var keyVaultADFLinkedServiceName = 'KeyVaultLinkedService'
var storageADFLinkedServiceName = 'AzureStorageLinkedService'
var dbADFLinkedServiceName = 'SQLDBLinkedService'

var ADFDatasetBlobfileName = 'DS_Blob'
var ADFDatasetSQLDBName = 'DS_SQLDB'

var ADFDemoPipelineName = 'ADF_Bicep_Demo'

var storageAccountSecretName = 'StorageAccountConnectionString'
var sqlDBSecretName = 'SqlConnectionString'

var existingStorageAccountName = 'azdevstoradfbicep'
var existingSQLServerName = 'azdev-sqlserver-adf-bicep'
var existingSQLDBName = 'AZDB-ADF-BICEP'

// usually these should be parameters!
var exinstingSQLUserName = 'adfbicep'
var existingSQLPassword = 'adfbic1!'

// unified tags for all resources:
var tags = {
  environment: 'demo'
  topic: 'adf <3 bicep'
}

resource StorageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: existingStorageAccountName
}

resource SqlServer 'Microsoft.Sql/servers@2021-05-01-preview' existing = {
  name: existingSQLServerName
}

resource SqlDb 'Microsoft.Sql/servers/databases@2019-06-01-preview' existing = {
  name: '${existingSQLServerName}/${existingSQLDBName}'
}

resource KeyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: keyVaultName
  tags: tags
  location: location
  properties: {
    accessPolicies: [
      {
        objectId: BicepDataFactory.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
        tenantId: subscription().tenantId
      }
    ]
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
  }
}

resource SecretStorageAccountConnectionString 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  name: '${KeyVault.name}/${storageAccountSecretName}'
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${StorageAccount.name};AccountKey=${listKeys(StorageAccount.id, StorageAccount.apiVersion).keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
  }
}

resource SecretSqlDBConnectionString 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  name: '${KeyVault.name}/${sqlDBSecretName}'
  properties: {
    value: 'Server=tcp:${SqlServer.name}${environment().suffixes.sqlServerHostname},1433;Initial Catalog=${SqlDb.name};Persist Security Info=False;User ID=${exinstingSQLUserName};Password=${existingSQLPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
  }
}

resource BicepDataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: dataFactoryName
  tags: tags
  location: location
  identity: {
    type: 'SystemAssigned'
  }
}

resource ADFLinkedServiceKeyVault 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: '${dataFactoryName}/${keyVaultADFLinkedServiceName}'
  dependsOn: [
    BicepDataFactory
  ]
  properties: {
    type: 'AzureKeyVault'
    typeProperties: {
      baseUrl: KeyVault.properties.vaultUri
    }
  }
}

resource ADFLinkedServiceStorageAcc 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: '${dataFactoryName}/${storageADFLinkedServiceName}'
  dependsOn: [
    BicepDataFactory
    KeyVault
    ADFLinkedServiceKeyVault
  ]
  properties: {
    type: 'AzureBlobStorage'
    typeProperties: {
      connectionString: {
        type: 'AzureKeyVaultSecret'
        store: {
          referenceName: keyVaultADFLinkedServiceName
          type: 'LinkedServiceReference'
        }
        secretName: storageAccountSecretName
      }
    }
  }
}

resource ADFLinkedServiceDB 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: '${dataFactoryName}/${dbADFLinkedServiceName}'
  dependsOn: [
    BicepDataFactory
    KeyVault
    ADFLinkedServiceKeyVault
  ]
  properties: {
    type: 'AzureSqlDatabase'
    typeProperties: {
      connectionString: {
        type: 'AzureKeyVaultSecret'
        store: {
          referenceName: keyVaultADFLinkedServiceName
          type: 'LinkedServiceReference'
        }
        secretName: sqlDBSecretName
      }
    }
  }
}

resource ADFDatasetBlobfile 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${dataFactoryName}/${ADFDatasetBlobfileName}'
  dependsOn: [
    BicepDataFactory
    ADFLinkedServiceStorageAcc
  ]
  properties: {
    type: 'DelimitedText'
    linkedServiceName: {
      referenceName: storageADFLinkedServiceName
      type: 'LinkedServiceReference'
    }

    typeProperties: {

      location: {
        type: 'AzureBlobStorageLocation'
        fileName: {
          value: 'moviesDB.csv'
          type: 'AzureBlobStorageLocation'
        }
        container: 'file-in'
      }
      columnDelimiter: ','
      escapeChar: '\\'
      firstRowAsHeader: true
      quoteChar: '"'
    }
    schema: [
      {
        name: 'movie'
        type: 'String'
      }
      {
        name: 'title'
        type: 'String'
      }
      {
        name: 'genres'
        type: 'String'
      }
      {
        name: 'year'
        type: 'String'
      }
      {
        name: 'Rating'
        type: 'String'
      }
      {
        name: 'Rotton Tomato'
        type: 'String'
      }
      {
        name: 'Address'
        type: 'String'
      }
    ]
  }
}

resource ADFDatasetSQLDB 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${dataFactoryName}/${ADFDatasetSQLDBName}'
  dependsOn: [
    BicepDataFactory
    ADFLinkedServiceDB
  ]
  properties: {
    type: 'AzureSqlTable'
    linkedServiceName: {
      referenceName: dbADFLinkedServiceName
      type: 'LinkedServiceReference'
    }
    typeProperties: {
      schema: 'dbo'
      table: 'movie'
    }
  }
}

resource ADFDemoPipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${dataFactoryName}/${ADFDemoPipelineName}'
  dependsOn: [
    BicepDataFactory
    ADFDatasetBlobfile
    ADFDatasetSQLDB
  ]
  properties: {
    activities: [
      {
        name: 'Copy data'
        type: 'Copy'
        typeProperties: {
          source: {
            type: 'DelimitedTextSource'
            storeSettings: {
              type: 'AzureBlobStorageReadSettings'
              recursive: true
              enablePartitionDiscovery: false
            }
          }
            sink: {
              type: 'AzureSqlSink'
              writeBehavior: 'insert'
              sqlWriterUseTableLock: false
              tableOption: 'autoCreate'
              disableMetricsCollection: false
            }
            enableStaging: false
            translator: {
              type: 'TabularTranslator'
              typeConversion: true
              typeConversionSettings: {
                allowDataTruncation: true
                treatBooleanAsNumber: false
              }
            }
          }
          inputs: [
            {
              referenceName: ADFDatasetBlobfileName
              type: 'DatasetReference'
            }
          ]
          outputs: [
            {
               referenceName: ADFDatasetSQLDBName
                type: 'DatasetReference'
            }
          ]
        }
    ]
  }
}

// az deployment group create --resource-group ADF-Bicep --template-file .\bicep-adf-demo.bicep --parameters location='WestEurope'
