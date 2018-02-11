global with sharing class BatchTestFramework 
							implements Database.Batchable<SObject>,
										Database.Stateful, 
										Database.AllowsCallouts,
										Schedulable 
{
	Boolean testMode;
	public Job__c job; 

//******************************************************************

	global BatchTestFramework() 
	{
		//  nothing to do
	}

//******************************************************************

	global void execute(SchedulableContext sc)  
	{
		JobSupport.submitJob('BatchTestFramework', 'No Parameters');
	}

//******************************************************************

	global database.querylocator start (Database.BatchableContext bc)  //  comment added 
	{		
        this.job = JobSupport.getJobForId (bc.getJobId());
		JobSupport.addLineToJobLog (this.job, 'Started', true);
        update this.job;
																		
		String query = 'SELECT Id, Name FROM Account LIMIT 100';
							
		Database.Querylocator ql = Database.getqueryLocator(query); 
		
		return ql;   
	}

//******************************************************************

	global void execute (Database.BatchableContext bc, list<Account> accounts) 
	{						 

    	Batch__c batch = new Batch__c (Job__c = this.job.Id);
    	
    	JobSupport.addLineToBatchLog (batch, 'Started', true);
		insert batch;

		for (Account a : accounts)
		{
			JobSupport.addLineToBatchLog (batch, 'Processed Account OK: ' + a.Name, false);
		}

    	JobSupport.addLineToBatchLog (batch, 'Finished', true);
		update batch;
	}

//******************************************************************
	
	global void finish (Database.BatchableContext bc)
	{
		JobSupport.addLineToJobLog (this.job, 'Finished', true);	
        update this.job;        
    }
}