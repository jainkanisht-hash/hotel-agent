public without sharing class CustomerFinancial360Controller {

    public class FinancialSummaryWrapper {
        @AuraEnabled public String contactEmail { get; set; }
        @AuraEnabled public String contactPhone { get; set; }
        @AuraEnabled public String accountId { get; set; }
        @AuraEnabled public String unifiedHexId { get; set; }
        @AuraEnabled public Decimal totalInvestment { get; set; }
        @AuraEnabled public Decimal currentPortfolio { get; set; }
        @AuraEnabled public Decimal futureGoal { get; set; }
        @AuraEnabled public Boolean hasData { get; set; }
        @AuraEnabled public String errorMessage { get; set; }

        public FinancialSummaryWrapper() {
            this.totalInvestment = 0;
            this.currentPortfolio = 0;
            this.futureGoal = 0;
            this.hasData = false;
        }
    }

    @AuraEnabled(cacheable=true)
    public static FinancialSummaryWrapper getContactFinancialSummary(Id contactId) {
        FinancialSummaryWrapper response = new FinancialSummaryWrapper();

        if (contactId == null) {
            response.errorMessage = 'No Contact record ID provided.';
            return response;
        }

        try {
            // STEP 1: Query Contact Details
            List<Contact> contacts = [SELECT Email, Phone FROM Contact WHERE Id = :contactId LIMIT 1];
            if (!contacts.isEmpty()) {
                response.contactEmail = contacts[0].Email;
                response.contactPhone = contacts[0].Phone;
            }

            // STEP 2: Resolve the Data Cloud Unified Individual ID (ssot__Id__c)
            String safeContactId = String.escapeSingleQuotes(String.valueOf(contactId).trim());
            List<SObject> linkRecords = Database.query(
                'SELECT UnifiedRecordId__c FROM UnifiedLinkssotIndividual02__dlm ' +
                'WHERE SourceRecordId__c = \'' + safeContactId + '\' LIMIT 1'
            );

            if (linkRecords.isEmpty()) {
                response.errorMessage = 'No unified profile link exists for this contact.';
                return response;
            }

            String unifiedHexId = (String) linkRecords[0].get('UnifiedRecordId__c');
            response.unifiedHexId = unifiedHexId;

            List<SObject> externalLinks = Database.query(
                'SELECT SourceRecordId__c FROM UnifiedLinkssotIndividual02__dlm ' +
                'WHERE UnifiedRecordId__c = \'' + unifiedHexId + '\' ' +
                'AND SourceRecordId__c LIKE \'ACC%\' LIMIT 1'
            );

            if (externalLinks.isEmpty()) {
                response.errorMessage = 'Unified profile found, but no linked external Account ID (ACC-*) exists.';
                return response;
            }

            String externalAccountId = (String) externalLinks[0].get('SourceRecordId__c');
            response.accountId = externalAccountId;

            // STEP 4: Query Snowflake & BigQuery DMOs
            List<SObject> investmentRecords = Database.query(
                'SELECT total_investment__c FROM Account_Investments__dlm WHERE account_id__c = \'' + externalAccountId + '\' LIMIT 1'
            );
            if (!investmentRecords.isEmpty() && investmentRecords[0].get('total_investment__c') != null) {
                response.totalInvestment = (Decimal) investmentRecords[0].get('total_investment__c');
            }

            List<SObject> portfolioRecords = Database.query(
                'SELECT current_portfolio__c FROM Current_Portfolio__dlm WHERE account_id__c = \'' + externalAccountId + '\' LIMIT 1'
            );
            if (!portfolioRecords.isEmpty() && portfolioRecords[0].get('current_portfolio__c') != null) {
                response.currentPortfolio = (Decimal) portfolioRecords[0].get('current_portfolio__c');
            }

            List<SObject> goalRecords = Database.query(
                'SELECT future_goal_amount__c FROM Future_Goal__dlm WHERE account_id__c = \'' + externalAccountId + '\' LIMIT 1'
            );
            if (!goalRecords.isEmpty() && goalRecords[0].get('future_goal_amount__c') != null) {
                response.futureGoal = (Decimal) goalRecords[0].get('future_goal_amount__c');
            }

            response.hasData = true;

        } catch (Exception ex) {
            response.errorMessage = 'Error retrieving 360 data: ' + ex.getMessage();
        }

        return response;
    }
}