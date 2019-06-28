# Create Management Pack Using Functions

# New Class
New-SCOMMPClass -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.MPX"
Add-SCOMMPClass -ClassName TestClass -ClassType WindowsComputer -ClassDescription Test -Abstract false -Hosted true -Singleton false -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx"
Add-SCOMMPClass -ClassName TestClass1 -ClassType WindowsComputer -ClassDescription Test -Abstract false -Hosted true -Singleton false -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx"
Add-SCOMMPClass -ClassName TestClassComputerGroup -ClassType ComputerGroup -ClassDescription Test -Abstract false -Hosted false -Singleton true -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx"
Add-SCOMMPClass -ClassName TestClassInstanceGroup -ClassType InstanceGroup -ClassDescription Test -Abstract false -Hosted false -Singleton true -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx"
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -SourceClassID TestClass | Add-SCOMMPClassProperty -PropertyName Name -PropertyType string -KeyValue true -PropertyDescription Test
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -SourceClassID TestClass1 | Add-SCOMMPClassProperty -PropertyName Version -PropertyType string -KeyValue true -PropertyDescription Test
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -SourceClassID TestClass | Add-SCOMMPRunAsAccount -SecureReferenceName TestRunAs -SecureReferenceDescription Test

# New Relationship
New-SCOMMPRelationShip -MPRelationshipFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPRelationship.mpx"
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -SourceClassID TestClass -TargetClassID TestClass1 | Add-SCOMMPRelationship -RelationshipName testRelationship -RelationshipDescription Test -Abstract false -Accessibility Internal -MPRelationshipFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPRelationship.mpx"

# New Discovery
# Note Need to make it where all discoveries can be added into one discovery file
New-SCOMMPDiscovery -MPDiscoveryFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPDiscovery.mpx"

# Create PowerShell Script
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -SourceClassID TestClass | Create-PowerShellScript -ScriptName "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\Test.ps1"

# New PowerShell Discovery
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -SourceClassID TestClass -RunAsAccount TestRunAs | Add-SCOMMPPowerShellDiscovery -DiscoveryName TestDiscovery -DiscoveryTarget WindowsComputer -DiscoveryDescription TestDiscovery -IntervalSeconds 300 -ScriptName Test.ps1 -TimeoutSeconds 300 -KnowledgeArticle "This is a test article" -MPDiscoveryFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPDiscovery.mpx"

# New Registry Discovery
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -SourceClassID TestClass -RunAsAccount TestRunAs | Add-SCOMMPRegistryDiscovery -DiscoveryName TestRegDiscovery -DiscoveryTarget WindowsComputer -DiscoveryDescription TestDiscovery -Frequency 300 -KnowledgeArticle "This is a test article" -MPDiscoveryFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPDiscovery.mpx"
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -SourceClassID TestClass | Add-SCOMMPRegistryKey -AttributeName TestName -RegistryPath HKLM\SOFTWARE\Microsoft\Test -PathType KeyExists -AttributeType Boolean -MPDiscoveryFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPDiscovery.mpx"

# New WMI Discovery
#New-SCOMMPDiscovery -MPDiscoveryFile C:\temp\MPDiscovery.mpx
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -SourceClassID TestClass -RunAsAccount TestRunAs | Add-SCOMMPWMIDiscovery -DiscoveryName TestWMI -DiscoveryTarget WindowsComputer -DiscoveryDescription Test -Namespace SMS_Collection -Query "select * from vsms_R_system" -Frequency 300 -KnowledgeArticle "This is a test article" -MPDiscoveryFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPDiscovery.mpx"

# Create VB Script
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -SourceClassID TestClass | Create-VBScript -ScriptName "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\Test.vbs"

# New VBScript Discovery
#New-SCOMMPDiscovery -MPDiscoveryFile C:\temp\MPVBScriptDiscovery.mpx
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -SourceClassID TestClass -RunAsAccount TestRunAs | Add-SCOMMPVBScriptDiscovery -DiscoveryName TestVBScript -DiscoveryTarget WindowsComputer -DiscoveryDescription Test -IntervalSeconds 300 -ScriptName Test.vbs -TimeoutSeconds 300 -KnowledgeArticle "This is a test article" -MPDiscoveryFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPDiscovery.mpx"

