public with sharing class GVS_SyncFirstStepPicklistValue implements Queueable, Database.AllowsCallouts {
  public final String[] processedPicklists;
  public final String settingsId;

  public GVS_SyncFirstStepPicklistValue(String[] picklistIds, String settings){
    processedPicklists = picklistIds;
    settingsId = settings;
  }
  
  public void execute(QueueableContext context) {
    try {
      Set<String> idsPicklistToHandle = GVS_Utils.getSet([SELECT Id FROM GVS_Picklist__c WHERE Id NOT IN :processedPicklists LIMIT 3], 'Id');
      System.debug('**************************************************************');
      System.debug('GVS_SyncFirstStepPicklistValue IN PROGRESS...');
      System.debug('PROCESSED PICKLISTS: ' + processedPicklists.size());
      System.debug('HANDLING PICKLISTS: ' + idsPicklistToHandle.size());
      System.debug('**************************************************************');
      if(idsPicklistToHandle.size() > 0){
        List<GVS_PicklistValue__c> picklistValues = [SELECT Value__c, Label__c, Active__c, Default__c, GlobalValueSetName__c, GlobalValueSetLabel__c FROM GVS_PicklistValue__c WHERE GVS_Picklist__c IN :idsPicklistToHandle];
        
        // Extract the names of the GlobalValueSets involved in the transaction
        Set<String> globalValueSetNames = GVS_Utils.getSet(picklistValues, 'GlobalValueSetName__c');
        
        System.debug('globalValueSetNames: ' + globalValueSetNames);
        // Create the service necessary to read/deploy metadata
        GVS_MetadataUtils.MetadataPort service = GVS_MetadataUtils.createService();
        // Read the metadata in the org related to the GlobalValueSet involved in the transaction (they may not exist if the GlobalValueSets must be created)
        // N.B.: This performs a callout
        List<GVS_MetadataUtils.GlobalValueSet> listPreviousGlobalValueSet = (List<GVS_MetadataUtils.GlobalValueSet>) service.readMetadata('GlobalValueSet', new List<String>(globalValueSetNames)).getRecords();
        
        // Map GlobalValueSet.FullName => GlobalValueSet
        Map<String, GVS_MetadataUtils.GlobalValueSet> mapGlobalValueSets = new Map<String, GVS_MetadataUtils.GlobalValueSet>();
        // Map GlobalValueSet.FullName => { PicklistValue.FullName => PicklistValue } (Insert and Update splitted since they will be handled through different services)
        Map<String, Map<String, GVS_MetadataUtils.CustomValue>> mapPicklistValuesToInsert = new Map<String, Map<String, GVS_MetadataUtils.CustomValue>>();
        Map<String, Map<String, GVS_MetadataUtils.CustomValue>> mapPicklistValuesToUpdate = new Map<String, Map<String, GVS_MetadataUtils.CustomValue>>();
        
        System.debug('listPreviousGlobalValueSet.size(): ' + listPreviousGlobalValueSet.size());
        // Populate the previous maps with the values read from the org
        for(GVS_MetadataUtils.GlobalValueSet gvs : listPreviousGlobalValueSet){
          // This check is necessary because if all the GlobalValueSets must be created, the "readMetadata()" service will return a record with fullName = null
          if(gvs.fullName != null){
            mapGlobalValueSets.put(gvs.fullName, gvs);
            if(mapPicklistValuesToUpdate.get(gvs.fullName) == null) mapPicklistValuesToUpdate.put(gvs.fullName, new Map<String, GVS_MetadataUtils.CustomValue>());
            for(GVS_MetadataUtils.CustomValue picklistValue : gvs.customValue){
              mapPicklistValuesToUpdate.get(gvs.fullName).put(picklistValue.fullName, picklistValue);
            }
          }
        }
        System.debug('picklistValues.size(): ' + picklistValues.size());
        
        // For each PicklistValue given in input
        for(GVS_PicklistValue__c picklistValue : picklistValues){
          
          // If the PicklistValue is part of an existing GlobalValueSet, it will insert/update the PicklistValue and update the GlobalValueSet
          if(mapPicklistValuesToUpdate.get(picklistValue.GlobalValueSetName__c) != null){
            mapPicklistValuesToUpdate.get(picklistValue.GlobalValueSetName__c).put(picklistValue.Value__c, getMetadataCustomValue(picklistValue));
          } else {
            // If the GlobalValueSet does not exist it will insert a new GlobalValueSet and its PicklistValues
            // If it is not yet defined, add the GlobalValueSet to insert
            if(mapPicklistValuesToInsert.get(picklistValue.GlobalValueSetName__c) == null){
              mapPicklistValuesToInsert.put(picklistValue.GlobalValueSetName__c, new Map<String, GVS_MetadataUtils.CustomValue>());
              mapGlobalValueSets.put(picklistValue.GlobalValueSetName__c, getMetadataGlobalValueSet(picklistValue));
            }
            // Add the current PicklistValue to the GlobalValueSet
            mapPicklistValuesToInsert.get(picklistValue.GlobalValueSetName__c).put(picklistValue.Value__c, getMetadataCustomValue(picklistValue));
          }
        }
        
        System.debug('mapPicklistValuesToUpdate.keySet().size(): ' + mapPicklistValuesToUpdate.keySet().size());
        // If there are GlobalValueSets to update, call a service and update them!
        if(mapPicklistValuesToUpdate.keySet().size() > 0){
          List<GVS_MetadataUtils.SaveResult> resultsUpdate = service.updateMetadata(prepareMetadataGlobalValueSetForDeployment(mapGlobalValueSets, mapPicklistValuesToUpdate));
          GVS_MetadataUtils.handleSaveResults(resultsUpdate);
        }
        System.debug('mapPicklistValuesToInsert.keySet().size(): ' + mapPicklistValuesToInsert.keySet().size());
        // If there are GlobalValueSets to insert, call a service and insert them!
        if(mapPicklistValuesToInsert.keySet().size() > 0){
          Integer counter = 0;
          List<GVS_MetadataUtils.GlobalValueSet> gvsMD = prepareMetadataGlobalValueSetForDeployment(mapGlobalValueSets, mapPicklistValuesToInsert);
          List<GVS_MetadataUtils.GlobalValueSet> metadataToDeploy = new List<GVS_MetadataUtils.GlobalValueSet>();
          while (counter < gvsMD.size()) {
            metadataToDeploy.add(gvsMD.get(counter++));
            if(Math.mod(counter, 10) == 0 || counter == gvsMD.size()){
              // Insert all the GlobalValueSets
              List<GVS_MetadataUtils.SaveResult> resultsInsert = service.createMetadata(metadataToDeploy);
              GVS_MetadataUtils.handleSaveResults(resultsInsert);
              metadataToDeploy = new List<GVS_MetadataUtils.GlobalValueSet>();
            }
          }
        }
        processedPicklists.addAll(idsPicklistToHandle);
        if(!Test.isRunningTest()) System.enqueueJob(new GVS_SyncFirstStepPicklistValue(processedPicklists, settingsId));
      } else {
        GVS_SettingsTriggerHandler.manualSkip = true;
        update new GVS_Settings__c(Id = settingsId, LastStopStep1__c = Datetime.now());
        GVS_SettingsTriggerHandler.manualSkip = false;
        if(!Test.isRunningTest()) System.enqueueJob(new GVS_SyncSecondStepEnableRT(new String[]{}, settingsId));
      }
    } catch (Exception ex) {
      GVS_Settings__c settings = [SELECT Id, NotifyErrorsTo__c FROM GVS_Settings__c WHERE Id = :settingsId];
      System.debug('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
      System.debug('GVS_SyncFirstStepPicklistValue ERROR');
      System.debug('ERROR TYPE: ' + ex.getTypeName());
      System.debug('ERROR LINE: ' + ex.getLineNumber());
      System.debug('ERROR MESSAGE: ' + ex.getMessage());
      System.debug('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
      insert new GVS_DeployError__c(GVS_Settings__c = settings.Id, ErrorType__c = ex.getTypeName(), ErrorLine__c = ex.getLineNumber(), Errors__c = ex.getMessage(), 
                                    DeploymentStep__c = 'GVS_SyncFirstStepPicklistValue', NotifyErrorsTo__c = settings.NotifyErrorsTo__c);
    }
  }

  private static GVS_MetadataUtils.CustomValue getMetadataCustomValue(GVS_PicklistValue__c picklistValue){
    GVS_MetadataUtils.CustomValue picklistValueMD = new GVS_MetadataUtils.CustomValue();
    picklistValueMD.fullName = picklistValue.Value__c;
    picklistValueMD.label = picklistValue.Label__c;
    picklistValueMD.default_x = picklistValue.Default__c ;
    picklistValueMD.isActive = picklistValue.Active__c;
    return picklistValueMD;
  }

  private static GVS_MetadataUtils.GlobalValueSet getMetadataGlobalValueSet(GVS_PicklistValue__c picklistValue){
    GVS_MetadataUtils.GlobalValueSet globalValueSetMD = new GVS_MetadataUtils.GlobalValueSet();
    globalValueSetMD.fullName = picklistValue.GlobalValueSetName__c;
    globalValueSetMD.masterLabel = picklistValue.GlobalValueSetLabel__c;
    globalValueSetMD.sorted = false;
    return globalValueSetMD;
  }

  private static List<GVS_MetadataUtils.GlobalValueSet> prepareMetadataGlobalValueSetForDeployment(Map<String, GVS_MetadataUtils.GlobalValueSet> mapGlobalValueSetMD, Map<String, Map<String, GVS_MetadataUtils.CustomValue>> mapPicklistValuesMD){
    List<GVS_MetadataUtils.GlobalValueSet> globalValueSet = new List<GVS_MetadataUtils.GlobalValueSet>();
    for(String gvsName : mapPicklistValuesMD.keySet()){
      GVS_MetadataUtils.GlobalValueSet gvs = mapGlobalValueSetMD.get(gvsName);
      gvs.customValue = mapPicklistValuesMD.get(gvsName).values();
      globalValueSet.add(gvs);
    }
    return globalValueSet;
  }

  @future
  private static void setStartStep1(String settingsJson){
    GVS_Settings__c settings = (GVS_Settings__c)JSON.deserialize(settingsJson, GVS_Settings__c.class);
    update settings;
  }
}