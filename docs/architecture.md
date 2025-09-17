<pre>

┌────────────────────────────────────────────────────────────┐

│                    Management Group Level                  │

│                                                            │

│  ┌──────────────────────────────────────────────────────┐  │

│  │ Azure Policy Assignments                             │  │

│  │                                                      │  │

│  │  • DeployIfNotExists                                 │  │

│  │     - RG-CSOC-LOGGING-AUDIT                          │  │

│  │     - Storage-Lifecycle-mgt-policy                   │  │

│  │                                                      │  │

│  │  • AuditIfNotExists                                  │  │

│  │     - CS-Blob-Security-Log-Aggregation               │  │

│  │     - CS-SQLdb-Security-Log-Aggregation              │  │

│  │     - CS-CosmosDB-Security-Log-Aggregation           │  │

│  │     - CS-Postgres-Security-Log-Aggregation           │  │

│  │     - CS-MySql-Security-Log-Aggregation              │  │

│  └──────────────────────────────────────────────────────┘  │

└────────────────────────────────────────────────────────────┘

&nbsp;             │

&nbsp;             ▼

┌────────────────────────────────────────────────────────────┐

│         Policy Triggers Resource Deployment (DINE)         │

│  - Creates RG-CSOC-LOGGING if missing                      │

│  - Deploys storage account with unique name                │

│  - Tags and scopes resources for logging                   │

└────────────────────────────────────────────────────────────┘

&nbsp;             │

&nbsp;             ▼

┌────────────────────────────────────────────────────────────┐

│         Central Automation Account (Single Region)         │

│  - Managed Identity: SLB-InfraRemediation-Automation       │

│  - Scheduled Runbooks                                      │

│     • Enable-BlobDiag-CSOC.ps1                             │

│     • Enable-SQLDiag-CSOC.ps1                              │

│     • Enable-CosmossqlDiag-CSOC.ps1                        │

│     • Enable-MySQL-CSOC.ps1                                │

│     • Configure-CSOC-StorageFirewall-Europe.ps1            │

└────────────────────────────────────────────────────────────┘

&nbsp;             │

&nbsp;             ▼

┌────────────────────────────────────────────────────────────┐

│        Cross-Subscription Remediation via Runbooks         │

│  - Queries policy compliance states                        │

│  - Enables diagnostic settings                             │

│  - Configures storage firewall and service endpoints       │

│  - Writes logs to centralized storage or Event Hub         │

└────────────────────────────────────────────────────────────┘

&nbsp;             │

&nbsp;             ▼

┌────────────────────────────────────────────────────────────┐

│               Centralized Logging Storage                  │

│  - Storage account: stor<uniqueHash><env>                  │

│  - Diagnostic setting names: CS-blobdiag, CS-sqldiag, etc. │

│  - Lifecycle management policy applied                     │

└────────────────────────────────────────────────────────────┘



</pre>

