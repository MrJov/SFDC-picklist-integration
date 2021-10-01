public with sharing class GVS_SettingsTriggerHandler {
  public static Boolean manualSkip = false;

  public void onBeforeInsert(List<GVS_Settings__c> triggerNew, Map<Id, GVS_Settings__c> triggerNewMap){
    manageSynchronization(triggerNew);
  }
  
  public void onBeforeUpdate(List<GVS_Settings__c> triggerOld, List<GVS_Settings__c> triggerNew, Map<Id, GVS_Settings__c> triggerOldMap, Map<Id, GVS_Settings__c> triggerNewMap){
    manageSynchronization(triggerNew);
  }

  private static void manageSynchronization(List<GVS_Settings__c> triggerNew){
    List<GVS_Settings__c> settings = (List<GVS_Settings__c>) GVS_Utils.filter(triggerNew, 'StartSynchronization__c', true);
    if(settings.size() > 0){
      settings[0].LastStartStep1__c = Datetime.now();
      ID jobID = System.enqueueJob(new GVS_SyncFirstStepPicklistValue(new String[]{}, settings[0].Id));
    }
  }
}