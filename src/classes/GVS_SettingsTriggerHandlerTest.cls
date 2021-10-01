@IsTest
private class GVS_SettingsTriggerHandlerTest {
  @IsTest
  private static void testSettings(){
    Test.startTest();
    GVS_Settings__c settings = new GVS_Settings__c(Name = 'TEST', StartSynchronization__c = false, NotifyErrorsTo__c = 'dlorenzi@deloitte.it');
    insert settings;
    System.assertEquals(0, [SELECT Id FROM AsyncApexJob].size());
    settings.StartSynchronization__c = true;
    update settings;
    System.assertEquals(1, [SELECT Id FROM AsyncApexJob].size());
    Test.stopTest();
  }
}