# New UNIX Discovery
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -SourceClassID TestClass -RunAsAccount TestRunAs | Add-SCOMMPUnixShellCommandDiscovery -DiscoveryName TestUnix -DiscoveryTarget UnixComputer -DiscoveryDescription Test -ShellCommand grep -Interval 300 -Timeout 300 -Pattern *test -KnowledgeArticle "This is a test article" -MPDiscoveryFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPDiscovery.mpx"

# New Computer Group Discovery
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -SourceClassID TestClass -TargetClassID TestClassComputerGroup | Add-SCOMMPComputerGroupDiscovery -DiscoveryName TestClassComputerGroupDiscovery -DiscoveryTarget ComputerGroup -DiscoveryDescription Test -KnowledgeArticle "This is a test article" -MPDiscoveryFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPDiscovery.mpx"

# New Instance Group Discovery
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -SourceClassID TestClass -TargetClassID TestClassInstanceGroup | Add-SCOMMPInstanceGroupDiscovery -DiscoveryName TestClassInstanceGroupDiscovery -DiscoveryTarget InstanceGroup -DiscoveryDescription Test -KnowledgeArticle "This is a test article" -MPDiscoveryFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPDiscovery.mpx"


# Create New Folder
New-SCOMMPFolder -MPFolderFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPFolder.mpx"
Add-SCOMMPFolder -FolderName TestFolder -MPFolderFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPFolder.mpx"
Get-SCOMClassID -MPFolderFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPFolder.mpx" -FolderID TestFolder | Add-SCOMMPFolder -FolderName Test1 -MPFolderFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPFolder.mpx"

# Create View
New-SCOMMPView -MPViewFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPView.mpx"
Get-SCOMClassID  -MPFolderFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPFolder.mpx" -FolderID TestFolder -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass | Add-SCOMMPView -ViewName TestView -ViewType AlertView -MPViewFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPView.mpx"
Get-SCOMClassID  -MPFolderFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPFolder.mpx" -FolderID TestFolder -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass | Add-SCOMMPView -ViewName TestView1 -ViewType StateView -MPViewFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPView.mpx"

# New SCOM Monitor Rule File
New-SCOMMPMonitorRule -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPMonitorRule.mpx"

# New Custom Probe Action
New-SCOMMPCustomProbeAction -MPCustomDataSourceFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPCustomDataSource.mpx" -MPCustomMonitorTypeFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPCustomMonitorType.mpx" -MPCustomProbeActionFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPCustomProbeAction.mpx"

# Add Custom Probe Action
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass -RunAsAccount TestRunAs | Add-SCOMMPCustomProbeAction -CustomModuleName TestCustomModule -AlertName CustomModuleAlert -AlertMessage "This is a Test" -KnowledgeArticle "This is a Test Article" -TimeoutSeconds 300 -MPCustomDataSourceFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPCustomDataSource.mpx" -MPCustomMonitorTypeFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPCustomMonitorType.mpx" -MPCustomProbeActionFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPCustomProbeAction.mpx" -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPMonitorRule.mpx" -ScriptName Test.ps1 -ScriptOutput "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\test.ps1"

# New SCOM Event Monitor
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass -RunAsAccount TestRunAs | Add-SCOMMPWindowsEventMonitor -MonitorName TestEventMonitor -MonitorEnabled true -AlertOnState Error -AlertPriority High -AlertSeverity Error -AlertName TestEventAlert -UnhealthyLogName Application -UnhealthyEventDisplayNumber 1000 -UnhealthyPublisherName Test -HealthyLogName Application -HealthyEventDisplayNumber 1001 -HealthyPublisherName Test -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPMonitorRule.mpx"

