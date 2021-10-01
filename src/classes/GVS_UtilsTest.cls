@IsTest
private class GVS_UtilsTest {

  @isTest
  static void testGetSetMethods() {
    Contact[] cL = new Contact[]{
      new Contact(Id = '003g000000CxTGm', AccountId = '001g000000CxTGm', FirstName = 'fn1', LastName = 'contact1', BirthDate = Date.valueOf('1990-01-01')),
      new Contact(Id = '003g000000CxTGo', AccountId = '001g000000CxTGo', FirstName = 'fn1', LastName = 'contact3', BirthDate = Date.valueOf('1996-01-01')),
      new Contact(Id = '003g000000CxTGn', AccountId = '001g000000CxTGo', FirstName = 'fn2', LastName = 'contact2', BirthDate = Date.valueOf('1992-01-01')),
      new Contact(Id = '003g000000CxTGn', AccountId = '001g000000CxTGo', FirstName = null, LastName = 'contact4', BirthDate = Date.valueOf('1992-01-01'))
    };

    Set<String> firstNameSet = GVS_Utils.getSet(cL, 'FirstName');
    System.assertEquals(2, firstNameSet.size());
    System.assertEquals(true, firstNameSet.containsAll(new String[]{
            'fn1', 'fn2'
    }));
  }

  @isTest
  static void testGroupBy() {
    Account[] aL = new Account[]{
            new Account(Name = 'a1', BillingStreet = 'street1'),
            new Account(Name = 'a1', BillingStreet = 'street1'),
            new Account(Name = 'a2', BillingStreet = 'street1')
    };

    Map<String, Account[]> testMap = GVS_Utils.groupBy(aL, 'BillingStreet');
    System.assertEquals(1, testMap.size());
    System.assertEquals(true, testMap.containsKey('street1'));
    System.assertEquals('a1', testMap.get('street1')[0].Name);
    System.assertEquals('a1', testMap.get('street1')[1].Name);
    System.assertEquals('a2', testMap.get('street1')[2].Name);

    testMap = GVS_Utils.groupBy(aL, '{BillingStreet}_{nAmE}', true);
    System.assertEquals(2, testMap.size());
    System.assertEquals(true, testMap.containsKey('street1_a1'));
    System.assertEquals(true, testMap.containsKey('street1_a2'));
    System.assertEquals('a1', testMap.get('street1_a1')[0].Name);
    System.assertEquals('a1', testMap.get('street1_a1')[1].Name);
    System.assertEquals('a2', testMap.get('street1_a2')[0].Name);

    //Test estrazione su campo non definito in datamodel
    testMap = GVS_Utils.groupBy(aL, '{BillingStreet}_{campoInesistente__c}', true);
    System.assertEquals(1, testMap.size());
    System.assertEquals(true, testMap.containsKey('street1_null'));
    System.assertEquals('a1', testMap.get('street1_null')[0].Name);
    System.assertEquals('a1', testMap.get('street1_null')[1].Name);
    System.assertEquals('a2', testMap.get('street1_null')[2].Name);
  }

  @isTest
  static void testFilter() {
    Account[] aL = new Account[]{
            new Account(Name = 'a1', BillingStreet = 'street'),
            new Account(Name = 'a2', BillingStreet = 'street'),
            new Account(Name = 'a3', BillingStreet = 'plaza')
    };

    Account[] filteredAL = GVS_Utils.filter(aL, 'BillingStreet', 'street');
    System.assertEquals(2, filteredAL.size());
    System.assertEquals('a1', filteredAL[0].Name);
    System.assertEquals('a2', filteredAL[1].Name);

    filteredAL = GVS_Utils.filter(aL, 'BillingStreet', 'street', false);
    System.assertEquals(1, filteredAL.size());
    System.assertEquals('a3', filteredAL[0].Name);

    filteredAL = GVS_Utils.filter(aL, 'BillingStreet', new Set<String>{
            'street', 'plaza'
    });
    System.assertEquals(3, filteredAL.size());
    System.assertEquals('a3', filteredAL[2].Name);

    Object objectSet = new Set<String>{
            'street'
    };
    filteredAL = GVS_Utils.filter(aL, 'BillingStreet', objectSet, false);
    System.assertEquals(1, filteredAL.size());
    System.assertEquals('a3', filteredAL[0].Name);
  }

}