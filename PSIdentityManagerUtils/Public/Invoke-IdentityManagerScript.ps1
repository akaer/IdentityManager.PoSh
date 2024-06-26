﻿function Invoke-IdentityManagerScript {
  [CmdletBinding()]
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
    [parameter(Mandatory = $true, HelpMessage = 'The name of the script')]
    [ValidateNotNullOrEmpty()]
    [string] $Name,
    [parameter(Mandatory = $false, HelpMessage = 'The script parameters')]
    [object[]] $Parameters = @()
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
      $scriptEnv = [VI.DB.Entities.SessionExtensions]::Scripts($sessionToUse)
      $scriptClass = $scriptEnv['scripts']
      $scriptRunner = New-Object 'VI.DB.Scripting.ScriptRunner' -ArgumentList @($scriptClass, $sessionToUse)

      # register events
      $registeredEvents = New-Object System.Collections.ArrayList
      $registeredEvents.Add((Register-ObjectEvent -InputObject $scriptRunner.Data -EventName 'Message' -Action { Write-Output $EventArgs.Text })) | Out-Null
      $registeredEvents.Add((Register-ObjectEvent -InputObject $scriptRunner.Data -EventName 'Progress' -Action { Write-Output $EventArgs.Text })) | Out-Null

      $result = $null
      try {
        # run script
        $result = $scriptRunner.Eval($Name, $Parameters)
      }
      finally {
        # unregister events
        $registeredEvents | ForEach-Object { Unregister-Event -SubscriptionId $_.Id -ErrorAction 'SilentlyContinue' }
      }

      $result
    } catch {
      Resolve-Exception -ExceptionObject $PSitem
    }

  }

  End {
  }
}