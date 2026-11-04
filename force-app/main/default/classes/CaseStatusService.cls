public without sharing class CaseStatusService {

    public class CaseInput {
        @InvocableVariable(label='Case Identifier' description='The 15 or 18 character Salesforce Case ID (starts with 500) or Case Number (e.g. 00001023)' required=true)
        public String caseIdentifier;
    }

    public class CaseOutput {
        @InvocableVariable(label='Case ID')
        public String caseId;

        @InvocableVariable(label='Case Number')
        public String caseNumber;

        @InvocableVariable(label='Case Status')
        public String status;

        @InvocableVariable(label='Case Subject')
        public String subject;

        @InvocableVariable(label='Case Priority')
        public String priority;

        @InvocableVariable(label='Found')
        public Boolean isFound;
    }

    @InvocableMethod(label='Get Case Status by ID' description='Looks up a Case by Case ID or Case Number and returns its current status, subject, and priority.')
    public static List<CaseOutput> getCaseStatus(List<CaseInput> inputs) {
        List<CaseOutput> results = new List<CaseOutput>();
        if (inputs == null || inputs.isEmpty()) {
            return results;
        }

        for (CaseInput input : inputs) {
            CaseOutput out = new CaseOutput();
            out.isFound = false;

            if (String.isNotBlank(input.caseIdentifier)) {
                String cleanInput = input.caseIdentifier.trim();
                List<Case> cases = new List<Case>();

                // Check by Case ID (500...) or by CaseNumber
                if (cleanInput.startsWith('500') && (cleanInput.length() == 15 || cleanInput.length() == 18)) {
                    cases = [SELECT Id, CaseNumber, Status, Subject, Priority FROM Case WHERE Id = :cleanInput LIMIT 1];
                } else {
                    cases = [SELECT Id, CaseNumber, Status, Subject, Priority FROM Case WHERE CaseNumber = :cleanInput LIMIT 1];
                }

                if (!cases.isEmpty()) {
                    Case c = cases[0];
                    out.caseId = c.Id;
                    out.caseNumber = c.CaseNumber;
                    out.status = c.Status;
                    out.subject = c.Subject;
                    out.priority = c.Priority;
                    out.isFound = true;
                }
            }
            results.add(out);
        }
        return results;
    }
}