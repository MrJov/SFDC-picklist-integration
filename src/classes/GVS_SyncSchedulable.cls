global class GVS_SyncSchedulable implements Schedulable {
  global void execute(SchedulableContext SC){
    GVS_Settings__c settings = [SELECT Id FROM GVS_Settings__c LIMIT 1];
    settings.StartSynchronization__c = true;
    update settings;
  }
}