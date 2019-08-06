/*
/*SAS Users Group
/*Combining SAS macros & PROC SQL
/*Presented by Leah Durbak ldurbak@urban.org
/*Feel free to distribute internally at Urban
/*08/06/2019
/*

/*update to your data location*/
libname sas "D:\Users\LDurbak\Box Sync\My Box Notes\My stuff\SAS Users Group";
/*What is efficient code?
Parsimonious - the code is simple and avoids redunancies
Correct - the code does not contain typos or other errors
Easy to maintain - the code is easy to understand and therefore updates are easy to implement

/*PROC SQL review
SQL is Structured Query Language
It's a (mostly) standardized way to query data, i.e. it is totally different than SAS syntax. 
"Mostly" because there are slightly different implementations of SQl. If you are looking for SQL help online, make sure you are looking for SAS PROC SQL help.
PROC SQL can be used to query and summarize data. It is not ideal for producing nice-looking reports or doing complex analytics. 
SQL can* improve your coding efficiency by:
	1. Passing queries to the SQL Optimizer, which finds the optimal way to return queries 
	2. Combining what would otherwise take multiple proc/data steps into a single SQL query
*Depending on your specific system's resources
The order of SQL statements are important - syntax errors may simply be that you have an "order by" statement before a "where" statement.
SQL is meant to be human-readable - try reading the following SQL query to see if you can tell what it is going to do (after the "proc sql;"):
*/

proc sql;
	select libname, memname, nobs
	from dictionary.tables
	where libname=upcase("sas")
	order by nobs;
quit;

proc sql;
	select *
	from dictionary.columns
	where libname=upcase("sas");
quit;

/* Metadata tables
dictionary.tables and dictionary.columns are examples of metadata tables that are available only through SAS PROC SQL. 
They contain metadata aka descriptive information about the objects in your SAS session, such as tables.
Metadata information is stored when an object is created/updated and therefore does not need to be calculated.
More information about metadata tables can be found here:
https://support.sas.com/resources/papers/proceedings/proceedings/sugi25/25/cc/25p077.pdf
*/

/* Example-driven ideas for efficient coding using PROC SQL and macros 
Take a look at the data:
*/
proc print data=sas.demo;
	title "Demographic table";
run;
proc print data=sas.hdrs;
	title "Claim Headers";
run;
proc sql inobs=10; /*inobs limits the incoming data, outobs limits the output data*/
	title "Claim Lines";
	select * 
	from sas.lns;
quit;
title;

/*We want to create summary spending tables for:
	- for each claim type (ClaimType, in the claim header table) 
	- for each type of service (TOS, in the claim line table) 
	- for each insurance provider (InsuranceProvider, in the demo table)
We want the summary statistics to be:
	- mean, minimum, and maximum of the PaidAmount
If we take a look at the number of combinations of claim type, type of service, and insurance provider (below), we can see we really do not want to do this manually.
*/
proc freq data=sas.hdrs;
	tables ClaimType;
run;
proc freq data=sas.lns;
	tables TOS;
run;
proc freq data=sas.demo;
	tables InsuranceProvider;
run;

/*Step 1: write the code without macros
From the metadata, we know that the lns table has the most observations.
(Admittedly, there are not enough observations to cause processing issues but in the real world this can easily happen.)
So let's set up our queries to limit the number of observations that we read in from the lns table at any point.
To achieve this, first join the hdr and demo tables to get the InsuranceProvider column.
We will do this in PROC SQL because we do not need an explicit sort first.
SQL also does not require equivalently named matching variables (even though they are the same in this example)*/

proc sql;
	/*left join: this is a type of SQL merging. 
 	Left joins return the results of everything in the table left of the join statement +
	only the observations from the table to the right of the join statement with matches in the left table.
	Other joins types are 
		"right join" (same as left but reversed direction),
		"inner join" (only observations with matches in both tables), and 
		"full join" (all observations, with or without matches in the other table)*/ 
	create table hdr_demo_Aetna_01 as /*create table [name] as will "save" the results of your SQL query as a table*/
	select hdr.*, InsuranceProvider
	from sas.hdrs as hdr left join sas.demo as dm /*good practice to give your tables meaningful aliases*/
	on hdr.ID =  dm.ID
		/*A "where" statement tells the SQL Optimizer to limit the observations read into SAS*/
	where ClaimType=01 and InsuranceProvider = "Aetna";
	
	/*The SQL Optimizer will run as soon as it encounters a ';' so you can include multiple
	SQL statements between "proc sql;" and "quit;", and use the output from any statement
	in subsequent statements*/
	title "hdr & demo join";
	select * from hdr_demo_Aetna_01;
