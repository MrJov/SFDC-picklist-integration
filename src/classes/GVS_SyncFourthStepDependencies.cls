public with sharing class GVS_SyncFourthStepDependencies implements Queueable, Database.AllowsCallouts {
  public final String[] processedPicklists;
  public final String settingsId;

  public GVS_SyncFourthStepDependencies(String[] picklistIds, String settings){
    processedPicklists = picklistIds;
    settingsId = settings;
    if(processedPicklists.size() == 0){ 
      GVS_SettingsTriggerHandler.manualSkip = true;
      update new GVS_Settings__c(Id = settingsId, LastStartStep4__c = Datetime.now()); 
      GVS_SettingsTriggerHandler.manualSkip = false;
    }
  }
  
  public void execute(QueueableContext context) {
    try{
      Set<String> idsPicklistToHandle = GVS_Utils.getSet([SELECT Id FROM GVS_Picklist__c WHERE Id NOT IN :processedPicklists LIMIT 3], 'Id');
      System.debug('**************************************************************');
      System.debug('GVS_SyncFourthStepDependencies IN PROGRESS...');
      System.debug('PROCESSED PICKLISTS: ' + processedPicklists.size());
      System.debug('HANDLING PICKLISTS: ' + idsPicklistToHandle.size());
      System.debug('**************************************************************');
      if(idsPicklistToHandle.size() > 0){
        List<GVS_PicklistValueDependency__c> picklistDependencies = [SELECT ControllingPicklistValue__c, DependentPicklistValue__c, SObjectName__c, FieldAPIName__c FROM GVS_PicklistValueDependency__c WHERE ControllingFieldValue__r.GVS_Picklist__c IN :idsPicklistToHandle];
        if(picklistDependencies.size() > 0){
          GVS_MetadataUtils.MetadataPort service = GVS_MetadataUtils.createService();
          Map<String, Map<String, List<String>>> mapFieldNameDependentControllingList = new Map<String, Map<String, List<String>>>();
          for(GVS_PicklistValueDependency__c pd : picklistDependencies){
            if(mapFieldNameDependentControllingList.get(pd.SObjectName__c + '.' + pd.FieldAPIName__c) == null) mapFieldNameDependentControllingList.put(pd.SObjectName__c + '.' + pd.FieldAPIName__c, new Map<String, List<String>>());
            if(mapFieldNameDependentControllingList.get(pd.SObjectName__c + '.' + pd.FieldAPIName__c).get(pd.DependentPicklistValue__c) == null) mapFieldNameDependentControllingList.get(pd.SObjectName__c + '.' + pd.FieldAPIName__c).put(pd.DependentPicklistValue__c, new List<String>());
            mapFieldNameDependentControllingList.get(pd.SObjectName__c + '.' + pd.FieldAPIName__c).get(pd.DependentPicklistValue__c).add(pd.ControllingPicklistValue__c);
          }
          List<GVS_MetadataUtils.CustomField> customFieldsMD = new List<GVS_MetadataUtils.CustomField>();
          for(GVS_MetadataUtils.IReadResult result : service.readMetadata(service, 'CustomField', new List<String>(mapFieldNameDependentControllingList.keySet()))){
            customFieldsMD.addAll((List<GVS_MetadataUtils.CustomField>) result.getRecords());
          }
          Boolean deployMetadata = false;
          for(GVS_MetadataUtils.CustomField fieldMD : customFieldsMD){
            if(fieldMD.fullName != null){
              deployMetadata = true;
              List<GVS_MetadataUtils.ValueSettings> dependenciesToUpdate = new List<GVS_MetadataUtils.ValueSettings>();
              Map<String, GVS_MetadataUtils.ValueSettings> mapFieldDependenciesMD = new Map<String, GVS_MetadataUtils.ValueSettings>();
              for(GVS_MetadataUtils.ValueSettings valueSetting : fieldMD.valueSet.valueSettings){
                mapFieldDependenciesMD.put(valueSetting.valueName, valueSetting);
              }
              if(mapFieldNameDependentControllingList.get(fieldMD.fullName) != null){
                List<GVS_MetadataUtils.ValueSettings> newValueSettingsMD = new List<GVS_MetadataUtils.ValueSettings>();
                Map<String, List<String>> mapFieldDependencies = mapFieldNameDependentControllingList.get(fieldMD.fullName);
                for(String value : mapFieldDependencies.keySet()){
                  GVS_MetadataUtils.ValueSettings newFieldDependencies = new GVS_MetadataUtils.ValueSettings();
                  if(mapFieldDependenciesMD.get(value) != null){
                    newFieldDependencies = mapFieldDependenciesMD.get(value);
                    Set<String> controllingValues = new Set<String>(newFieldDependencies.controllingFieldValue);
                    // if(operation.equalsIgnoreCase('INSERT')){
                      controllingValues.addAll(mapFieldDependencies.get(value));
                    // TODO: La DELETE ha qualche problema nel caso non ci siano più dipendenze
                    // } else if(operation.equalsIgnoreCase('DELETE')){
                    //   controllingValues.removeAll(mapFieldDependencies.get(value));
                    // }
                    newFieldDependencies.controllingFieldValue = new List<String>(controllingValues);
                  } else {
                  // if(operation.equalsIgnoreCase('INSERT')){
                    newFieldDependencies.valueName = value;
                    Set<String> controllingValues = new Set<String>();
                    controllingValues.addAll(mapFieldDependencies.get(value));
                    newFieldDependencies.controllingFieldValue = new List<String>(controllingValues);
                  }
                  newValueSettingsMD.add(newFieldDependencies);
                }
                fieldMD.valueSet.valueSettings = newValueSettingsMD;
              }
            }
          }
          if(deployMetadata){
            Integer counter = 0;
            List<GVS_MetadataUtils.CustomField> metadataToDeploy = new List<GVS_MetadataUtils.CustomField>();
            while (counter < customFieldsMD.size()) {
              if(customFieldsMD[counter].fullName != null){
                metadataToDeploy.add(customFieldsMD.get(counter++));
                if(Math.mod(counter, 10) == 0 || counter == customFieldsMD.size()){
                  List<GVS_MetadataUtils.SaveResult> resultsUpdate = service.updateMetadata(metadataToDeploy);
                  GVS_MetadataUtils.handleSaveResults(resultsUpdate);
                  metadataToDeploy = new List<GVS_MetadataUtils.CustomField>();
                }
              } else {
                counter++;
              }
            }
          }
        }
        processedPicklists.addAll(idsPicklistToHandle);
        if(!Test.isRunningTest()) System.enqueueJob(new GVS_SyncFourthStepDependencies(processedPicklists, settingsId));
      } else {
        GVS_SettingsTriggerHandler.manualSkip = true;
        update new GVS_Settings__c(Id = settingsId, LastStopStep4__c = Datetime.now());
        GVS_SettingsTriggerHandler.manualSkip = false;
      }
    } catch (Exception ex) {
      GVS_Settings__c settings = [SELECT Id, NotifyErrorsTo__c FROM GVS_Settings__c WHERE Id = :settingsId];
      System.debug('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
      System.debug('GVS_SyncFourthStepDependencies ERROR');
      System.debug('ERROR TYPE: ' + ex.getTypeName());
      System.debug('ERROR LINE: ' + ex.getLineNumber());
      System.debug('ERROR MESSAGE: ' + ex.getMessage());
      System.debug('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
      insert new GVS_DeployError__c(GVS_Settings__c = settings.Id, ErrorType__c = ex.getTypeName(), ErrorLine__c = ex.getLineNumber(), Errors__c = ex.getMessage(), 
                                    DeploymentStep__c = 'GVS_SyncFourthStepDependencies', NotifyErrorsTo__c = settings.NotifyErrorsTo__c);
    }
  }
}