# New SCOM Event Reset Monitor
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass -RunAsAccount TestRunAs | Add-SCOMMPWindowsEventManualResetMonitor -MonitorName TestManualReset -MonitorEnabled true -AlertOnState Error -AlertPriority High -AlertSeverity Error -AlertName TestEventAlert1 -UnhealthyLogName Application -UnhealthyEventDisplayNumber 1003 -UnhealthyPublisherName Test -KnowledgeArticle "This is a test article" -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPMonitorRule.mpx"

# New SCOM Event Timer Rest
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass -RunAsAccount TestRunAs | Add-SCOMMPWindowsEventTimerResetMonitor -MonitorName TestTimerReset -MonitorEnabled true -AlertOnState Error -AlertPriority High -AlertSeverity Error -AlertName TestTimer -UnhealthyLogName Application -UnhealthyEventDisplayNumber 1005 -UnhealthyPublisherName Test -TimerWaitInSeconds 300 -KnowledgeArticle "This is a test article" -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPMonitorRule.mpx"

# New SCOM Service Monitor
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass -RunAsAccount TestRunAs | Add-SCOMMPWindowsServiceMonitor -MonitorName TestServiceMonitor -MonitorEnabled true -AlertOnState Error -AlertPriority High -AlertSeverity Error -AlertName TestServiceAlert -AlertMessage "This Service is down" -ServiceName "iisadmin" -AlertOnAuto true -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPMonitorRule.mpx"

# New SCOM Service Monitor CPU Threshold
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass -RunAsAccount TestRunAs | Add-SCOMMPWindowsServiceCPUPerformanceMonitor -MonitorName TestServiceMonitorCPU -MonitorEnabled true -AlertOnState Error -AlertName TestCPU -AlertMessage Test -AlertPriority High -AlertSeverity Error -AlertOnAuto true -ServiceName iisadmin -Frequency 300 -Threshold 10 -NumSamples 3 -KnowledgeArticle "this is a test article" -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPMonitorRule.mpx"

# New SCOM Service Monitor Memory Threshold
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass -RunAsAccount TestRunAs | Add-SCOMMPWindowsServiceMemoryPerformanceMonitor -MonitorName TestServiceMonitorMemory -MonitorEnabled true -AlertOnState Error -AlertName TestMemory -AlertMessage Test -AlertPriority High -AlertSeverity Error -AlertOnAuto true -ServiceName iisadmin -Frequency 300 -Threshold 10 -NumSamples 3 -KnowledgeArticle "this is a test article" -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPMonitorRule.mpx"

# New SCOM Generic Log Monitor
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass -RunAsAccount TestRunAs | Add-SCOMMPWindowsGenericLogMonitor -MonitorName TestGenericLogMonitor -MonitorEnabled true -AlertOnState Error -AlertName Logmonitortest -AlertMessage Test -AlertPriority High -AlertSeverity Error -LogFileDirectory C:\Temp -LogPattern *.test -LogIsUTF8 false -ErrorMessagePattern Error -KnowledgeArticle "this is a test article" -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPMonitorRule.mpx"

# New SCOM Performance Monitor
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass -RunAsAccount TestRunAs | Add-SCOMMPPerformanceMonitor -MonitorName TestPerformanceMonitor -MonitorEnabled true -AlertOnState Error -AlertPriority High -AlertSeverity Error -ComputerName Test -CounterName cpu -ObjectName Process -InstanceName Test -AllInstances true -Frequency 10 -Threshold 10 -KnowledgeArticle "this is a test article" -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPMonitorRule.mpx"

# New SCOM Windows Event Rule
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass -RunAsAccount TestRunAs | Add-SCOMMPWindowsEventRule -RuleName TestEventRule -RuleDescription Test -RuleEnabled true -LogName Application -EventDisplayNumber 1008 -PublisherName Test -AlertName TestAlert -RulePriority High -RuleSeverity Critical -KnowledgeArticle "This is a test article" -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPMonitorRule.mpx"