quit;

/*Next, add the lns table elements we need. We are also going to do this merge in SQL because we can use a SQL join to limit the incoming data
from the lns table with our already-limited hdr_demo_Aetna table (which used a "where" statement to limit the number of observations brought into SAS memory)*/
proc sql;
	create table lns_Aetna_01 as
	select hdr.*,
		lns.TOS,
		lns.PaidAmount
	from sas.lns as lns right join hdr_demo_Aetna as hdr 
	on lns.ClaimHeaderLink = hdr.ClaimHeaderLink;
	
	title "Lns for Aetna with Claim Type = 1";
	select *
	from lns_Aetna_01;
quit;

/*We can combine the previous two "create table" SQL statements into a single step.*/
proc sql;
	create table demo_hdr_lns_Aetna_01 as 
	select hdr.*, 
		dm.InsuranceProvider,
		lns.TOS,
		lns.PaidAmount
	from sas.hdrs as hdr left join sas.demo as dm 
	on hdr.ID =  dm.ID
	left join sas.lns as lns
	on lns.ClaimHeaderLink = hdr.ClaimHeaderLink
	where ClaimType=01 and InsuranceProvider = "Aetna";

	title "Lns for Aetna with Claim Type = 1";
	select *
	from demo_hdr_lns_Aetna_01;
quit;

/*Is this more efficient?
It is more parsimonious - it took fewer lines. In this case, with my system resources, it did take less time.
Is it correct? Yes, we got the same results from both methods.
Is it clear? I don't this multiple-table join is too confusing, but it is very subjective so it is worth considering who will be using/maintaining your code.
*/
proc sql;
	/*PROC SQL can create summary calculations like count/mean/min/max/etc. easily*/
	create table sas.summary_lns_Aetna_01 as 
	select 
		TOS, 
		count(PaidAmount) as N_claim_lns, /*count() counts non-null values*/
		mean(PaidAmount) as mean_PaidAmount, 
		min(PaidAmount) as min_PaidAmount, 
		max(PaidAmount) as max_PaidAmount
	from demo_hdr_lns_Aetna_01
	/*The GROUP BY statement tells SQL to perform these calculations for observations grouped by distinct values for that element - TOS in this case*/
	group by TOS;

	title "Summary Stats of Paid Amount for Aenta with Claim Type = 01";
	select *
	from sas.summary_lns_Aetna_01;
quit;


/*Step 2: Replace hardcoded values with macro variables
Hint: Select the entire proc sql section below and hit Ctrl+H to bring up Find&Replace. 
Use this window to replace the word Aetna with the provider macro variable.
Find&Replace can be very useful but it must be used with care to avoid adding typos into your code.
*/
%let claim_type=1;
%let provider = Aetna;

proc sql;
	create table demo_hdr_lns_Aetna_01 as 
	select hdr.*, 
		dm.InsuranceProvider,
		lns.TOS,
		lns.PaidAmount
	from sas.hdrs as hdr left join sas.demo as dm 
	on hdr.ID =  dm.ID
	left join sas.lns as lns
	on lns.ClaimHeaderLink = hdr.ClaimHeaderLink
	where ClaimType=01 and InsuranceProvider = "Aetna";

	create table sas.summary_lns_Aetna_01 as 
	select 
		TOS, 
		count(PaidAmount) as N_claim_lns,
		mean(PaidAmount) as mean_PaidAmount, 
		min(PaidAmount) as min_PaidAmount, 
		max(PaidAmount) as max_PaidAmount
	from lns_Aetna_01
	group by TOS;
quit;

