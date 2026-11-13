public class SnowflakeAgeUpdater {

    public class UpdateRequest {
        @InvocableVariable(required=true description='The Account ID (e.g., ACC-101)')
        public String accountId;
        
        @InvocableVariable(required=false description='The new age to update in Snowflake (leave blank if only updating investment)')
        public Integer newAge;

        @InvocableVariable(required=false description='The new Total Investment amount to update in Snowflake (leave blank if only updating age)')
        public Decimal newInvestment;
    }

    @InvocableMethod(
        label='Update Age in Snowflake' 
        description='Updates the Age and/or Total Investment of a customer in Snowflake. Requires Account ID and at least one of newAge or newInvestment.'
    )
    public static List<String> updateAge(List<UpdateRequest> requests) {
        List<String> results = new List<String>();
        
        for (UpdateRequest req : requests) {
            if (req.newAge == null && req.newInvestment == null) {
                results.add('Error: Please provide either a new age or a new investment amount to update.');
                continue;
            }

            String safeAccountId = String.escapeSingleQuotes(req.accountId);
            List<String> statusMessages = new List<String>();

            // 1. Update Age if provided
            if (req.newAge != null) {
                String ageSql = 'UPDATE POC_DB.POC.ACCOUNT_INFO SET AGE = ' + req.newAge + ' WHERE ACCOUNT_ID = \'' + safeAccountId + '\';';
                statusMessages.add(executeSql(ageSql, 'Age for ' + req.accountId + ' updated to ' + req.newAge));
            }

            // 2. Update Total Investment if provided
            if (req.newInvestment != null) {
                // Adjust ACCOUNT_INVESTMENTS below if your Snowflake table name differs
                String invSql = 'UPDATE POC_DB.POC.ACCOUNT_INVESTMENTS SET TOTAL_INVESTMENT = ' + req.newInvestment + ' WHERE ACCOUNT_ID = \'' + safeAccountId + '\';';
                statusMessages.add(executeSql(invSql, 'Total Investment for ' + req.accountId + ' updated to ' + req.newInvestment));
            }

            results.add(String.join(statusMessages, ' | '));
        }
        return results;
    }

    private static String executeSql(String sqlCommand, String successMessage) {
        String jsonBody = '{"statement": "' + sqlCommand + '", "timeout": 60, "database": "POC_DB", "schema": "POC", "warehouse": "DC_WH"}';
        
        HttpRequest httpRequest = new HttpRequest();
        httpRequest.setEndpoint('callout:Snowflake_API/api/v2/statements');
        httpRequest.setMethod('POST');
        httpRequest.setHeader('Content-Type', 'application/json');
        httpRequest.setHeader('Accept', 'application/json');
        httpRequest.setBody(jsonBody);
        
        Http http = new Http();
        try {
            HttpResponse response = http.send(httpRequest);
            if (response.getStatusCode() == 200 || response.getStatusCode() == 202) {
                return 'Success: ' + successMessage;
            } else {
                return 'Error: ' + response.getStatusCode() + ' - ' + response.getBody();
            }
        } catch (Exception e) {
            return 'Callout Exception: ' + e.getMessage();
        }
    }
}