# New SCOM PowerShell Script Rule
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass -RunAsAccount TestRunAs | Add-SCOMMPWindowsPowerShellScriptRule -RuleName TestPowershellRule -RuleDescription Test -RuleEnabled true -RulePriority High -RuleSeverity Critical -AlertName Test -AlertMessage TestMessage -ScriptName Test.ps1 -IntervalSeconds 300 -TimeoutSeconds 300 -KnowledgeArticle "This is a test article" -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPMonitorRule.mpx"

# New SCOM Performance Rule
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass -RunAsAccount TestRunAs | Add-SCOMMPPerformanceRule  -RuleName TestPerfRule -RuleDescription Test -RuleEnabled true -AlertName Test -AlertMessage TestMessage -ComputerName Test -CounterName cpu -ObjectName Process -Frequency 300 -Threshold 10 -InstanceProperty 20 -Tolerance -MaxSampleSeparation 5 -AllInstances true  -KnowledgeArticle "This is a test article" -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPMonitorRule.mpx"

# New SCOM Linux Log File Monitor
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass -RunAsAccount TestRunAs | Add-SCOMMPUnixLogFileRule -RuleName TestRuleUnixLog -RuleDescription Test -RuleEnabled true -LogFile grep -RegExpFilter *Test -PublisherName Test -RulePriority High -RuleSeverity Critical -AlertName TestAlert5 -KnowledgeArticle "THis is a test article" -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPMonitorRule.mpx"

# New SCOM Agent Task Command Line
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass | Add-SCOMMPAgentTaskCommandLine -TaskName TestTaskCMD -TaskEnabled true -TaskApplicationName TestApp -TaskWorkingDirectory C:\Temp -TaskCommandLine ipconfig -TimeoutSeconds 300 -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPMonitorRule.mpx"

# New SCOM Agent Task Script
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass | Add-SCOMMPAgentTaskScript -TaskName TestTaskScript -TaskEnabled true -TaskApplicationName TestApp -TaskWorkingDirectory C:\Temp -Scriptname Test.bat -TimeoutSeconds 300 -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPMonitorRule.mpx"

# New SCOM Agent Task Unix Script
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass -RunAsAccount TestRunAs | Add-SCOMMPAgentTaskUnixScript -TaskName TestTaskUnixScript -TaskEnabled true -Scriptname Test.unix -TimeoutSeconds 300 -TimeoutMilliSeconds 3000 -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPMonitorRule.mpx"

# New SCOM Agent Task Unix Shell
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass -RunAsAccount TestRunAs | Add-SCOMMPAgentTaskUnixShell -TaskName TestaskUnixShell -TaskEnabled true -ShellCommand grep -TimeoutSeconds 300 -TimeoutMilliSeconds 3000 -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPMonitorRule.mpx"

# New SCOM Diagnostic Task
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -MonitorRuleID TestEventMonitor | Add-SCOMMPDiagnosticTaskCommandLine -DiagnosticName TestDiagnostic -DiagnosticEnabled true -DiagnosticMonitorTarget TestEventMonitor -DiagnosticExecuteOnState Error -DiagnosticApplicationName PowerShell -DiagnosticWorkingDirectory C:\Temp -DiagnosticCommandLine ipconfig -TimeoutSeconds 300 -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPMonitorRule.mpx"

# New SCOM Recovery Task
Get-SCOMClassID -MPClassFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -TargetClassID TestClass -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPClass.mpx" -MonitorRuleID TestEventMonitor | Add-SCOMMPRecoveryTaskCommandLine -RecoveryName TestRecovery -RecoveryMonitorTarget TestEventMonitor -RecoveryEnabled true -RecoveryApplicationName PowerShell -RecoveryWorkingDirectory C:\Temp -RecoveryCommandLine Get-Service -RecoveryResetMonitor true -RecoveryExecuteOnState Error -TimeoutSeconds 300 -MPMonitorRuleFile "C:\Users\Administrator\source\repos\Test Management Pack\Test Management Pack\MPMonitorRule.mpx"



