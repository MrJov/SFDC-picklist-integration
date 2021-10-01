trigger GVS_Settings on GVS_Settings__c (before insert, before update) {
  if(!GVS_SettingsTriggerHandler.manualSkip){
    GVS_SettingsTriggerHandler handler = new GVS_SettingsTriggerHandler();
    /* Before Insert */
    if (Trigger.isInsert && Trigger.isBefore) { handler.onBeforeInsert(Trigger.new, Trigger.newMap); }
    /* Before Update */
    else if (Trigger.isUpdate && Trigger.isBefore) { handler.onBeforeUpdate(Trigger.old, Trigger.new, Trigger.oldMap, Trigger.newMap); }
  }
}