#
#
#  SCOM Management Pack Creator PS Module
#  By Dujon Walsham
# 
#  Version 1.0 Release Notes
#  - Creates XML for each individual part of the Management Pack
#  - Creates Classes
#  - Creates Monitors (Two State Event Monitor Currently)
#  - Creates Rules (Two State Event Rule Currently)
#  - Creates Discoveries (PowerShell, VBScript, WMI & Registry)
#  - Creates Views (State View, Performance, Override and Event View)
#  - Creates Folders
#  
#  Version 2.0 Release Notes
#
#  - Dynamically detects all classes for easier selection for the MP creation
#  - Create all Views
#  - Create Relationships & Computer Rollups
#  - Create additional monitors & rules
#  - Add Alert Supression parameters
#  - Add custom probes i.e. Monitor Based on Scripts via PowerShell with overridable parameters
#
#
#  Version 3.0 Release Notes
# 
#
#
# 
# - Switch Parameters for all functions and Intellisense for dynamic class detection
# - MPX file output to import to Visual Studio Projects
# - Importable Module within Powershell with CMDLets
# - UNIX/Linux Support - Discovery & Monitoring
# - Adding Product Knowledgebase Articles to Discoveries and Monitors/Rules
# - Multiple Discoveries and Monitors/Rules can now be added into one MPX file
# - Add Manual Reset and Timer Reset Windows Event Monitors
# - Create Tasks
# - Create Diagnostic & Recovery tasks
# - Error Handling, Help Messages and Comments for MPX files
# 
#
###################################################################################################################################################

                                                          #########################################
                                                          #                                       #
                                                          #    PowerShell Module Functions        #
                                                          #                                       #
                                                          #                                       #
                                                          #########################################


####################################################################################################################################################
# New-SCOMMPClass - Create New Class File
####################################################################################################################################################

 Function New-SCOMMPClass
 {
  
  Param (

  [Parameter(Mandatory=$true,HelpMessage="Full path and filename of your Class File")]
  [String]$MPClassFile

  )
 
 # Builds the XML structure for the Class
   Add-Content $MPClassFile "<ManagementPackFragment SchemaVersion=""2.0"" xmlns:xsd=""http://www.w3.org/2001/XMLSchema"">`n <TypeDefinitions>`n  <EntityTypes>`n   <ClassTypes>`n   </ClassTypes>`n</EntityTypes>`n<SecureReferences>`n</SecureReferences>`n </TypeDefinitions>`n <LanguagePacks>`n  <LanguagePack ID=""ENU"" IsDefault=""true"">`n   <DisplayStrings>`n    </DisplayStrings>`n  </LanguagePack>`n </LanguagePacks>`n</ManagementPackFragment> "
   }

