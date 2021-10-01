# Global Value Set Integration Management
## _Handle Global Picklist integration through Salesforce objects_


### Main Content
#### Custom Objects
    GVS_Picklist__c 
| Field | Description | Example |
| ------ | ------ | ------ |
|Name|Name of the global picklist|PaymentMethod|
|Label__c|Label of the global picklist|Payment Method|
|Descrizione__c|Friendly description|Payment method values|
|ExternalId__c|Unique identifier, usually the same as the name|PaymentMethod|
|GlobalValueSet__c|Fixed boolean value|true|

    GVS_PicklistValue__c
| Field | Description | Example |
| ------ | ------ | ------ |
|Name|Friendly name of the global picklist value|RID|
|GVS_Picklist__c|Reference to the GVS_Picklist__c record|_Salesforce ID_|
|Active__c|Boolean, true if the value must be active|true|
|Default__c|Boolean, true if this is the default value|false|
|ExternalId__c|Unique identifier|PaymentMethod_RID|
|Label__c|Label for the value **must be unique**|RID|
|Value__c|API name of the value **must be unique**|RID|
|OriginalLabel__c|Original label, can be useful when there are non-unique labels|RID|

    GVS_PicklistValueDependency__c
| Field | Description | Example |
| ------ | ------ | ------ |
|Name|Auto-Number|GVS_PVD-000000006|
|ControllingFieldValue__c|Reference to the controlling GVS_PicklistValue__c record|_Salesforce ID_|
|DependentValue__c|Reference to the dependent GVS_PicklistValue__c record|_Salesforce ID_|
|FieldAPIName__c|API Name of the field which is the controlled picklist|PaymentMethodDetail__c|
|SObjectName__c|API Name of the object where the dependent picklist is located|Opportunity|
|ExternalId__c|Unique identifier|PaymentMethod_Oppoortunity_PaymentMethodDetail__c_RID_RIDDetail|
    
    GVS_PicklistValueTranslation__c
| Field | Description | Example |
| ------ | ------ | ------ |
|Name|Auto-Number|GVS_PVT-000000006|
|GVS_PicklistValue__c|Reference to the translated GVS_PicklistValue__c record|_Salesforce ID_|
|LanguageCode__c|Language code in Salesforce format|en_US|
|Translation__c|Translated label|Bank RID|
|ExternalId__c|Unique identifier|PaymentMethod_RID_en_US|

    GVS_EnableRecordType__c
| Field | Description | Example |
| ------ | ------ | ------ |
|Name|Auto-Number|GVS_RT-0006|
|GVS_Picklist__c|Reference to the GVS_Picklist__c record|_Salesforce ID_|
|PicklistName__c|API Name of the field that use the global picklist|PaymentMethod__c|
|SObjectName__c|API Name of the object where the picklist must be enabled for the record type|Opportunity|
|RecordTypeName__c|DeveloperName of the record type|StandardOpportunity|
|ExternalId__c|Unique identifier|PaymentMethod_Opportunity_PaymentMethod__c_StandardOpportunity|


    GVS_Settings__c
| Field | Description | Example |
| ------ | ------ | ------ |
|Name|Friendly name for the record|Default|
|NotifyErrorsTo__c|Email address where the error notifications are sent|tony@stark.com|
|StartSynchronization__c|Boolean, when set to true the deployment starts|true|
|GetStartNotification__c|Boolean, if true the user receives a desktop only notification in Salesforce when the deployment starts|false|
|GetStopNotification__c|Boolean, if true the user receives a desktop only notification in Salesforce when the deployment stops|false|
|LastStartStepN__c|Date/time when the step N started the last time|2021-10-01T02:00:00.000|
|LastStopStepN__c|Date/time when the step N finished the last time|2021-10-01T02:00:29.000|

    GVS_DeployError__c
| Field | Description | Example |
| ------ | ------ | ------ |
|Name|Auto-Number|GVS_ERR-0006|
|GVS_Settings__c|Reference to GVS_Settings__c record|Salesforce ID|
|DeploymentStep__c|Apex class where the error happened|GVS_SyncSecondStepEnableRT|
|ErrorLine__c|Line where the error was cought|553|
|ErrorType__c|Exception Type|System.CalloutException|
|ErrorsNo__c|Unused||
|Errors__c|Error message|IO Exception: Read timed out|

#### Apex Classes
- GVS\_SyncSchedulable - Class that can be scheduled in order to trigger the deployment process at given time by updating a record of the object GVS\_Settings with the field _StartSynchronization\_\_c = true_
- GVS\_SettingsTriggerHandler - Class that starts the first step of the integrtation process
- GVS\_SyncFirstStepPicklistValue, GVS\_SyncSecondStepEnableRT, GVS\_SyncThirdStepTranslations, GVS\_SyncFourthStepDependencies - Classes that handles the deployment of the different metadata involved in the process
- Other utility and test classes
