public with sharing class GVS_SyncThirdStepTranslations implements Queueable, Database.AllowsCallouts {
  public final String[] processedPicklists;
  public final String settingsId;

  public GVS_SyncThirdStepTranslations(String[] picklistIds, String settings){
    processedPicklists = picklistIds;
    settingsId = settings;
    if(processedPicklists.size() == 0){ 
      GVS_SettingsTriggerHandler.manualSkip = true;
      update new GVS_Settings__c(Id = settingsId, LastStartStep3__c = Datetime.now()); 
      GVS_SettingsTriggerHandler.manualSkip = false;
    }
  }

  public void execute(QueueableContext context) {
    try{
      Set<String> idsPicklistToHandle = GVS_Utils.getSet([SELECT Id FROM GVS_Picklist__c WHERE Id NOT IN :processedPicklists LIMIT 3], 'Id');
      System.debug('**************************************************************');
      System.debug('GVS_SyncThirdStepTranslations IN PROGRESS...');
      System.debug('PROCESSED PICKLISTS: ' + processedPicklists.size());
      System.debug('HANDLING PICKLISTS: ' + idsPicklistToHandle.size());
      System.debug('**************************************************************');
      if(idsPicklistToHandle.size() > 0){
        // Create the service necessary to read/deploy metadata
        GVS_MetadataUtils.MetadataPort service = GVS_MetadataUtils.createService();
        // Perform a query to retrieve the values through the master-detail relationship
        List<GVS_PicklistValueTranslation__c> translations = [SELECT Id, GVS_PicklistValue__r.GlobalValueSetName__c, GVS_PicklistValue__r.Value__c, LanguageCode__c, Translation__c FROM GVS_PicklistValueTranslation__c WHERE GVS_PicklistValue__r.GVS_Picklist__c IN :idsPicklistToHandle];
        // Map translationKey ({GlobalValueSet.FullName}-{LanguageCode}) => List<GVS_PicklistValueTranslation__c>
        Map<String, List<SObject>> mapTranslations = GVS_Utils.groupBy(translations, '{GVS_PicklistValue__r.GlobalValueSetName__c}-{LanguageCode__c}', true);
        // List of GlobalValueSetTranslation that will be created
        List<GVS_MetadataUtils.GlobalValueSetTranslation> gvsTranslationsMD = new List<GVS_MetadataUtils.GlobalValueSetTranslation>();
        // For each GlobalValueSetTranslation to insert
        for(String gvsNameLanguageCode : mapTranslations.keySet()){
          // Prepare the list of ValueTranslations metadata
          List<GVS_MetadataUtils.ValueTranslation> translationsMD = new List<GVS_MetadataUtils.ValueTranslation>();
          // For each GVS_PicklistValueTranslation__c retrieved through the query
          for(GVS_PicklistValueTranslation__c translation : (List<GVS_PicklistValueTranslation__c>) mapTranslations.get(gvsNameLanguageCode)){
            // Create the ValueTranslation metadata
            GVS_MetadataUtils.ValueTranslation translationMD = new GVS_MetadataUtils.ValueTranslation();
            translationMD.masterLabel = translation.GVS_PicklistValue__r.Value__c;
            translationMD.translation = translation.Translation__c;
            translationsMD.add(translationMD);
          }
          // Create the GlobalValueSetTranslation metadata
          GVS_MetadataUtils.GlobalValueSetTranslation gvst = new GVS_MetadataUtils.GlobalValueSetTranslation();
          gvst.valueTranslation = translationsMD;
          gvst.fullName = gvsNameLanguageCode;
          gvsTranslationsMD.add(gvst);
        }
        if(gvsTranslationsMD.size() > 0){
          Integer counter = 0;
          List<GVS_MetadataUtils.GlobalValueSetTranslation> metadataToDeploy = new List<GVS_MetadataUtils.GlobalValueSetTranslation>();
          while (counter < gvsTranslationsMD.size()) {
            metadataToDeploy.add(gvsTranslationsMD.get(counter++));
            if(Math.mod(counter, 10) == 0 || counter == gvsTranslationsMD.size()){
              // Insert all the GlobalValueSetTranslations
              List<GVS_MetadataUtils.SaveResult> resultsInsert = service.createMetadata(metadataToDeploy);
              GVS_MetadataUtils.handleSaveResults(resultsInsert);
              metadataToDeploy = new List<GVS_MetadataUtils.GlobalValueSetTranslation>();
            }
          }
        }
        processedPicklists.addAll(idsPicklistToHandle);
        if(!Test.isRunningTest()) System.enqueueJob(new GVS_SyncThirdStepTranslations(processedPicklists, settingsId));
      } else {
        GVS_SettingsTriggerHandler.manualSkip = true;
        update new GVS_Settings__c(Id = settingsId, LastStopStep3__c = Datetime.now());
        GVS_SettingsTriggerHandler.manualSkip = false;
        // Altro giro altro regalo
        if(!Test.isRunningTest()) System.enqueueJob(new GVS_SyncFourthStepDependencies(new String[]{}, settingsId));
      }
    } catch (Exception ex) {
      GVS_Settings__c settings = [SELECT Id, NotifyErrorsTo__c FROM GVS_Settings__c WHERE Id = :settingsId];
      System.debug('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
      System.debug('GVS_SyncThirdStepTranslations ERROR');
      System.debug('ERROR TYPE: ' + ex.getTypeName());
      System.debug('ERROR LINE: ' + ex.getLineNumber());
      System.debug('ERROR MESSAGE: ' + ex.getMessage());
      System.debug('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
      insert new GVS_DeployError__c(GVS_Settings__c = settings.Id, ErrorType__c = ex.getTypeName(), ErrorLine__c = ex.getLineNumber(), Errors__c = ex.getMessage(), 
                                    DeploymentStep__c = 'GVS_SyncThirdStepTranslations', NotifyErrorsTo__c = settings.NotifyErrorsTo__c);
      if(!Test.isRunningTest()) System.enqueueJob(new GVS_SyncFourthStepDependencies(new String[]{}, settingsId));
    }
  }
}