#######################################################################################################################################################
# Add-SCOMMPClass - Adds a New Class to your Class File
#######################################################################################################################################################

 Function Add-SCOMMPClass
 {
  [cmdletbinding()]

  Param (
  [Parameter(Mandatory=$true,HelpMessage="Name of the class you will create")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$ClassName,

  [Parameter(Mandatory=$true,ValuefromPipelineByPropertyName=$true,HelpMessage="Select which type of class you will base your class on. If hosting another class then choose CustomClass to enter a custom one")]
  [Alias('SourceClassID')]
  [AllowNull()]
  [AllowEmptyString()]
  [ValidateSet('WindowsComputer','WindowsApplicationComponent','WindowsLocalApplication','UnixComputer','ComputerGroup','InstanceGroup','ComputerHealthRollup','CustomClass')]
  [String]$ClassType,

  [Parameter(Mandatory=$true,HelpMessage="Short descritpion of the class you are creating")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$ClassDescription,

  [Parameter(Mandatory=$true,HelpMessage="Will this class be a parent class")]
  [ValidateSet('true','false')]
  [String]$Abstract,

  [Parameter(Mandatory=$true,HelpMessage="Will this class be hosted by another parent class")]
  [ValidateSet('true','false')]
  [String]$Hosted,

  [Parameter(Mandatory=$true,HelpMessage="Will this class contain only one object")]
  [ValidateSet('true','false')]
  [String]$Singleton,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Location of the Class MPX file")]
  [String[]]$MPClassFile
  )

  # Sets ClassType to BaseClass
  Switch ($ClassType){
  'WindowsComputer' {$BaseClass = 'Windows!Microsoft.Windows.ComputerRole'}
  'WindowsApplicationComponent' {$BaseClass = 'Windows!Microsoft.Windows.ApplicationComponent'}
  'WindowsLocalApplication' {$BaseClass = "Windows!Microsoft.Windows.LocalApplication"}
  'UnixComputer' {$BaseClass = 'Unix!Microsoft.Unix.ComputerRole'}
  'ComputerGroup' {$BaseClass = 'SC!Microsoft.SystemCenter.ComputerGroup'}
  'InstanceGroup' {$BaseClass = 'MSIL!Microsoft.SystemCenter.InstanceGroup'}
  'ComputerHealthRollup' {$BaseClass = 'System!System.ComputerRole'}
  'CustomClass' {$BaseClass = Read-Host "You have chosen to use a customclass as its target. Type the name of the class you wish to use as its type"}
   }

  # Formats the Class Name to the relevant format for the XML to handle the Class name
  $ClassID = $ClassName -replace " ", "."
  $ClassContent = Get-Content $MPClassFile

  # Writes the Class Type information in the class file
  $FindLastClassTypeLine = Select-String $MPClassFile -pattern "</ClassTypes>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastClassTypeLine] += "`n    <ClassType ID=""$classID"" Base=""$BaseClass"" Accessibility=""Internal"" Abstract=""$Abstract"" Hosted=""$Hosted"" Singleton=""$Singleton"">`n   </ClassType>"
  $ClassContent | Set-Content $MPClassFile

  # Reloads the Class XML file with the new changes
  $ClassContent = Get-Content $MPClassFile
  
  # Writes the DisplayStrings to the XML so SCOM can read the display names correctly
  $FindLastDisplayStringLine = Select-String $MPClassFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$ClassID"">`n     <Name>$ClassName</Name>`n     <Description>$ClassDescription</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPClassFile

 } 

#########################################################################################################################################################
# Get-ClassID - Obtains all of the classes in your Class file so you can pass it through to create more options
# Enabled to pipeline for MPClassFile and ClassID for AffectedClassID switches
#########################################################################################################################################################

  Function Get-SCOMClassID
  {
    [cmdletbinding()]

   Param (
  [Parameter(Mandatory=$false,HelpMessage="Location of the Class MPX file")]
  [String]$MPClassFile,

  [Parameter(Mandatory=$false,HelpMessage="Location of the Folder MPX file")]
  [String]$MPFolderFile,

  [Parameter(Mandatory=$false,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )

  DynamicParam {
  # Switches to build Class References for all functions to build management pack
  $ParamAttrib = New-Object  System.Management.Automation.ParameterAttribute
  $ParamAttrib.Mandatory = $false
  $ParamAttrib.ParameterSetName = '__AllParameterSets'

  # Using Classes, Folders and Monitors/Rules
  If ($MPClassFile -ne $null -and $MPFolderFile -ne $null -and $MPMonitorRuleFile -ne $null)
  {
  $AttribColl = New-Object  System.Collections.ObjectModel.Collection[System.Attribute]
  $AttribColl.Add($ParamAttrib)

  $AttribColl1 = New-Object  System.Collections.ObjectModel.Collection[System.Attribute]
  $AttribColl1.Add($ParamAttrib)

  $AttribColl2 = New-Object  System.Collections.ObjectModel.Collection[System.Attribute]
  $AttribColl2.Add($ParamAttrib)

  $AffectedClasses = ((Get-Content $MPClassFile) -match "<DisplayString ElementID" -notmatch "SubElementID") -replace "<DisplayString ElementID=""", "" -replace """", "" -replace ">", ""
  $AffectedClasses = $AffectedClasses.trim()

  $AffectedFolders = ((Get-Content $MPFolderFile) -match "<DisplayString ElementID" -notmatch "SubElementID") -replace "<DisplayString ElementID=""", "" -replace """", "" -replace ">", ""
  $AffectedFolders = $AffectedFolders.Trim()

  $AffectedMonitorsRules = ((Get-Content $MPMonitorRuleFile) -match "<DisplayString ElementID" -notmatch "SubElementID") -replace "<DisplayString ElementID=""", "" -replace """", "" -replace ">", ""
  $AffectedMonitorsRules = $AffectedMonitorsRules.Trim()

  $AttribColl.Add((New-Object  System.Management.Automation.ValidateSetAttribute($AffectedClasses)))
  $AttribColl1.Add((New-Object  System.Management.Automation.ValidateSetAttribute($AffectedFolders)))
  $AttribColl2.Add((New-Object  System.Management.Automation.ValidateSetAttribute($AffectedMonitorsRules)))

  $RuntimeParam = New-Object  System.Management.Automation.RuntimeDefinedParameter('SourceClassID', [string],  $AttribColl)
  $RuntimeParam1 = New-Object  System.Management.Automation.RuntimeDefinedParameter('TargetClassID', [string],  $AttribColl)
  $RuntimeParam2 = New-Object  System.Management.Automation.RuntimeDefinedParameter('RunAsAccount', [string],  $AttribColl)
  $RuntimeParam3 = New-Object  System.Management.Automation.RuntimeDefinedParameter('FolderID', [string],  $AttribColl1)
  $RuntimeParam4 = New-Object  System.Management.Automation.RuntimeDefinedParameter('MonitorRuleID', [string],  $AttribColl2)

  $RuntimeParamDic = New-Object  System.Management.Automation.RuntimeDefinedParameterDictionary
  $RuntimeParamDic.Add('SourceClassID', $RuntimeParam)
  $RuntimeParamDic.Add('TargetClassID', $RuntimeParam1)
  $RuntimeParamDic.Add('RunAsAccount', $RuntimeParam2)
  $RuntimeParamDic.Add('FolderID', $RuntimeParam3)
  $RuntimeParamDic.Add('MonitorRuleID', $RuntimeParam4)
  return $RuntimeParamDic
  }

  # Using Classes and Monitors/Rules

  If ($MPClassFile -ne $null -and $MPMonitorRuleFile -ne $null)
  {
  $AttribColl = New-Object  System.Collections.ObjectModel.Collection[System.Attribute]
  $AttribColl.Add($ParamAttrib)

  $AttribColl1 = New-Object  System.Collections.ObjectModel.Collection[System.Attribute]
  $AttribColl1.Add($ParamAttrib)

  $AffectedClasses = ((Get-Content $MPClassFile) -match "<DisplayString ElementID" -notmatch "SubElementID") -replace "<DisplayString ElementID=""", "" -replace """", "" -replace ">", ""
  $AffectedClasses = $AffectedClasses.trim()

  $AffectedMonitorsRules = ((Get-Content $MPMonitorRuleFile) -match "<DisplayString ElementID" -notmatch "SubElementID") -replace "<DisplayString ElementID=""", "" -replace """", "" -replace ">", ""
  $AffectedMonitorsRules = $AffectedMonitorsRules.Trim()

  $AttribColl.Add((New-Object  System.Management.Automation.ValidateSetAttribute($AffectedClasses)))
  $AttribColl1.Add((New-Object  System.Management.Automation.ValidateSetAttribute($AffectedMonitorsRules)))


  $RuntimeParam = New-Object  System.Management.Automation.RuntimeDefinedParameter('SourceClassID', [string],  $AttribColl)
  $RuntimeParam1 = New-Object  System.Management.Automation.RuntimeDefinedParameter('TargetClassID', [string],  $AttribColl)
  $RuntimeParam2 = New-Object  System.Management.Automation.RuntimeDefinedParameter('RunAsAccount', [string],  $AttribColl)
  $RuntimeParam3 = New-Object  System.Management.Automation.RuntimeDefinedParameter('MonitorRuleID', [string],  $AttribColl1)

  $RuntimeParamDic = New-Object  System.Management.Automation.RuntimeDefinedParameterDictionary
  $RuntimeParamDic.Add('SourceClassID', $RuntimeParam)
  $RuntimeParamDic.Add('TargetClassID', $RuntimeParam1)
  $RuntimeParamDic.Add('RunAsAccount', $RuntimeParam2)
  $RuntimeParamDic.Add('MonitorRuleID', $RuntimeParam3)
  return $RuntimeParamDic
  }

  # Using Folders Only
  If ($MPClassFile -eq $null -and $MPMonitorRuleFile -eq $null -and $MPFolderFile -ne $null)
  {
  $AttribColl = New-Object  System.Collections.ObjectModel.Collection[System.Attribute]
  $AttribColl.Add($ParamAttrib)

  $AffectedFolders = ((Get-Content $MPFolderFile) -match "<DisplayString ElementID" -notmatch "SubElementID") -replace "<DisplayString ElementID=""", "" -replace """", "" -replace ">", ""
  $AffectedFolders = $AffectedFolders.Trim()

  $AttribColl.Add((New-Object  System.Management.Automation.ValidateSetAttribute($AffectedFolders)))

  $RuntimeParam = New-Object  System.Management.Automation.RuntimeDefinedParameter('FolderID', [string],  $AttribColl)

  $RuntimeParamDic = New-Object  System.Management.Automation.RuntimeDefinedParameterDictionary
  $RuntimeParamDic.Add('FolderID', $RuntimeParam)
  return $RuntimeParamDic
  }


  # Using Classes Only
  If ($MPClassFile -ne $null -and $MPMonitorRuleFile -eq $Null -and $MPFolderFile -eq $null)
  {
  $AttribColl = New-Object  System.Collections.ObjectModel.Collection[System.Attribute]
  $AttribColl.Add($ParamAttrib)

  $AffectedClasses = ((Get-Content $MPClassFile) -match "<DisplayString ElementID" -notmatch "SubElementID") -replace "<DisplayString ElementID=""", "" -replace """", "" -replace ">", ""
  $AffectedClasses = $AffectedClasses.trim()

  $AttribColl.Add((New-Object  System.Management.Automation.ValidateSetAttribute($AffectedClasses)))

  $RuntimeParam = New-Object  System.Management.Automation.RuntimeDefinedParameter('SourceClassID', [string],  $AttribColl)
  $RuntimeParam1 = New-Object  System.Management.Automation.RuntimeDefinedParameter('TargetClassID', [string],  $AttribColl)
  $RuntimeParam2 = New-Object  System.Management.Automation.RuntimeDefinedParameter('RunAsAccount', [string],  $AttribColl)

  $RuntimeParamDic = New-Object  System.Management.Automation.RuntimeDefinedParameterDictionary
  $RuntimeParamDic.Add('SourceClassID', $RuntimeParam)
  $RuntimeParamDic.Add('TargetClassID', $RuntimeParam1)
  $RuntimeParamDic.Add('RunAsAccount', $RuntimeParam2)
  return $RuntimeParamDic
  }

    # Using Monitors/Rules Only
  If ($MPMonitorRuleFile -ne $Null -and $MPClassFile -eq $null -and $MPFolderFile -eq $null)
  {
  $AttribColl = New-Object  System.Collections.ObjectModel.Collection[System.Attribute]
  $AttribColl.Add($ParamAttrib)

  $AffectedMonitorsRules = ((Get-Content $MPMonitorRuleFile) -match "<DisplayString ElementID" -notmatch "SubElementID") -replace "<DisplayString ElementID=""", "" -replace """", "" -replace ">", ""
  $AffectedMonitorsRules = $AffectedMonitorsRules.Trim()

  $AttribColl.Add((New-Object  System.Management.Automation.ValidateSetAttribute($AffectedMonitorsRules)))

  $RuntimeParam = New-Object  System.Management.Automation.RuntimeDefinedParameter('MonitorRuleID', [string],  $AttribColl)

  $RuntimeParamDic = New-Object  System.Management.Automation.RuntimeDefinedParameterDictionary
  $RuntimeParamDic.Add('MonitorRuleID', $RuntimeParam)
  return $RuntimeParamDic
  }

  }

  Process {
  $ClassObject = New-Object -TypeName PSObject
  $ClassObject | Add-Member -MemberType NoteProperty -Name SourceClassID -Value $PSBoundParameters.SourceClassID
  $ClassObject | Add-Member -MemberType NoteProperty -Name TargetClassID -Value $PSBoundParameters.TargetClassID
  $ClassObject | Add-Member -MemberType NoteProperty -Name RunAsAccount -Value $PSBoundParameters.RunAsAccount
  $ClassObject | Add-Member -MemberType NoteProperty -Name FolderID -Value $PSBoundParameters.FolderID
  $ClassObject | Add-Member -MemberType NoteProperty -Name MonitorRuleID -Value $PSBoundParameters.MonitorRuleID
  $ClassObject | Add-Member -MemberType NoteProperty -Name MPClassFile -Value $MPClassFile
  $ClassObject
  }

 }

######################################################################################################################################################
# Add-SCOMMPClassProperty - Add Properties to your SCOM Class
# You can use the Get-ClassID function to pipeline the SCOM class you need to create a property for
######################################################################################################################################################

  Function Add-SCOMMPClassProperty
  {
  [cmdletbinding()]

   Param (
  [Parameter(Mandatory=$true,HelpMessage="Name of the property attribute which will be added to your class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$PropertyName,

  [Parameter(Mandatory=$true,HelpMessage="Select the type of property you will use")]
  [ValidateSet('int','decimal','double','string','datetime','guid','bool','enum','richtext','binary')]
  [String]$PropertyType,

  [Parameter(Mandatory=$true,HelpMessage="Will this property be a key value to the class")]
  [ValidateSet('true','false')]
  [String]$KeyValue,  

  [Parameter(Mandatory=$true,HelpMessage="Description of the property")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$PropertyDescription,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the class which the property will be added to")]
  [Alias('SourceClassID')]
  [AllowNull()]
  [AllowEmptyString()]
  [String[]]$AffectedClassID,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Location of the Class MPX file")]
  [String[]]$MPClassFile

  )

  # Formats the Property Name to the relevant format for the XML to handle the Property name
  $AffectedClassID = $AffectedClassID -replace " ", "."
  $PropertyID = $PropertyName -replace " ", "."
  $ClassContent = Get-Content $MPClassFile

  # Writes the DisplayStrings to the XML so SCOM can read the display names correctly
  $FindLastDisplayStringLine = Select-String $MPClassFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$AffectedClassID"" SubElementID=""$PropertyID"">`n     <Name>$PropertyName</Name>`n     <Description>$PropertyDescription</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPClassFile

  # Adds the Property to the Class within the XML file
  (Get-Content $MPClassFile) | 
     Foreach-Object {
         $_ 
         if ($_ -match "<Classtype ID=""$AffectedClassID""") 
         {
             
             "     <Property ID=""$PropertyID"" Key=""$KeyValue"" Type=""$PropertyType""/>"
         }
     } | Set-Content $MPClassFile
  }

  #######################################################################################################################################################
  # Add-SCOMMPRunAsAccount - Add Run As Account to your Class
  #######################################################################################################################################################

  Function Add-SCOMMPRunAsAccount
  {
   [cmdletbinding()]

  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter the name of the Run As Account")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$SecureReferenceName,

  [Parameter(Mandatory=$true,HelpMessage="Enter a description for the Run As Account")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$SecureReferenceDescription,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Location of the Class MPX file")]
  [String[]]$MPClassFile
  )

  # Formats the Secure Reference Name to the relevant format for the XML to handle the Secure Reference name
  $SecureReferenceID = $SecureReferenceName -replace " ", "."
  $ClassContent = Get-Content $MPClassFile

  # Adds the Secure Reference (Run As Account) to the management pack
  $FindLastSecureReferenceLine = Select-String $MPClassFile -pattern "</SecureReferences>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastSecureReferenceLine] += "`n  <SecureReference ID=""$SecureReferenceID"" Accessibility=""Internal"" Context=""System!System.Entity"" />"
  $ClassContent | Set-Content $MPClassFile

  # Reloads the Class XML file with the new changes
  $ClassContent = Get-Content $MPClassFile

  # Writes the DisplayStrings to the XML so SCOM can read the display names correctly
  $FindLastDisplayStringLine = Select-String $MPClassFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$SecureReferenceID"">`n     <Name>$SecureReferenceName</Name>`n     <Description>$SecureReferenceDescription</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPClassFile

}

############################################################################################################################################################
# New-SCOMMPRelationship
# Creating relationships between different classes
############################################################################################################################################################

  Function New-SCOMMPRelationship
  {

  Param (
  [Parameter(Mandatory=$true,HelpMessage="Location of the Relationship MPX file")]
  [String]$MPRelationshipFile

  )

  # Builds the XML structure for the Class
  Add-Content $MPRelationshipFile "<ManagementPackFragment SchemaVersion=""2.0"" xmlns:xsd=""http://www.w3.org/2001/XMLSchema"">`n <TypeDefinitions>`n  <EntityTypes>`n      <RelationshipTypes>`n        </RelationshipTypes>`n    </EntityTypes>`n  </TypeDefinitions>`n  <LanguagePacks>`n    <LanguagePack ID=""ENU"" IsDefault=""true"">`n      <DisplayStrings>`n      </DisplayStrings>`n    </LanguagePack>`n  </LanguagePacks>`n</ManagementPackFragment>"
  }

############################################################################################################################################################
# Add-SCOMMPRelationship
# Adding relationships between different classes
############################################################################################################################################################

 Function Add-SCOMMPRelationship
 {
  [cmdletbinding()]

 Param(

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the Relationship")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$RelationshipName,

  [Parameter(Mandatory=$true,HelpMessage="Enter a description for the Relationship")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$RelationshipDescription,

  [Parameter(Mandatory=$true,HelpMessage="Will this class be a parent class")]
  [ValidateSet('true','false')]
  [String]$Abstract,

  [Parameter(Mandatory=$true,HelpMessage="Determine the class Accessibility to be edited")]
  [ValidateSet('Internal','Public')]
  [String]$Accessibility,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the source class which will be used in the relationship")]
  [Alias('SourceClassID')]
  [String[]]$SourceType,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which will be used in the relationship")]
  [Alias('TargetClassID')]
  [String[]]$TargetType,

  [Parameter(Mandatory=$true,HelpMessage="Location of the Relationship MPX file")]
  [String]$MPRelationshipFile

  )

  # Formats the Class Name to the relevant format for the XML to handle the Class name
  $RelationshipID = $RelationshipName -replace " ", "."
  $ClassContent = Get-Content $MPRelationshipFile

  # Writes the Class Type information in the class file
  $FindLastRelationshipTypeLine = Select-String $MPRelationshipFile -pattern "</RelationshipTypes>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastRelationshipTypeLine] += "`n        <RelationshipType ID=""$RelationshipID"" Base=""System!System.Containment"" Abstract=""$Abstract"" Accessibility=""$Accessibility"">`n          <Source ID=""Source"" Type=""$SourceType""/>`n          <Target ID=""Target"" Type=""$TargetType""/>`n        </RelationshipType>"
  $ClassContent | Set-Content $MPRelationshipFile

  # Reloads the Class XML file with the new changes
  $ClassContent = Get-Content $MPRelationshipFile

  # Writes the DisplayStrings to the XML so SCOM can read the display names correctly
  $FindLastDisplayStringLine = Select-String $MPRelationshipFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$RelationshipID"">`n     <Name>$RelationshipName</Name>`n     <Description>$RelationshipDescription</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPRelationshipFile
 }

############################################################################################################################################################
# New-SCOMMPDiscovery
# Adding relationships between different classes
############################################################################################################################################################

 Function New-SCOMMPDiscovery
  {
   [cmdletbinding()]

  Param (

  [Parameter(Mandatory=$true,HelpMessage="Location of the Discovery MPX file")]
  [String]$MPDiscoveryFile

  )

  # Wrties variable values which are specific to Visual Studios
  $IncludeFileContent = "$" + "IncludeFileContent"
  $MPElement = "$" + "MPElement"
  $Target =  "$" + "Target"

  # Writes the XML structure of the Discovery
  Add-Content $MPDiscoveryFile "<ManagementPackFragment SchemaVersion=""2.0"" xmlns:xsd=""http://www.w3.org/2001/XMLSchema"">`n  <Monitoring>`n   <Discoveries>`n    </Discoveries>`n  </Monitoring>`n  <LanguagePacks>`n    <LanguagePack ID=""ENU"" IsDefault=""true"">`n      <DisplayStrings>`n      </DisplayStrings>`n      <KnowledgeArticles>`n      </KnowledgeArticles>`n    </LanguagePack>`n  </LanguagePacks>`n</ManagementPackFragment>"

  }

############################################################################################################################################################
# Add-SCOMMPPowerShellDiscovery
# Adding relationships between different classes
############################################################################################################################################################

  Function Add-SCOMMPPowerShellDiscovery
  {
   [cmdletbinding()]

  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$DiscoveryName,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the discovery will be ran against")]
  [Alias('TargetClassID')]
  [ValidateSet('WindowsComputer','WindowsApplicationComponent','WindowsLocalApplication','UnixComputer','ComputerGroup','InstanceGroup','ComputerHealthRollup', 'CustomClass')]
  [String[]]$DiscoveryTarget,

  [Parameter(Mandatory=$true,HelpMessage="Enter a description for the discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$DiscoveryDescription,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the source class which the properties will be extracted from to be added to")]
  [Alias('SourceClassID')]
  [String[]]$DiscoveryClass,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the Run As Account which will be used for this discovery")]
  [Alias('RunAsAccount')]
  [String[]]$DiscoveryRunAsAccount,

  [Parameter(Mandatory=$true,HelpMessage="Enter the Interval based in seconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$IntervalSeconds,

  [Parameter(Mandatory=$false,HelpMessage="Enter a time based on 24 Hour clock to run at schedule")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$SyncTime,

  [Parameter(Mandatory=$true,HelpMessage="Enter the name of the powershell script the discovery will use")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$ScriptName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the timeout period based in seconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TimeoutSeconds,

  [Parameter(Mandatory=$false,HelpMessage="Enter a paragrahp for the knowledgebase article for this discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$KnowledgeArticle,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Location of the Class MPX file")]
  [String[]]$MPClassFile,

  [Parameter(Mandatory=$true,HelpMessage="Location of the Discovery MPX file")]
  [String]$MPDiscoveryFile

 )

   # Sets ClassType
  Switch ($DiscoveryTarget){
  'WindowsComputer' {$BaseClass = 'Windows!Microsoft.Windows.ComputerRole'}
  'WindowsApplicationComponent' {$BaseClass = 'Windows!Microsoft.Windows.ApplicationComponent'}
  'WindowsLocalApplication' {$BaseClass = "Windows!Microsoft.Windows.LocalApplication"}
  'UnixComputer' {$BaseClass = 'Unix!Microsoft.Unix.ComputerRole'}
  'ComputerGroup' {$BaseClass = 'SC!Microsoft.SystemCenter.ComputerGroup'}
  'InstanceGroup' {$BaseClass = 'MSIL!Microsoft.SystemCenter.InstanceGroup'}
  'ComputerHealthRollup' {$BaseClass = 'System!System.ComputerRole'}
  'CustomClass' {$BaseClass = Read-Host "You have chosen to use a customclass as its target. Type the name of the class you wish to use as its type"}
  }

  
  # Wrties variable values which are specific to Visual Studios
  $DiscoveryID = $DiscoveryName -replace " ", "."
  $Target = "$" + "Target"
  $Data = "$" + "Data"
  $MPElement = "$" + "MPElement"
  $IncludeFileContent = "$" + "IncludeFileContent"

  # Formats the Secure Reference Name to the relevant format for the XML to handle the Secure Reference name
  $ClassContent = Get-Content $MPDiscoveryFile

  # Retrieves the details for the Class created previously 
  $MPClassContent = Get-Content $MPClassFile

  # Finds all of the properties which were created from that particular class by searching the class.xml file
  $FindProperties = ((Get-Content $MPClassFile) -match "<DisplayString ElementID=""$DiscoveryClass"" SubElementID") -replace "<DisplayString ElementID=""$DiscoveryClass"" SubElementID", "<Property TypeID=""$DiscoveryClass"" PropertyID" -replace ">", " />"

  # Writes the Discovery ID to the XML Management Pack
  $FindDiscoveriesLine = Select-String $MPDiscoveryFile -pattern "</Discoveries>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindDiscoveriesLine] += "`n      <Discovery ID=""$DiscoveryID"" Target=""$BaseClass"" Enabled=""true"" ConfirmDelivery=""false"" Remotable=""true"" Priority=""Normal"">`n        <Category>Discovery</Category>`n        <DiscoveryTypes>`n          <DiscoveryClass TypeID=""$DiscoveryClass"">`n          $FindProperties`n          </DiscoveryClass>`n        </DiscoveryTypes>`n             <DataSource ID=""DS"" TypeID=""Windows!Microsoft.Windows.TimedPowerShell.DiscoveryProvider"" RunAs=""$DiscoveryRunAsAccount"">`n          <IntervalSeconds>$IntervalSeconds</IntervalSeconds>`n          <SyncTime>$SyncTime</SyncTime>`n          <ScriptName>$ScriptName</ScriptName>`n          <ScriptBody>$IncludeFileContent/$ScriptName$</ScriptBody>`n       <Parameters>`n            <Parameter>`n              <Name>sourceID</Name>`n              <Value>$MPElement$</Value>`n            </Parameter>`n            <Parameter>`n              <Name>managedEntityID</Name>`n              <Value>$Target/Id$</Value>`n            </Parameter>`n            <Parameter>`n              <Name>computerName</Name>`n              <Value>$Target/Host/Property[Type=""Windows!Microsoft.Windows.Computer""]/PrincipalName$</Value>`n            </Parameter>`n          </Parameters>`n          <TimeoutSeconds>$TimeoutSeconds</TimeoutSeconds>`n      </DataSource>`n      </Discovery>"
  $ClassContent | Set-Content $MPDiscoveryFile

  # Reloads the Class XML file with the new changes
  $ClassContent = Get-Content $MPDiscoveryFile

  # Writes the DisplayStrings to the XML so SCOM can read the display names correctly
  $FindLastDisplayStringLine = Select-String $MPDiscoveryFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$DiscoveryID"">`n     <Name>$DiscoveryName</Name>`n     <Description>$DiscoveryDescription</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPDiscoveryFile

  # Reloads the Class XML file with the new changes
  $ClassContent = Get-Content $MPDiscoveryFile

  # Writes the Knowledge Article to the XML so SCOM can read the display names correctly
  $FindLastKnowledgeArticleLine = Select-String $MPDiscoveryFile -pattern "</KnowledgeArticles>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastKnowledgeArticleLine] += "`n    <KnowledgeArticle ElementID=""$DiscoveryID"" Visible=""true"">`n     <MamlContent>`n     <maml:section xmlns:maml=""http://schemas.microsoft.com/maml/2004/10"">`n              <maml:title>$DiscoveryName</maml:title>`n              <maml:para>$KnowledgeArticle</maml:para>`n            </maml:section>`n          </MamlContent>`n    </KnowledgeArticle>"
  $ClassContent | Set-Content $MPDiscoveryFile

  }

############################################################################################################################################################
# Add-SCOMMPRegistryDiscovery
# Adding relationships between different classes
############################################################################################################################################################

  Function Add-SCOMMPRegistryDiscovery
  {
   [cmdletbinding()]

  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$DiscoveryName,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the discovery will be ran against")]
  [Alias('TargetClassID')][ValidateSet('WindowsComputer','WindowsApplicationComponent','WindowsLocalApplication','UnixComputer','ComputerGroup','InstanceGroup','ComputerHealthRollup', 'CustomClass')]
  [String[]]$DiscoveryTarget,

  [Parameter(Mandatory=$true,HelpMessage="Enter a description for the discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$DiscoveryDescription,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the source class which the properties will be extracted from to be added to")]
  [Alias('SourceClassID')]
  [String[]]$DiscoveryClass,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the Run As Account which will be used for this discovery")]
  [Alias('RunAsAccount')]
  [String[]]$DiscoveryRunAsAccount,

  [Parameter(Mandatory=$true,HelpMessage="Enter the frequency which the discovery will run in seconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$Frequency,

  [Parameter(Mandatory=$false,HelpMessage="Enter a paragraph for the knowledgebase article for this discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$KnowledgeArticle,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Location of the Class MPX file")]
  [String[]]$MPClassFile,

  [Parameter(Mandatory=$true,HelpMessage="Location of the Discovery MPX file")]
  [String]$MPDiscoveryFile

  )

     # Sets ClassType
  Switch ($DiscoveryTarget){
  'WindowsComputer' {$BaseClass = 'Windows!Microsoft.Windows.ComputerRole'}
  'WindowsApplicationComponent' {$BaseClass = 'Windows!Microsoft.Windows.ApplicationComponent'}
  'WindowsLocalApplication' {$BaseClass = "Windows!Microsoft.Windows.LocalApplication"}
  'UnixComputer' {$BaseClass = 'Unix!Microsoft.Unix.ComputerRole'}
  'ComputerGroup' {$BaseClass = 'SC!Microsoft.SystemCenter.ComputerGroup'}
  'InstanceGroup' {$BaseClass = 'MSIL!Microsoft.SystemCenter.InstanceGroup'}
  'ComputerHealthRollup' {$BaseClass = 'System!System.ComputerRole'}
  'CustomClass' {$BaseClass = Read-Host "You have chosen to use a customclass as its target. Type the name of the class you wish to use as its type"}
  }

  # Wrties variable values which are specific to Visual Studios
  $Target = "$" + "Target"
  $MPElement = "$" + "MPElement"
  $ClassContent = Get-Content $MPDiscoveryFile
  $DiscoveryID = $DiscoveryName -replace " ", "."

  # Retrieves the details for the Class created previously 
  $MPClassContent = Get-Content $MPClassFile

  # Finds all of the properties which were created from that particular class by searching the class.xml file
  $FindProperties = ((Get-Content $MPClassFile) -match "<DisplayString ElementID=""$DiscoveryClass"" SubElementID") -replace "<DisplayString ElementID=""$DiscoveryClass"" SubElementID", "<Property TypeID=""$DiscoveryClass"" PropertyID" -replace ">", " />"

  # Writes the Discovery ID to the XML Management Pack
  $FindDiscoveriesLine = Select-String $MPDiscoveryFile -pattern "</Discoveries>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindDiscoveriesLine] += "`n      <Discovery ID=""$DiscoveryID"" Target=""$BaseClass"" Enabled=""true"" ConfirmDelivery=""false"" Remotable=""true"" Priority=""Normal"">`n        <Category>Discovery</Category>`n        <DiscoveryTypes>`n          <DiscoveryClass TypeID=""$DiscoveryClass"">`n          $FindProperties`n          </DiscoveryClass>`n        </DiscoveryTypes>`n             <DataSource ID=""DS"" TypeID=""Windows!Microsoft.Windows.FilteredRegistryDiscoveryProvider"" RunAs=""$DiscoveryRunAsAccount"">`n                <ComputerName>$Target/Host/Property[Type=""$BaseClass""]/NetworkName$</ComputerName>`n        <RegistryAttributeDefinitions>`n      </RegistryAttributeDefinitions>`n      <Frequency>$Frequency</Frequency>`n      <ClassId>$MPElement[Name=""$DiscoveryClass""]$</ClassId>`n      <InstanceSettings>`n        <Settings>`n          <Setting>`n            <Name>$MPElement[Name=""Windows!Microsoft.Windows.Computer""]/PrincipalName$</Name>`n            <Value>$Target/Host/Property[Type=""Windows!Microsoft.Windows.Computer""]/PrincipalName$</Value>`n          </Setting>`n        </Settings>`n      </InstanceSettings>`n       </DataSource>`n      </Discovery>"
  $ClassContent | Set-Content $MPDiscoveryFile

  # Reloads the Class XML file with the new changes
  $ClassContent = Get-Content $MPDiscoveryFile

  # Writes the DisplayStrings to the XML so SCOM can read the display names correctly
  $FindLastDisplayStringLine = Select-String $MPDiscoveryFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$DiscoveryID"">`n     <Name>$DiscoveryName</Name>`n     <Description>$DiscoveryDescription</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPDiscoveryFile

  # Reloads the Class XML file with the new changes
  $ClassContent = Get-Content $MPDiscoveryFile

  # Writes the Knowledge Article to the XML so SCOM can read the display names correctly
  $FindLastKnowledgeArticleLine = Select-String $MPDiscoveryFile -pattern "</KnowledgeArticles>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastKnowledgeArticleLine] += "`n    <KnowledgeArticle ElementID=""$DiscoveryID"" Visible=""true"">`n     <MamlContent>`n     <maml:section xmlns:maml=""http://schemas.microsoft.com/maml/2004/10"">`n              <maml:title>$DiscoveryName</maml:title>`n              <maml:para>$KnowledgeArticle</maml:para>`n            </maml:section>`n          </MamlContent>`n    </KnowledgeArticle>"
  $ClassContent | Set-Content $MPDiscoveryFile

  }

############################################################################################################################################################
# Add-SCOMMPRegistryKey
# Create a new registry key used to discover a class
############################################################################################################################################################

  Function Add-SCOMMPRegistryKey
  {
   [cmdletbinding()]
  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter name for the attribute")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$AttributeName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the registry location of the key. Prefixed with HKLM for Local Machine")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$RegistryPath,

  [Parameter(Mandatory=$true,HelpMessage="Choose which path will be taken for the registry key discovery")]
  [ValidateSet('KeyExists','KeyValue')]
  [String]$PathType,

  [Parameter(Mandatory=$true,HelpMessage="Select the attribute type of the key being discovered")]
  [ValidateSet('Boolean','String','Integer','Float')]
  [String]$AttributeType,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the source class which will be used for the registry key discovery")]
  [Alias('SourceClassID')]
  [String]$ClassID,

  [Parameter(Mandatory=$true,HelpMessage="Location of the Discovery MPX file")]
  [String]$MPDiscoveryFile

  )

   # Sets PathType
   Switch ($PathType){
  'KeyExists' {$RegPathType = "0"}
  'KeyValue' {$RegPathType = "1"}
  }

   # Sets AttributeType
   Switch ($AttributeType){
  'Boolean' {$RegAttributeType = "0"}
  'String' {$RegAttributeType = "1"}
  'Integer' {$RegAttributeType = "2"}
  'Float' {$RegAttributeType = "3"}
  }

  # Reloads the Class XML file with the new changes
  $Data = "$" + "Data"
  $ClassContent = Get-Content $MPDiscoveryFile

  # Write Registry Key Attribute
  $FindRegistryAttributeDefinitionLine = Select-String $MPDiscoveryFile -pattern "</RegistryAttributeDefinitions>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindRegistryAttributeDefinitionLine] += "`n        <RegistryAttributeDefinition>`n            <AttributeName>$AttributeName</AttributeName>`n            <Path>$RegistryPath</Path>`n            <PathType>$RegPathType</PathType>`n            <AttributeType>$RegAttributeType</AttributeType>`n        </RegistryAttributeDefinition>"
  $ClassContent | Set-Content $MPDiscoveryFile

  # Reloads the Class XML file with the new changes
   $ClassContent = Get-Content $MPDiscoveryFile

 If ($RegPathType -eq "0")
  {
    # Write Expression
    $FindInstanceSettingsLine = Select-String $MPDiscoveryFile -pattern "</InstanceSettings>" | ForEach-Object {$_.LineNumber -1}
    $ClassContent[$FindInstanceSettingsLine] += "`n            <Expression>`n              <SimpleExpression>`n                <ValueExpression>`n                      <XPathQuery Type=""Boolean"">Values/$AttributeName</XPathQuery>`n                </ValueExpression>`n                  <Operator>Equal</Operator>`n                  <ValueExpression>`n                    <Value Type=""Boolean"">true</Value>`n                  </ValueExpression>`n              </SimpleExpression>`n            </Expression>"
    $ClassContent | Set-Content $MPDiscoveryFile

     # Reloads the Class XML file with the new changes
     $ClassContent = Get-Content $MPDiscoveryFile
    }
   Else
  {
     # Write Instance Value
    $FindSettingsLine = Select-String $MPDiscoveryFile -pattern "</Settings>" | ForEach-Object {$_.LineNumber -2}
    $ClassContent[$FindSettingsLine] += "`n          <Setting>`n            <Name>$MPElement[Name=""$ClassID""]/$AttributeName$</Name>`n            <Value>$Data/Values/$AttributeName$</Value>`n          </Setting>"
    $ClassContent | Set-Content $MPDiscoveryFile

     # Reloads the Class XML file with the new changes
     $ClassContent = Get-Content $MPDiscoveryFile
    }
}


############################################################################################################################################################
# Add-SCOMMPWMIDiscovery
# Adding relationships between different classes
############################################################################################################################################################

  Function Add-SCOMMPWMIDiscovery
  {
   [cmdletbinding()]

  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$DiscoveryName,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the discovery will be ran against")]
  [Alias('TargetClassID')][ValidateSet('WindowsComputer','WindowsApplicationComponent','WindowsLocalApplication','UnixComputer','ComputerGroup','InstanceGroup','ComputerHealthRollup', 'CustomClass')]
  [String[]]$DiscoveryTarget,

  [Parameter(Mandatory=$true,HelpMessage="Enter a description for the discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$DiscoveryDescription,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the source class which the properties will be extracted from to be added to")]
  [Alias('SourceClassID')]
  [String[]]$DiscoveryClass,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the Run As Account which will be used for this discovery")]
  [Alias('RunAsAccount')]
  [String[]]$DiscoveryRunAsAccount,
  
  [Parameter(Mandatory=$true,HelpMessage="Enter the namespace which the WMI will connect to ")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$Namespace,

  [Parameter(Mandatory=$true,HelpMessage="Enter the query which will be used for the Namespace")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$Query,

  [Parameter(Mandatory=$true,HelpMessage="Enter the frequency which the discovery will be ran at")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$Frequency,

  [Parameter(Mandatory=$false,HelpMessage="Enter a paragraph for the knowledgebase article for this discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$KnowledgeArticle,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Location of the Class MPX file")]
  [String[]]$MPClassFile,

  [Parameter(Mandatory=$true,HelpMessage="Location of the Discovery MPX file")]
  [String]$MPDiscoveryFile

  )

   # Sets ClassType
   Switch ($DiscoveryTarget){
  'WindowsComputer' {$BaseClass = 'Windows!Microsoft.Windows.ComputerRole'}
  'WindowsApplicationComponent' {$BaseClass = 'Windows!Microsoft.Windows.ApplicationComponent'}
  'WindowsLocalApplication' {$BaseClass = "Windows!Microsoft.Windows.LocalApplication"}
  'UnixComputer' {$BaseClass = 'Unix!Microsoft.Unix.ComputerRole'}
  'ComputerGroup' {$BaseClass = 'SC!Microsoft.SystemCenter.ComputerGroup'}
  'InstanceGroup' {$BaseClass = 'MSIL!Microsoft.SystemCenter.InstanceGroup'}
  'ComputerHealthRollup' {$BaseClass = 'System!System.ComputerRole'}
  'CustomClass' {$BaseClass = Read-Host "You have chosen to use a customclass as its target. Type the name of the class you wish to use as its type"}
  }
  

  # Reloads the Class XML file with the new changes
  $Target = "$" + "Target"
  $MPElement = "$" + "MPElement"
  $Data = "$" + "Data"
  $DiscoveryID = $DiscoveryName -replace " ", ""
  $ClassContent = Get-Content $MPDiscoveryFile

  # Retrieves the details for the Class created previously 
  $MPClassContent = Get-Content $MPClassFile

  # Finds all of the properties which were created from that particular class by searching the class.xml file
  $FindProperties = ((Get-Content $MPClassFile) -match "<DisplayString ElementID=""$DiscoveryClass"" SubElementID") -replace "<DisplayString ElementID=""$DiscoveryClass"" SubElementID", "<Property TypeID=""$DiscoveryClass"" PropertyID" -replace ">", " />"

  # Writes the Discovery ID to the XML Management Pack
  $FindDiscoveriesLine = Select-String $MPDiscoveryFile -pattern "</Discoveries>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindDiscoveriesLine] += "`n      <Discovery ID=""$DiscoveryID"" Target=""$BaseClass"" Enabled=""true"" ConfirmDelivery=""false"" Remotable=""true"" Priority=""Normal"">`n        <Category>Discovery</Category>`n        <DiscoveryTypes>`n          <DiscoveryClass TypeID=""$DiscoveryClass"">`n          $FindProperties`n          </DiscoveryClass>`n        </DiscoveryTypes>`n             <DataSource ID=""DS"" TypeID=""Windows!Microsoft.Windows.WmiProviderWithClassSnapshotDataMapper"" RunAs=""$DiscoveryRunAsAccount"">`n          <NameSpace>$NameSpace</NameSpace>`n          <Query>$Query</Query>`n          <Frequency>$Frequency</Frequency>`n          <ClassId>$MPElement[Name=""$DiscoveryClass""]$</ClassId>`n       <InstanceSettings>`n            <Settings>`n              <Setting>`n              <Name>$MPElement[Name=""Windows!Microsoft.Windows.Computer""]/PrincipalName$</Name>`n            <Value>$Target/Host/Property[Type=""Windows!Microsoft.Windows.Computer""]/PrincipalName$</Value>`n            </Setting>`n              <Setting>`n              <Name>$MPElement[Name=""System!System.Entity""]/DisplayName$</Name>`n            <Value>$Target/Host/Property[Type=""Windows!Microsoft.Windows.Computer""]/PrincipalName$</Value>`n            </Setting>`n              </Settings>`n              </InstanceSettings>`n        </DataSource>`n      </Discovery>"
  $ClassContent | Set-Content $MPDiscoveryFile

  # Reloads the Class XML file with the new changes
  $ClassContent = Get-Content $MPDiscoveryFile

   # Writes the DisplayStrings to the XML so SCOM can read the display names correctly
  $FindLastDisplayStringLine = Select-String $MPDiscoveryFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$DiscoveryID"">`n     <Name>$DiscoveryName</Name>`n     <Description>$DiscoveryDescription</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPDiscoveryFile

   # Reloads the Class XML file with the new changes
  $ClassContent = Get-Content $MPDiscoveryFile

  # Writes the Knowledge Article to the XML so SCOM can read the display names correctly
  $FindLastKnowledgeArticleLine = Select-String $MPDiscoveryFile -pattern "</KnowledgeArticles>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastKnowledgeArticleLine] += "`n    <KnowledgeArticle ElementID=""$DiscoveryID"" Visible=""true"">`n     <MamlContent>`n     <maml:section xmlns:maml=""http://schemas.microsoft.com/maml/2004/10"">`n              <maml:title>$DiscoveryName</maml:title>`n              <maml:para>$KnowledgeArticle</maml:para>`n            </maml:section>`n          </MamlContent>`n    </KnowledgeArticle>"
  $ClassContent | Set-Content $MPDiscoveryFile

  }

############################################################################################################################################################
# Add-SCOMMPVBScriptDiscovery
# Adding relationships between different classes
############################################################################################################################################################

  Function Add-SCOMMPVBScriptDiscovery
  {
   [cmdletbinding()]

  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$DiscoveryName,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the discovery will be ran against")]
  [Alias('TargetClassID')][ValidateSet('WindowsComputer','WindowsApplicationComponent','WindowsLocalApplication','UnixComputer','ComputerGroup','InstanceGroup','ComputerHealthRollup', 'CustomClass')]
  [String[]]$DiscoveryTarget,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the source class which the properties will be extracted from to be added to")]
  [Alias('SourceClassID')]
  [String[]]$DiscoveryClass,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the Run As Account which will be used for this discovery")]
  [Alias('RunAsAccount')]
  [String[]]$DiscoveryRunAsAccount,

  [Parameter(Mandatory=$true,HelpMessage="Enter a description for the discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$DiscoveryDescription,

  [Parameter(Mandatory=$true,HelpMessage="Enter the Interval based in seconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$IntervalSeconds,

  [Parameter(Mandatory=$false,HelpMessage="Enter a time based on 24 Hour clock to run at schedule")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$SyncTime,

  [Parameter(Mandatory=$true,HelpMessage="Enter the name of the powershell script the discovery will use")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$ScriptName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the timeout period based in seconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TimeoutSeconds,

  [Parameter(Mandatory=$false,HelpMessage="Enter a paragraph for the knowledgebase article for this discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$KnowledgeArticle,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Location of the Class MPX file")]
  [String[]]$MPClassFile,

  [Parameter(Mandatory=$true,HelpMessage="Location of the Discovery MPX file")]
  [String]$MPDiscoveryFile

  )

   # Sets ClassType
   Switch ($DiscoveryTarget){
  'WindowsComputer' {$BaseClass = 'Windows!Microsoft.Windows.ComputerRole'}
  'WindowsApplicationComponent' {$BaseClass = 'Windows!Microsoft.Windows.ApplicationComponent'}
  'WindowsLocalApplication' {$BaseClass = "Windows!Microsoft.Windows.LocalApplication"}
  'UnixComputer' {$BaseClass = 'Unix!Microsoft.Unix.ComputerRole'}
  'ComputerGroup' {$BaseClass = 'SC!Microsoft.SystemCenter.ComputerGroup'}
  'InstanceGroup' {$BaseClass = 'MSIL!Microsoft.SystemCenter.InstanceGroup'}
  'ComputerHealthRollup' {$BaseClass = 'System!System.ComputerRole'}
  'CustomClass' {$BaseClass = Read-Host "You have chosen to use a customclass as its target. Type the name of the class you wish to use as its type"}
  }

  # Reloads the Class XML file with the new changes
  $Target = "$" + "Target"
  $MPElement = "$" + "MPElement"
  $Data = "$" + "Data"
  $DiscoveryID = $DiscoveryName -replace " ", ""
  $IncludeFileContent = "$" + "IncludeFileContent"
  $ClassContent = Get-Content $MPDiscoveryFile

  # Retrieves the details for the Class created previously 
  $MPClassContent = Get-Content $MPClassFile

  # Finds all of the properties which were created from that particular class by searching the class.xml file
  $FindProperties = ((Get-Content $MPClassFile) -match "<DisplayString ElementID=""$DiscoveryClass"" SubElementID") -replace "<DisplayString ElementID=""$DiscoveryClass"" SubElementID", "<Property TypeID=""$DiscoveryClass"" PropertyID" -replace ">", " />"

  # Writes the Discovery ID to the XML Management Pack
  $FindDiscoveriesLine = Select-String $MPDiscoveryFile -pattern "</Discoveries>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindDiscoveriesLine] += "`n      <Discovery ID=""$DiscoveryID"" Target=""$BaseClass"" Enabled=""true"" ConfirmDelivery=""false"" Remotable=""true"" Priority=""Normal"">`n        <Category>Discovery</Category>`n        <DiscoveryTypes>`n          <DiscoveryClass TypeID=""$DiscoveryClass"">`n          $FindProperties`n          </DiscoveryClass>`n        </DiscoveryTypes>`n             <DataSource ID=""DS"" TypeID=""Windows!Microsoft.Windows.TimedScript.DiscoveryProvider"" RunAs=""$DiscoveryRunAsAccount"">`n          <IntervalSeconds>$IntervalSeconds</IntervalSeconds>`n          <SyncTime>$SyncTime</SyncTime>`n          <ScriptName>$ScriptName</ScriptName>`n          <Arguments>$MPElement$ $Target/Id$ $Target/Host/Property[Type=""Windows!Microsoft.Windows.Computer""]/PrincipalName$</Arguments>`n         <ScriptBody>$IncludeFileContent/$ScriptName$</ScriptBody>`n         <TimeoutSeconds>$TimeoutSeconds</TimeoutSeconds>`n        </DataSource>`n      </Discovery>"
  $ClassContent | Set-Content $MPDiscoveryFile

  # Reloads the Class XML file with the new changes
  $ClassContent = Get-Content $MPDiscoveryFile

   # Writes the DisplayStrings to the XML so SCOM can read the display names correctly
  $FindLastDisplayStringLine = Select-String $MPDiscoveryFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$DiscoveryID"">`n     <Name>$DiscoveryName</Name>`n     <Description>$DiscoveryDescription</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPDiscoveryFile

   # Reloads the Class XML file with the new changes
  $ClassContent = Get-Content $MPDiscoveryFile

  # Writes the Knowledge Article to the XML so SCOM can read the display names correctly
  $FindLastKnowledgeArticleLine = Select-String $MPDiscoveryFile -pattern "</KnowledgeArticles>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastKnowledgeArticleLine] += "`n    <KnowledgeArticle ElementID=""$DiscoveryID"" Visible=""true"">`n     <MamlContent>`n     <maml:section xmlns:maml=""http://schemas.microsoft.com/maml/2004/10"">`n              <maml:title>$DiscoveryName</maml:title>`n              <maml:para>$KnowledgeArticle</maml:para>`n            </maml:section>`n          </MamlContent>`n    </KnowledgeArticle>"
  $ClassContent | Set-Content $MPDiscoveryFile
 
  } 

############################################################################################################################################################
# Add-SCOMMPUnixShellCommandDiscovery
# Adding relationships between different classes
############################################################################################################################################################

  Function Add-SCOMMPUnixShellCommandDiscovery
  {
   [cmdletbinding()]

  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$DiscoveryName,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the discovery will be ran against")]
  [Alias('TargetClassID')][ValidateSet('WindowsComputer','WindowsApplicationComponent','WindowsLocalApplication','UnixComputer','ComputerGroup','InstanceGroup','ComputerHealthRollup', 'CustomClass')]
  [String[]]$DiscoveryTarget,

  [Parameter(Mandatory=$true,HelpMessage="Enter a description for the discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$DiscoveryDescription,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the source class which the properties will be extracted from to be added to")]
  [Alias('SourceClassID')]
  [String[]]$DiscoveryClass,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the Run As Account which will be used for this discovery")]
  [Alias('RunAsAccount')]
  [String[]]$DiscoveryRunAsAccount,

  [Parameter(Mandatory=$true,HelpMessage="Enter the shell command which will be used")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$ShellCommand,

  [Parameter(Mandatory=$true,HelpMessage="Enter the pattern which will need to be discovered")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$Pattern,

  [Parameter(Mandatory=$true,HelpMessage="Enter the interval in seconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$Interval,

  [Parameter(Mandatory=$true,HelpMessage="Enter the timeout in seconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$Timeout,

  [Parameter(Mandatory=$false,HelpMessage="Enter a paragraph for the knowledgebase article for this discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$KnowledgeArticle,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Location of the Class MPX file")]
  [String[]]$MPClassFile,

  [Parameter(Mandatory=$true,HelpMessage="Location of the Discovery MPX file")]
  [String]$MPDiscoveryFile

  )

   # Sets ClassType
   Switch ($DiscoveryTarget){
  'WindowsComputer' {$BaseClass = 'Windows!Microsoft.Windows.ComputerRole'}
  'WindowsApplicationComponent' {$BaseClass = 'Windows!Microsoft.Windows.ApplicationComponent'}
  'WindowsLocalApplication' {$BaseClass = "Windows!Microsoft.Windows.LocalApplication"}
  'UnixComputer' {$BaseClass = 'Unix!Microsoft.Unix.ComputerRole'}
  'ComputerGroup' {$BaseClass = 'SC!Microsoft.SystemCenter.ComputerGroup'}
  'InstanceGroup' {$BaseClass = 'MSIL!Microsoft.SystemCenter.InstanceGroup'}
  'ComputerHealthRollup' {$BaseClass = 'System!System.ComputerRole'}
  'CustomClass' {$BaseClass = Read-Host "You have chosen to use a customclass as its target. Type the name of the class you wish to use as its type"}
  }


  # Reloads the Class XML file with the new changes
  $Target = "$" + "Target"
  $MPElement = "$" + "MPElement"
  $Data = "$" + "Data"
  $DiscoveryID = $DiscoveryName -replace " ", ""
  $IncludeFileContent = "$" + "IncludeFileContent"
  $ClassContent = Get-Content $MPDiscoveryFile

  # Retrieves the details for the Class created previously 
  $MPClassContent = Get-Content $MPClassFile

  # Finds all of the properties which were created from that particular class by searching the class.xml file
  $FindProperties = ((Get-Content $MPClassFile) -match "<DisplayString ElementID=""$DiscoveryClass"" SubElementID") -replace "<DisplayString ElementID=""$DiscoveryClass"" SubElementID", "<Property TypeID=""$DiscoveryClass"" PropertyID" -replace ">", " />"

  # Write Unix Shell Commmand Discovery
  $FindDiscoveriesLine = Select-String $MPDiscoveryFile -pattern "</Discoveries>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindDiscoveriesLine] += "`n      <Discovery ID=""$DiscoveryID"" Target=""$BaseClass"" Enabled=""false"" ConfirmDelivery=""false"" Remotable=""true"" Priority=""Normal"">`n        <Category>Discovery</Category>`n        <DiscoveryTypes>`n          <DiscoveryClass TypeID=""$DiscoveryClass"">`n            $FindProperties`n          </DiscoveryClass>`n        </DiscoveryTypes>`n             <DataSource ID=""DS"" TypeID=""UnixAuth!Unix.Authoring.TimedShellCommand.Discovery.DataSource"" RunAs=""$DiscoveryRunAsAccount"">`n          <Interval>$Interval</Interval>`n          <TargetSystem>$Target/Host/Property[Type=""Unix!Microsoft.Unix.Computer""]/PrincipalName$</TargetSystem>`n          <ShellCommand>$ShellCommand</ShellCommand>`n          <Timeout>$Timeout</Timeout>`n          <UserName>$RunAs[Name=""$DiscoveryRunAsAccount""]/UserName$</UserName>`n          <Password>$RunAs[Name=""$DiscoveryRunAsAccount""]/Password$</Password>`n    <FilterExpression>`n      <RegExExpression>`n        <ValueExpression>`n          <XPathQuery>//*[local-name()=""StdOut""]</XPathQuery>`n        </ValueExpression>`n        <Operator>MatchesRegularExpression</Operator>`n        <Pattern>$Pattern</Pattern>`n      </RegExExpression>`n    </FilterExpression>`n    <ClassId>$MPElement[Name=""$DiscoveryClass""]$</ClassId>`n    <InstanceSettings>`n      <Settings>`n        <Setting>`n          <Name>$MPElement[Name='Unix!Microsoft.Unix.Computer']/PrincipalName$</Name>`n          <Value>$Target/Host/Property[Type=""Unix!Microsoft.Unix.Computer""]/PrincipalName$</Value>`n        </Setting>`n        <Setting>`n          <Name>$MPElement[Name='System!System.Entity']/DisplayName$</Name>`n          <Value>$Target/Host/Property[Type=""Unix!Microsoft.Unix.Computer""]/PrincipalName$</Value>`n        </Setting>`n      </Settings>`n    </InstanceSettings>`n  </DataSource>`n      </Discovery>"
  $ClassContent | Set-Content $MPDiscoveryFile

  # Reloads the Class XML file with the new changes
  $ClassContent = Get-Content $MPDiscoveryFile

  # Writes the DisplayStrings to the XML so SCOM can read the display names correctly
  $FindLastDisplayStringLine = Select-String $MPDiscoveryFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$DiscoveryID"">`n     <Name>$DiscoveryName</Name>`n     <Description>$DiscoveryDescription</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPDiscoveryFile

  # Reloads the Class XML file with the new changes
  $ClassContent = Get-Content $MPDiscoveryFile

  # Writes the Knowledge Article to the XML so SCOM can read the display names correctly
  $FindLastKnowledgeArticleLine = Select-String $MPDiscoveryFile -pattern "</KnowledgeArticles>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastKnowledgeArticleLine] += "`n    <KnowledgeArticle ElementID=""$DiscoveryID"" Visible=""true"">`n     <MamlContent>`n     <maml:section xmlns:maml=""http://schemas.microsoft.com/maml/2004/10"">`n              <maml:title>$DiscoveryName</maml:title>`n              <maml:para>$KnowledgeArticle</maml:para>`n            </maml:section>`n          </MamlContent>`n    </KnowledgeArticle>"
  $ClassContent | Set-Content $MPDiscoveryFile

  }

############################################################################################################################################################
# Add-SCOMMPComputerGroupDiscovery
# Adding relationships between different classes
############################################################################################################################################################

  Function Add-SCOMMPComputerGroupDiscovery
  {
   [cmdletbinding()]

  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$DiscoveryName,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the discovery will be ran against")]
  [Alias('TargetClassID')][ValidateSet('WindowsComputer','WindowsApplicationComponent','WindowsLocalApplication','UnixComputer','ComputerGroup','InstanceGroup','ComputerHealthRollup', 'CustomClass')]
  [String[]]$DiscoveryTarget,

  [Parameter(Mandatory=$true,HelpMessage="Enter a description for the discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$DiscoveryDescription,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the source class which the properties will be extracted from to be added to")]
  [Alias('SourceClassID')]
  [String[]]$DiscoveryClass,

  [Parameter(Mandatory=$false,HelpMessage="Enter a paragraph for the knowledgebase article for this discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$KnowledgeArticle,

  [Parameter(Mandatory=$true,HelpMessage="Location of the Discovery MPX file")]
  [String]$MPDiscoveryFile

  )

   # Sets ClassType
   Switch ($DiscoveryTarget){
  'WindowsComputer' {$BaseClass = 'Windows!Microsoft.Windows.ComputerRole'}
  'WindowsApplicationComponent' {$BaseClass = 'Windows!Microsoft.Windows.ApplicationComponent'}
  'WindowsLocalApplication' {$BaseClass = "Windows!Microsoft.Windows.LocalApplication"}
  'UnixComputer' {$BaseClass = 'Unix!Microsoft.Unix.ComputerRole'}
  'ComputerGroup' {$BaseClass = 'SC!Microsoft.SystemCenter.ComputerGroup'}
  'InstanceGroup' {$BaseClass = 'MSIL!Microsoft.SystemCenter.InstanceGroup'}
  'ComputerHealthRollup' {$BaseClass = 'System!System.ComputerRole'}
  }


  # Reloads the Class XML file with the new changes
  $MPElement = "$" + "MPElement"
  $DiscoveryID = $DiscoveryName -replace " ", ""
  $ClassContent = Get-Content $MPDiscoveryFile

  # Write Computer Group Discovery
  $FindDiscoveriesLine = Select-String $MPDiscoveryFile -pattern "</Discoveries>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindDiscoveriesLine] += "`n      <Discovery ID=""$DiscoveryID"" Target=""$BaseClass"" Enabled=""false"" ConfirmDelivery=""false"" Remotable=""true"" Priority=""Normal"">`n        <Category>Discovery</Category>`n        <DiscoveryTypes />`n        <DataSource ID=""DS"" TypeID=""SC!Microsoft.SystemCenter.GroupPopulator"">`n          <RuleId>$MPElement$</RuleId>`n          <GroupInstanceId>$MPElement[Name=""$DiscoveryName""]$</GroupInstanceId>`n          <MembershipRules>`n            <MembershipRule>`n              <MonitoringClass>$MPElement[Name=""$BaseClass""]$</MonitoringClass>`n              <RelationshipClass>$MPElement[Name=""SC!Microsoft.SystemCenter.ComputerGroupContainsComputer""]$</RelationshipClass>`n              <Expression>`n                <Contains>`n                  <MonitoringClass>$MPElement[Name=""$DiscoveryClass""]$</MonitoringClass>`n                </Contains>`n              </Expression>`n            </MembershipRule>`n          </MembershipRules>`n        </DataSource>`n      </Discovery>"
  $ClassContent | Set-Content $MPDiscoveryFile

  # Reloads the Class XML file with the new changes
  $ClassContent = Get-Content $MPDiscoveryFile

  # Writes the DisplayStrings to the XML so SCOM can read the display names correctly
  $FindLastDisplayStringLine = Select-String $MPDiscoveryFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$DiscoveryID"">`n     <Name>$DiscoveryName</Name>`n     <Description>$DiscoveryDescription</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPDiscoveryFile
  
  # Reloads the Class XML file with the new changes  
  $ClassContent = Get-Content $MPDiscoveryFile

  # Writes the Knowledge Article to the XML so SCOM can read the display names correctly
  $FindLastKnowledgeArticleLine = Select-String $MPDiscoveryFile -pattern "</KnowledgeArticles>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastKnowledgeArticleLine] += "`n    <KnowledgeArticle ElementID=""$DiscoveryID"" Visible=""true"">`n     <MamlContent>`n     <maml:section xmlns:maml=""http://schemas.microsoft.com/maml/2004/10"">`n              <maml:title>$DiscoveryName</maml:title>`n              <maml:para>$KnowledgeArticle</maml:para>`n            </maml:section>`n          </MamlContent>`n    </KnowledgeArticle>"
  $ClassContent | Set-Content $MPDiscoveryFile

  }

############################################################################################################################################################
# Add-SCOMMPRegistryDiscovery
# Adding relationships between different classes
############################################################################################################################################################

  Function Add-SCOMMPInstanceGroupDiscovery
  {
   [cmdletbinding()]

  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$DiscoveryName,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the discovery will be ran against")]
  [Alias('TargetClassID')][ValidateSet('WindowsComputer','WindowsApplicationComponent','WindowsLocalApplication','UnixComputer','ComputerGroup','InstanceGroup','ComputerHealthRollup')]
  [String[]]$DiscoveryTarget,

  [Parameter(Mandatory=$true,HelpMessage="Enter a description for the discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$DiscoveryDescription,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the source class which the properties will be extracted from to be added to")]
  [Alias('SourceClassID')]
  [String[]]$DiscoveryClass,

  [Parameter(Mandatory=$false,HelpMessage="Enter a paragraph for the knowledgebase article for this discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$KnowledgeArticle,

  [Parameter(Mandatory=$true,HelpMessage="Location of the Discovery MPX file")]
  [String]$MPDiscoveryFile

  )

   # Sets ClassType
   Switch ($DiscoveryTarget){
  'WindowsComputer' {$BaseClass = 'Windows!Microsoft.Windows.ComputerRole'}
  'WindowsApplicationComponent' {$BaseClass = 'Windows!Microsoft.Windows.ApplicationComponent'}
  'WindowsLocalApplication' {$BaseClass = $ClassType = "Windows!Microsoft.Windows.LocalApplication"}
  'UnixComputer' {$BaseClass = 'Unix!Microsoft.Unix.ComputerRole'}
  'ComputerGroup' {$BaseClass = 'SC!Microsoft.SystemCenter.ComputerGroup'}
  'InstanceGroup' {$BaseClass = 'MSIL!Microsoft.SystemCenter.InstanceGroup'}
  'ComputerHealthRollup' {$BaseClass = 'System!System.ComputerRole'}
  }

  # Reloads the Class XML file with the new changes
  $MPElement = "$" + "MPElement"
  $DiscoveryID = $DiscoveryName -replace " ", ""
  $ClassContent = Get-Content $MPDiscoveryFile

  # Write Computer Group Discovery
  $FindDiscoveriesLine = Select-String $MPDiscoveryFile -pattern "</Discoveries>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindDiscoveriesLine] += "`n      <Discovery ID=""$DiscoveryID"" Target=""$BaseClass"" Enabled=""false"" ConfirmDelivery=""false"" Remotable=""true"" Priority=""Normal"">`n        <Category>Discovery</Category>`n        <DiscoveryTypes />`n        <DataSource ID=""DS"" TypeID=""SC!Microsoft.SystemCenter.GroupPopulator"">`n          <RuleId>$MPElement$</RuleId>`n          <GroupInstanceId>$MPElement[Name=""$DiscoveryName""]$</GroupInstanceId>`n          <MembershipRules>`n            <MembershipRule>`n              <MonitoringClass>$MPElement[Name=""Windows!Microsoft.Windows.Computer""]$</MonitoringClass>`n              <RelationshipClass>$MPElement[Name=""MSIL!Microsoft.SystemCenter.InstanceGroupContainsEntities""]$</RelationshipClass>`n              <Expression>`n                <Contains>`n                  <MonitoringClass>$MPElement[Name=""$DiscoveryClass""]$</MonitoringClass>`n                </Contains>`n              </Expression>`n            </MembershipRule>`n          </MembershipRules>`n        </DataSource>`n      </Discovery>"
  $ClassContent | Set-Content $MPDiscoveryFile

  # Reloads the Class XML file with the new changes
  $ClassContent = Get-Content $MPDiscoveryFile

  # Writes the DisplayStrings to the XML so SCOM can read the display names correctly
  $FindLastDisplayStringLine = Select-String $MPDiscoveryFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$DiscoveryID"">`n     <Name>$DiscoveryName</Name>`n     <Description>$DiscoveryDescription</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPDiscoveryFile
  
  # Reloads the Class XML file with the new changes
  $ClassContent = Get-Content $MPDiscoveryFile

  # Writes the Knowledge Article to the XML so SCOM can read the display names correctly
  $FindLastKnowledgeArticleLine = Select-String $MPDiscoveryFile -pattern "</KnowledgeArticles>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastKnowledgeArticleLine] += "`n    <KnowledgeArticle ElementID=""$DiscoveryID"" Visible=""true"">`n     <MamlContent>`n     <maml:section xmlns:maml=""http://schemas.microsoft.com/maml/2004/10"">`n              <maml:title>$DiscoveryName</maml:title>`n              <maml:para>$KnowledgeArticle</maml:para>`n            </maml:section>`n          </MamlContent>`n    </KnowledgeArticle>"
  $ClassContent | Set-Content $MPDiscoveryFile

  }

############################################################################################################################################################
# Create-PowerShellScript
# Adding relationships between different classes
############################################################################################################################################################

 Function Create-PowerShellScript 
 {
  [cmdletbinding()]

  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter the name of the PowerShell script")]
  [String]$ScriptName,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the source class which the properties will be extracted from to be added to")]
  [Alias('SourceClassID')]
  [String[]]$DiscoveryClass,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Location of the Class MPX file")]
  [String[]]$MPClassFile

  )

  # Wrties variable values which are specific to Visual Studios
  $Instance = "$" + "instance"
  $SourceID = "$" + "sourceid"
  $ManagedEntityId = "$" + "managedEntityId"
  $Computername = "$" + "computerName"
  $api = "$" + "api"
  $discoveryData = "$" + "discoveryData"

  # Grabbing all of the properties
  $PropertiesDetection = (((Get-Content $MPClassFile) -match "<DisplayString ElementID=""$DiscoveryClass"" SubElementID") -replace "<DisplayString ElementID=""$DiscoveryClass"" SubElementID=""","" -replace """", "" -replace ">", "").Trim()

  # Writes the PowerShell Discovery script logic
  Add-Content $ScriptName "param($sourceId,$managedEntityId,$computerName)`n `n$api = new-object -comObject 'MOM.ScriptAPI'`n$discoveryData = $api.CreateDiscoveryData(0, $SourceId, $ManagedEntityId)"
  Add-Content $ScriptName "`n$Instance = $discoveryData.CreateClassInstance(""$MPElement[Name='$DiscoveryClass']$"")`n$instance.AddProperty(""$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$"", $computerName) "
  Add-Content $ScriptName "`n <Insert Script Here>"
  ForEach ($line in $PropertiesDetection) {Add-Content $ScriptName "`n$Instance.AddProperty(""$MPElement[Name='$DiscoveryClass']/$line$,#Add Variable Here to Discovery this property#"")"}
  Add-Content $ScriptName "`n$discoveryData.AddInstance($instance)"
  Add-Content $ScriptName "`n$discoveryData"

  Write-Host "Edit the PowerShell script to contain your script portion for the discovery. Start from under the $Discoverydata line" -ForegroundColor Yellow
  Write-Host "The Script will contain the properties lines. Make sure you add the variable next to the "\," and comments character to assure that the property will be discovered by your script portion" -ForegroundColor Yellow

  }

############################################################################################################################################################
# Create-VBScript
# Adding relationships between different classes
############################################################################################################################################################

  Function Create-VBScript
  {
   [cmdletbinding()]

  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter the name of the VB script")]
  [String]$ScriptName,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the source class which the properties will be extracted from to be added to")]
  [Alias('SourceClassID')]
  [String[]]$DiscoveryClass,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Location of the Class MPX file")]
  [String[]]$MPClassFile

  )

  # Wrties variable values which are specific to Visual Studios
  $Instance = "$" + "instance"
  $SourceID = "$" + "sourceid"
  $ManagedEntityId = "$" + "managedEntityId"
  $Computername = "$" + "computerName"
  $api = "$" + "api"
  $discoveryData = "$" + "discoveryData"
  $MPElement = "$" + "MPElement"

  # Grabbing all of the properties
  $PropertiesDetection = (((Get-Content $MPClassFile) -match "<DisplayString ElementID=""$DiscoveryClass"" SubElementID") -replace "<DisplayString ElementID=""$DiscoveryClass"" SubElementID=""","" -replace """", "" -replace ">", "").Trim()

  # Write VBScript
  Add-Content $ScriptName "SourceId = WScript.Arguments(0)"
  Add-Content $ScriptName "ManagedEntityId = WScript.Arguments(1)"
  Add-Content $ScriptName "sComputerName = WScript.Arguments(2)"
  Add-Content $ScriptName "`nSet oAPI = CreateObject(""MOM.ScriptAPI"")"
  Add-Content $ScriptName "Set oDiscoveryData = oAPI.CreateDiscoveryData(0, SourceId, ManagedEntityId)"
  Add-Content $ScriptName "`nFor i = 1 to 3"
  Add-Content $ScriptName "Set oInstance = oDiscoveryData.CreateClassInstance (""$MPElement[Name='$DiscoveryClass']$"") "
  Add-Content $ScriptName "oInstance.AddProperty ""$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$"", sComputerName"
  ForEach ($line in $PropertiesDetection) {Add-Content $ScriptName "oInstance.AddProperty ""$MPElement[Name='$DiscoveryClass']/$line$"","}

  Write-Host "Edit the VB script to contain your script portion for the discovery. Start from under the Discoverydata line" -ForegroundColor Yellow
  Write-Host "The Script will contain the properties lines. Make sure you add the variable next to the "\," and comments character to assure that the property will be discovered by your script portion" -ForegroundColor Yellow

  }

############################################################################################################################################################
# New-SCOMMPFolder
# Add New Views to your view class
############################################################################################################################################################

  Function New-SCOMMPFolder
  {
   [cmdletbinding()]

  Param (

  [Parameter(Mandatory=$true,HelpMessage="Location of the Folder MPX file")]
  [String]$MPFolderFile
  )

  Add-Content $MPFolderFile "<ManagementPackFragment SchemaVersion=""2.0"" xmlns:xsd=""http://www.w3.org/2001/XMLSchema"">`n  <Presentation>`n    <Folders>`n    </Folders>`n    <FolderItems>`n    </FolderItems>`n  </Presentation>`n  <LanguagePacks>`n   <LanguagePack ID=""ENU"" IsDefault=""true"">`n            <DisplayStrings>`n      </DisplayStrings>`n    </LanguagePack>`n  </LanguagePacks>`n</ManagementPackFragment>"

  }

############################################################################################################################################################
# Add-SCOMMPFolder
# Add New Views to your view class
############################################################################################################################################################

  Function Add-SCOMMPFolder
  {
   [cmdletbinding()]

  Param (
  [Parameter(Mandatory=$true,HelpMessage="Enter the name of the folder")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$FolderName,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the parent folder ID. Default value is to place at the root")]
  [Alias('FolderID')]
  [String]$FolderParent = 'SC!Microsoft.SystemCenter.Monitoring.ViewFolder.Root',

  [Parameter(Mandatory=$true,HelpMessage="Location of the Folder MPX file")]
  [String]$MPFolderFile

  )

  # Wrties variable values which are specific to Visual Studios
  $FolderID = $FolderName -replace " ", "."
  $ClassContent = Get-Content $MPFolderFile

  # Writes the Folder XML to the management pack
  $FindFoldersline = Select-String $MPFolderFile -pattern "</Folders>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindFoldersline] += "`n      <Folder ID=""$FolderID"" Accessibility=""Internal"" ParentFolder=""$FolderParent"" />"
  $ClassContent | Set-Content $MPFolderFile

  #Reload content
  $ClassContent = Get-Content $MPFolderFile

  # Writes the DisplayStrings to the XML so SCOM can read the display names correctly
  $FindLastDisplayStringLine = Select-String $MPFolderFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$FolderID"">`n     <Name>$FolderName</Name>`n     <Description>$FolderDescription</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPFolderFile

} 

############################################################################################################################################################
# New-SCOMMPView
# Create new MPX file for your View classes
############################################################################################################################################################

  Function New-SCOMMPView
  {
   [cmdletbinding()]
  Param (

  [Parameter(Mandatory=$true,HelpMessage="Location of the View MPX file")]
  [String]$MPViewFile

  )

  Add-Content $MPViewFile "<ManagementPackFragment SchemaVersion=""2.0"" xmlns:xsd=""http://www.w3.org/2001/XMLSchema"">`n  <Presentation>`n    <Views>`n    </Views>`n    <FolderItems>`n    </FolderItems>`n  </Presentation>`n  <LanguagePacks>`n   <LanguagePack ID=""ENU"" IsDefault=""true"">`n    <DisplayStrings>`n      </DisplayStrings>`n    </LanguagePack>`n  </LanguagePacks>`n</ManagementPackFragment>"

  }

############################################################################################################################################################
# Add-SCOMMPView
# Add New Views to your view class
############################################################################################################################################################

  Function Add-SCOMMPView
  {
    [cmdletbinding()]

  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the view class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$ViewName,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the view will contain objects from")]
  [Alias('TargetClassID')]
  [String[]]$ViewTarget,

  [Parameter(Mandatory=$true,HelpMessage="Select the view type which will be created")]
  [ValidateSet('AlertView','DashboardView','DiagramView','EventView','InventoryView','ManagedObjectView','PerformanceView','OverridesView','StateView','StateDetailView','TaskStatusView','URLView')]
  [String[]]$ViewType,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the folder ID of where the view will be placed")]
  [AllowNull()]
  [AllowEmptyString()]
  [String[]]$FolderID,

  [Parameter(Mandatory=$true,HelpMessage="Location of the View MPX file")]
  [String]$MPViewFile

  )

   # Sets ViewType
   Switch ($ViewType){
  'AlertView' {$MPViewType = 'SC!Microsoft.SystemCenter.AlertViewType'}
  'DashboardView' {$MPViewType = 'SC!Microsoft.SystemCenter.DashboardViewType'}
  'DiagramView' {$MPViewType = "SC!Microsoft.SystemCenter.DiagramViewType"}
  'EventView' {$MPViewType = 'SC!Microsoft.SystemCenter.EventViewType'}
  'InventoryView' {$MPViewType = 'SC!Microsoft.SystemCenter.InventoryViewType'}
  'ManagedObjectView' {$MPViewType = 'MSIL!Microsoft.SystemCenter.InstanceGroup'}
  'PerformanceView' {$MPViewType = 'SC!Microsoft.SystemCenter.PerformanceViewType'}
  'OverridesView' {$MPViewType = 'SC!Microsoft.SystemCenter.OverridesSummaryViewType'}
  'StateView' {$MPViewType = 'SC!Microsoft.SystemCenter.StateViewType'}
  'StateDetailView' {$MPViewType = 'SC!Microsoft.SystemCenter.StateDetailDefinitionViewType'}
  'TaskStatusView' {$MPViewType = 'SC!Microsoft.SystemCenter.TaskStatusViewType'}
  'UrlView' {$MPViewType = 'SC!Microsoft.SystemCenter.UrlViewType'}
  }


 # Wrties variable values which are specific to Visual Studios
 $ViewID = $ViewName -replace " ", "."
 $ClassContent = Get-Content $MPViewFile
 #$ViewTarget = $ViewTarget -replace " ", "."

 # Writes the view XML to the management pack

  # Sets ViewType
  If ($MPViewType -eq "SC!Microsoft.SystemCenter.AlertViewType") {
   $FindViewsline = Select-String $MPViewFile -pattern "</views>" | ForEach-Object {$_.LineNumber -2}
   $ClassContent[$FindViewsline] += "`n      <View ID=""$ViewID"" Accessibility=""Internal"" Target=""$ViewTarget"" TypeID=""$MPViewType"" Visible=""true"">`n        <Category>Operations</Category>`n        <Criteria>`n          <!--Use Error, Warning or Success for Severity-->`n          <!--To use multiple severities copy the Severity line and add another severity-->`n          <!--If wanting to display everything delete from <SeverityList> to </SeverityList>-->`n          <SeverityList>`n            <Severity>Error</Severity>`n          </SeverityList>`n          <!--Use High, Medium or Low for Priority-->`n          <!--To use multiple priorities copy the Priority line and add another Priority-->`n          <!--If wanting to display everything delete from <PriorityList> to </PriorityList>-->`n          <PriorityList>`n            <Priority>Medium</Priority>`n          </PriorityList>`n          <!--Enter the resolution state number to the <State> switch display only those resolution states-->`n          <!--To use multiple resolution states copy the State line and add another state-->`n          <!--If wanting to display everything delete from <ResolutionState> to </ResolutionState>-->`n          <ResolutionState>`n            <State>0</State>`n          </ResolutionState>`n        </Criteria>`n      </View>"
   $ClassContent | Set-Content $MPViewFile
   Write-Host "You can add Resolution States, Severity and Priority filtering to the XML in the switches within Visual Studio" -ForegroundColor Yellow
   }

  If ($MPViewType -eq "SC!Microsoft.SystemCenter.DashboardViewType") {
   $FindViewsline = Select-String $MPViewFile -pattern "</views>" | ForEach-Object {$_.LineNumber -2}
   $ClassContent[$FindViewsline] += "`n      <View ID=""$ViewID"" Accessibility=""Internal"" Target=""$ViewTarget"" TypeID=""$MPViewType"" Visible=""true"">`n        <Category>Operations</Category>`n      </View>"
   $ClassContent | Set-Content $MPViewFile
  }
  
  If ($MPViewType -eq "SC!Microsoft.SystemCenter.DiagramViewType") {
   $FindViewsline = Select-String $MPViewFile -pattern "</views>" | ForEach-Object {$_.LineNumber -2}
   $ClassContent[$FindViewsline] += "`n      <View ID=""$ViewID"" Accessibility=""Internal"" Target=""$ViewTarget"" TypeID=""$MPViewType"" Visible=""true"">`n        <Category>Operations</Category>`n      </View>"
   $ClassContent | Set-Content $MPViewFile
  }
  
  If ($MPViewType -eq "SC!Microsoft.SystemCenter.EventViewType") {
   $FindViewsline = Select-String $MPViewFile -pattern "</views>" | ForEach-Object {$_.LineNumber -2}
   $ClassContent[$FindViewsline] += "`n      <View ID=""$ViewID"" Accessibility=""Internal"" Target=""$ViewTarget"" TypeID=""$MPViewType"" Visible=""true"">`n        <Category>Operations</Category>`n        <Criteria>`n          <EventNumberList>`n            <EventNumber></EventNumber>`n          </Criteria>      </View>"
   $ClassContent | Set-Content $MPViewFile
   Write-Host "You can add the Event number filtering to the XML in the switches within Visual Studio" -ForegroundColor Yellow
  }
  
  If ($MPViewType -eq "SC!Microsoft.SystemCenter.InventoryViewType") {
   $FindViewsline = Select-String $MPViewFile -pattern "</views>" | ForEach-Object {$_.LineNumber -2}
   $ClassContent[$FindViewsline] += "`n      <View ID=""$ViewID"" Accessibility=""Internal"" Target=""$ViewTarget"" TypeID=""$MPViewType"" Visible=""true"">`n        <Category>Operations</Category>`n      </View>"
   $ClassContent | Set-Content $MPViewFile  
  }
  
  If ($MPViewType -eq "SC!Microsoft.SystemCenter.ManagedObjectViewType") {
   $ViewType = "SC!Microsoft.SystemCenter.ManagedObjectViewType"
   $FindViewsline = Select-String $MPViewFile -pattern "</views>" | ForEach-Object {$_.LineNumber -2}
   $ClassContent[$FindViewsline] += "`n      <View ID=""$ViewID"" Accessibility=""Internal"" Target=""$ViewTarget"" TypeID=""$MPViewType"" Visible=""true"">`n        <Category>Operations</Category>`n      </View>"
   $ClassContent | Set-Content $MPViewFile  }
  
  If ($MPViewType -eq "SC!Microsoft.SystemCenter.PerformanceViewType") {
   $FindViewsline = Select-String $MPViewFile -pattern "</views>" | ForEach-Object {$_.LineNumber -2}
   $ClassContent[$FindViewsline] += "`n      <View ID=""$ViewID"" Accessibility=""Internal"" Target=""$ViewTarget"" TypeID=""$MPViewType"" Visible=""true"">`n        <Category>Operations</Category>`n        <Criteria>`n          <Object></Object>`n          <Instance>test</Instance>`n          <Counter></Counter>`n        </Criteria>`n      </View>"
   $ClassContent | Set-Content $MPViewFile
   }
  
  If ($MPViewType -eq "SC!Microsoft.SystemCenter.OverridesSummaryViewType") {
   $ViewType = "SC!Microsoft.SystemCenter.OverridesSummaryViewType"
   $FindViewsline = Select-String $MPViewFile -pattern "</views>" | ForEach-Object {$_.LineNumber -2}
   $ClassContent[$FindViewsline] += "`n      <View ID=""$ViewID"" Accessibility=""Internal"" Target=""$ViewTarget"" TypeID=""$MPViewType"" Visible=""true"">`n        <Category>Operations</Category>`n      </View>"
   $ClassContent | Set-Content $MPViewFile
   }
  
  If ($MPViewType -eq "SC!Microsoft.SystemCenter.StateViewType") {
   $FindViewsline = Select-String $MPViewFile -pattern "</views>" | ForEach-Object {$_.LineNumber -2}
   $ClassContent[$FindViewsline] += "`n      <View ID=""$ViewID"" Accessibility=""Internal"" Target=""$ViewTarget"" TypeID=""$MPViewType"" Visible=""true"">`n        <Category>Operations</Category>`n        <Criteria>`n          <!--Use Red (Error), Yellow (Warning), Green (Healthy) for the severity-->`n          <!--To use multiple severities copy the Severity line and add another severity-->`n          <!--If wanting to display everything delete from <SeverityList> to </SeverityList>-->`n                    <SeverityList>`n            <Severity>Red</Severity>`n          </SeverityList>`n          <!--Use true or false to display machines in maintenance mode-->`n          <InMaintenanceMode>true</InMaintenanceMode>`n        </Criteria>      </View>"
   $ClassContent | Set-Content $MPViewFile
   Write-Host "You can add the Severity and if you want to show devices in maintenance mode (true or false) to the XML in the switches within Visual Studio" -ForegroundColor Yellow
  }

  If ($MPViewType -eq "SC!Microsoft.SystemCenter.StateDetailDefinitionViewType") {
  $FindViewsline = Select-String $MPViewFile -pattern "</views>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindViewsline] += "`n      <View ID=""$ViewID"" Accessibility=""Internal"" Target=""$ViewTarget"" TypeID=""$MPViewType"" Visible=""true"">`n        <Category>Operations</Category>`n      </View>"
  $ClassContent | Set-Content $MPViewFile
  }
  
  If ($MPViewType -eq "SC!Microsoft.SystemCenter.TaskStatusViewType") {
  $FindViewsline = Select-String $MPViewFile -pattern "</views>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindViewsline] += "`n      <View ID=""$ViewID"" Accessibility=""Internal"" Target=""$ViewTarget"" TypeID=""$MPViewType"" Visible=""true"">`n        <Category>Operations</Category>`n        <Criteria>`n           <!--Use Succeeded, Scheduled, Startred or Failed for filtering of your Task Status -->`n       <!--If needing to add more filters copy the status lines and paste underneath -->`          <StatusList>`n            <Status>Scheduled</Status>`n          </StatusList>`n        </Criteria>`n      </View>"
  $ClassContent | Set-Content $MPViewFile
  }
  
  If ($MPViewType -eq "SC!Microsoft.SystemCenter.UrlViewType") {
  $URL = Read-Host "Type in the website"
  $URL = $URL -replace ":","%3A" -replace "/","%2F"
  $FindViewsline = Select-String $MPViewFile -pattern "</views>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindViewsline] += "`n      <View ID=""$ViewID"" Accessibility=""Internal"" Target=""$ViewTarget"" TypeID=""$MPViewType"" Visible=""true"">`n        <Category>Operations</Category>`n        <Criteria>`n          <Url>$URL</Url>`n        </Criteria>`n      </View>"
  $ClassContent | Set-Content $MPViewFile
  }

 # Reload content
 $ClassContent = Get-Content $MPViewFile

 # Writes the DisplayStrings to the XML so SCOM can read the display names correctly
 $FindLastDisplayStringLine = Select-String $MPViewFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
 $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$ViewID"">`n     <Name>$ViewName</Name>`n     <Description>$ViewDescription</Description>`n    </DisplayString>"
 $ClassContent | Set-Content $MPViewFile

 #Reload content
 $ClassContent = Get-Content $MPViewFile

 # Writes the View to be placed in a specific folder
 $FindFolderItemsLine = Select-String $MPViewFile -pattern "</FolderItems>" | ForEach-Object {$_.LineNumber -2}
 $ClassContent[$FindFolderItemsLine] += "`n      <FolderItem ElementID=""$ViewID"" Folder=""$FolderID"" ID=""$ViewID.folderitem"" />"
 $ClassContent | Set-Content $MPViewFile

}

############################################################################################################################################################
# New-SCOMMPMonitorRule
# 
############################################################################################################################################################

  Function New-SCOMMPMonitorRule
  {
  Param (

  [Parameter(Mandatory=$true,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )
  Add-Content $MPMonitorRuleFile "<ManagementPackFragment SchemaVersion=""2.0"" xmlns:xsd=""http://www.w3.org/2001/XMLSchema"">`n  <Monitoring>`n   <Rules>`n   </Rules>`n   <Tasks>`n   </Tasks>`n    <Monitors>`n </Monitors>`n   <Diagnostics>`n</Diagnostics>`n   <Recoveries>`n</Recoveries>`n   </Monitoring>`n   <Presentation>`n    <StringResources>`n   </StringResources>`n  </Presentation>`n  <LanguagePacks>`n    <LanguagePack ID=""ENU"" IsDefault=""true"">`n      <DisplayStrings>`n      </DisplayStrings>`n      <KnowledgeArticles>`n      </KnowledgeArticles>`n    </LanguagePack>`n  </LanguagePacks>`n</ManagementPackFragment>"

  }

############################################################################################################################################################
# New-SCOMMPCustomProbeAction
# 
############################################################################################################################################################

  Function New-SCOMMPCustomProbeAction
  {
   Param(
    
  [Parameter(Mandatory=$true,HelpMessage="Location of the CustomDataSource MPX file")]
  [String]$MPCustomDataSourceFile,
   
  [Parameter(Mandatory=$true,HelpMessage="Location of the CustomMonitorType MPX file")]
  [String]$MPCustomMonitorTypeFile,
   
  [Parameter(Mandatory=$true,HelpMessage="Location of the CustomProbeAction MPX file")]
  [String]$MPCustomProbeActionFile

   )

  Add-Content $MPCustomProbeActionFile "<ManagementPackFragment SchemaVersion=""2.0"" xmlns:xsd=""http://www.w3.org/2001/XMLSchema"">`n  <TypeDefinitions>`n    <ModuleTypes>`n    </ModuleTypes>`n  </TypeDefinitions>`n</ManagementPackFragment>"
  Add-Content $MPCustomDataSourceFile "<ManagementPackFragment SchemaVersion=""2.0"" xmlns:xsd=""http://www.w3.org/2001/XMLSchema"">`n  <TypeDefinitions>`n    <ModuleTypes>`n    </ModuleTypes>`n  </TypeDefinitions>`n</ManagementPackFragment>"
  Add-Content $MPCustomMonitorTypeFile "<ManagementPackFragment SchemaVersion=""2.0"" xmlns:xsd=""http://www.w3.org/2001/XMLSchema"">`n  <TypeDefinitions>`n    <MonitorTypes>`n    </MonitorTypes>`n  </TypeDefinitions>`n</ManagementPackFragment>"
  }

############################################################################################################################################################
# Add-SCOMMPCustomProbeAction
# 
############################################################################################################################################################

  Function Add-SCOMMPCustomProbeAction
  {
      [cmdletbinding()]

  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the custom module class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$CustomModuleName,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the monitor will apply to")]
  [Alias('TargetClassID')]
  [String]$MonitorTarget,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the run as account to which the monitor will need to be ran by")]
  [Alias('RunAsAccount')]
  [String[]]$MonitorRunAsAccount,
    
  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the alert to be generated from the monitor")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$AlertName,
  
  [Parameter(Mandatory=$true,HelpMessage="Enter an alert message for the generated alert")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$AlertMessage ,

  [Parameter(Mandatory=$false,HelpMessage="Enter a paragraph for the knowledgebase article for this discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$KnowledgeArticle,

  [Parameter(Mandatory=$true,HelpMessage="Enter the timeout in seconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TimeoutSeconds,

  [Parameter(Mandatory=$true,HelpMessage="Enter the name of the PowerShell script")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$ScriptName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the location of where the powershell script will be saved to")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$ScriptOutput,

  [Parameter(Mandatory=$true,HelpMessage="Location of the CustomDataSource MPX file")]
  [String]$MPCustomDataSourceFile,
   
  [Parameter(Mandatory=$true,HelpMessage="Location of the CustomMonitorType MPX file")]
  [String]$MPCustomMonitorTypeFile,
   
  [Parameter(Mandatory=$true,HelpMessage="Location of the CustomProbeAction MPX file")]
  [String]$MPCustomProbeActionFile,

  [Parameter(Mandatory=$true,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )

  # Write PowerShell Script Template
  $Instance = "$" + "instance"
  $SourceID = "$" + "sourceid"
  $ManagedEntityId = "$" + "managedEntityId"
  $Computername = "$" + "computerName"
  $api = "$" + "api"
  $testsuccessful = "$" + "testsuccessful"
  $bag = "$" + "bag"
  $IncludeFileContent = "$" + "IncludeFileContent"
  #$MPID = $ManagementPackName -replace " ","."
  #$PSScriptName = "$MPID.TimedPSScript.ps1"

  Add-Content $ScriptOutput "param($computerName)`n$api = new-object -comObject 'MOM.ScriptAPI'`n$api.LogScriptEvent('$PSScriptName',20,4,$computername)`n$bag = $api.CreatePropertybag()`n$bag.AddValue('ComputerName',$Computername)`n <InsertScriptLogicHere>`n If ($testsuccessful -eq $true)`n {$bag.AddValue('Result','Good')}`n else`n {$bag.AddValue('Result','Bad')}`n $bag"

  Write-Host "Edit the PowerShell script to contain your script portion for the custom probe when you attach a monitor to it. Start from under the $bag.Add Value line" -ForegroundColor Yellow
  Write-Host "There is an IF statement containing a variable called $Testsuccessful which can be replaced with anything but is used to verify if there is an error for an alert to be generated or healthy for an alert to be closed" -ForegroundColor Yellow

  # Wrties variable values which are specific to Visual Studios
  $Target = "$" + "Target"
  $Config = "$" + "Config"
  $ID = $CustomModuleName -replace " ","."
  $ProbeActionModuleID = "$ID.ProbeAction.PowerShellScript"
  $DataSourceModuleID = "$ID.DataSource.PowerShellScript"
  $UnitMonitorTypeID = "$ID.MonitorType"
  $ClassContent = Get-Content $MPCustomProbeActionFile

  # Write Probe Module Type
  $FindModuleTypesLine = Select-String $MPCustomProbeActionFile -pattern "</ModuleTypes>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindModuleTypesLine] += "`n      <ProbeActionModuleType ID=""$ProbeActionModuleID"" Accessibility=""Internal"" Batching=""false"" PassThrough=""false"" RunAs=""$MonitorRunAsAccount"">`n        <Configuration>`n          <xsd:element minOccurs=""1"" name=""ComputerName"" type=""xsd:string"" />`n        </Configuration>`n        <ModuleImplementation Isolation=""Any"">`n          <Composite>`n            <MemberModules>`n              <ProbeAction ID=""PSScript"" TypeID=""Windows!Microsoft.Windows.PowerShellPropertyBagProbe"">`n               <ScriptName>$ScriptName</ScriptName>`n                <ScriptBody>$IncludeFileContent/$ScriptName$</ScriptBody>`n                 <Parameters>`n                  <Parameter>`n                    <Name>ComputerName</Name>`n                    <Value>$Config/ComputerName$</Value>`n                  </Parameter>`n                 </Parameters>`n                 <TimeoutSeconds>$TimeoutSeconds</TimeoutSeconds>`n               </ProbeAction>`n            </MemberModules>`n            <Composition>`n              <Node ID=""PSScript"" />`n            </Composition>`n          </Composite>`n        </ModuleImplementation>`n        <OutputType>System!System.PropertyBagData</OutputType>`n        <InputType>System!System.BaseData</InputType>`n      </ProbeActionModuleType>"
  $ClassContent | Set-Content $MPCustomProbeActionFile
  #$ClassContent[$FindModuleTypesLine] += "`n      <DataSourceModuleType ID=""$CustomModuleID"" Accessibility=""Internal"" Batching=""false"" RunAs=""$RunAsAccount"">`n              <Configuration>`n              </Configuration>`n          <xsd:element minOccurs=""1"" name=""IntervalSeconds"" type=""xsd:integer"" />`n          <xsd:element minOccurs=""0"" name=""SyncTime"" type=""xsd:string"" />`n          <xsd:element minOccurs=""1"" name=""ComputerName"" type=""xsd:string"" />`n        </Configuration>              <OverrideableParameters>`n          <OverrideableParameter ID=""IntervalSeconds"" Selector=""$Config/IntervalSeconds$"" ParameterType=""int"" />`n          <OverrideableParameter ID=""SyncTime"" Selector=""$Config/SyncTime$"" ParameterType=""string"" />                </OverrideableParameters>`n                <ModuleImplementation Isolation=""Any"">`n                  <Composite>`n                    <MemberModules>`n                      <DataSource ID=""Schedule"" TypeID=""System!System.SimpleScheduler"">`n                      `n<IntervalSeconds>$Config/IntervalSeconds$</IntervalSeconds>`n                <SyncTime>$SyncTime</SyncTime>`n              </DataSource>`n              <ProbeAction ID=""Probe"" TypeID=""$CustomModuleID"">`n                <ComputerName>$Config/ComputerName$</ComputerName>`n              </ProbeAction>`n            </MemberModules>`n            <Composition>`n              <Node ID=""Probe"">`n                <Node ID=""Schedule"" />`n              </Node>`n            </Composition>`n          </Composite>`n        </ModuleImplementation>`n        <OutputType>System!System.PropertyBagData</OutputType>`n      </DataSourceModuleType>`n      <ProbeActionModuleType ID=""$CustomModuleID"" Accessibility=""Internal"" Batching=""false"" PassThrough=""false"" RunAs=""$RunAsAccount"">`n        <Configuration>`n          <xsd:element minOccurs=""1"" name=""ComputerName"" type=""xsd:string"" />`n        </Configuration>`n        <ModuleImplementation Isolation=""Any"">`n          <Composite>`n            <MemberModules>`n              <ProbeAction ID=""PSScript"" TypeID=""Windows!Microsoft.Windows.PowerShellPropertyBagProbe"">`n               <ScriptName>$PSScriptName</ScriptName>`n                `n<ScriptBody>$IncludeFileContent/$PSScriptName</ScriptBody>`n                 <Parameters>`n                  <Parameter>`n                    <Name>ComputerName</Name>`n                    <Value>$Config/ComputerName$</Value>`n                  </Parameter>`n                 </Parameters>`n                 <TimeoutSeconds>$TimeoutSeconds</TimeoutSeconds>`n               </ProbeAction>`n            </MemberModules>`n            <Composition>`n              <Node ID=""PSScript"" />`n            </Composition>`n          </Composite>`n        </ModuleImplementation>`n        <OutputType>System!System.PropertyBagData</OutputType>`n        <InputType>System!System.BaseData</InputType>`n      </ProbeActionModuleType>`n    </ModuleTypes>`n     <MonitorTypes>`n       <UnitMonitorType ID=""$CustomModuleID"" Accessibility=""Internal"" RunAs=""$RunAsAccount"">`n         <MonitorTypeStates>`n           <MonitorTypeState ID=""Success"" NoDetection=""false""/>`n           <MonitorTypeState ID=""Failure"" NoDetection=""false""/>`n         </MonitorTypeStates>`n         <Configuration>`n           <xsd:element minOccurs=""1"" name=""ComputerName"" type=""xsd.string"" />`n           <xsd:element minOccurs=""1"" name=""IntervalSeconds"" type=""xsd.integer"" />`n           <xsd:element minOccurs=""1"" name=""SyncTime"" type=""xsd.string"" />`n         </Configuration>`n         <OverrideableParameters>`n           <OverrideableParameter ID=""IntervalSeconds"" Selector=""$Config/IntervalSeconds$"" ParameterType=""int""/>`n         </OverrideableParameters>`n         <MonitorImplementation>`n           <MemberModules>`n             <DataSource ID=""DataSource"" TypeID=""$CustomModuleID"">`n               <IntervalSeconds>$Config/IntervalSeconds$</IntervalSeconds>`n               <SyncTime>$Config/SyncTime$</SyncTime>`n               <ComputerName>$Config/ComputerName$</ComputerName>`n             </DataSource>`n             <ProbeAction ID=""PassThru"" TypeID=""System!System.PassThroughProbe"" />`n             <ProbeAction ID=""Probe"" TypeID=""$CustomModuleID"">`n               <ComputerName>$Config/ComputerName$</ComputerName>`n             </ProbeAction>`n               <ConditionDetection ID=""FilterSuccess"" TypeID=""System!System.ExpressionFilter"">`n               <Expression>`n                 <SimpleExpression>`n                   <ValueExpression>`n                     <XPathQuery Type=""String"">Property[@Name='Result']</XPathQuery>`n                   </ValueExpression>`n                   <Operator>Equal</Operator>`n                   <ValueExpression>`n                     <Value Type=""String"">Good</Value>`n                   </ValueExpression>`n                 </SimpleExpression>`n               </Expression>`n             </ConditionDetection>`n<ConditionDetection ID=""FilterFailure"" TypeID=""System!System.ExpressionFilter"">`n               <Expression>`n                 <SimpleExpression>`n                   <ValueExpression>`n                     <XPathQuery Type=""String"">Property[@Name='Result']</XPathQuery>`n                   </ValueExpression>`n                   <Operator>Equal</Operator>`n                   <ValueExpression>`n                     <Value Type=""String"">Bad</Value>`n                   </ValueExpression>`n                 </SimpleExpression>`n               </Expression>`n             </ConditionDetection>`n           </MemberModules>`n           <RegularDetections>`n             <RegularDetection MonitorTypeStateID=""Success"">`n               <Node ID=""FilterSuccess"">`n                 <Node ID=""DataSource"" />`n               </Node>`n             </RegularDetection>`n             <RegularDetection MonitorTypeStateID=""Failure"">`n               <Node ID=""FilterFailure"">`n                 <Node ID=""DataSource"" />`n               </Node>`n             </RegularDetection>`n           </RegularDetections>`n           <OnDemandDetections>`n             <OnDemandDetection MonitorTypeStateID=""Success"">`n               <Node ID=""FilterSuccess"">`n                 <Node ID=""Probe"">`n                   <Node ID=""PassThru"" />`n                 </Node>`n               </Node>`n             </OnDemandDetection>`n             <OnDemandDetection MonitorTypeStateID=""Failure"">`n               <Node ID=""FilterFailure"">`n                 <Node ID=""Probe"">`n                   <Node ID=""PassThru"" />`n                 </Node>`n               </Node>`n             </OnDemandDetection>`n           </OnDemandDetections>`n         </MonitorImplementation>`n       </UnitMonitorType>`n     </MonitorTypes>"

  # Load DataSource XML File
  $ClassContent = Get-Content $MPCustomDataSourceFile

  # Write Data Source Module Type
  $FindModuleTypesLine = Select-String $MPCustomDataSourceFile -pattern "</ModuleTypes>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindModuleTypesLine] += "`n      <DataSourceModuleType ID=""$DataSourceModuleID"" Accessibility=""Internal"" Batching=""false"" RunAs=""$MonitorRunAsAccount"">`n              <Configuration>`n              <xsd:element minOccurs=""1"" name=""IntervalSeconds"" type=""xsd:integer"" />`n              <xsd:element minOccurs=""0"" name=""SyncTime"" type=""xsd:string"" />`n              <xsd:element minOccurs=""1"" name=""ComputerName"" type=""xsd:string"" />`n        </Configuration>`n              <OverrideableParameters>`n          <OverrideableParameter ID=""IntervalSeconds"" Selector=""$Config/IntervalSeconds$"" ParameterType=""int"" />`n          <OverrideableParameter ID=""SyncTime"" Selector=""$Config/SyncTime$"" ParameterType=""string"" />`n                </OverrideableParameters>`n                <ModuleImplementation Isolation=""Any"">`n                  <Composite>`n                    <MemberModules>`n                      <DataSource ID=""Schedule"" TypeID=""System!System.SimpleScheduler"">`n                      <IntervalSeconds>$Config/IntervalSeconds$</IntervalSeconds>`n                <SyncTime>$SyncTime</SyncTime>`n              </DataSource>`n              <ProbeAction ID=""Probe"" TypeID=""$ProbeActionModuleID"">`n                <ComputerName>$Config/ComputerName$</ComputerName>`n              </ProbeAction>`n            </MemberModules>`n            <Composition>`n              <Node ID=""Probe"">`n                <Node ID=""Schedule"" />`n              </Node>`n            </Composition>`n          </Composite>`n        </ModuleImplementation>`n        <OutputType>System!System.PropertyBagData</OutputType>`n      </DataSourceModuleType>"
  $ClassContent | Set-Content $MPCustomDataSourceFile

  # Load Unit Montior Type File
  $ClassContent = Get-Content $MPCustomMonitorTypeFile

  # Write Unit Monitor Type File
  $FindMonitorTypesLine = Select-String $MPCustomMonitorTypeFile -pattern "</MonitorTypes>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindMonitorTypesLine] += "`n       <UnitMonitorType ID=""$UnitMonitorTypeID"" Accessibility=""Internal"" RunAs=""$MonitorRunAsAccount"">`n         <MonitorTypeStates>`n           <MonitorTypeState ID=""Success"" NoDetection=""false""/>`n           <MonitorTypeState ID=""Failure"" NoDetection=""false""/>`n         </MonitorTypeStates>`n         <Configuration>`n           <xsd:element minOccurs=""1"" name=""ComputerName"" type=""xsd:string"" />`n           <xsd:element minOccurs=""1"" name=""IntervalSeconds"" type=""xsd:integer"" />`n           <xsd:element minOccurs=""1"" name=""SyncTime"" type=""xsd:string"" />`n         </Configuration>`n         <OverrideableParameters>`n           <OverrideableParameter ID=""IntervalSeconds"" Selector=""$Config/IntervalSeconds$"" ParameterType=""int""/>`n          <OverrideableParameter ID=""SyncTime"" Selector=""$Config/SyncTime$"" ParameterType=""string""/>`n         </OverrideableParameters>`n         <MonitorImplementation>`n           <MemberModules>`n             <DataSource ID=""DataSource"" TypeID=""$DataSourceModuleID"">`n               <IntervalSeconds>$Config/IntervalSeconds$</IntervalSeconds>`n               <SyncTime>$Config/SyncTime$</SyncTime>`n               <ComputerName>$Config/ComputerName$</ComputerName>`n             </DataSource>`n             <ProbeAction ID=""PassThru"" TypeID=""System!System.PassThroughProbe"" />`n             <ProbeAction ID=""Probe"" TypeID=""$ProbeActionModuleID"">`n               <ComputerName>$Config/ComputerName$</ComputerName>`n             </ProbeAction>`n               <ConditionDetection ID=""FilterSuccess"" TypeID=""System!System.ExpressionFilter"">`n               <Expression>`n                 <SimpleExpression>`n                   <ValueExpression>`n                     <XPathQuery Type=""String"">Property[@Name='Result']</XPathQuery>`n                   </ValueExpression>`n                   <Operator>Equal</Operator>`n                   <ValueExpression>`n                     <Value Type=""String"">Good</Value>`n                   </ValueExpression>`n                 </SimpleExpression>`n               </Expression>`n             </ConditionDetection>`n              <ConditionDetection ID=""FilterFailure"" TypeID=""System!System.ExpressionFilter"">`n               <Expression>`n                 <SimpleExpression>`n                   <ValueExpression>`n                     <XPathQuery Type=""String"">Property[@Name='Result']</XPathQuery>`n                   </ValueExpression>`n                   <Operator>Equal</Operator>`n                   <ValueExpression>`n                     <Value Type=""String"">Bad</Value>`n                   </ValueExpression>`n                 </SimpleExpression>`n               </Expression>`n             </ConditionDetection>`n           </MemberModules>`n           <RegularDetections>`n             <RegularDetection MonitorTypeStateID=""Success"">`n               <Node ID=""FilterSuccess"">`n                 <Node ID=""DataSource"" />`n               </Node>`n             </RegularDetection>`n             <RegularDetection MonitorTypeStateID=""Failure"">`n               <Node ID=""FilterFailure"">`n                 <Node ID=""DataSource"" />`n               </Node>`n             </RegularDetection>`n           </RegularDetections>`n           <OnDemandDetections>`n             <OnDemandDetection MonitorTypeStateID=""Success"">`n               <Node ID=""FilterSuccess"">`n                 <Node ID=""Probe"">`n                   <Node ID=""PassThru"" />`n                 </Node>`n               </Node>`n             </OnDemandDetection>`n             <OnDemandDetection MonitorTypeStateID=""Failure"">`n               <Node ID=""FilterFailure"">`n                 <Node ID=""Probe"">`n                   <Node ID=""PassThru"" />`n                 </Node>`n               </Node>`n             </OnDemandDetection>`n           </OnDemandDetections>`n         </MonitorImplementation>`n       </UnitMonitorType>"
  $ClassContent | Set-Content $MPCustomMonitorTypeFile

  # Write Monitor to monitor file
  $MonitorName = "$CustomModuleName PSScriptMonitor"
  $MonitorEnabled = "true"
  #$MonitorRunAsAccount = $RunAsAccount
  $AlertOnState = "Error"
  $AlertPriority = "Normal"
  $IntervalSeconds = "300"
  $MonitorID = $MonitorName -replace " ", "."
  $AlertMessageID = "$MonitorID.AlertMessage"
  $Target = "$" + "Target"
  $Data = "$" + "Data"
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write Monitor
  $FindMonitorsLine = Select-String $MPMonitorRuleFile -pattern "</Monitors>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindMonitorsLine] += "`n      <UnitMonitor ID=""$MonitorID"" Accessibility=""Internal"" Enabled=""$MonitorEnabled"" Target=""$MonitorTarget"" ParentMonitorID=""Health!System.Health.AvailabilityState"" Remotable=""true"" Priority=""Normal"" TypeID=""$UnitMonitorTypeID"" ConfirmDelivery=""false"" RunAs=""$MonitorRunAsAccount"">`n        <Category>PerformanceHealth</Category>`n        <AlertSettings AlertMessage=""$AlertMessageID"">`n          <AlertOnState>$AlertOnState</AlertOnState>`n          <AutoResolve>true</AutoResolve>`n          <AlertPriority>$AlertPriority</AlertPriority>`n          <AlertSeverity>MatchMonitorHealth</AlertSeverity>`n        </AlertSettings>`n        <OperationalStates>`n          <OperationalState ID=""Success"" MonitorTypeStateID=""Success"" HealthState=""Success"" />`n          <OperationalState ID=""Failure"" MonitorTypeStateID=""Failure"" HealthState=""Error"" />`n        </OperationalStates>`n        <Configuration>`n          <ComputerName>$Target/Host/Property[Type=""Windows!Microsoft.Windows.Computer""]/PrincipalName$</ComputerName>`n          <IntervalSeconds>$IntervalSeconds</IntervalSeconds>`n          <SyncTime />`n        </Configuration>`n      </UnitMonitor>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write String Resources
  $FindStringResourcesLine = Select-String $MPMonitorRuleFile -pattern "</StringResources>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindStringResourcesLine] += "`n<StringResource ID=""$AlertMessageID"" />"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write display strings
  $FindLastDisplayStringLine = Select-String $MPMonitorRuleFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$MonitorID"">`n     <Name>$MonitorName</Name>`n     <Description>$MonitorDescription</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$AlertMessageID"">`n     <Name>$AlertName</Name>`n     <Description>$AlertMessage</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$MonitorID"" SubElementID=""Success"">`n     <Name>Success</Name>`n     <Description>Success</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$MonitorID"" SubElementID=""Failure"">`n     <Name>Failure</Name>`n     <Description>Failure</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Writes the Knowledge Article to the XML so SCOM can read the display names correctly
  $FindLastKnowledgeArticleLine = Select-String $MPMonitorRuleFile -pattern "</KnowledgeArticles>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastKnowledgeArticleLine] += "`n    <KnowledgeArticle ElementID=""$MonitorID"" Visible=""true"">`n     <MamlContent>`n     <maml:section xmlns:maml=""http://schemas.microsoft.com/maml/2004/10"">`n              <maml:title>$MonitorName</maml:title>`n              <maml:para>$KnowledgeArticle</maml:para>`n            </maml:section>`n          </MamlContent>`n    </KnowledgeArticle>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  }

############################################################################################################################################################
# Add-SCOMMPWindowsEventMonitor
# 
############################################################################################################################################################

  Function Add-SCOMMPWindowsEventMonitor
  {
   [cmdletbinding()]
  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the monitor class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$MonitorName,

  [Parameter(Mandatory=$true,HelpMessage="Select if the Monitor will be enabled straight away")]
  [ValidateSet('true','false')]
  [String]$MonitorEnabled,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the monitor will apply to")]
  [Alias('TargetClassID')]
  [String]$MonitorTarget,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the run as account to which the monitor will need to be ran by")]
  [Alias('RunAsAccount')]
  [String[]]$MonitorRunAsAccount,

  [Parameter(Mandatory=$true,HelpMessage="Select which error state the alert will generate from")]
  [ValidateSet('Error','Warning')]
  [String]$AlertOnState,

  [Parameter(Mandatory=$true,HelpMessage="Select which alert priority the alert will have")]
  [ValidateSet('High','Normal', 'Low')]
  [String]$AlertPriority,

  [Parameter(Mandatory=$true,HelpMessage="Select which alert severity the alert will have")]
  [ValidateSet('Error','Warning')]
  [String]$AlertSeverity,

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the alert")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$AlertName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the windows event viewer log name for unhealthy status")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$UnhealthyLogName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the windows event display number for unhealthy status")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$UnhealthyEventDisplayNumber,

  [Parameter(Mandatory=$true,HelpMessage="Enter the windows event publisher name for unhealthy status")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$UnhealthyPublisherName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the windows event viewer log name for healthy status")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$HealthyLogName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the windows event display number for healthy status")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$HealthyEventDisplayNumber,

  [Parameter(Mandatory=$true,HelpMessage="Enter the windows event publisher name for healthy status")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$HealthyPublisherName,

  [Parameter(Mandatory=$false,HelpMessage="Enter a paragraph for the knowledgebase article for this discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$KnowledgeArticle,

  [Parameter(Mandatory=$true,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )
 

  # Wrties variable values which are specific to Visual Studios
  $Target = "$" + "Target"
  $Data = "$" + "Data"
  $ClassContent = Get-Content $MPMonitorRuleFile
  $MonitorID = $MonitorName -replace " ", "."
  $AlertMessageID = "$MonitorID.AlertMessage"

  # Write Monitor
  $FindMonitorsLine = Select-String $MPMonitorRuleFile -pattern "</Monitors>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindMonitorsLine] += "`n      <UnitMonitor ID=""$MonitorID"" Accessibility=""Internal"" Enabled=""$MonitorEnabled"" Target=""$MonitorTarget"" ParentMonitorID=""Health!System.Health.AvailabilityState"" Remotable=""true"" Priority=""Normal"" TypeID=""Windows!Microsoft.Windows.2SingleEventLog2StateMonitorType"" ConfirmDelivery=""false"" RunAs=""$MonitorRunAsAccount"">`n        <Category>AvailabilityHealth</Category>`n        <AlertSettings AlertMessage=""$AlertMessageID"">`n          <AlertOnState>$AlertOnState</AlertOnState>`n          <AutoResolve>true</AutoResolve>`n          <AlertPriority>$AlertPriority</AlertPriority>`n          <AlertSeverity>MatchMonitorHealth</AlertSeverity>`n          <AlertParameters>`n            <!--To add additional parameters for this monitor copy the XML line underneath as AlertParameter2-->`n            <!--If needing more variables delete ""EventDescription"" and replace with PublisherName/EventSourceName/Channel/LoggingComputer/EventNumer/EventCategory as examples-->`n            <!--To display in alert message find the AlertMessageID below in the DisplayStrings section and add the AlertParameter number in brackets for example {0] is AlertParameter1 and upwards-->            <AlertParameter1>$Data/Context/EventDescription$</AlertParameter1>`n          </AlertParameters>`n          </AlertSettings>`n        <OperationalStates>`n          <OperationalState ID=""FirstEventRaised"" MonitorTypeStateID=""FirstEventRaised"" HealthState=""$AlertSeverity"" />`n          <OperationalState ID=""SecondEventRaised"" MonitorTypeStateID=""SecondEventRaised"" HealthState=""Success"" />`n        </OperationalStates>`n        <Configuration>`n          <FirstComputerName>$Target/Host/Property[Type=""Windows!Microsoft.Windows.Computer""]/NetworkName$</FirstComputerName>`n          <FirstLogName>$UnhealthyLogName</FirstLogName>`n          <FirstExpression>`n            <And>`n              <Expression>`n                <SimpleExpression>`n                  <ValueExpression>`n                    <XPathQuery Type=""UnsignedInteger"">EventDisplayNumber</XPathQuery> `n                  </ValueExpression>`n                  <Operator>Equal</Operator>`n                  <ValueExpression>`n                    <Value Type=""UnsignedInteger"">$UnhealthyEventDisplayNumber</Value>`n                  </ValueExpression>`n                </SimpleExpression>`n              </Expression>`n              <Expression>`n                <SimpleExpression>`n                  <ValueExpression>`n                    <XPathQuery Type=""String"">PublisherName</XPathQuery>`n                  </ValueExpression>`n                  <Operator>Equal</Operator>`n                  <ValueExpression>`n                    <Value Type=""String"">$UnhealthyPublisherName</Value>`n                  </ValueExpression>`n                </SimpleExpression>`n              </Expression>`n              <Expression>`n              </Expression>`n            </And>`n          </FirstExpression>`n          <SecondComputerName>$Target/Host/Property[Type=""Windows!Microsoft.Windows.Computer""]/NetworkName$</SecondComputerName>`n          <SecondLogName>$HealthyLogName</SecondLogName>`n          <SecondExpression>`n            <And>`n              <Expression>`n                <SimpleExpression>`n                  <ValueExpression>`n                    <XPathQuery Type=""UnsignedInteger"">EventDisplayNumber</XPathQuery>`n                  </ValueExpression>`n                  <Operator>Equal</Operator>`n                  <ValueExpression>`n                    <Value Type=""UnsignedInteger"">$HealthyEventDisplayNumber</Value>`n                  </ValueExpression>`n                </SimpleExpression>`n              </Expression>`n              <Expression>`n                <SimpleExpression>`n                  <ValueExpression>`n                    <XPathQuery Type=""String"">PublisherName</XPathQuery>`n                  </ValueExpression>`n                  <Operator>Equal</Operator>`n                  <ValueExpression>`n                    <Value Type=""String"">$HealthyPublisherName</Value>`n                  </ValueExpression>`n                </SimpleExpression>`n              </Expression>`n              <Expression>`n              </Expression>`n            </And>`n          </SecondExpression>`n        </Configuration>`n      </UnitMonitor>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write String Resources
  $FindStringResourcesLine = Select-String $MPMonitorRuleFile -pattern "</StringResources>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindStringResourcesLine] += "`n<StringResource ID=""$AlertMessageID"" />"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File 
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write display strings
  $FindLastDisplayStringLine = Select-String $MPMonitorRuleFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$MonitorID"">`n     <Name>$MonitorName</Name>`n     <Description>$MonitorDescription</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$AlertMessageID"">`n     <Name>$AlertName</Name>`n     <Description>Event Description: {0}</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$MonitorID"" SubElementID=""FirstEventRaised"">`n     <Name>FirstEventRaised</Name>`n     <Description>FirstEventRaised</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$MonitorID"" SubElementID=""SecondEventRaised"">`n     <Name>SecondEventRaised</Name>`n     <Description>SecondEventRaised</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Writes the Knowledge Article to the XML so SCOM can read the display names correctly
  $FindLastKnowledgeArticleLine = Select-String $MPMonitorRuleFile -pattern "</KnowledgeArticles>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastKnowledgeArticleLine] += "`n    <KnowledgeArticle ElementID=""$MonitorID"" Visible=""true"">`n     <MamlContent>`n     <maml:section xmlns:maml=""http://schemas.microsoft.com/maml/2004/10"">`n              <maml:title>$MonitorName</maml:title>`n              <maml:para>$KnowledgeArticle</maml:para>`n            </maml:section>`n          </MamlContent>`n    </KnowledgeArticle>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  }

############################################################################################################################################################
# Add-SCOMMPWindowsEventManualResetMonitor
# 
############################################################################################################################################################

  Function Add-SCOMMPWindowsEventManualResetMonitor
  {
   [cmdletbinding()]
  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the monitor class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$MonitorName,

  [Parameter(Mandatory=$true,HelpMessage="Select if the Monitor will be enabled straight away")]
  [ValidateSet('true','false')]
  [String]$MonitorEnabled,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the monitor will apply to")]
  [Alias('TargetClassID')]
  [String]$MonitorTarget,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the run as account to which the monitor will need to be ran by")]
  [Alias('RunAsAccount')]
  [String[]]$MonitorRunAsAccount,

  [Parameter(Mandatory=$true,HelpMessage="Select which error state the alert will generate from")]
  [ValidateSet('Error','Warning')]
  [String]$AlertOnState,

  [Parameter(Mandatory=$true,HelpMessage="Select which alert priority the alert will have")]
  [ValidateSet('High','Normal', 'Low')]
  [String]$AlertPriority,

  [Parameter(Mandatory=$true,HelpMessage="Select which alert severity the alert will have")]
  [ValidateSet('Error','Warning')]
  [String]$AlertSeverity,

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the alert")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$AlertName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the windows event viewer log name for unhealthy status")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$UnhealthyLogName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the windows event display number for unhealthy status")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$UnhealthyEventDisplayNumber,

  [Parameter(Mandatory=$true,HelpMessage="Enter the windows event publisher name for unhealthy status")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$UnhealthyPublisherName,

  [Parameter(Mandatory=$false,HelpMessage="Enter a paragraph for the knowledgebase article for this discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$KnowledgeArticle,

  [Parameter(Mandatory=$true,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )
 

  # Wrties variable values which are specific to Visual Studios
  $Target = "$" + "Target"
  $Data = "$" + "Data"
  $ClassContent = Get-Content $MPMonitorRuleFile
  $MonitorID = $MonitorName -replace " ", "."
  $AlertMessageID = "$MonitorID.AlertMessage"

  # Write Monitor
  $FindMonitorsLine = Select-String $MPMonitorRuleFile -pattern "</Monitors>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindMonitorsLine] += "`n      <UnitMonitor ID=""$MonitorID"" Accessibility=""Internal"" Enabled=""$MonitorEnabled"" Target=""$MonitorTarget"" ParentMonitorID=""Health!System.Health.AvailabilityState"" Remotable=""true"" Priority=""Normal"" TypeID=""Windows!Microsoft.Windows.SingleEventLogManualReset2StateMonitorType"" ConfirmDelivery=""false"" RunAs=""$MonitorRunAsAccount"">`n        <Category>Custom</Category>`n        <AlertSettings AlertMessage=""$AlertMessageID"">`n          <AlertOnState>$AlertOnState</AlertOnState>`n          <AutoResolve>true</AutoResolve>`n          <AlertPriority>$AlertPriority</AlertPriority>`n          <AlertSeverity>MatchMonitorHealth</AlertSeverity>`n          <AlertParameters>`n            <!--To add additional parameters for this monitor copy the XML line underneath as AlertParameter2-->`n            <!--If needing more variables delete ""EventDescription"" and replace with PublisherName/EventSourceName/Channel/LoggingComputer/EventNumer/EventCategory as examples-->`n            <!--To display in alert message find the AlertMessageID below in the DisplayStrings section and add the AlertParameter number in brackets for example {0] is AlertParameter1 and upwards-->            <AlertParameter1>$Data/Context/EventDescription$</AlertParameter1>`n          </AlertParameters>`n          </AlertSettings>`n        <OperationalStates>`n          <OperationalState ID=""EventRaised"" HealthState=""$AlertSeverity"" MonitorTypeStateID=""EventRaised""/>`n          <OperationalState ID=""ManualResetEventRaised"" HealthState=""Success"" MonitorTypeStateID=""ManualResetEventRaised""/>`n        </OperationalStates>`n        <Configuration>`n          <ComputerName>$Target/Host/Property[Type=""Windows!Microsoft.Windows.Computer""]/NetworkName$</ComputerName>`n          <LogName>$UnhealthyLogName</LogName>`n          <Expression>`n            <And>`n              <Expression>`n                <SimpleExpression>`n                  <ValueExpression>`n                    <XPathQuery Type=""UnsignedInteger"">EventDisplayNumber</XPathQuery> `n                  </ValueExpression>`n                  <Operator>Equal</Operator>`n                  <ValueExpression>`n                    <Value Type=""UnsignedInteger"">$UnhealthyEventDisplayNumber</Value>`n                  </ValueExpression>`n                </SimpleExpression>`n              </Expression>`n              <Expression>`n                <SimpleExpression>`n                  <ValueExpression>`n                    <XPathQuery Type=""String"">PublisherName</XPathQuery>`n                  </ValueExpression>`n                  <Operator>Equal</Operator>`n                  <ValueExpression>`n                    <Value Type=""String"">$UnhealthyPublisherName</Value>`n                  </ValueExpression>`n                </SimpleExpression>`n              </Expression>`n              <Expression>`n              </Expression>`n            </And>`n          </Expression>`n        </Configuration>`n      </UnitMonitor>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write String Resources
  $FindStringResourcesLine = Select-String $MPMonitorRuleFile -pattern "</StringResources>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindStringResourcesLine] += "`n<StringResource ID=""$AlertMessageID"" />"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File 
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write display strings
  $FindLastDisplayStringLine = Select-String $MPMonitorRuleFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$MonitorID"">`n     <Name>$MonitorName</Name>`n     <Description>$MonitorDescription</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$AlertMessageID"">`n     <Name>$AlertName</Name>`n     <Description>Event Description: {0}</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$MonitorID"" SubElementID=""EventRaised"">`n     <Name>EventRaised</Name>`n     <Description>EventRaised</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$MonitorID"" SubElementID=""ManualResetEventRaised"">`n     <Name>ManualResetEventRaised</Name>`n     <Description>ManualResetEventRaised</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Writes the Knowledge Article to the XML so SCOM can read the display names correctly
  $FindLastKnowledgeArticleLine = Select-String $MPMonitorRuleFile -pattern "</KnowledgeArticles>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastKnowledgeArticleLine] += "`n    <KnowledgeArticle ElementID=""$MonitorID"" Visible=""true"">`n     <MamlContent>`n     <maml:section xmlns:maml=""http://schemas.microsoft.com/maml/2004/10"">`n              <maml:title>$MonitorName</maml:title>`n              <maml:para>$KnowledgeArticle</maml:para>`n            </maml:section>`n          </MamlContent>`n    </KnowledgeArticle>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  }

############################################################################################################################################################
# Add-SCOMMPWindowsEventTimerResetMonitor
# 
############################################################################################################################################################

  Function Add-SCOMMPWindowsEventTimerResetMonitor
  {
   [cmdletbinding()]
  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the monitor class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$MonitorName,

  [Parameter(Mandatory=$true,HelpMessage="Select if the Monitor will be enabled straight away")]
  [ValidateSet('true','false')]
  [String]$MonitorEnabled,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the monitor will apply to")]
  [Alias('TargetClassID')]
  [String]$MonitorTarget,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the run as account to which the monitor will need to be ran by")]
  [Alias('RunAsAccount')]
  [String[]]$MonitorRunAsAccount,

  [Parameter(Mandatory=$true,HelpMessage="Select which error state the alert will generate from")]
  [ValidateSet('Error','Warning')]
  [String]$AlertOnState,

  [Parameter(Mandatory=$true,HelpMessage="Select which alert priority the alert will have")]
  [ValidateSet('High','Normal', 'Low')]
  [String]$AlertPriority,

  [Parameter(Mandatory=$true,HelpMessage="Select which alert severity the alert will have")]
  [ValidateSet('Error','Warning')]
  [String]$AlertSeverity,

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the alert")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$AlertName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the windows event viewer log name for unhealthy status")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$UnhealthyLogName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the windows event display number for unhealthy status")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$UnhealthyEventDisplayNumber,

  [Parameter(Mandatory=$true,HelpMessage="Enter the windows event publisher name for unhealthy status")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$UnhealthyPublisherName,

  [Parameter(Mandatory=$false,HelpMessage="Enter the time it will take to reset in seconds")]
  [String]$TimerWaitInSeconds,

  [Parameter(Mandatory=$false,HelpMessage="Enter a paragraph for the knowledgebase article for this discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$KnowledgeArticle,

  [Parameter(Mandatory=$true,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )

  # Wrties variable values which are specific to Visual Studios
  $Target = "$" + "Target"
  $Data = "$" + "Data"
  $ClassContent = Get-Content $MPMonitorRuleFile
  $MonitorID = $MonitorName -replace " ", "."
  $AlertMessageID = "$MonitorID.AlertMessage"

  # Write Monitor
  $FindMonitorsLine = Select-String $MPMonitorRuleFile -pattern "</Monitors>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindMonitorsLine] += "`n      <UnitMonitor ID=""$MonitorID"" Accessibility=""Internal"" Enabled=""$MonitorEnabled"" Target=""$MonitorTarget"" ParentMonitorID=""Health!System.Health.AvailabilityState"" Remotable=""true"" Priority=""Normal"" TypeID=""Windows!Microsoft.Windows.SingleEventLogTimer2StateMonitorType"" ConfirmDelivery=""false"" RunAs=""$MonitorRunAsAccount"">`n        <Category>Custom</Category>`n        <AlertSettings AlertMessage=""$AlertMessageID"">`n          <AlertOnState>$AlertOnState</AlertOnState>`n          <AutoResolve>true</AutoResolve>`n          <AlertPriority>$AlertPriority</AlertPriority>`n          <AlertSeverity>MatchMonitorHealth</AlertSeverity>`n          <AlertParameters>`n            <!--To add additional parameters for this monitor copy the XML line underneath as AlertParameter2-->`n            <!--If needing more variables delete ""EventDescription"" and replace with PublisherName/EventSourceName/Channel/LoggingComputer/EventNumer/EventCategory as examples-->`n            <!--To display in alert message find the AlertMessageID below in the DisplayStrings section and add the AlertParameter number in brackets for example {0] is AlertParameter1 and upwards-->            <AlertParameter1>$Data/Context/EventDescription$</AlertParameter1>`n          </AlertParameters>`n          </AlertSettings>`n        <OperationalStates>`n          <OperationalState ID=""EventRaised"" MonitorTypeStateID=""EventRaised"" HealthState=""$AlertSeverity"" />`n          <OperationalState ID=""TimerEventRaised"" MonitorTypeStateID=""TimerEventRaised"" HealthState=""Success"" />`n        </OperationalStates>`n        <Configuration>`n          <ComputerName>$Target/Host/Property[Type=""Windows!Microsoft.Windows.Computer""]/NetworkName$</ComputerName>`n          <LogName>$UnhealthyLogName</LogName>`n          <Expression>`n            <And>`n              <Expression>`n                <SimpleExpression>`n                  <ValueExpression>`n                    <XPathQuery Type=""UnsignedInteger"">EventDisplayNumber</XPathQuery> `n                  </ValueExpression>`n                  <Operator>Equal</Operator>`n                  <ValueExpression>`n                    <Value Type=""UnsignedInteger"">$UnhealthyEventDisplayNumber</Value>`n                  </ValueExpression>`n                </SimpleExpression>`n              </Expression>`n              <Expression>`n                <SimpleExpression>`n                  <ValueExpression>`n                    <XPathQuery Type=""String"">PublisherName</XPathQuery>`n                  </ValueExpression>`n                  <Operator>Equal</Operator>`n                  <ValueExpression>`n                    <Value Type=""String"">$UnhealthyPublisherName</Value>`n                  </ValueExpression>`n                </SimpleExpression>`n              </Expression>`n              <Expression>`n              </Expression>`n            </And>`n          </Expression>`n          <TimerWaitInSeconds>$TimerWaitInSeconds</TimerWaitInSeconds>`n        </Configuration>`n      </UnitMonitor>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write String Resources
  $FindStringResourcesLine = Select-String $MPMonitorRuleFile -pattern "</StringResources>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindStringResourcesLine] += "`n<StringResource ID=""$AlertMessageID"" />"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File 
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write display strings
  $FindLastDisplayStringLine = Select-String $MPMonitorRuleFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$MonitorID"">`n     <Name>$MonitorName</Name>`n     <Description>$MonitorDescription</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$AlertMessageID"">`n     <Name>$AlertName</Name>`n     <Description>Event Description: {0}</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$MonitorID"" SubElementID=""EventRaised"">`n     <Name>EventRaised</Name>`n     <Description>EventRaised</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$MonitorID"" SubElementID=""TimerEventRaised"">`n     <Name>TimerEventRaised</Name>`n     <Description>TimerEventRaised</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Writes the Knowledge Article to the XML so SCOM can read the display names correctly
  $FindLastKnowledgeArticleLine = Select-String $MPMonitorRuleFile -pattern "</KnowledgeArticles>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastKnowledgeArticleLine] += "`n    <KnowledgeArticle ElementID=""$MonitorID"" Visible=""true"">`n     <MamlContent>`n     <maml:section xmlns:maml=""http://schemas.microsoft.com/maml/2004/10"">`n              <maml:title>$MonitorName</maml:title>`n              <maml:para>$KnowledgeArticle</maml:para>`n            </maml:section>`n          </MamlContent>`n    </KnowledgeArticle>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  }

############################################################################################################################################################
# Add-SCOMMPWindowsServiceMonitor
# 
############################################################################################################################################################

  Function Add-SCOMMPWindowsServiceMonitor
  {
   [cmdletbinding()]
  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the monitor class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$MonitorName,

  [Parameter(Mandatory=$true,HelpMessage="Select if the Monitor will be enabled straight away")]
  [ValidateSet('true','false')]
  [String]$MonitorEnabled,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the monitor will apply to")]
  [Alias('TargetClassID')]
  [String]$MonitorTarget = "SystemCenter!Microsoft.SystemCenter.AllComputersGroup",

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the run as account to which the monitor will need to be ran by")]
  [Alias('RunAsAccount')]
  [String[]]$MonitorRunAsAccount,

  [Parameter(Mandatory=$true,HelpMessage="Select which error state the alert will generate from")]
  [ValidateSet('Error','Warning')]
  [String]$AlertOnState,

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the alert")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$AlertName,

  [Parameter(Mandatory=$true,HelpMessage="Enter an alert message for the alert generated")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$AlertMessage,

  [Parameter(Mandatory=$true,HelpMessage="Select which alert priority the alert will have")]
  [ValidateSet('High','Normal', 'Low')]
  [String]$AlertPriority,

  [Parameter(Mandatory=$true,HelpMessage="Select which alert severity the alert will have")]
  [ValidateSet('Error','Warning')]
  [String]$AlertSeverity,

  [Parameter(Mandatory=$true,HelpMessage="Enter the name of the service to monitor, can use Get-Service to find the names")]
  [String]$ServiceName,

  [Parameter(Mandatory=$true,HelpMessage="Select if the monitor will monitor if the service is set as automatic")]
  [ValidateSet('true','false')]
  [String]$AlertOnAuto,

  [Parameter(Mandatory=$false,HelpMessage="Enter a paragraph for the knowledgebase article for this discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$KnowledgeArticle,

  [Parameter(Mandatory=$true,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )

  # Wrties variable values which are specific to Visual Studios
  $Target = "$" + "Target"
  $Data = "$" + "Data"
  $ClassContent = Get-Content $MPMonitorRuleFile
  $MonitorID = $MonitorName -replace " ", "."
  $AlertMessageID = "$MonitorID.AlertMessage"

  # Write Monitor
  $FindMonitorsLine = Select-String $MPMonitorRuleFile -pattern "</Monitors>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindMonitorsLine] += "`n      <UnitMonitor ID=""$MonitorID"" Accessibility=""Internal"" Enabled=""$MonitorEnabled"" Target=""$MonitorTarget"" ParentMonitorID=""Health!System.Health.AvailabilityState"" Remotable=""true"" Priority=""Normal"" TypeID=""Windows!Microsoft.Windows.CheckNTServiceStateMonitorType"" ConfirmDelivery=""false"" RunAs=""$MonitorRunAsAccount"">`n        <Category>AvailabilityHealth</Category>`n        <AlertSettings AlertMessage=""$AlertMessageID"">`n          <AlertOnState>$AlertOnState</AlertOnState>`n          <AutoResolve>true</AutoResolve>`n          <AlertPriority>$AlertPriority</AlertPriority>`n          <AlertSeverity>MatchMonitorHealth</AlertSeverity>`n          <AlertParameters>`n            <AlertParameter1>$Target/Host/Property[Type=""Windows!Microsoft.Windows.Computer""]/NetworkName$</AlertParameter1>`n          </AlertParameters>`n                  </AlertSettings>`n        <OperationalStates>`n          <OperationalState ID=""FirstEventRaised"" MonitorTypeStateID=""Running"" HealthState=""Success"" />`n          <OperationalState ID=""SecondEventRaised"" MonitorTypeStateID=""NotRunning"" HealthState=""Error"" />`n        </OperationalStates>`n        <Configuration>`n          <ComputerName>$Target/Host/Property[Type=""Windows!Microsoft.Windows.Computer""]/NetworkName$</ComputerName>`n          <ServiceName>$ServiceName</ServiceName>`n          <CheckStartupType>$AlertonAuto</CheckStartupType>`n        </Configuration>`n      </UnitMonitor>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write String Resources
  $FindStringResourcesLine = Select-String $MPMonitorRuleFile -pattern "</StringResources>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindStringResourcesLine] += "`n<StringResource ID=""$AlertMessageID"" />"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write display strings
  $FindLastDisplayStringLine = Select-String $MPMonitorRuleFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$MonitorID"">`n     <Name>$MonitorName</Name>`n     <Description>$MonitorDescription</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$AlertMessageID"">`n     <Name>$AlertName</Name>`n     <Description>$AlertMessage</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$MonitorID"" SubElementID=""FirstEventRaised"">`n     <Name>FirstEventRaised</Name>`n     <Description>FirstEventRaised</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$MonitorID"" SubElementID=""SecondEventRaised"">`n     <Name>SecondEventRaised</Name>`n     <Description>SecondEventRaised</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Writes the Knowledge Article to the XML so SCOM can read the display names correctly
  $FindLastKnowledgeArticleLine = Select-String $MPMonitorRuleFile -pattern "</KnowledgeArticles>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastKnowledgeArticleLine] += "`n    <KnowledgeArticle ElementID=""$MonitorID"" Visible=""true"">`n     <MamlContent>`n     <maml:section xmlns:maml=""http://schemas.microsoft.com/maml/2004/10"">`n              <maml:title>$MonitorName</maml:title>`n              <maml:para>$KnowledgeArticle</maml:para>`n            </maml:section>`n          </MamlContent>`n    </KnowledgeArticle>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  }

############################################################################################################################################################
# Add-SCOMMPWindowsServiceCPUPerformanceMonitor
# 
############################################################################################################################################################

  Function Add-SCOMMPWindowsServiceCPUPerformanceMonitor
  {
   [cmdletbinding()]

  Param (


  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the monitor class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$MonitorName,

  [Parameter(Mandatory=$true,HelpMessage="Select if the Monitor will be enabled straight away")]
  [ValidateSet('true','false')]
  [String]$MonitorEnabled,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the monitor will apply to")]
  [Alias('TargetClassID')]
  [String]$MonitorTarget = "SystemCenter!Microsoft.SystemCenter.AllComputersGroup",

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the run as account to which the monitor will need to be ran by")]
  [Alias('RunAsAccount')]
  [String[]]$MonitorRunAsAccount,

  [Parameter(Mandatory=$true,HelpMessage="Select which error state the alert will generate from")]
  [ValidateSet('Error','Warning')]
  [String]$AlertOnState,

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the alert")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$AlertName,

  [Parameter(Mandatory=$true,HelpMessage="Enter an alert message for the alert generated")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$AlertMessage,

  [Parameter(Mandatory=$true,HelpMessage="Select which alert priority the alert will have")]
  [ValidateSet('High','Normal', 'Low')]
  [String]$AlertPriority,

  [Parameter(Mandatory=$true,HelpMessage="Select which alert severity the alert will have")]
  [ValidateSet('Error','Warning')]
  [String]$AlertSeverity,

  [Parameter(Mandatory=$true,HelpMessage="Select if the monitor will monitor if the service is set as automatic")]
  [ValidateSet('true','false')]
  [String]$AlertOnAuto,

  [Parameter(Mandatory=$true,HelpMessage="Enter the name of the service to monitor, can use Get-Service to find the names")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$ServiceName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the frequency of the monitor in seconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$Frequency,

  [Parameter(Mandatory=$true,HelpMessage="Enter the threshold to not breach in numerals based on percentage")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$Threshold,

  [Parameter(Mandatory=$true,HelpMessage="Enter the number of samples to compare with")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$NumSamples,

  [Parameter(Mandatory=$false,HelpMessage="Enter a paragraph for the knowledgebase article for this discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$KnowledgeArticle,

  [Parameter(Mandatory=$true,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )

  # Wrties variable values which are specific to Visual Studios
  $Target = "$" + "Target"
  $Data = "$" + "Data"
  $ClassContent = Get-Content $MPMonitorRuleFile
  $MonitorID = $MonitorName -replace " ", "."
  $AlertMessageID = "$MonitorID.AlertMessage"

  # Write Monitor
  $FindMonitorsLine = Select-String $MPMonitorRuleFile -pattern "</Monitors>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindMonitorsLine] += "`n      <UnitMonitor ID=""$MonitorID"" Accessibility=""Internal"" Enabled=""$MonitorEnabled"" Target=""$MonitorTarget"" ParentMonitorID=""Health!System.Health.PerformanceState"" Remotable=""true"" Priority=""Normal"" TypeID=""MSNL!Microsoft.SystemCenter.NTService.ConsecutiveSamplesThreshold.ErrorOnTooHigh"" ConfirmDelivery=""false"" RunAs=""$MonitorRunAsAccount"">`n        <Category>PerformanceHealth</Category>`n        <AlertSettings AlertMessage=""$AlertMessageID"">`n          <AlertOnState>$AlertOnState</AlertOnState>`n          <AutoResolve>true</AutoResolve>`n          <AlertPriority>$AlertPriority</AlertPriority>`n          <AlertSeverity>MatchMonitorHealth</AlertSeverity>`n          <AlertParameters>`n                        <AlertParameter1>$Target/Host/Property[Type=""Windows!Microsoft.Windows.Computer""]/NetworkName$</AlertParameter1>`n          </AlertParameters>`n                  </AlertSettings>`n        <OperationalStates>`n          <OperationalState ID=""OK"" MonitorTypeStateID=""SampleCountNormal"" HealthState=""Success"" />`n          <OperationalState ID=""Error"" MonitorTypeStateID=""SampleCountTooHigh"" HealthState=""Error"" />`n        </OperationalStates>`n        <Configuration>`n          <ServiceName>$ServiceName</ServiceName>`n          <ObjectName>Process</ObjectName>`n          <CounterName>Percent Processor Time</CounterName>`n          <InstanceProperty>Name</InstanceProperty>`n          <ValueProperty>PercentProcessorTime</ValueProperty>`n          <Frequency>$Frequency</Frequency>`n          <ScaleBy>$Target/Host/Property[Type=""Windows!Microsoft.Windows.Computer""]/LogicalProcessors$</ScaleBy>`n          <Threshold>$Threshold</Threshold>`n          <NumSamples>$NumSamples</NumSamples>`n        </Configuration>`n      </UnitMonitor>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write String Resources
  $FindStringResourcesLine = Select-String $MPMonitorRuleFile -pattern "</StringResources>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindStringResourcesLine] += "`n<StringResource ID=""$AlertMessageID"" />"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write display strings
  $FindLastDisplayStringLine = Select-String $MPMonitorRuleFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$MonitorID"">`n     <Name>$MonitorName</Name>`n     <Description>$MonitorDescription</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$AlertMessageID"">`n     <Name>$AlertName</Name>`n     <Description>$AlertMessage</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$MonitorID"" SubElementID=""OK"">`n     <Name>SampleCountNormal</Name>`n     <Description>SampleCountNormal</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$MonitorID"" SubElementID=""Error"">`n     <Name>SampleCountTooHigh</Name>`n     <Description>SampleCountTooHigh</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Writes the Knowledge Article to the XML so SCOM can read the display names correctly
  $FindLastKnowledgeArticleLine = Select-String $MPMonitorRuleFile -pattern "</KnowledgeArticles>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastKnowledgeArticleLine] += "`n    <KnowledgeArticle ElementID=""$MonitorID"" Visible=""true"">`n     <MamlContent>`n     <maml:section xmlns:maml=""http://schemas.microsoft.com/maml/2004/10"">`n              <maml:title>$MonitorName</maml:title>`n              <maml:para>$KnowledgeArticle</maml:para>`n            </maml:section>`n          </MamlContent>`n    </KnowledgeArticle>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  }

############################################################################################################################################################
# Add-SCOMMPWindowsServiceMemoryPerformanceMonitor
# 
############################################################################################################################################################

  Function Add-SCOMMPWindowsServiceMemoryPerformanceMonitor
  {
   [cmdletbinding()]

  Param (
  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the monitor class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$MonitorName,

  [Parameter(Mandatory=$true,HelpMessage="Select if the Monitor will be enabled straight away")]
  [ValidateSet('true','false')]
  [String]$MonitorEnabled,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the monitor will apply to")]
  [Alias('TargetClassID')]
  [String]$MonitorTarget = "SystemCenter!Microsoft.SystemCenter.AllComputersGroup",

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the run as account to which the monitor will need to be ran by")]
  [Alias('RunAsAccount')]
  [String[]]$MonitorRunAsAccount,

  [Parameter(Mandatory=$true,HelpMessage="Select which error state the alert will generate from")]
  [ValidateSet('Error','Warning')]
  [String]$AlertOnState,

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the alert")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$AlertName,

  [Parameter(Mandatory=$true,HelpMessage="Enter an alert message for the alert generated")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$AlertMessage,

  [Parameter(Mandatory=$true,HelpMessage="Select which alert priority the alert will have")]
  [ValidateSet('High','Normal', 'Low')]
  [String]$AlertPriority,

  [Parameter(Mandatory=$true,HelpMessage="Select which alert severity the alert will have")]
  [ValidateSet('Error','Warning')]
  [String]$AlertSeverity,

  [Parameter(Mandatory=$true,HelpMessage="Select if the monitor will monitor if the service is set as automatic")]
  [ValidateSet('true','false')]
  [String]$AlertOnAuto,

  [Parameter(Mandatory=$true,HelpMessage="Enter the name of the service to monitor, can use Get-Service to find the names")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$ServiceName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the frequency of the monitor in seconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$Frequency,

  [Parameter(Mandatory=$true,HelpMessage="Enter the threshold to not breach in numerals based on percentage")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$Threshold,

  [Parameter(Mandatory=$true,HelpMessage="Enter the number of samples to compare with")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$NumSamples,

  [Parameter(Mandatory=$false,HelpMessage="Enter a paragraph for the knowledgebase article for this discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$KnowledgeArticle,

  [Parameter(Mandatory=$true,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )


  # Wrties variable values which are specific to Visual Studios
  $Target = "$" + "Target"
  $Data = "$" + "Data"
  $ClassContent = Get-Content $MPMonitorRuleFile
  $MonitorID = $MonitorName -replace " ", "."
  $AlertMessageID = "$MonitorID.AlertMessage"

  # Write Monitor
  $FindMonitorsLine = Select-String $MPMonitorRuleFile -pattern "</Monitors>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindMonitorsLine] += "`n      <UnitMonitor ID=""$MonitorID"" Accessibility=""Internal"" Enabled=""$MonitorEnabled"" Target=""$MonitorTarget"" ParentMonitorID=""Health!System.Health.PerformanceState"" Remotable=""true"" Priority=""Normal"" TypeID=""MSNL!Microsoft.SystemCenter.NTService.ConsecutiveSamplesThreshold.ErrorOnTooHigh"" ConfirmDelivery=""false"" RunAs=""$MonitorRunAsAccount"">`n        <Category>PerformanceHealth</Category>`n        <AlertSettings AlertMessage=""$AlertMessageID"">`n          <AlertOnState>$AlertOnState</AlertOnState>`n          <AutoResolve>true</AutoResolve>`n          <AlertPriority>$AlertPriority</AlertPriority>`n          <AlertSeverity>MatchMonitorHealth</AlertSeverity>`n          <AlertParameters>`n                        <AlertParameter1>$Target/Host/Property[Type=""Windows!Microsoft.Windows.Computer""]/NetworkName$</AlertParameter1>`n          </AlertParameters>`n                  </AlertSettings>`n        <OperationalStates>`n          <OperationalState ID=""OK"" MonitorTypeStateID=""SampleCountNormal"" HealthState=""Success"" />`n          <OperationalState ID=""Error"" MonitorTypeStateID=""SampleCountTooHigh"" HealthState=""Error"" />`n        </OperationalStates>`n        <Configuration>`n          <ServiceName>$ServiceName</ServiceName>`n          <ObjectName>Process</ObjectName>`n          <CounterName>Private Bytes</CounterName>`n          <InstanceProperty>Name</InstanceProperty>`n          <ValueProperty>PrivateBytes</ValueProperty>`n          <Frequency>$Frequency</Frequency>`n          <ScaleBy>$Target/Host/Property[Type=""Windows!Microsoft.Windows.Computer""]/LogicalProcessors$</ScaleBy>`n          <Threshold>$Threshold</Threshold>`n          <NumSamples>$NumSamples</NumSamples>`n        </Configuration>`n      </UnitMonitor>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write String Resources
  $FindStringResourcesLine = Select-String $MPMonitorRuleFile -pattern "</StringResources>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindStringResourcesLine] += "`n<StringResource ID=""$AlertMessageID"" />"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write display strings
  $FindLastDisplayStringLine = Select-String $MPMonitorRuleFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$MonitorID"">`n     <Name>$MonitorName</Name>`n     <Description>$MonitorDescription</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$AlertMessageID"">`n     <Name>$AlertName</Name>`n     <Description>$AlertMessage</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$MonitorID"" SubElementID=""OK"">`n     <Name>SampleCountNormal</Name>`n     <Description>SampleCountNormal</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$MonitorID"" SubElementID=""Error"">`n     <Name>SampleCountTooHigh</Name>`n     <Description>SampleCountTooHigh</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Writes the Knowledge Article to the XML so SCOM can read the display names correctly
  $FindLastKnowledgeArticleLine = Select-String $MPMonitorRuleFile -pattern "</KnowledgeArticles>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastKnowledgeArticleLine] += "`n    <KnowledgeArticle ElementID=""$MonitorID"" Visible=""true"">`n     <MamlContent>`n     <maml:section xmlns:maml=""http://schemas.microsoft.com/maml/2004/10"">`n              <maml:title>$MonitorName</maml:title>`n              <maml:para>$KnowledgeArticle</maml:para>`n            </maml:section>`n          </MamlContent>`n    </KnowledgeArticle>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  }

############################################################################################################################################################
# Add-SCOMMPWindowsGenericLogMonitor
# 
############################################################################################################################################################

  Function Add-SCOMMPWindowsGenericLogMonitor
  {
   [cmdletbinding()]

  Param (
  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the monitor class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$MonitorName,

  [Parameter(Mandatory=$true,HelpMessage="Select if the Monitor will be enabled straight away")]
  [ValidateSet('true','false')]
  [String]$MonitorEnabled,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the monitor will apply to")]
  [Alias('TargetClassID')]
  [String]$MonitorTarget = "SystemCenter!Microsoft.SystemCenter.AllComputersGroup",

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the run as account to which the monitor will need to be ran by")]
  [Alias('RunAsAccount')]
  [String[]]$MonitorRunAsAccount,

  [Parameter(Mandatory=$true,HelpMessage="Select which error state the alert will generate from")]
  [ValidateSet('Error','Warning')]
  [String]$AlertOnState,

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the alert")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$AlertName,

  [Parameter(Mandatory=$true,HelpMessage="Enter an alert message for the alert generated")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$AlertMessage,

  [Parameter(Mandatory=$true,HelpMessage="Select which alert priority the alert will have")]
  [ValidateSet('High','Normal', 'Low')]
  [String]$AlertPriority,

  [Parameter(Mandatory=$true,HelpMessage="Select which alert severity the alert will have")]
  [ValidateSet('Error','Warning')]
  [String]$AlertSeverity,

  [Parameter(Mandatory=$true,HelpMessage="Enter the path for the generic log file")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$LogFileDirectory,

  [Parameter(Mandatory=$true,HelpMessage="Enter the log pattern which needs to match")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$LogPattern ,

  [Parameter(Mandatory=$true,HelpMessage="Select if this is a UTF8 log")]
  [ValidateSet('true','false')]
  [String]$LogIsUTF8,

  [Parameter(Mandatory=$true,HelpMessage="Enter the error message pattern which needs to match")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$ErrorMessagePattern,

  [Parameter(Mandatory=$false,HelpMessage="Enter a paragraph for the knowledgebase article for this discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$KnowledgeArticle,

  [Parameter(Mandatory=$true,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )

  # Wrties variable values which are specific to Visual Studios
  $Target = "$" + "Target"
  $Data = "$" + "Data"
  $ClassContent = Get-Content $MPMonitorRuleFile
  $MonitorID = $MonitorName -replace " ", "."
  $AlertMessageID = "$MonitorID.AlertMessage"

  # Write Monitor
  $FindMonitorsLine = Select-String $MPMonitorRuleFile -pattern "</Monitors>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindMonitorsLine] += "`n      <UnitMonitor ID=""$MonitorID"" Accessibility=""Internal"" Enabled=""$MonitorEnabled"" Target=""$MonitorTarget"" ParentMonitorID=""Health!System.Health.AvailabilityState"" Remotable=""true"" Priority=""Normal"" TypeID=""SAL!System.ApplicationLog.GenericLog.SingleEventManualReset2StateMonitorType"" ConfirmDelivery=""false"" RunAs=""$MonitorRunAsAccount"">`n        <Category>PerformanceHealth</Category>`n        <AlertSettings AlertMessage=""$AlertMessageID"">`n          <AlertOnState>$AlertOnState</AlertOnState>`n          <AutoResolve>true</AutoResolve>`n          <AlertPriority>$AlertPriority</AlertPriority>`n          <AlertSeverity>MatchMonitorHealth</AlertSeverity>`n</AlertSettings>`n        <OperationalStates>`n          <OperationalState ID=""Error"" MonitorTypeStateID=""EventRaised"" HealthState=""Error"" />`n          <OperationalState ID=""OK"" MonitorTypeStateID=""ManualResetEventRaised"" HealthState=""Success"" />`n        </OperationalStates>`n        <Configuration>`n          <LogFileDirectory>C:\ProgramData\Metron\Logs</LogFileDirectory>`n          <LogFilePattern>$LogPattern</LogFilePattern>`n          <LogIsUTF8>$LogIsUTF8</LogIsUTF8>`n          <Expression>`n            <RegExExpression>`n              <ValueExpression>`n                <XPathQuery Type=""String"">Params/Param[1]</XPathQuery>`n              </ValueExpression>`n              <Operator>ContainsSubstring</Operator>`n              <Pattern>$ErrorMessagePattern</Pattern>`n            </RegExExpression>`n          </Expression>`n          </Configuration>`n      </UnitMonitor>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write String Resources
  $FindStringResourcesLine = Select-String $MPMonitorRuleFile -pattern "</StringResources>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindStringResourcesLine] += "`n<StringResource ID=""$AlertMessageID"" />"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write display strings
  $FindLastDisplayStringLine = Select-String $MPMonitorRuleFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$MonitorID"">`n     <Name>$MonitorName</Name>`n     <Description>$MonitorDescription</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$AlertMessageID"">`n     <Name>$AlertName</Name>`n     <Description>$AlertMessage</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$MonitorID"" SubElementID=""Error"">`n     <Name>EventRaised</Name>`n     <Description>EventRaised</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$MonitorID"" SubElementID=""OK"">`n     <Name>ManualEventRaised</Name>`n     <Description>ManualEventRaised</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Writes the Knowledge Article to the XML so SCOM can read the display names correctly
  $FindLastKnowledgeArticleLine = Select-String $MPMonitorRuleFile -pattern "</KnowledgeArticles>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastKnowledgeArticleLine] += "`n    <KnowledgeArticle ElementID=""$MonitorID"" Visible=""true"">`n     <MamlContent>`n     <maml:section xmlns:maml=""http://schemas.microsoft.com/maml/2004/10"">`n              <maml:title>$MonitorName</maml:title>`n              <maml:para>$KnowledgeArticle</maml:para>`n            </maml:section>`n          </MamlContent>`n    </KnowledgeArticle>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  }

############################################################################################################################################################
# Add-SCOMMPPerformanceMonitor
# 
############################################################################################################################################################

  Function Add-SCOMMPPerformanceMonitor
  {
   [cmdletbinding()]

  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the monitor class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$MonitorName,

  [Parameter(Mandatory=$true,HelpMessage="Select if the Monitor will be enabled straight away")]
  [ValidateSet('true','false')]
  [String]$MonitorEnabled,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the monitor will apply to")]
  [Alias('TargetClassID')]
  [String]$MonitorTarget = "SystemCenter!Microsoft.SystemCenter.AllComputersGroup",

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the run as account to which the monitor will need to be ran by")]
  [Alias('RunAsAccount')]
  [String[]]$MonitorRunAsAccount,

  [Parameter(Mandatory=$true,HelpMessage="Enter the computername for the monitor if applicable")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$ComputerName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the counter which the performance monitor will be based on")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$CounterName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the object from the counter which the performance monitor will be based on")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$ObjectName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the instance name from the counter which the performance monitor will be based on")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$InstanceName,

  [Parameter(Mandatory=$true,HelpMessage="Select if the monitor will monitor all instances of the selected counter")]
  [ValidateSet('true','false')]
  [String]$AllInstances,

  [Parameter(Mandatory=$true,HelpMessage="Enter a frequency which the monitor will run in seconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$Frequency,

  [Parameter(Mandatory=$true,HelpMessage="Enter the threshold for the counter in integer in percentage")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$Threshold,

  [Parameter(Mandatory=$true,HelpMessage="Select which error state the alert will generate from")]
  [ValidateSet('Error','Warning')]
  [String]$AlertOnState,

  [Parameter(Mandatory=$true,HelpMessage="Select which alert priority the alert will have")]
  [ValidateSet('High','Normal', 'Low')]
  [String]$AlertPriority,

  [Parameter(Mandatory=$true,HelpMessage="Select which alert severity the alert will have")]
  [ValidateSet('Error','Warning')]
  [String]$AlertSeverity,

  [Parameter(Mandatory=$false,HelpMessage="Enter a paragraph for the knowledgebase article for this discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$KnowledgeArticle,

  [Parameter(Mandatory=$true,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )

  # Wrties variable values which are specific to Visual Studios
  $Target = "$" + "Target" 
  $Data = "$" + "Data"
  $MonitorID = $MonitorName -replace " ", "."
  $AlertMessageID = "$MonitorID.AlertMessage"
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write Monitor
  $FindMonitorsLine = Select-String $MPMonitorRuleFile -pattern "</Monitors>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindMonitorsLine] += "`n      <UnitMonitor ID=""$MonitorID"" Accessibility=""Internal"" Enabled=""$MonitorEnabled"" Target=""$MonitorTarget"" ParentMonitorID=""Health!System.Health.PerformanceState"" Remotable=""true"" Priority=""Normal"" TypeID=""Performance!System.Performance.ThresholdMonitorType"" ConfirmDelivery=""false"" RunAs=""$MonitorRunAsAccount"">`n        <Category>PerformanceHealth</Category>`n        <AlertSettings AlertMessage=""$AlertMessageID"">`n          <AlertOnState>$AlertOnState</AlertOnState>`n          <AutoResolve>true</AutoResolve>`n          <AlertPriority>$AlertPriority</AlertPriority>`n          <AlertSeverity>MatchMonitorHealth</AlertSeverity>`n          <AlertParameters>`n            <AlertParameter1>$Data[Default='']/Context/InstanceName$</AlertParameter1>`n            <AlertParameter2>$Data[Default='']/Context/ObjectName$</AlertParameter2>`n            <AlertParameter3>$Data[Default='']/Context/CounterName$</AlertParameter3>`n            <AlertParameter4>$Data[Default='']/Context/Value$</AlertParameter4>`n            <AlertParameter5>$Data[Default='']/Context/TimeSampled$</AlertParameter5>`n          </AlertParameters>`n                  </AlertSettings>`n        <OperationalStates>`n          <OperationalState ID=""OK"" MonitorTypeStateID=""UnderThreshold"" HealthState=""Success"" />`n          <OperationalState ID=""Error"" MonitorTypeStateID=""OverThreshold"" HealthState=""Error"" />`n        </OperationalStates>`n        <Configuration>`n          <ComputerName>$ComputerName</ComputerName>`n          <CounterName>$CounterName</CounterName>`n          <ObjectName>$Objectname</ObjectName>`n          <InstanceName>$InstanceName</InstanceName>`n          <AllInstances>$AllInstances</AllInstances>`n          <Frequency>$Frequency</Frequency>`n          <Threshold>$Threshold</Threshold>`n          </Configuration>`n      </UnitMonitor>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write String Resources
  $FindStringResourcesLine = Select-String $MPMonitorRuleFile -pattern "</StringResources>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindStringResourcesLine] += "`n<StringResource ID=""$AlertMessageID"" />"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write display strings
  $FindLastDisplayStringLine = Select-String $MPMonitorRuleFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$MonitorID"">`n     <Name>$MonitorName</Name>`n     <Description>$MonitorDescription</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$AlertMessageID"">`n     <Name>$AlertName</Name>`n     <Description>Instance Name: {0}`n Object Name {1}`n Counter Name: {2}`n Value: {3}`n Time Sampled: {4}</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$MonitorID"" SubElementID=""OK"">`n     <Name>UnderThreshold</Name>`n     <Description>UnderThreshold</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$MonitorID"" SubElementID=""Error"">`n     <Name>OverThreshold</Name>`n     <Description>OverThreshold</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Writes the Knowledge Article to the XML so SCOM can read the display names correctly
  $FindLastKnowledgeArticleLine = Select-String $MPMonitorRuleFile -pattern "</KnowledgeArticles>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastKnowledgeArticleLine] += "`n    <KnowledgeArticle ElementID=""$MonitorID"" Visible=""true"">`n     <MamlContent>`n     <maml:section xmlns:maml=""http://schemas.microsoft.com/maml/2004/10"">`n              <maml:title>$MonitorName</maml:title>`n              <maml:para>$KnowledgeArticle</maml:para>`n            </maml:section>`n          </MamlContent>`n    </KnowledgeArticle>"
  $ClassContent | Set-Content $MPMonitorRuleFile

}


############################################################################################################################################################
# Add-SCOMMPWindowsEventRule
# 
############################################################################################################################################################

  Function Add-SCOMMPWindowsEventRule
  {
   [cmdletbinding()]

  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the rule class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$RuleName,

  [Parameter(Mandatory=$true,HelpMessage="Enter a description for the rule class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$RuleDescription,

  [Parameter(Mandatory=$true,HelpMessage="Select if the rule will be enabled by default")]
  [ValidateSet('true','false')]
  [String]$RuleEnabled,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the rule will be used for")]
  [Alias('TargetClassID')]
  [String]$RuleTarget = "SystemCenter!Microsoft.SystemCenter.AllComputersGroup",

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the run as account which the rule will use")]
  [Alias('RunAsAccount')]
  [String[]]$RuleRunAsAccount,

  [Parameter(Mandatory=$true,HelpMessage="Enter the windows event log the rule will use for unhealthy status")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$LogName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the windows event display number the rule will use for unhealthy status")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$EventDisplayNumber,

  [Parameter(Mandatory=$true,HelpMessage="Enter the windows event publisher the rule will use for unhealthy status")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$PublisherName,

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the alert")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$AlertName,

  [Parameter(Mandatory=$true,HelpMessage="Select which priority the alert generated will have")]
  [ValidateSet('High', 'Normal', 'Low')]
  [String]$RulePriority,

  [Parameter(Mandatory=$true,HelpMessage="Select which severity the alert generated will have")]
  [ValidateSet('Critical', 'Warning', 'Information')]
  [String]$RuleSeverity,

  [Parameter(Mandatory=$false,HelpMessage="Enter a paragraph for the knowledgebase article for this discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$KnowledgeArticle,

  [Parameter(Mandatory=$true,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )

   # Sets Severity
   Switch ($RuleSeverity){
  'Critical' {$Severity = '1'}
  'Warning' {$Severity = '2'}
  'Information' {$Severity = '3'}
  }

   # Sets Priority
   Switch ($RulePriority){
  'High' {$Priority = '1'}
  'Normal' {$Priority = '2'}
  'Low' {$Priority = '3'}
  }

  # Wrties variable values which are specific to Visual Studios
  $Data = "$" + "Data"
  $MPElement = "$" + "MPElement"
  $RuleID = $RuleName -replace " ", "."
  $AlertMessageID = "$RuleID.AlertMessage"
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write Rule
  $FindRulesLine = Select-String $MPMonitorRuleFile -pattern "</Rules>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindRulesLine] += "`n      <Rule ID=""$RuleID"" Target=""$RuleTarget"" Enabled=""$RuleEnabled"" ConfirmDelivery=""false"" Remotable=""true"" Priority=""Normal"" DiscardLevel=""100"">`n        <Category>Alert</Category>`n        <DataSources>`n          <DataSource ID=""DS"" TypeID=""Windows!Microsoft.Windows.EventProvider"" RunAs=""$RuleRunAsAccount"">`n             <LogName>$LogName</LogName>`n            <Expression>`n              <And>`n                <Expression>`n                  <SimpleExpression>`n                    <ValueExpression>`n                      <XPathQuery>Channel</XPathQuery>`n                    </ValueExpression>`n                    <Operator>Equal</Operator>`n                    <ValueExpression>`n                      <Value>$LogName</Value>`n                    </ValueExpression>`n                  </SimpleExpression>`n                </Expression>`n                <Expression>`n                  <SimpleExpression>`n                    <ValueExpression>`n                      <XPathQuery>EventDisplayNumber</XPathQuery>`n                    </ValueExpression>`n                    <Operator>Equal</Operator>`n                    <ValueExpression>`n                      <Value>$EventDisplayNumber</Value>`n                    </ValueExpression>`n     </SimpleExpression>`n     </Expression>`n                <Expression>`n                  <SimpleExpression>`n                    <ValueExpression>`n                      <XPathQuery>PublisherName</XPathQuery>`n                    </ValueExpression>`n                    <Operator>Equal</Operator>`n                    <ValueExpression>`n                      <Value>$PublisherName</Value>`n                    </ValueExpression>`n                  </SimpleExpression>`n                </Expression>`n              </And>`n            </Expression>`n          </DataSource>`n        </DataSources>`n        <ConditionDetection ID=""CD"" TypeID=""System!System.ExpressionFilter"" RunAs=""$RuleRunAsAccount"">`n          <Expression>`n            <RegExExpression>`n              <ValueExpression>`n                <XPathQuery>PublisherName</XPathQuery>`n              </ValueExpression>`n              <Operator>MatchesRegularExpression</Operator>`n              <Pattern>$PublisherName</Pattern>`n            </RegExExpression>`n          </Expression>`n        </ConditionDetection>`n        <WriteActions>`n          <WriteAction ID=""Alert"" TypeID=""Health!System.Health.GenerateAlert"">`n            <Priority>$Priority</Priority>`n            <Severity>$Severity</Severity>`n            <AlertMessageId>$MPElement[Name=""$AlertMessageID""]$</AlertMessageId>`n            <AlertParameters>`n              <AlertParameter1>$Data/EventDescription$</AlertParameter1>`n            </AlertParameters>`n               <Suppression>`n              <SuppressionValue>$Data/EventDescription$</SuppressionValue>`n            </Suppression>`n          </WriteAction>`n        </WriteActions>`n      </Rule>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write String Resources
  $FindStringResourcesLine = Select-String $MPMonitorRuleFile -pattern "</StringResources>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindStringResourcesLine] += "`n<StringResource ID=""$AlertMessageID"" />"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write display strings
  $FindLastDisplayStringLine = Select-String $MPMonitorRuleFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$RuleID"">`n     <Name>$RuleName</Name>`n     <Description>$RuleDescription</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$AlertMessageID"">`n     <Name>$AlertName</Name>`n     <Description>Event Description: {0} </Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Writes the Knowledge Article to the XML so SCOM can read the display names correctly
  $FindLastKnowledgeArticleLine = Select-String $MPMonitorRuleFile -pattern "</KnowledgeArticles>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastKnowledgeArticleLine] += "`n    <KnowledgeArticle ElementID=""$RuleID"" Visible=""true"">`n     <MamlContent>`n     <maml:section xmlns:maml=""http://schemas.microsoft.com/maml/2004/10"">`n              <maml:title>$RuleName</maml:title>`n              <maml:para>$KnowledgeArticle</maml:para>`n            </maml:section>`n          </MamlContent>`n    </KnowledgeArticle>"
  $ClassContent | Set-Content $MPMonitorRuleFile


  }

############################################################################################################################################################
# Add-SCOMMPWindowsPowerShellScriptRule
# 
############################################################################################################################################################

  Function Add-SCOMMPWindowsPowerShellScriptRule
  {
   [cmdletbinding()]

  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the rule class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$RuleName,

  [Parameter(Mandatory=$true,HelpMessage="Enter a description for the rule class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$RuleDescription,

  [Parameter(Mandatory=$true,HelpMessage="Select if the rule will be enabled by default")]
  [ValidateSet('true','false')]
  [String]$RuleEnabled,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the rule will be used for")]
  [Alias('TargetClassID')]
  [String]$RuleTarget = "SystemCenter!Microsoft.SystemCenter.AllComputersGroup",

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the run as account which the rule will use")]
  [Alias('RunAsAccount')]
  [String[]]$RuleRunAsAccount,

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the alert")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$AlertName,

  [Parameter(Mandatory=$true,HelpMessage="Enter an alert message for the alert generated")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$AlertMessage,

  [Parameter(Mandatory=$true,HelpMessage="Enter the name of the PowerShell script which will be used. You will need to create one after")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$ScriptName,

  [Parameter(Mandatory=$true,HelpMessage="Select which priority the alert generated will have")]
  [ValidateSet('High', 'Normal', 'Low')]
  [String]$RulePriority,

  [Parameter(Mandatory=$true,HelpMessage="Select which severity the alert generated will have")]
  [ValidateSet('Critical', 'Warning', 'Information')]
  [String]$RuleSeverity,

  [Parameter(Mandatory=$true,HelpMessage="Enter the Interval based in seconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$IntervalSeconds,

  [Parameter(Mandatory=$false,HelpMessage="Enter a time based on 24 Hour clock to run at schedule")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$SyncTime,

  [Parameter(Mandatory=$true,HelpMessage="Enter the timeout in seconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TimeoutSeconds,

  [Parameter(Mandatory=$false,HelpMessage="Enter a paragraph for the knowledgebase article for this discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$KnowledgeArticle,

  [Parameter(Mandatory=$true,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )

   # Sets Severity
   Switch ($RuleSeverity){
  'Critical' {$Severity = '1'}
  'Warning' {$Severity = '2'}
  'Information' {$Severity = '3'}
  }

   # Sets Priority
   Switch ($RulePriority){
  'High' {$Priority = '1'}
  'Normal' {$Priority = '2'}
  'Low' {$Priority = '3'}
  }


  # Create PowerShell Script variables
  #$ScriptName = $ScriptName + ".ps1" -replace " ", "."
  $RuleID = $RuleName -replace " ","."
  $AlertMessageID = "$RuleID.AlertMessage"
  $IncludeFileContent = "$" + "IncludeFileContent"
  $ScriptBody = "$IncludeFileContent/$ScriptName$"
  $ClassContent = Get-Content $MPMonitorRuleFile
  Write-Host "Ensure to create your PowerShell script in Visual Studios which contains the same name you have entered" -ForegroundColor Yellow
  Write-Host ""

  # Write Rule
  $FindRulesLine = Select-String $MPMonitorRuleFile -pattern "</Rules>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindRulesLine] += "`n      <Rule ID=""$RuleID"" Target=""$RuleTarget"" Enabled=""$RuleEnabled"" ConfirmDelivery=""false"" Remotable=""true"" Priority=""Normal"" DiscardLevel=""100"">`n        <Category>Alert</Category>`n        <DataSources>`n          <DataSource ID=""Scheduler"" TypeID=""System!System.Scheduler"" RunAs=""$RuleRunAsAccount"">`n      <Scheduler>`n        <SimpleReccuringSchedule>`n          <Interval>$IntervalSeconds</Interval>`n          <SyncTime>$SyncTime</SyncTime>`n      </SimpleReccuringSchedule>`n      <ExcludeDates />`n    </Scheduler></DataSource>`n        </DataSources>`n    <WriteActions>`n          <WriteAction ID=""ExecuteScript"" TypeID=""Windows!Microsoft.Windows.PowerShellPropertyBagWriteAction"">`n        <ScriptName>$ScriptName</ScriptName>`n        <ScriptBody>$ScriptBody</ScriptBody>`n        <TimeoutSeconds>$TimeoutSeconds</TimeoutSeconds>`n      </WriteAction>`n        </WriteActions>`n      </Rule>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write String Resources
  $FindStringResourcesLine = Select-String $MPMonitorRuleFile -pattern "</StringResources>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindStringResourcesLine] += "`n<StringResource ID=""$AlertMessageID"" />"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write display strings
  $FindLastDisplayStringLine = Select-String $MPMonitorRuleFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$RuleID"">`n     <Name>$RuleName</Name>`n     <Description>$RuleDescription</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$AlertMessageID"">`n     <Name>$AlertName</Name>`n     <Description>$AlertMessage</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Writes the Knowledge Article to the XML so SCOM can read the display names correctly
  $FindLastKnowledgeArticleLine = Select-String $MPMonitorRuleFile -pattern "</KnowledgeArticles>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastKnowledgeArticleLine] += "`n    <KnowledgeArticle ElementID=""$RuleID"" Visible=""true"">`n     <MamlContent>`n     <maml:section xmlns:maml=""http://schemas.microsoft.com/maml/2004/10"">`n              <maml:title>$RuleName</maml:title>`n              <maml:para>$KnowledgeArticle</maml:para>`n            </maml:section>`n          </MamlContent>`n    </KnowledgeArticle>"
  $ClassContent | Set-Content $MPMonitorRuleFile


  } 

############################################################################################################################################################
# Add-SCOMMPPerformanceRule
# 
############################################################################################################################################################

  Function Add-SCOMMPPerformanceRule
  {
   [cmdletbinding()]

  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the rule class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$RuleName,

  [Parameter(Mandatory=$true,HelpMessage="Enter a description for the rule class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$RuleDescription,

  [Parameter(Mandatory=$true,HelpMessage="Select if the rule will be enabled by default")]
  [ValidateSet('true','false')]
  [String]$RuleEnabled,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the rule will be used for")]
  [Alias('TargetClassID')]
  [String]$RuleTarget = "SystemCenter!Microsoft.SystemCenter.AllComputersGroup",

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the run as account which the rule will use")]
  [Alias('RunAsAccount')]
  [String[]]$RuleRunAsAccount,

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the alert")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$AlertName,

  [Parameter(Mandatory=$true,HelpMessage="Enter an alert message for the alert generated")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$AlertMessage,

  [Parameter(Mandatory=$true,HelpMessage="Enter the computername for the monitor if applicable")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$ComputerName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the counter which the performance monitor will be based on")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$CounterName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the object from the counter which the performance monitor will be based on")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$ObjectName,

  [Parameter(Mandatory=$true,HelpMessage="Select if the monitor will monitor all instances of the selected counter")]
  [ValidateSet('true','false')]
  [String]$AllInstances,

  [Parameter(Mandatory=$true,HelpMessage="Enter a frequency which the monitor will run in seconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$Frequency,

  [Parameter(Mandatory=$true,HelpMessage="Enter the threshold for the counter in integer in percentage")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$Threshold,

  [Parameter(Mandatory=$true,HelpMessage="Enter the instance property value")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$InstanceProperty,

  [Parameter(Mandatory=$true,HelpMessage="Enter the tolerance value")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$Tolerance,

  [Parameter(Mandatory=$true,HelpMessage="Enter the maximum sample separation value")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$MaxSampleSeparation,

  [Parameter(Mandatory=$false,HelpMessage="Enter a paragraph for the knowledgebase article for this discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$KnowledgeArticle,

  [Parameter(Mandatory=$true,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )

   # Sets Severity
   Switch ($RuleSeverity){
  'Critical' {$Severity = '1'}
  'Warning' {$Severity = '2'}
  'Information' {$Severity = '3'}
  }

   # Sets Priority
   Switch ($RulePriority){
  'High' {$Priority = '1'}
  'Normal' {$Priority = '2'}
  'Low' {$Priority = '3'}
  }

  # Wrties variable values which are specific to Visual Studios
  $Data = "$" + "Data"
  $MPElement = "$" + "MPElement"
  $RuleID = $RuleName -replace " ", "."
  $AlertMessageID = "$RuleID.AlertMessage"
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write Rule
  $FindRulesLine = Select-String $MPMonitorRuleFile -pattern "</Rules>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindRulesLine] += "`n      <Rule ID=""$RuleID"" Target=""$RuleTarget"" Enabled=""$RuleEnabled"" ConfirmDelivery=""false"" Remotable=""true"" Priority=""Normal"" DiscardLevel=""100"">`n        <Category>PerformanceCollection</Category>`n        <DataSources>`n          <DataSource ID=""DS"" TypeID=""Perf!System.Performance.OptimizedDataProvider"" RunAs=""$RuleRunAsAccount"">`n      <ComputerName>$ComputerName</ComputerName>`n          <CounterName>$Countername</CounterName>`n          <ObjectName>$ObjectName</ObjectName>`n          <InstanceName>$InstanceName</InstanceName>`n          <AllInstances>$AllInstances</AllInstances>`n          <Frequency>$Frequency</Frequency>`n          <Tolerance>$Tolerance</Tolerance>`n          <ToleranceType>Percentage</ToleranceType>`n          <MaximumSampleSeparation>$MaxSampleSeparation</MaximumSampleSeparation>`n        </DataSource>`n      </DataSources>`n              <WriteActions>`n          <WriteAction ID=""WriteToDB"" TypeID=""SC!Microsoft.SystemCenter.CollectPerformanceData"" />`n        <WriteAction ID=""WriteToDW"" TypeID=""MSDL!Microsoft.SystemCenter.DataWarehouse.PublishPerformanceData"" />`n             </WriteActions>`n      </Rule>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write String Resources
  $FindStringResourcesLine = Select-String $MPMonitorRuleFile -pattern "</StringResources>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindStringResourcesLine] += "`n<StringResource ID=""$AlertMessageID"" />"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write display strings
  $FindLastDisplayStringLine = Select-String $MPMonitorRuleFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$RuleID"">`n     <Name>$RuleName</Name>`n     <Description>$RuleDescription</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$AlertMessageID"">`n     <Name>$AlertName</Name>`n     <Description>$AlertMessage</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Writes the Knowledge Article to the XML so SCOM can read the display names correctly
  $FindLastKnowledgeArticleLine = Select-String $MPMonitorRuleFile -pattern "</KnowledgeArticles>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastKnowledgeArticleLine] += "`n    <KnowledgeArticle ElementID=""$RuleID"" Visible=""true"">`n     <MamlContent>`n     <maml:section xmlns:maml=""http://schemas.microsoft.com/maml/2004/10"">`n              <maml:title>$RuleName</maml:title>`n              <maml:para>$KnowledgeArticle</maml:para>`n            </maml:section>`n          </MamlContent>`n    </KnowledgeArticle>"
  $ClassContent | Set-Content $MPMonitorRuleFile


  }

############################################################################################################################################################
# Add-SCOMMPUnixLogFileRule
# 
############################################################################################################################################################

  Function Add-SCOMMPUnixLogFileRule
  {
   [cmdletbinding()]

  Param (

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the rule class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$RuleName,

  [Parameter(Mandatory=$true,HelpMessage="Enter a description for the rule class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$RuleDescription,

  [Parameter(Mandatory=$true,HelpMessage="Select if the rule will be enabled by default")]
  [ValidateSet('true','false')]
  [String]$RuleEnabled,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the rule will be used for")]
  [Alias('TargetClassID')]
  [String]$RuleTarget = "SystemCenter!Microsoft.SystemCenter.AllComputersGroup",

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the run as account which the rule will use")]
  [Alias('RunAsAccount')]
  [String[]]$RuleRunAsAccount,

  [Parameter(Mandatory=$true,HelpMessage="Enter the log file which will be monitored")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$LogFile,

  [Parameter(Mandatory=$true,HelpMessage="Enter the expression fiter pattern which will match to monitor")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$RegExpFilter,

  [Parameter(Mandatory=$true,HelpMessage="Enter the name of the publisher")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$PublisherName,

  [Parameter(Mandatory=$true,HelpMessage="Select which priority the alert generated will have")]
  [ValidateSet('High', 'Normal', 'Low')]
  [String]$RulePriority,

  [Parameter(Mandatory=$true,HelpMessage="Select which severity the alert generated will have")]
  [ValidateSet('Critical', 'Warning', 'Information')]
  [String]$RuleSeverity,

  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the alert")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$AlertName,

  [Parameter(Mandatory=$false,HelpMessage="Enter a paragraph for the knowledgebase article for this discovery")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$KnowledgeArticle,

  [Parameter(Mandatory=$true,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )

   # Sets Severity
   Switch ($RuleSeverity){
  'Critical' {$Severity = '1'}
  'Warning' {$Severity = '2'}
  'Information' {$Severity = '3'}
  }

   # Sets Priority
   Switch ($RulePriority){
  'High' {$Priority = '1'}
  'Normal' {$Priority = '2'}
  'Low' {$Priority = '3'}
  }

  # Wrties variable values which are specific to Visual Studios
  $Data = "$" + "Data"
  $MPElement = "$" + "MPElement"
  $RuleID = $RuleName -replace " ", "."
  $AlertMessageID = "$RuleID.AlertMessage"
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write Rule
  $FindRulesLine = Select-String $MPMonitorRuleFile -pattern "</Rules>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindRulesLine] += "`n      <Rule ID=""$RuleID"" Target=""$RuleTarget"" Enabled=""$RuleEnabled"" ConfirmDelivery=""false"" Remotable=""true"" Priority=""Normal"" DiscardLevel=""100"">`n        <Category>EventCollection</Category>`n        <DataSources>`n          <DataSource ID=""EventDS"" TypeID=""Unix!Microsoft.Unix.SCXLog.VarPriv.DataSource"">`n                         <Host>$Target/Property[Type=""MicrosoftUnixLibrary7711240!Microsoft.Unix.Computer""]/PrincipalName$</Host>`n                        <LogFile>$LogFile</LogFile>`n            <UserName>$RunAs[Name=""$RuleRunAsAccount""]/UserName$</UserName>`n            <Password>$RunAs[Name=""$RuleRunAsAccount""]/Password$</Password>`n            <RegExpFilter>$RegExpFilter</RegExpFilter>`n            <IndividualAlerts>false</IndividualAlerts>`n          </DataSource>`n        </DataSources>`n        <WriteActions>`n          <WriteAction ID=""GenerateAlert"" TypeID=""Health!System.Health.GenerateAlert"">`n            <Priority>$Priority</Priority>`n            <Severity>$Severity</Severity>`n            <AlertName>$AlertName</AlertName>`n            <AlertDescription>$Data/EventDescription$</AlertDescription>`n            <Suppression>`n              <SuppressionValue />`n            </Suppression>`n          </WriteAction>`n        </WriteActions>`n      </Rule>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write String Resources
  $FindStringResourcesLine = Select-String $MPMonitorRuleFile -pattern "</StringResources>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindStringResourcesLine] += "`n<StringResource ID=""$AlertMessageID"" />"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write display strings
  $FindLastDisplayStringLine = Select-String $MPMonitorRuleFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$RuleID"">`n     <Name>$RuleName</Name>`n     <Description>$RuleDescription</Description>`n    </DisplayString>`n    <DisplayString ElementID=""$AlertMessageID"">`n     <Name>$AlertName</Name>`n     <Description>Event Description: {0} </Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Writes the Knowledge Article to the XML so SCOM can read the display names correctly
  $FindLastKnowledgeArticleLine = Select-String $MPMonitorRuleFile -pattern "</KnowledgeArticles>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastKnowledgeArticleLine] += "`n    <KnowledgeArticle ElementID=""$RuleID"" Visible=""true"">`n     <MamlContent>`n     <maml:section xmlns:maml=""http://schemas.microsoft.com/maml/2004/10"">`n              <maml:title>$RuleName</maml:title>`n              <maml:para>$KnowledgeArticle</maml:para>`n            </maml:section>`n          </MamlContent>`n    </KnowledgeArticle>"
  $ClassContent | Set-Content $MPMonitorRuleFile


  }

############################################################################################################################################################
# Add-SCOMMPAgentTaskCommandLine
# 
############################################################################################################################################################
  
  Function Add-SCOMMPAgentTaskCommandLine
  {
   [cmdletbinding()]

  Param (
  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the task class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TaskName ,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the task will run for")]
  [Alias('TargetClassID')]
  [String]$TaskTarget = "SystemCenter!Microsoft.SystemCenter.AllComputersGroup",

  [Parameter(Mandatory=$true,HelpMessage="Select if the task will be enabled by default")]
  [ValidateSet('true','false')]
  [String]$TaskEnabled,

  [Parameter(Mandatory=$true,HelpMessage="Enter the application which the task will use")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TaskApplicationName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the working directory which the task will use")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TaskWorkingDirectory,

  [Parameter(Mandatory=$true,HelpMessage="Enter the command line which the task will use")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TaskCommandLine,

  [Parameter(Mandatory=$true,HelpMessage="Enter the timeout in seconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TimeoutSeconds,

  [Parameter(Mandatory=$true,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )

  # Wrties variable values which are specific to Visual Studios
  $Data = "$" + "Data"
  $MPElement = "$" + "MPElement"
  $TaskID = $TaskName -replace " ", "."
  $AlertMessageID = "$RuleID.AlertMessage"
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write Task
  $FindTasksLine = Select-String $MPMonitorRuleFile -pattern "</Tasks>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindTasksLine] += "`n      <Task ID=""$TaskID"" Accessibility=""Public"" Enabled=""true"" Target=""$TaskTarget"" Timeout=""300"" Remotable=""true"">`n       <Category>Custom</Category>`n       <WriteAction ID=""PA"" TypeID=""System!System.CommandExecuter"">`n        <ApplicationName>$TaskApplicationName</ApplicationName>`n        <WorkingDirectory>$TaskWorkingDirectory</WorkingDirectory>`n        <CommandLine>$TaskCommandLine</CommandLine>`n        <TimeoutSeconds>$TimeoutSeconds</TimeoutSeconds>`n        <RequireOutput>true</RequireOutput>`n        <Files />`n       </WriteAction>`n      </Task>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload MPX File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write display strings
  $FindLastDisplayStringLine = Select-String $MPMonitorRuleFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$TaskID"">`n     <Name>$TaskName</Name>`n     <Description>$TaskDescription</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload XML File
  $ClassContent = Get-Content $MPMonitorRuleFile

  
  }

############################################################################################################################################################
# Add-SCOMMPAgentTaskScript
# 
############################################################################################################################################################
  
  Function Add-SCOMMPAgentTaskScript
  {
   [cmdletbinding()]

  Param (
  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the task class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TaskName ,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the task will run for")]
  [Alias('TargetClassID')]
  [String]$TaskTarget = "SystemCenter!Microsoft.SystemCenter.AllComputersGroup",

  [Parameter(Mandatory=$true,HelpMessage="Select if the task will be enabled by default")]
  [ValidateSet('true','false')]
  [String]$TaskEnabled,

  [Parameter(Mandatory=$true,HelpMessage="Enter the application which the task will use")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TaskApplicationName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the working directory which the task will use")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TaskWorkingDirectory,

  [Parameter(Mandatory=$true,HelpMessage="Enter the name of the script the task will use")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$ScriptName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the timeout in seconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TimeoutSeconds,

  [Parameter(Mandatory=$true,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )

  # Wrties variable values which are specific to Visual Studios
  $Data = "$" + "Data"
  $MPElement = "$" + "MPElement"
  $TaskID = $TaskName -replace " ", "."
  $IncludeFileContent = "$" + "IncludeFileContent"
  $AlertMessageID = "$RuleID.AlertMessage"
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write Task
  $FindTasksLine = Select-String $MPMonitorRuleFile -pattern "</Tasks>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindTasksLine] += "`n      <Task ID=""$TaskID"" Accessibility=""Public"" Enabled=""true"" Target=""$TaskTarget"" Timeout=""300"" Remotable=""true"">`n       <Category>Custom</Category>`n       <WriteAction ID=""PA"" TypeID=""Windows!Microsoft.Windows.ScriptWriteAction"">`n        <ScriptName>$Scriptname</ScriptName>`n        <Arguments/>`n        <ScriptBody>$IncludeFileContent/$ScriptName$</ScriptBody>`n        <TimeoutSeconds>$TimeoutSeconds</TimeoutSeconds>`n          </WriteAction>`n      </Task>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload MPX File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write display strings
  $FindLastDisplayStringLine = Select-String $MPMonitorRuleFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$TaskID"">`n     <Name>$TaskName</Name>`n     <Description>$TaskDescription</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPMonitorRuleFile
  
  }

############################################################################################################################################################
# Add-SCOMMPAgentTaskUnixShell
# 
############################################################################################################################################################
  
  Function Add-SCOMMPAgentTaskUnixShell
  {
   [cmdletbinding()]

  Param (
  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the task class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TaskName ,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the task will run for")]
  [Alias('TargetClassID')]
  [String]$TaskTarget = "SystemCenter!Microsoft.SystemCenter.AllComputersGroup",

  [Parameter(Mandatory=$true,HelpMessage="Select if the task will be enabled by default")]
  [ValidateSet('true','false')]
  [String]$TaskEnabled,

  [Parameter(Mandatory=$true,HelpMessage="Enter the shell commmand which the task will use")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$ShellCommand,

  [Parameter(Mandatory=$true,HelpMessage="Enter the timeout in seconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TimeoutSeconds,

  [Parameter(Mandatory=$true,HelpMessage="Enter the timeout in milliseconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TimeoutMilliSeconds,

  [Parameter(Mandatory=$true,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )

  # Wrties variable values which are specific to Visual Studios
  $Data = "$" + "Data"
  $MPElement = "$" + "MPElement"
  $TaskID = $TaskName -replace " ", "."
  $IncludeFileContent = "$" + "IncludeFileContent"
  $AlertMessageID = "$RuleID.AlertMessage"
  $RunAs = "$" + "RunAs"
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write Task
  $FindTasksLine = Select-String $MPMonitorRuleFile -pattern "</Tasks>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindTasksLine] += "`n      <Task ID=""$TaskID"" Accessibility=""Public"" Enabled=""true"" Target=""$TaskTarget"" Timeout=""300"" Remotable=""true"">`n       <Category>Custom</Category>`n       <ProbeAction ID=""PA"" TypeID=""Unix!Microsoft.Unix.ShellCommand.ProbeAction"">`n        <TargetSystem>$Target/Property[Type=""MicrosoftUnixLibrary!MicrosoftUnixComputer""]/NetworkName$</TargetSystem>`n        <UserName>$RunAs[Name=""$TaskRunAsAccount""]/UserName$</UserName>`n        <Password>$RunAs[Name=""$TaskRunAsAccount""]/Password$</Password>`n          <ShellCommand>$ShellCommand</ShellCommand>`n        <TimeOut>$TimeoutSeconds</TimeOut>`n          <TimeOutInMS>$TimeoutMilliSeconds</TimeOutInMS>`n          </ProbeAction>`n      </Task>`n"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload MPX File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write display strings
  $FindLastDisplayStringLine = Select-String $MPMonitorRuleFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$TaskID"">`n     <Name>$TaskName</Name>`n     <Description>$TaskDescription</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPMonitorRuleFile
  
  }

############################################################################################################################################################
# Add-SCOMMPAgentTaskUnixScript
# 
############################################################################################################################################################
  
  Function Add-SCOMMPAgentTaskUnixScript
  {
   [cmdletbinding()]

  Param (
  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the task class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TaskName ,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the target class which the task will run for")]
  [Alias('TargetClassID')]
  [String]$TaskTarget = "SystemCenter!Microsoft.SystemCenter.AllComputersGroup",

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the run as account which the task will run under")]
  [Alias('RunAsAccount')]
  [String[]]$TaskRunAsAccount,

  [Parameter(Mandatory=$true,HelpMessage="Select if the task will be enabled by default")]
  [ValidateSet('true','false')]
  [String]$TaskEnabled,

  [Parameter(Mandatory=$true,HelpMessage="Enter the name of the script the task will use")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$ScriptName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the timeout in seconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TimeoutSeconds,

  [Parameter(Mandatory=$true,HelpMessage="Enter the timeout in milliseconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TimeoutMilliSeconds,

  [Parameter(Mandatory=$true,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )

  # Wrties variable values which are specific to Visual Studios
  $Data = "$" + "Data"
  $MPElement = "$" + "MPElement"
  $TaskID = $TaskName -replace " ", "."
  $IncludeFileContent = "$" + "IncludeFileContent"
  $AlertMessageID = "$RuleID.AlertMessage"
  $RunAs = "$" + "RunAs"
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write Task
  $FindTasksLine = Select-String $MPMonitorRuleFile -pattern "</Tasks>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindTasksLine] += "`n      <Task ID=""$TaskID"" Accessibility=""Public"" Enabled=""true"" Target=""$TaskTarget"" Timeout=""300"" Remotable=""true"">`n       <Category>Custom</Category>`n       <ProbeAction ID=""PA"" TypeID=""Unix!Microsoft.Invoke.Script.ProbeAction"">`n        <TargetSystem>$Target/Property[Type=""MicrosoftUnixLibrary!MicrosoftUnixComputer""]/NetworkName$</TargetSystem>`n        <UserName>$RunAs[Name=""$TaskRunAsAccount""]/UserName$</UserName>`n        <Password>$RunAs[Name=""$TaskRunAsAccount""]/Password$</Password>`n          <Script>$Scriptname</Script>`n        <ScriptArgs>$ScriptArgs</ScriptArgs>`n        <TimeOut>$TimeoutSeconds</TimeOut>`n          <TimeOutInMS></TimeOutInMS>`n          </ProbeAction>`n      </Task>`n"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload MPX File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write display strings
  $FindLastDisplayStringLine = Select-String $MPMonitorRuleFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$TaskID"">`n     <Name>$TaskName</Name>`n     <Description>$TaskDescription</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPMonitorRuleFile
  
  }

############################################################################################################################################################
# Add-SCOMMPDiagnosticTaskCommandLine
# 
############################################################################################################################################################
  
  Function Add-SCOMMPDiagnosticTaskCommandLine
  {
   [cmdletbinding()]

  Param (
  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the diagnostic task class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$DiagnosticName,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter a target class for the diagnostic task to run for")]
  [Alias('TargetClassID')]
  [String]$DiagnosticTarget = "SystemCenter!Microsoft.SystemCenter.AllComputersGroup",

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the monitor target which the task will run for")]
  [Alias('MonitorRuleID')]
  [String]$DiagnosticMonitorTarget,

  [Parameter(Mandatory=$true,HelpMessage="Select if the diagnostic task will be enabled by default")]
  [ValidateSet('true','false')]
  [String]$DiagnosticEnabled,

  [Parameter(Mandatory=$true,HelpMessage="Select which state the diagnostic task will execute on")]
  [ValidateSet('Error','Warning')]
  [String]$DiagnosticExecuteOnState,

  [Parameter(Mandatory=$true,HelpMessage="Enter the name of the application the diagnostic task will use")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$DiagnosticApplicationName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the working directory which the diagnostic task will work in")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$DiagnosticWorkingDirectory,

  [Parameter(Mandatory=$true,HelpMessage="Enter the command line which the diagnostic task will use")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$DiagnosticCommandLine,

  [Parameter(Mandatory=$true,HelpMessage="Enter the timeout in seconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TimeoutSeconds,

  [Parameter(Mandatory=$true,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )

  # Wrties variable values which are specific to Visual Studios
  $Data = "$" + "Data"
  $MPElement = "$" + "MPElement"
  $DiagnosticID = $DiagnosticName -replace " ", "."
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write Task
  $FindDiagnosticsLine = Select-String $MPMonitorRuleFile -pattern "</Diagnostics>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindDiagnosticsLine] += "`n      <Diagnostic Remotable=""true"" Timeout=""300"" Target=""$DiagnosticTarget"" Enabled=""$DiagnosticEnabled"" Accessibility=""Public"" ID=""$DiagnosticID"" ExecuteOnState=""$DiagnosticExecuteOnState"" Monitor=""$DiagnosticMonitorTarget"">`n       <Category>Custom</Category>`n       <ProbeAction ID=""$DiagnosticID.Diagnostic"" TypeID=""System!System.CommandExecuterProbe"">`n        <ApplicationName>$DiagnosticApplicationName</ApplicationName>`n        <WorkingDirectory>$DiagnosticWorkingDirectory</WorkingDirectory>`n        <CommandLine>$DiagnosticCommandLine</CommandLine>`n        <TimeoutSeconds>$TimeoutSeconds</TimeoutSeconds>`n        <RequireOutput>true</RequireOutput>`n        <Files />`n       </ProbeAction>`n      </Diagnostic>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload MPX File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write display strings
  $FindLastDisplayStringLine = Select-String $MPMonitorRuleFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$DiagnosticID"">`n     <Name>$DiagnosticName</Name>`n     <Description>$DiagnosticDescription</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPMonitorRuleFile
  
  }


############################################################################################################################################################
# Add-SCOMMPRecoveryTaskCommandLine
# 
############################################################################################################################################################
  
  Function Add-SCOMMPRecoveryTaskCommandLine
  {
   [cmdletbinding()]

  Param (
  [Parameter(Mandatory=$true,HelpMessage="Enter a name for the recovery task class")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$RecoveryName,

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter a target class for the recovery task to run for")]
  [Alias('TargetClassID')]
  [String]$RecoveryTarget = "SystemCenter!Microsoft.SystemCenter.AllComputersGroup",

  [Parameter(ValueFromPipelineByPropertyName = $true,HelpMessage="Enter the monitor target which the task will run for")]
  [Alias('MonitorRuleID')]
  [String]$RecoveryMonitorTarget,

  [Parameter(Mandatory=$true,HelpMessage="Select if the recovery task will be enabled by default")]
  [ValidateSet('true','false')]
  [String]$RecoveryEnabled,

  [Parameter(Mandatory=$true,HelpMessage="Select if the recovery task will reset the monitor after finishing the task")]
  [ValidateSet('true','false')]
  [String]$RecoveryResetMonitor,

  [Parameter(Mandatory=$true,HelpMessage="Enter the name of the application which the recovery task will use")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$RecoveryApplicationName,

  [Parameter(Mandatory=$true,HelpMessage="Enter the working directory which the recovery task will use")]
  [String]$RecoveryWorkingDirectory,

  [Parameter(Mandatory=$true,HelpMessage="Enter the command line which the recovery task will use")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$RecoveryCommandLine,

  [Parameter(Mandatory=$true,HelpMessage="Select which state the recovery task will execute on")]
  [ValidateSet('Error','Warning')]
  [String]$RecoveryExecuteOnState,

  [Parameter(Mandatory=$true,HelpMessage="Enter the timeout in seconds")]
  [AllowNull()]
  [AllowEmptyString()]
  [String]$TimeoutSeconds,

  [Parameter(Mandatory=$true,HelpMessage="Location of the MonitorRule MPX file")]
  [String]$MPMonitorRuleFile

  )

  # Wrties variable values which are specific to Visual Studios
  $Data = "$" + "Data"
  $MPElement = "$" + "MPElement"
  $RecoveryID = $RecoveryName -replace " ", "."
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write Task
  $FindRecoveriesLine = Select-String $MPMonitorRuleFile -pattern "</Recoveries>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindRecoveriesLine] += "`n      <Recovery Remotable=""true"" Timeout=""300"" Target=""$RecoveryTarget"" Enabled=""$RecoveryEnabled"" Accessibility=""Public"" ID=""$RecoveryID"" ExecuteOnState=""$RecoveryExecuteOnState"" Monitor=""$RecoveryMonitorTarget"" ResetMonitor=""$RecoveryResetMonitor"">`n       <Category>Custom</Category>`n       <WriteAction ID=""$RecoveryID.Recovery"" TypeID=""System!System.CommandExecuter"">`n        <ApplicationName>$RecoveryApplicationName</ApplicationName>`n        <WorkingDirectory>$RecoveryWorkingDirectory</WorkingDirectory>`n        <CommandLine>$RecoveryCommandLine</CommandLine>`n        <TimeoutSeconds>$TimeoutSeconds</TimeoutSeconds>`n        <RequireOutput>true</RequireOutput>`n        <Files />`n       </WriteAction>`n      </Recovery>"
  $ClassContent | Set-Content $MPMonitorRuleFile

  # Reload MPX File
  $ClassContent = Get-Content $MPMonitorRuleFile

  # Write display strings
  $FindLastDisplayStringLine = Select-String $MPMonitorRuleFile -pattern "</DisplayStrings>" | ForEach-Object {$_.LineNumber -2}
  $ClassContent[$FindLastDisplayStringLine] += "`n    <DisplayString ElementID=""$RecoveryID"">`n     <Name>$RecoveryName</Name>`n     <Description>$RecoveryDescription</Description>`n    </DisplayString>"
  $ClassContent | Set-Content $MPMonitorRuleFile
  
  }