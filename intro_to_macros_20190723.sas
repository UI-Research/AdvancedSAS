/*update to your data location*/
libname sas "D:\Users\LDurbak\Box Sync\My Box Notes\My stuff\SAS Users Group";

/*take a look at the data*/
proc print data=sas.demo;run;
proc print data=sas.hdrs;run;
proc print data=sas.lns;run;

/*
Automatic Macro Variables
*stored in the global macro table, which are can look at in your log with %put _automatic_
*/
%put _automatic_;

/*or you can look at a single automatic macro variable*/
%put &systime.;
%put Today is &sysday.;

/*
Macro Use Case #1:
* symbolic substitution
*/
proc print data=sas.demo;
	var FirstName LastName InsuranceProvider;
	where DOB > '01jan1990'd;
	title "Providers for Beneficiaries born after 01/01/1990";
	title2 'Created &systime. &sysday., &sysdate9.';
run;
/*
Why didn't this work?
*The macro processor will try to evaluate &macro_triggers with " " but not ' ' 
*This is an important distinction you can leverage to control when a macro is resolved or not
Change the ' ' to " " in the title2 and run again
*/

/*
Macro Use Case #2:
* automated production
*/
/*
User-defined macro varaibles
*Add user-defined macro variables to the global macro table using %let
*You set the macro once, usually at the top of your program, and can reference it again and again
*/
%let high_bill_limit = 800;
%let low_bill_limit = 500-50;
%put _global_;

proc freq data=sas.hdrs;
	title "Claim Type Frequencies for High Bill Claims (over $&high_bill_limit.)";
	tables ClaimType;
	where TotalPaidAmount > &high_bill_limit.;
run;

proc freq data=sas.hdrs;
	title "Claim Type Frequencies for Low Bill Claims (under $&low_bill_limit.)";
	tables ClaimType;
	where TotalPaidAmount < &low_bill_limit.;
run;
/*
How does the title look in this second example?
*The macro processor resolves the macro - it doesn't perform any calculations/etc.!
*SAS knows to resolve the calculation in the where statement, but not in the title
*What if you want the macro to resolve the macro in the title? SAS macro functions can do this for you
*/
proc freq data=sas.hdrs;
	title "Claim Type Frequencies for Low Bill Claims (under $%eval(&low_bill_limit.))";
	tables ClaimType;
	where TotalPaidAmount < &low_bill_limit.;
run;
/*
Helpful SAS macro functions include (but are not limited to): 
%UPCASE - Translates letters from lowercase to uppercase.
%SUBSTR - Extracts a substring from a character string.
%SCAN - Extracts a word from a character string.
%INDEX - Searches a character string for specified text.
%EVAL - Performs arithmetic and logical operations.
%SYSFUNC - Executes SAS functions.
%STR - Masks special characters.
%NRSTR - Masks special characters, including macro triggers.
*/

/*
Reminder: it's good practice to delimit your macro variables with ".". It's not required but can save you a lot of headaches like:
*/
%let provider = BCBS;

proc sql;
	title "&provider Beneficiaries with Claims over the High Bill Limit ($&high_bill_limit)";
	create table summary_&provider_highbills as
	select FirstName, LastName, DOB
	from sas.demo
	where ID in (select ID from sas.hdrs where TotalPaidAmount > &high_bill_limit);

	select * 
	from summary_&provider._highbills;
	title;
quit;
/*Put a '.' after &provider in the first SQL statement and run it again*/

/*
Macro Use Case #3:
* conditional construction
*/
/*
You can make your own macro functions using the %macro - %mend call
*/
%macro monthly;
	title "Sum Paid Amount by Month";
	proc sql;
		select month(ServiceBeginDate) as Month, year(ServiceBeginDate) as Year, sum(PaidAmount) as sum_PaidAmount
		from sas.lns
		group by calculated Year, calculated Month
		order by calculated Year, calculated Month;
	quit;
	title;
%mend;
%macro yearly;
	title "Sum Paid Amount by Year";
	proc sql;
		select year(ServiceBeginDate) as Year, sum(PaidAmount) as sum_PaidAmount
		from sas.lns
		group by calculated Year
		order by calculated Year;
	quit;
	title;
%mend;
%macro reports;
	%monthly
	%if &sysday=Tuesday %then %yearly;
%mend;
%reports;

/*
A note on macro function parameters
*/
%macro unique_claims_by(provider, by_var);
	proc sql;
		title "Unique Claims by &by_var. for &provider";
		select &by_var., count(distinct ClaimHeaderLink) label="Number Unique Claims" 
		from sas.lns
		where ID in (select ID from sas.demo where InsuranceProvider = "&provider.")
		group by &by_var.;
	quit;
%mend;

%unique_claims_by(provider=&provider,by_var=TOS);
/*
Why provider=&provider? Shouldn't SAS know that &provider. within the macro function is the &provider. we already created in the global macro list?
Nope! The macro parameters are placed in a Local Symbol Table (vs. the Global Symbol Table) and can only be reference within the macro.
(You can get around this by calling the paramater prior to the macro parameter list, e.g. 
%let global_macro =;
%macro do_this(global_macro);
	~~macro function~~
%mend;
This &global macro is now available outside the macro function, e.g.:
%put &global_macro.;
*/
 
%unique_claims_by(insurance="Aetna",by_var=ServiceBeginDate);
/*Why didn't the second macro call work?*/

/*
Macro Use Case #4:
* dynamic generation of code
*/
/*
We want to get summary statistics of the payment amount for each TOS by claim type.
First, let's create working code to get the output we want for a single claim type
*/
proc sql;
		create table claim_lns_2 as
		select lns.*, hdrs.ClaimType
		from sas.lns as lns left join sas.hdrs as hdrs
		on lns.ClaimHeaderLink = hdrs.ClaimHeaderLink
		where ClaimType=2;
	quit;

	proc sql;
		create table sas.claim_lns_means_2 as 
		select 
			TOS, 
			count(PaidAmount) as N, 
			mean(PaidAmount) as mean_PaidAmount, 
			min(PaidAmount) as min_PaidAmount, 
			max(PaidAmount) as max_PaidAmount
		from claim_lns_2
		group by TOS;

		title "Summary Stats of Paid Amount for Claim Type &claim_type.";
		select *
		from sas.claim_lns_means_2;
	quit;
/*
Next, macrotize the code, adding in a loop to run over all claim types*/
proc freq data=sas.hdrs;
	tables ClaimType;
run;
%macro paidamt_summary();
	%do i=1 %to 7;
	%let claim_type = &i.;
		proc sql;
			create table claim_lns_&claim_type. as
			select lns.*, hdrs.ClaimType
			from sas.lns as lns left join sas.hdrs as hdrs
			on lns.ClaimHeaderLink = hdrs.ClaimHeaderLink
			where ClaimType=&claim_type.;
		quit;

		proc sql;
			create table sas.claim_lns_means_&claim_type. as 
			select 
				TOS, 
				count(PaidAmount) as N, 
				mean(PaidAmount) as mean_PaidAmount, 
				min(PaidAmount) as min_PaidAmount, 
				max(PaidAmount) as max_PaidAmount
			from claim_lns_&claim_type.
			group by TOS;

			title "Summary Stats of Paid Amount for Claim Type &claim_type.";
			select *
			from sas.claim_lns_means_&claim_type.;
		quit;
	%end;
%mend;

%paidamt_summary;

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

%let claim_types = (1,2,5);
proc freq data=sas.hdrs;
	tables ID*ClaimType/list nocum;
	where ClaimType in &claim_types.;
run;

