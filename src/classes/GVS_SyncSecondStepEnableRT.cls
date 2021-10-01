public with sharing class GVS_SyncSecondStepEnableRT implements Queueable, Database.AllowsCallouts {
  public final String[] processedPicklists;
  public final String settingsId;

  public GVS_SyncSecondStepEnableRT(String[] picklistIds, String settings){
    processedPicklists = picklistIds;
    settingsId = settings;
    if(processedPicklists.size() == 0){ 
      GVS_SettingsTriggerHandler.manualSkip = true;
      update new GVS_Settings__c(Id = settingsId, LastStartStep2__c = Datetime.now()); 
      GVS_SettingsTriggerHandler.manualSkip = false;
    }
  }

  public void execute(QueueableContext context) {
    try{
      Set<String> idsPicklistToHandle = GVS_Utils.getSet([SELECT Id FROM GVS_Picklist__c WHERE Id NOT IN :processedPicklists LIMIT 1], 'Id');
      System.debug('**************************************************************');
      System.debug('GVS_SyncSecondStepEnableRT IN PROGRESS...');
      System.debug('PROCESSED PICKLISTS: ' + processedPicklists.size());
      System.debug('HANDLING PICKLISTS: ' + idsPicklistToHandle.size());
      System.debug('**************************************************************');
      if(idsPicklistToHandle.size() > 0){
        List<GVS_EnableRecordType__c> picklistRecordTypes = [SELECT Id, SObjectName__c, RecordTypeName__c, GVS_Picklist__c, PicklistName__c, GlobalValueSetName__c FROM GVS_EnableRecordType__c WHERE GVS_Picklist__c IN :idsPicklistToHandle];
        if(picklistRecordTypes.size() > 0){
          GVS_MetadataUtils.MetadataPort service = GVS_MetadataUtils.createService();
          Map<String, Map<String, String>> mapRecordTypePicklist = new Map<String, Map<String, String>>();
          for(GVS_EnableRecordType__c prt : picklistRecordTypes){
            if(mapRecordTypePicklist.get(prt.SObjectName__c + '.' + prt.RecordTypeName__c) == null) mapRecordTypePicklist.put(prt.SObjectName__c + '.' + prt.RecordTypeName__c, new Map<String, String>());
            mapRecordTypePicklist.get(prt.SObjectName__c + '.' + prt.RecordTypeName__c).put(prt.PicklistName__c, prt.GlobalValueSetName__c);
          }
          System.debug('Provo a leggere questi record types: ' + mapRecordTypePicklist.keySet()); 
          List<GVS_MetadataUtils.RecordType> recordTypeMD = new List<GVS_MetadataUtils.RecordType>();
          for(GVS_MetadataUtils.IReadResult result : service.readMetadata(service, 'RecordType', new List<String>(mapRecordTypePicklist.keySet()), 1)){
            recordTypeMD.addAll((List<GVS_MetadataUtils.RecordType>) result.getRecords());
          }
          // List<GVS_MetadataUtils.RecordType> recordTypeMD = (List<GVS_MetadataUtils.RecordType>) service.readMetadata('RecordType', new List<String>(mapRecordTypePicklist.keySet())).getRecords();
          Set<String> globalValueSetNames = GVS_Utils.getSet(picklistRecordTypes, 'GlobalValueSetName__c');
          List<GVS_MetadataUtils.GlobalValueSet> globalValueSetMD = (List<GVS_MetadataUtils.GlobalValueSet>) service.readMetadata('GlobalValueSet', new List<String>(globalValueSetNames)).getRecords();
          Map<String, GVS_MetadataUtils.GlobalValueSet> mapGlobalValueSetMD = new Map<String, GVS_MetadataUtils.GlobalValueSet>();
          for(GVS_MetadataUtils.GlobalValueSet gvs : globalValueSetMD){
            mapGlobalValueSetMD.put(gvs.fullName, gvs);
          }
          Boolean deployMetadata = false;
          List<GVS_MetadataUtils.RecordType> updateRecordType = new List<GVS_MetadataUtils.RecordType>();
          for(GVS_MetadataUtils.RecordType recordType : recordTypeMD){
            if(recordType.fullName != null){
              deployMetadata = true;
              GVS_MetadataUtils.RecordType rt = new GVS_MetadataUtils.RecordType();
              rt.fullName = recordType.fullName;
              rt.active = recordType.active;
              rt.label = recordType.label;
              rt.picklistValues = new List<GVS_MetadataUtils.RecordTypePicklistValue>();
              for(GVS_MetadataUtils.RecordTypePicklistValue picklist : recordType.picklistValues){
                if(mapRecordTypePicklist.get(recordType.fullName).keySet().contains(picklist.picklist)){
                  GVS_MetadataUtils.RecordTypePicklistValue rtPicklist = new GVS_MetadataUtils.RecordTypePicklistValue();

                  Map<String, GVS_MetadataUtils.PicklistValue> mapValues = new Map<String, GVS_MetadataUtils.PicklistValue>();
                  for(GVS_MetadataUtils.PicklistValue picklistValue : picklist.values){
                    // mapValues.put(picklistValue.fullName, picklistValue);
                    mapValues.put(EncodingUtil.urlDecode(picklistValue.fullName, 'UTF-8'), picklistValue);
                  }
                  for(GVS_MetadataUtils.CustomValue value : mapGlobalValueSetMD.get(mapRecordTypePicklist.get(recordType.fullName).get(picklist.picklist)).customValue){
                    if(value.isActive != false){
                      if(mapValues.containsKey(value.fullName)){
                        mapValues.get(value.fullName).isActive = value.isActive;
                      } else {
                        GVS_MetadataUtils.PicklistValue pv = new GVS_MetadataUtils.PicklistValue();
                        pv.fullName = value.fullName;
                        pv.isActive = value.isActive;
                        pv.description = value.description;
                        pv.default_x = value.default_x;
                        picklist.values.add(pv);
                        mapValues.put(pv.fullName, pv);
                      }
                    }
                  }
                  rt.picklistValues.add(picklist);
                }
              }
              updateRecordType.add(rt);
            }
          }

          if(deployMetadata){
            for(GVS_MetadataUtils.RecordType rtToUpdate : updateRecordType){
              List<GVS_MetadataUtils.SaveResult> resultsUpdate = service.updateMetadata(new GVS_MetadataUtils.RecordType[]{rtToUpdate});
              GVS_MetadataUtils.handleSaveResults(resultsUpdate);
            }
          }
        }

        processedPicklists.addAll(idsPicklistToHandle);
        if(!Test.isRunningTest()) System.enqueueJob(new GVS_SyncSecondStepEnableRT(processedPicklists, settingsId));
      } else {
        // Altro giro altro regalo
        GVS_SettingsTriggerHandler.manualSkip = true;
        update new GVS_Settings__c(Id = settingsId, LastStopStep2__c = Datetime.now());
        GVS_SettingsTriggerHandler.manualSkip = false;
        if(!Test.isRunningTest()) System.enqueueJob(new GVS_SyncThirdStepTranslations(new String[]{}, settingsId));
      }
    } catch (Exception ex) {
      GVS_Settings__c settings = [SELECT Id, NotifyErrorsTo__c FROM GVS_Settings__c WHERE Id = :settingsId];
      System.debug('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
      System.debug('GVS_SyncSecondStepEnableRT ERROR');
      System.debug('ERROR TYPE: ' + ex.getTypeName());
      System.debug('ERROR LINE: ' + ex.getLineNumber());
      System.debug('ERROR MESSAGE: ' + ex.getMessage());
      System.debug('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
      insert new GVS_DeployError__c(GVS_Settings__c = settings.Id, ErrorType__c = ex.getTypeName(), ErrorLine__c = ex.getLineNumber(), Errors__c = ex.getMessage(), 
                                    DeploymentStep__c = 'GVS_SyncSecondStepEnableRT', NotifyErrorsTo__c = settings.NotifyErrorsTo__c);
      if(!Test.isRunningTest()) System.enqueueJob(new GVS_SyncThirdStepTranslations(new String[]{}, settingsId));
    }
  }
}