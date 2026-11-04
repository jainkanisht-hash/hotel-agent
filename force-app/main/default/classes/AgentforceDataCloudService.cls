public class AgentforceDataCloudService {

    public class AgentInput {
        @InvocableVariable(label='Contact ID' description='The Salesforce Contact ID')
        public String contactId;
        
        @InvocableVariable(label='Contact Email' description='The Contact Email Address')
        public String contactEmail;
        
        @InvocableVariable(label='Contact Name' description='The Contact Full Name')
        public String contactName;
    }

    public class AgentOutput {
        @InvocableVariable(label='Customer Name')
        public String customerName;

        @InvocableVariable(label='Customer Age')
        public Decimal age;

        @InvocableVariable(label='Net Worth')
        public Decimal netWorth;

        @InvocableVariable(label='Total Investment')
        public Decimal totalInvestment;

        @InvocableVariable(label='Current Portfolio')
        public Decimal currentPortfolio;

        @InvocableVariable(label='Future Goal')
        public Decimal futureGoal;

        @InvocableVariable(label='Account ID')
        public String accountIdUsed;

        @InvocableVariable(label='Unified Individual ID')
        public String unifiedHexId;

        @InvocableVariable(label='Result Message')
        public String resultMessage;

        @InvocableVariable(label='Widget Payload' description='System field for UI widget rendering')
        public String widgetPayload;
    }

    @InvocableMethod(label='Get 360 Customer Profile' description='Retrieves a unified customer profile and financial information from Data 360.')
    public static List<AgentOutput> getProfileData(List<AgentInput> requests) {
        if (requests == null || requests.isEmpty()) {
            return new List<AgentOutput>();
        }
        if (requests.size() > 1) {
            throw new IllegalArgumentException('This Agentforce service only supports processing one customer at a time.');
        }

        List<AgentOutput> results = new List<AgentOutput>();
        AgentOutput out = new AgentOutput();
        AgentInput req = requests[0];

        try {
            String unifiedId;
            String accountId;
            String contactId = req.contactId;

            if (String.isBlank(contactId) && String.isNotBlank(req.contactEmail)) {
                List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :req.contactEmail LIMIT 1];
                if (!contacts.isEmpty()) {
                    contactId = contacts[0].Id;
                }
            }

            if (String.isNotBlank(contactId)) {
                String escapedContactId = String.escapeSingleQuotes(contactId);
                List<SObject> links = Database.query(
                    'SELECT UnifiedRecordId__c FROM UnifiedLinkssotIndividual02__dlm ' + 
                    'WHERE SourceRecordId__c = \'' + escapedContactId + '\' LIMIT 1'
                );

                if (!links.isEmpty()) {
                    unifiedId = String.valueOf(links[0].get('UnifiedRecordId__c'));
                }
            }

            if (String.isBlank(unifiedId) && String.isNotBlank(req.contactName)) {
                String escapedName = String.escapeSingleQuotes(req.contactName);
                List<SObject> individuals = Database.query(
                    'SELECT ssot__Id__c FROM UnifiedssotIndividual02__dlm ' + 
                    'WHERE ssot__PersonName__c = \'' + escapedName + '\' LIMIT 1'
                );

                if (!individuals.isEmpty()) {
                    unifiedId = String.valueOf(individuals[0].get('ssot__Id__c'));
                }
            }

            if (String.isBlank(unifiedId)) {
                out.resultMessage = 'No matching Unified Individual was found.';
                results.add(out);
                return results;
            }

            out.unifiedHexId = unifiedId;
            String escapedUnifiedId = String.escapeSingleQuotes(unifiedId);

            List<SObject> externalLinks = Database.query(
                'SELECT SourceRecordId__c FROM UnifiedLinkssotIndividual02__dlm ' +
                'WHERE UnifiedRecordId__c = \'' + escapedUnifiedId + '\' ' +
                'AND SourceRecordId__c LIKE \'ACC%\' LIMIT 1'
            );

            if (externalLinks.isEmpty()) {
                out.resultMessage = 'Unified Individual found, but no ACC account link was found.';
                results.add(out);
                return results; // Exit early
            }

            accountId = String.valueOf(externalLinks[0].get('SourceRecordId__c'));
            out.accountIdUsed = accountId;
            String escapedAccountId = String.escapeSingleQuotes(accountId);

            ConnectApi.CdpQueryInput queryInput = new ConnectApi.CdpQueryInput();
            queryInput.sql = 'SELECT ' + 
                'u.ssot__Id__c, ' + 
                'u.ssot__PersonName__c, ' + 
                'l.SourceRecordId__c, ' + 
                'MAX(u.ssot__Age__c), ' + 
                'MAX(u.ssot__NetWorth__c), ' +
                'SUM(i.total_investment__c), ' +
                'MAX(p.current_portfolio__c), ' +
                'MAX(g.future_goal_amount__c) ' +
                'FROM UnifiedssotIndividual02__dlm u ' +
                'LEFT JOIN UnifiedLinkssotIndividual02__dlm l ' +
                'ON u.ssot__Id__c = l.UnifiedRecordId__c ' +
                'LEFT JOIN Account_Investments__dlm i ' +
                'ON l.SourceRecordId__c = i.account_id__c ' +
                'LEFT JOIN Current_Portfolio__dlm p ' +
                'ON l.SourceRecordId__c = p.account_id__c ' +
                'LEFT JOIN Future_Goal__dlm g ' +
                'ON l.SourceRecordId__c = g.account_id__c ' +
                'WHERE u.ssot__Id__c = \'' + escapedUnifiedId + '\' ' +
                'AND l.SourceRecordId__c = \'' + escapedAccountId + '\' ' +
                'GROUP BY ' +
                'u.ssot__Id__c, ' +
                'u.ssot__PersonName__c, ' +
                'l.SourceRecordId__c ' +
                'LIMIT 1';

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

        results.add(out);
        return results;
    }

    private static String getStringValue(List<Object> row, Integer index) {
        if (row == null || row.size() <= index || row[index] == null) {
            return null;
        }
        return String.valueOf(row[index]);
    }

    private static Decimal getDecimalValue(List<Object> row, Integer index) {
        if (row == null || row.size() <= index || row[index] == null) {
            return null;
        }
        return Decimal.valueOf(String.valueOf(row[index]));
    }
}