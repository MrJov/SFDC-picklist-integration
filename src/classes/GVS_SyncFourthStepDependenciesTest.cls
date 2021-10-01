@isTest
private class GVS_SyncFourthStepDependenciesTest {
  @TestSetup
  static void setupData(){
    insert new GVS_Settings__c(Name = 'Test');
    GVS_Picklist__c picklist = new GVS_Picklist__c(Name = 'MarvelGroups', Label__c = 'Marvel Groups', GlobalValueSet__c = true, ExternalId__c = 'MarvelGroups');
    insert picklist;
    GVS_Picklist__c picklistDC = new GVS_Picklist__c(Name = 'DCGroups', Label__c = 'DC Groups', GlobalValueSet__c = true, ExternalId__c = 'DCGroups');
    insert picklistDC;
    List<GVS_EnableRecordType__c> picklistRecordType = new List<GVS_EnableRecordType__c>();
    picklistRecordType.add(new GVS_EnableRecordType__c(ExternalId__c = 'Account_Hero_Group__c', SObjectName__c = 'Account', RecordTypeName__c = 'Hero', PicklistName__c = 'Group__c', GVS_Picklist__c = picklist.Id));
    picklistRecordType.add(new GVS_EnableRecordType__c(ExternalId__c = 'Account_Hero_Character__c', SObjectName__c = 'Account', RecordTypeName__c = 'Hero', PicklistName__c = 'Character__c', GVS_Picklist__c = picklist.Id));
    picklistRecordType.add(new GVS_EnableRecordType__c(ExternalId__c = 'Account_Villain_Group__c', SObjectName__c = 'Account', RecordTypeName__c = 'Villain', PicklistName__c = 'Group__c', GVS_Picklist__c = picklist.Id));
    picklistRecordType.add(new GVS_EnableRecordType__c(ExternalId__c = 'Account_Villain_Character__c', SObjectName__c = 'Account', RecordTypeName__c = 'Villain', PicklistName__c = 'Character__c', GVS_Picklist__c = picklist.Id));
    insert picklistRecordType;
    List<GVS_PicklistValue__c> groups = new List<GVS_PicklistValue__c>();
    groups.add(new GVS_PicklistValue__c(GVS_Picklist__c = picklist.Id, Name = 'Marvel Groups - Avengers', Value__c = 'Avengers', Label__c = 'Avengers', Active__c = true, Default__c = false, ExternalId__c = 'MarvelGroups_Avengers'));
    groups.add(new GVS_PicklistValue__c(GVS_Picklist__c = picklist.Id, Name = 'Marvel Groups - X-Men', Value__c = 'XMen', Label__c = 'X-Men', Active__c = true, Default__c = false, ExternalId__c = 'MarvelGroups_XMen'));
    groups.add(new GVS_PicklistValue__c(GVS_Picklist__c = picklistDC.Id, Name = 'DC Groups - Justice League of America', Value__c = 'JLA', Label__c = 'Justice League of America', Active__c = true, Default__c = false, ExternalId__c = 'DCGroups_JLA'));
    insert groups;
    List<GVS_PicklistValueTranslation__c> translations = new List<GVS_PicklistValueTranslation__c>();
    translations.add(new GVS_PicklistValueTranslation__c(GVS_PicklistValue__c = groups[0].Id, LanguageCode__c = 'it', Translation__c = 'Vendicatori', ExternalId__c = 'MarvelGroups_Avengers_it'));
    translations.add(new GVS_PicklistValueTranslation__c(GVS_PicklistValue__c = groups[1].Id, LanguageCode__c = 'it', Translation__c = 'Difensori', ExternalId__c = 'MarvelGroups_Defenders_it'));
    insert new GVS_PicklistValueDependency__c (ControllingFieldValue__c = groups[0].Id, DependentValue__c = groups[1].Id, ExternalId__c = 'AAAAAAAA', FieldAPIName__c = 'Type', SObjectName__c = 'Account');
  }

  @isTest
  private static void testPicklistValueDependencysSync(){
    Test.setMock(WebServiceMock.class, new GVS_CalloutMock());
    Test.startTest();
    System.enqueueJob(new GVS_SyncFourthStepDependencies(new String[]{}, [SELECT Id FROM GVS_Settings__c].Id));
    Test.stopTest();
  }
}