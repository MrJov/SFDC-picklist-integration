@isTest
private class GVS_SyncSchedulableTest {
  @TestSetup
  static void setupData(){
    insert new GVS_Settings__c(Name = 'Test');
  }
  
  @isTest
  private static void testScheduling(){
    Test.startTest();
    String nextYear = String.valueOf(Date.today().year() + 1);
    String CRON_EXP = '0 0 0 3 9 ? ' + nextYear;
    String jobId = System.schedule('GVS_SyncSchedulableTest',  CRON_EXP,  new GVS_SyncSchedulable());
    CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE Id = :jobId];
    System.assertEquals(CRON_EXP, ct.CronExpression);
    System.assertEquals(0, ct.TimesTriggered);
    System.assertEquals(nextYear + '-09-03 00:00:00', String.valueOf(ct.NextFireTime));
    Test.stopTest();
  }
}