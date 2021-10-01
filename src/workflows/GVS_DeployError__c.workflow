<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <alerts>
        <fullName>GVS_DeployErrorNotification</fullName>
        <description>GVS - Deploy Error Notification</description>
        <protected>false</protected>
        <recipients>
            <field>NotifyErrorsTo__c</field>
            <type>email</type>
        </recipients>
        <senderType>CurrentUser</senderType>
        <template>GVS_EmailTemplates/GVS_DeployErrorNotification</template>
    </alerts>
</Workflow>
