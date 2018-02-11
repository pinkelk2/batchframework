@isTest
private class JobSupport_Test  
{
    static testMethod void test () 
    {
        Account a1 = new Account (Name = 'Test Account 1');
        insert a1;

        Job_Type__c jt1 = new Job_Type__c (Name='Test 1');
        insert jt1;

        Job__c j1 = new Job__c (Job_Type__c = jt1.Id);
        insert j1;

        Batch__c b1 = new Batch__c (Job__c = j1.Id);

        JobSupport.scheduleJob('BatchTestFramework', 12, 12);
        JobSupport.submitJob('BatchTestFramework');
        JobSupport.multiScheduleJob('BatchTestFramework', 0, 1);

        JobSupport.setCurrentJob (j1);
        JobSupport.addJobLog('Test');
        JobSupport.getJobLogs();

        JobSupport.setCurrentBatch (b1);
        JobSupport.addBatchLog('Test');
        JobSupport.getBatchLogs();
        JobSupport.cleanupOldJobs(j1);
    }
}