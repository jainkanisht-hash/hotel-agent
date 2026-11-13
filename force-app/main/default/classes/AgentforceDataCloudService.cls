// Added explicit sharing declaration (change to 'without sharing' if the Agent needs system-level access)
public with sharing class AgentforceDataCloudService {

    public class AgentInput {
        @InvocableVariable(label='Contact ID' description='The Salesforce Contact ID')
        public String contactId;
        
        @InvocableVariable(label='Contact Email' description='The Contact Email Address')
        public String contactEmail;
        
        @InvocableVariable(label='Contact Name' description='The Contact Full Name')
        public String contactName;
    }

    public class ProfileData {
        @InvocableVariable(label='Customer Name' description='The full name of the customer from Data Cloud.') 
        public String customerName;
        
        @InvocableVariable(label='Customer Age' description='The age of the customer.') 
        public Decimal age;
        
        @InvocableVariable(label='Net Worth' description='The calculated net worth of the customer in USD.') 
        public Decimal netWorth;
        
        @InvocableVariable(label='Total Investment' description='The total amount the customer has invested in USD.') 
        public Decimal totalInvestment;
        
        @InvocableVariable(label='Current Portfolio' description='The current monetary value of the customer portfolio.') 
        public Decimal currentPortfolio;
        
        @InvocableVariable(label='Future Goal' description='The monetary target the customer is aiming for in their future goal.') 
        public Decimal futureGoal;
        
        @InvocableVariable(label='Account ID' description='The Salesforce Account ID linked to this unified profile.') 
        public String accountIdUsed;
        
        @InvocableVariable(label='Unified Individual ID' description='The Data Cloud Unified Individual ID (Hex ID).') 
        public String unifiedHexId;
        
        @InvocableVariable(label='Result Message' description='System message indicating success or failure of the profile retrieval.') 
        public String resultMessage;
    }

    public class AgentOutput {
        @InvocableVariable(label='Customer Profile Details' description='Unified customer 360 profile details')
        public ProfileData customerProfile;
    }

    @InvocableMethod(label='Get 360 Customer Profile' description='Retrieves a unified customer profile and financial information from Data 360.')
    public static List<AgentOutput> getProfileData(List<AgentInput> requests) {
        List<AgentOutput> results = new List<AgentOutput>();
        if (requests == null || requests.isEmpty()) return results;

        for (AgentInput req : requests) {
            AgentOutput wrapper = new AgentOutput();
            ProfileData out = new ProfileData();
            wrapper.customerProfile = out;

            try {
                String unifiedId;
                String accountId;
                String contactId = req.contactId;

                if (String.isBlank(contactId) && String.isNotBlank(req.contactEmail)) {
                    List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :req.contactEmail LIMIT 1];
                    if (!contacts.isEmpty()) contactId = contacts[0].Id;
                }

                if (String.isNotBlank(contactId)) {
                    String escapedContactId = String.escapeSingleQuotes(contactId);
                    List<SObject> links = Database.query('SELECT UnifiedRecordId__c FROM UnifiedLinkssotIndividual02__dlm WHERE SourceRecordId__c = \'' + escapedContactId + '\' LIMIT 1');
                    if (!links.isEmpty()) unifiedId = String.valueOf(links[0].get('UnifiedRecordId__c'));
                }

                if (String.isBlank(unifiedId) && String.isNotBlank(req.contactName)) {
                    String escapedName = String.escapeSingleQuotes(req.contactName);
                    List<SObject> individuals = Database.query('SELECT ssot__Id__c FROM UnifiedssotIndividual02__dlm WHERE ssot__PersonName__c = \'' + escapedName + '\' LIMIT 1');
                    if (!individuals.isEmpty()) unifiedId = String.valueOf(individuals[0].get('ssot__Id__c'));
                }

                if (String.isBlank(unifiedId)) {
                    out.resultMessage = 'No matching Unified Individual was found.';
                    results.add(wrapper);
                    continue; 
                }

                out.unifiedHexId = unifiedId;
                String escapedUnifiedId = String.escapeSingleQuotes(unifiedId);

                List<SObject> externalLinks = Database.query('SELECT SourceRecordId__c FROM UnifiedLinkssotIndividual02__dlm WHERE UnifiedRecordId__c = \'' + escapedUnifiedId + '\' AND SourceRecordId__c LIKE \'ACC%\' LIMIT 1');

                if (externalLinks.isEmpty()) {
                    out.resultMessage = 'Unified Individual found, but no ACC account link was found.';
                    results.add(wrapper);
                    continue; 
                }

                accountId = String.valueOf(externalLinks[0].get('SourceRecordId__c'));
                out.accountIdUsed = accountId;
                String escapedAccountId = String.escapeSingleQuotes(accountId);

                ConnectApi.CdpQueryInput queryInput = new ConnectApi.CdpQueryInput();
                queryInput.sql = 'SELECT u.ssot__Id__c, u.ssot__PersonName__c, l.SourceRecordId__c, MAX(u.ssot__Age__c), MAX(u.ssot__NetWorth__c), SUM(i.total_investment__c), MAX(p.current_portfolio__c), MAX(g.future_goal_amount__c) ' +
                    'FROM UnifiedssotIndividual02__dlm u LEFT JOIN UnifiedLinkssotIndividual02__dlm l ON u.ssot__Id__c = l.UnifiedRecordId__c ' +
                    'LEFT JOIN Account_Investments__dlm i ON l.SourceRecordId__c = i.account_id__c LEFT JOIN Current_Portfolio__dlm p ON l.SourceRecordId__c = p.account_id__c ' +
                    'LEFT JOIN Future_Goal__dlm g ON l.SourceRecordId__c = g.account_id__c ' +
                    'WHERE u.ssot__Id__c = \'' + escapedUnifiedId + '\' AND l.SourceRecordId__c = \'' + escapedAccountId + '\' ' +
                    'GROUP BY u.ssot__Id__c, u.ssot__PersonName__c, l.SourceRecordId__c LIMIT 1';

                ConnectApi.CdpQueryOutputV2 response = ConnectApi.CdpQuery.queryAnsiSqlV2(queryInput);

                if (response != null && response.data != null && !response.data.isEmpty()) {
                    List<Object> row = response.data[0].rowData;
                    out.customerName = getStringValue(row, 1);
                    out.age = getDecimalValue(row, 3);
                    out.netWorth = getDecimalValue(row, 4);
                    out.totalInvestment = getDecimalValue(row, 5);
                    out.currentPortfolio = getDecimalValue(row, 6);
                    out.futureGoal = getDecimalValue(row, 7);
                    out.resultMessage = 'Customer profile retrieved successfully.';
                } else {
                    out.resultMessage = 'The customer was found, but the combined query returned no financial profile.';
                }
            } catch (Exception e) {
                out.resultMessage = 'Unable to retrieve customer profile: ' + e.getMessage();
            }

            results.add(wrapper);
        }
        
        return results;
    }

    private static String getStringValue(List<Object> row, Integer index) {
        if (row == null || row.size() <= index || row[index] == null) return null;
        return String.valueOf(row[index]);
    }

    private static Decimal getDecimalValue(List<Object> row, Integer index) {
        if (row == null || row.size() <= index || row[index] == null) return null;
        return Decimal.valueOf(String.valueOf(row[index]));
    }
}