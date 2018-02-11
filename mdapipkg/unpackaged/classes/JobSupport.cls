public class JobSupport  
{
	static list<Job_Log__c> jobLogs = new list<Job_Log__c>{};
	static list<Batch_Log__c> batchLogs = new list<Batch_Log__c>{};

	static Job__c currentJob;
	static Batch__c currentBatch;

//  ***************************************************************

	public static void addJobLog (String message)
	{
		if (currentJob == null) return;

		jobLogs.add (new Job_Log__c (Job__c = currentJob.Id, Message__c = message));
	}

//  ***************************************************************

	public static list<Job_Log__c> getJobLogs ()
	{
		return jobLogs;
	}

//  ***************************************************************

	public static void setCurrentJob (Job__c job)
	{
		currentJob = job;
	} 

//  ***************************************************************

	public static void addBatchLog (String message)
	{
		if (currentBatch == null) return;

		batchLogs.add (new Batch_Log__c (Batch__c = currentBatch.Id, Message__c = message));
	}

//  ***************************************************************

	public static list<Batch_Log__c> getBatchLogs ()
	{
		return batchLogs;
	}

//  ***************************************************************

	public static void setCurrentBatch (Batch__c batch)
	{
		currentBatch = batch;
	} 
	
//  ***************************************************************

	public static void cleanupOldJobs (Job__c job)
	{
		Integer daysToKeepJobs = Integer.valueOf((job.Job_Type__r.Days_to_Keep_Jobs__c == null ? 90 : job.Job_Type__r.Days_to_Keep_Jobs__c)) ;

		Date expiryDate = System.today().addDays(-daysToKeepJobs);

		try
		{
			delete [SELECT Id FROM Job__c 
						WHERE Status__c = 'Finished' 
						AND Job_Type__c = :job.Job_Type__c 
						AND CreatedDate < :expiryDate];
		}
		catch (Exception e) {}
	}

//  ***************************************************************

	public static void multiScheduleJob (String jobType, Integer startHour, Integer every)

	//  this method calls multiScheduleJob with no parameters

	{
		multiScheduleJob (jobType, null, startHour, every);
	}

//  ***************************************************************

	public static void multiScheduleJob (String jobType, String parameters, Integer startHour, Integer every)
	{
		if (every == 0) return;
		if (startHour > 23) return;

		for (Integer i=startHour;i<24;i=i+every)
		{
			System.debug (i);
			scheduleJob (jobType, parameters, i, 0);
		}
	}

//  ***************************************************************

	public static void scheduleJob (String jobType, Integer hour, Integer minute)

	//  this method calls scheduleJob with no parameters

	{	
		scheduleJob (jobType, null, hour, minute);
	}

//  ***************************************************************

	public static void scheduleJob (String jobType, String parameters, Integer hour, Integer minute)
	{	
		Job_Type__c jt = new Job_Type__c ();
		
		try
		{
			jt = [SELECT Id, Name, Batch_Size__c FROM Job_Type__c WHERE Name = :jobType LIMIT 1];
		}
		catch (Exception e)
		{
			jt.Name = jobType;
			jt.Batch_Size__c = 25;
			insert jt;
		}
		
		DateTime dt = DateTime.newInstance (System.now().year(), System.now().month(), System.now().day(), hour, minute, 0);
		
		String jobName = jobType + ' Daily at ' + dt.format('HH:mm');
		String scheduledTime = dt.format('ss mm HH ? * 1-7 ****');

        Schedulable obj = (Schedulable) Type.forName(jobType).newInstance();
        Id asyncApexJobId = system.schedule (jobName, scheduledTime, obj);  

		Job__c j = new Job__c (Job_Type__c = jt.Id, Job_Id__c = asyncApexJobId, 
								Parameters__c = parameters, 
								Status__c = 'Repeat Scheduled',
								Scheduled_Hour__c = hour,
								Scheduled_Minute__c = minute);
		insert j;
	}
	
//  ***************************************************************
	
	public static void submitJob (String jobType)

	//  this method calls submitJob with empty Job parameters

	{
		submitJob (jobType, '');
	}

//  ***************************************************************
	
	public static void submitJob (String jobType, Id scheduledJobId)
	{
		Job__c j = getJobForId (scheduledJobId);

		submitJob (jobType, j.Parameters__c, j);
	}

//  ***************************************************************
	
	public static void submitJob (String jobType, String parameters, Job__c parentJob)
	
	//  this method submits an immediate batch job and creates a Job__c record for the code to use
	//  it will optionally create a Job_Type__c record if one is not found in the database with the supplied name
	//  parameters can be supplied in a JSON String
	//  it is only called from submitJob (String jobType, Id scheduledJobId), which is called by the Scheduler calling the execute method
	//  this allows a scheduled job to be connected to it's parent which controls the schedule
	
	{
		Job_Type__c jt = new Job_Type__c ();
		
		try
		{
			jt = [SELECT Id, Batch_Size__c FROM Job_Type__c WHERE Name = :jobType LIMIT 1];
		}
		catch (Exception e)
		{
			jt.Name = jobType;
			jt.Batch_Size__c = 25; 
			insert jt;
		}
		
        Database.Batchable<SObject> obj = (Database.Batchable<SObject>) Type.forName(jobType).newInstance();
        Id asyncApexJobId = Database.executeBatch (obj, Integer.valueOf(jt.Batch_Size__c));  

		Job__c j = new Job__c (Job_Type__c = jt.Id, 
								Job_Id__c = asyncApexJobId, 
								Parameters__c = parameters, 
								Parent_Job__c = parentJob.Id,
								Status__c = 'Scheduled');
		insert j;
	}

//  ***************************************************************
	
	public static void submitJob (String jobType, String parameters)
	
	//  this method submits an immediate batch job and creates a Job__c record for the code to use
	//  it will optionally create a Job_Type__c record if one is not found in the database with the supplied name
	//  parameters can be supplied in a JSON String
	
	{
		Job_Type__c jt = new Job_Type__c ();
		
		try
		{
			jt = [SELECT Id, Batch_Size__c FROM Job_Type__c WHERE Name = :jobType LIMIT 1];
		}
		catch (Exception e)
		{
			jt.Name = jobType;
			jt.Batch_Size__c = 25; 
			insert jt;
		}
		
        Database.Batchable<SObject> obj = (Database.Batchable<SObject>) Type.forName(jobType).newInstance();
        Id asyncApexJobId = Database.executeBatch (obj, Integer.valueOf(jt.Batch_Size__c));  

		Job__c j = new Job__c (Job_Type__c = jt.Id, Job_Id__c = asyncApexJobId, Parameters__c = parameters, Status__c = 'Scheduled');
		insert j;
	}

//  ***************************************************************
	
	public static Job__c getJobForId (Id jobId)
	{		
		try 
		{
			currentJob = [SELECT Id, Parameters__c, Job_Type__c, Job_Type__r.Disabled__c, Job_Type__r.Parameters__c, 
					Job_Type__r.Days_to_Keep_Jobs__c,
					Status__c, Started__c, Finished__c, Log__c 
					FROM Job__c 
					WHERE Job_Id__c = :jobId 
					LIMIT 1];

			cleanupOldJobs (currentJob);
		}
		catch (Exception e) {}


		System.debug('$$$$$$ in getJobForId ' + currentJob);

		return currentJob;
	}

//  ***************************************************************
	
	public static void addLineToJobLog (Job__c job, String line, Boolean updateStatus)
	{
		if (job.Log__c == null)
		{
			job.Log__c = line + '\n';
		}
		else
		{
			job.Log__c += line + '\n';
		}

		if (updateStatus == true)
		{
			job.Status__c = line;
			if (line == 'Started') job.Started__c = System.now();
			if (line == 'Finished' || line == 'Failed') job.Finished__c = System.now();
		}
	}

//  ***************************************************************
	
	public static void addLineToBatchLog (Batch__c batch, String line, Boolean updateStatus)
	{
		if (batch.Log__c == null)
		{
			batch.Log__c = line + '\n';
		}
		else
		{
			batch.Log__c += line + '\n';
		}
		
		if (updateStatus == true)
		{
			batch.Status__c = line;
			if (line == 'Started') batch.Started__c = System.now();
			if (line == 'Finished' || line == 'Failed') batch.Finished__c = System.now();
		}
	}

//  ***************************************************************
	
	public static void addLineToBatchLog (Batch__c batch, String line, Boolean updateStatus, Boolean notifiableError)
	{
		if (notifiableError) 
		{
			if (batch.Notifiable_Errors__c == null)
			{
				batch.Notifiable_Errors__c = 0;
			}
			batch.Notifiable_Errors__c++;
		}
		addLineToBatchLog (batch, line, updateStatus);
	}
}