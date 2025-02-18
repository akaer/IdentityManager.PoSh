﻿function Get-ImEvent() {
  Param (
    [parameter(Mandatory = $false, HelpMessage = 'The session to use')]
    [ValidateScript({
      try {
        $_.GetType().ImplementedInterfaces.Contains([type]'VI.DB.Entities.ISession')
      }
      catch [System.Management.Automation.PSInvalidCastException] {
        throw [System.Management.Automation.PSInvalidCastException] 'The given value is not a valid session.'
      }
    })]
    $Session = $null,
    [parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, HelpMessage = 'Entity to interact with')]
    [VI.DB.Entities.IEntity] $Entity,
    [parameter(Mandatory = $false, HelpMessage = 'The tablename of the object')]
    [string] $Type,
    [parameter(Mandatory = $false, HelpMessage = 'Load object by UID or XObjectKey')]
    [string] $Identity
  )

  Begin {
    try {
      # Determine session to use
      $sessionToUse = Get-IdentityManagerSessionToUse -Session $Session
      if ($null -eq $sessionToUse) {
        throw [System.ArgumentNullException] 'Session'
      }
      $src = [VI.DB.Entities.SessionExtensions]::Source($sessionToUse)
    } catch {
      Resolve-Exception -ExceptionObject $PSitem
    }
  }

  Process {
    try {

      # Load object by identity
      $Entity = Get-EntityByIdentity -Session $sessionToUse -Type $Type -Identity $Identity -Entity $Entity

      if ($null -ne $Entity.PSObject.Members['Table']) {
        $uid = $Entity.Table.Uid
      } else {
        $metaData = [VI.DB.Entities.SessionExtensions]::MetaData($sessionToUse)
        $tableMetaData = $metaData.GetTableAsync($Entity.Tablename, $noneToken).GetAwaiter().GetResult()
        $uid = $tableMetaData.Uid
      }

      $query = [VI.DB.Entities.Query]::From('QBMEvent').Where("UID_DialogTable = '$uid'").Select('EventName')
      $entityCollection = $src.GetCollectionAsync($query, [VI.DB.Entities.EntityCollectionLoadType]::Slim, $noneToken).GetAwaiter().GetResult()

      ForEach ($e in $entityCollection) {
        $eventName = Get-EntityColumnValue -Entity $e -Column 'EventName'

        $eventName
      }
    } catch {
      Resolve-Exception -ExceptionObject $PSitem
    }
  }

  End {
  }
}