/*Step 3: add a loop to run over all claim types*/
/*this macro creates tables for all 7 claim types with summary spending statistics by TOS for a single provider, which is defined by the %let provider = ; in the global macro table*/
%macro paidamt_summary_aetna();
	%do i=1 %to 7;
	%let claim_type = &i.;
		proc sql;
		create table demo_hdr_lns_&provider._&claim_type. as 
		select hdr.*, 
			dm.InsuranceProvider,
			lns.TOS,
			lns.PaidAmount
		from sas.hdrs as hdr left join sas.demo as dm 
		on hdr.ID =  dm.ID
		left join sas.lns as lns
		on lns.ClaimHeaderLink = hdr.ClaimHeaderLink
		where ClaimType=&claim_type. and InsuranceProvider = "&provider.";

		create table sas.summary_lns_&provider._&claim_type. as 
		select 
			TOS, 
			count(PaidAmount) as N_claim_lns,
			mean(PaidAmount) as mean_PaidAmount, 
			min(PaidAmount) as min_PaidAmount, 
			max(PaidAmount) as max_PaidAmount
		from demo_hdr_lns_&provider._&claim_type.
		group by TOS;
		
		title "Summary Spending Statistics by TOS for &provider. for Claims with ClaimType = &claim_type.";
		select *
		from sas.summary_lns_&provider._&claim_type.;
	quit;

	%end;
%mend;

%paidamt_summary_aetna;

/*Step 4: Add a loop to create the same tables for each provider
This is a way you can loop over values that are character strings.
I'm going to use proc sql to create a macro variable that contains each of the three providers separated by a space
Then we can check that the macro variables looks as expected in our log.
*/
proc sql;
	select distinct InsuranceProvider into :distinct_prvdrs separated by " "
	from sas.demo;
quit;
%put &distinct_prvdrs.;
/*
Then we can loop over the values in this string using %scan.
First, set up the %do loop
Then define the in_provider macro - here, %scan selects the i-th word of the &distinct_prvdrs macro variable. 
See your log for how this loop is working. 
*/
%macro check_loop();
	%do i=1 %to 3;
		%let in_provider = %scan(&distinct_prvdrs., &i);
		%put &i.;
		%put &in_provider.;
	%end;
%mend;
%check_loop;
/*Now that we have verified that this loop is working as expected, let's add in the code we want to loop through.*/
/*This macro creates tables for all InsuranceProvider and ClaimType combintions with summary spending statistics by TOS */
%macro paidamt_summary_byprovider;
	%do i=1 %to 3;
		%let provider = %scan(&distinct_prvdrs., &i);
		%do next=1 %to 7;
			%let claim_type = &next.;
			proc sql;
				create table demo_hdr_lns_&provider._&claim_type. as 
				select hdr.*, 
					dm.InsuranceProvider,
					lns.TOS,
					lns.PaidAmount
				from sas.hdrs as hdr left join sas.demo as dm 
				on hdr.ID =  dm.ID
				left join sas.lns as lns
				on lns.ClaimHeaderLink = hdr.ClaimHeaderLink
				where ClaimType=&claim_type. and InsuranceProvider = "&provider.";

				create table sas.summary_lns_&provider._&claim_type. as 
				select 
					TOS, 
					count(PaidAmount) as N_claim_lns,
					mean(PaidAmount) as mean_PaidAmount, 
					min(PaidAmount) as min_PaidAmount, 
					max(PaidAmount) as max_PaidAmount
				from demo_hdr_lns_&provider._&claim_type.
				group by TOS;
			quit;
		%end;
	%end;
%mend;

%paidamt_summary_byprovider;


proc print data=sas.summary_lns_unitedhealthcare_6;
	title "Summary Spending by TOS for UnitedHealthcare Claims with Claim Type = 6";
run;
/*
Tips for Troublshooting Macros in Your Code
*/
/*See what macros resolve to in your log*/
options symbolgen ;
%let tos = 19;
proc print data=sas.lns;
	where TOS = &tos.;
run;
options nosymbolgen;

/*ALWAYS CHECK YOUR LOG*/
proc freq data=sas.hdrs;
	tables ID*ClaimType/list;
	where ClaimType in &claim_types.;
run;

/*Make your log informative*/
%let claim_types = (1,2,5);
%put &claim_types.;
proc freq data=sas.hdrs;
	tables ID*ClaimType/list nocum;
	where ClaimType in &claim_types.;
run;

