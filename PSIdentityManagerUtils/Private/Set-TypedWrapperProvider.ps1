﻿function Set-TypedWrapperProvider {
  [CmdletBinding()]
  Param (
    [parameter(Mandatory = $true, HelpMessage = 'The session to use')]
    [ValidateNotNull()]
    [VI.DB.Entities.ISession] $Session,
    [Parameter(Mandatory = $false, HelpMessage = 'Cmdlet prefix to use for handling multiple connections')]
    [String] $Prefix = '',
    [Parameter(Mandatory = $false, HelpMessage = 'List of modules to skip for function generation')]
    [String[]] $ModulesToSkip
  )

  Begin {
  }

  Process
  {
    try {

      $metaData = [VI.DB.Entities.SessionExtensions]::MetaData($Session)
      if ($null -eq $ModulesToSkip)
      {
        $tables = $metaData.GetTablesAsync($noneToken).GetAwaiter().GetResult() | Where-Object { -not $_.IsDeactivated }
      } else {
        $tables = $metaData.GetTablesAsync($noneToken).GetAwaiter().GetResult() | Where-Object { -not $_.IsDeactivated -And (-not $ModulesToSkip.Contains($_.Uid.Substring(0, 3))) }
      }

      $progressCount = 0
      $totalOperationsCount = $tables.Count

      ForEach ($tableProperty in $tables) {
        $funcName = $tableProperty.TableName

        # Do not update progress for every function. It takes to much time.
        if ($progressCount % 10 -eq 0) {
          Write-Progress -Activity 'Generating "Set-" functions' -Status "Function $progressCount of $totalOperationsCount" -CurrentOperation "Set-$Prefix$funcName" -PercentComplete ($progressCount / $totalOperationsCount * 100)
        }
        $progressCount++

        $funcTemplateHeader = @"
function global:Set-$Prefix$funcName() {
  Param (
    [parameter(Mandatory = `$false, ValueFromPipeline=`$true, HelpMessage = 'Entity to interact with')]
    [VI.DB.Entities.IEntity] `$Entity = `$null,
    [parameter(Mandatory = `$false, HelpMessage = 'Load object by UID or XObjectKey')]
    [string] `$Identity,
"@

        $cols = new-object string[] 0
        ForEach ($column in $tableProperty.Columns) {
          if (-not $column.Enabled) {
            # Skip deactivated columns
            Continue
          }
          $cols += "'" + $column.ColumnName + "',"
          $paramName = $column.ColumnName

          if ($column.IsUid -or $column.IsDynamicFK) {
            $dateType = "Object"
          } else {
            $dateType = [VI.Base.DbVal]::GetType($column.Type).Name
          }

          $helpText = $null

          if (-not [string]::IsNullOrEmpty($column.Display)) {
            $helpText = $column.Display.Translated -replace "’",  "`'" -replace '"', '`"' -replace '“',  '`"' -replace '”',  '`"' -replace "'", "`'"
          }

          $columnTemplate = @"
`r`n
  [parameter(Mandatory = `$false, HelpMessage = "$helpText")]
  [$dateType] `$$paramName,
"@

          $funcTemplateHeader = $funcTemplateHeader + $columnTemplate
        }
        $funcTemplateHeader = $funcTemplateHeader.Substring(0, $funcTemplateHeader.Length - 1) + ')'
        $cols[$cols.Length -1 ] = $cols[$cols.Length - 1].Substring(0, $cols[$cols.Length - 1].Length - 1)

        $funcTemplateFooter = @"
`r`n
  Process {
    try {
      `$session = `$Global:imsessions['$Prefix'].Session
      `$cols = @($cols)

      if (-not [String]::IsNullOrEmpty(`$Identity) -and `$null -eq `$Entity) {
        # if the identity is an objectkey, check it belongs to the table this function is associated with.
        if (`$Identity -like '<Key><T>*</T><P>*</P></Key>') {
          `$objectKey = [VI.DB.DbObjectKey]::new(`$Identity)

          if (-not (`$objectKey.Tablename -eq '$funcName')) {
            throw "The provided XObjectKey `$Identity is not valid for objects of type '$funcName'."
          }
        }
      }

      `$properties = @{}
      ForEach (`$boundParam in `$PSBoundParameters.GetEnumerator()) {
        if ((`$cols -contains `$boundParam.Key)) {
          `$properties.Add(`$boundParam.Key, `$boundParam.Value)
        }
      }

      Set-Entity -Session `$session -Entity `$Entity -Type '$funcName' -Identity `$Identity -Properties `$properties
    } catch {
      Resolve-Exception -ExceptionObject `$PSitem
    }
  }
}
"@

        $funcTemplate = $funcTemplateHeader + $funcTemplateFooter

        try {
          Invoke-Expression $funcTemplate
        } catch {
          Resolve-Exception -ExceptionObject $PSitem
        }
      }
    } catch {
      Resolve-Exception -ExceptionObject $PSitem
    }
  }

  End {
    $Global:setTypedWrapperProviderDone = $true
    # Make PSScriptAnalyzer happy.
    $Global:setTypedWrapperProviderDone |Out-Null
  }
}