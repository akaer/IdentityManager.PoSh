function New-Entity {
  [CmdletBinding()]
  Param (
    [parameter(Mandatory = $false, HelpMessage = 'The session to use')]
    [VI.DB.Entities.ISession] $Session = $null,
    [parameter(Mandatory = $true, HelpMessage = 'The tablename of the object to create')]
    [ValidateNotNullOrEmpty()]
    [String] $Type,
    [parameter(Mandatory = $false, HelpMessage = 'The entity properties')]
    [Hashtable] $Properties = @{},
    [parameter(Mandatory = $false, HelpMessage = 'If the unsaved switch is specified the entity will not be automatically saved to the database. Intended for bulk operations.')]
    [switch] $Unsaved = $false
  )

  Begin {
    try {
      # Determine session to use
      $sessionToUse = Get-IdentityManagerSessionToUse -Session $Session
      if ($null -eq $sessionToUse) {
        throw [System.ArgumentNullException] 'Session'
      }
    } catch {
      Resolve-Exception -ExceptionObject $PSitem
    }
  }

  Process {
    try {

      # Create entity
      $src = [VI.DB.Entities.SessionExtensions]::Source($sessionToUse)
      $entity = $src.CreateNewAsync($Type, [VI.DB.Entities.EntityParameters]::new(), $noneToken).GetAwaiter().GetResult()
      $entity = Add-EntityMemberExtensions -Entity $entity

      # Set property values
      foreach($property in $Properties.Keys) {
        Set-EntityColumnValue -Entity $entity -Column $property -Value $Properties[$property]
      }

      # Save entity via UnitOfWork to Database
      if (-Not $Unsaved) {
        $uow = New-UnitOfWork -Session $sessionToUse
        Add-UnitOfWorkEntity -UnitOfWork $uow -Entity $entity
        Save-UnitOfWork -UnitOfWork $uow
      }

      return $entity
    } catch {
      Resolve-Exception -ExceptionObject $PSitem
    }

  }

  End {
  }
}