/*update to your data location*/
libname sas "D:\Users\LDurbak\Box Sync\My Box Notes\My stuff\SAS Users Group";

/*take a look at the data*/
proc print data=sas.demo;
	title "Demographic table";
run;
proc print data=sas.hdrs;
	title "Claim Headers";
run;
proc print data=sas.lns;
	title "Claim Lines";
run;

/*
Automatic Macro Variables
SAS includes a number of automatic macro variables that provide information about your SAS session
* includes the date/time you opened the SAS session, which can be used for dating reports
* %put _automatic_ shows you all automatic macros available in your log
*/
%put _automatic_;

/*Or you can look at a single automatic macro variable*/
%put &systime.;
%put Today is &sysday.;

/* Advanced topic - optional: Do you need a dynamic date/time? You can use the date()/time() functions in SAS - we can look at them in our log using the syntax below*/
%put %sysfunc(date(),date9.);
%put %sysfunc(time(),tod8.);
/*
Example #1: Using automatic macro variables
Create a dated report without having to change the date/time every day.
*/
/*First write the code without macros*/
proc print data=sas.demo;
	title "Providers for Beneficiaries born after 01/01/1990";
	title2 "Created 10:30 Wednesday, 24JUL2019";
	var FirstName LastName InsuranceProvider;
	where DOB > '01jan1990'd;
run;
/*Next, add macros to the variables you need to be dynamic*/
proc print data=sas.demo;
	title "Providers for Beneficiaries born after 01/01/1990";
	title2 'Created &systime. &sysday., &sysdate9.';
	var FirstName LastName InsuranceProvider;
	where DOB > '01jan1990'd;
run;
/*
Why didn't this work?
*The macro processor will try to evaluate &macro_triggers within " " but not ' ' 
*This is an important distinction you can leverage to control when a macro is resolved or not
Change the ' ' to " " in the title2 and run again
*/

/*
Example #2: Creating and using user-defined macro variables
User-defined macros:
* You can create your own macro variables using %let
* Once you set a macro in your SAS session, it is available for use
* If will not be stored in SAS - you will have to create it each time you open a new SAS session

Say you frequently print out frequencies of ClaimType for claims with a TotalPaidAmount over a certain dollar amount as well as under a certain amount. 
However, these dollar limits change every few months. 
Instead of changing those dollar amounts everywhere they appear in your code, you can replace them with a user-defined macro that you will need to change only once.
*/
/*First write the code without macros*/
proc freq data=sas.hdrs;
	title "Claim Type Frequencies for High Bill Claims (over $800)";
	tables ClaimType;
	where TotalPaidAmount > 800;
run;

proc freq data=sas.hdrs;
	title "Claim Type Frequencies for Low Bill Claims (under $450)";
	tables ClaimType;
	where TotalPaidAmount < 450;
run;

/*Next, add macros to the variables you need to be dynamic*/
/*Create your user-defined macros*/
%let high_bill_limit = 800;
%let low_bill_limit = 500-50;
/*See your macros in the log*/
%put _global_;

/*Replace your hard-coded values with the applicable &macro-trigger*/
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
*It does not look as we want it to because the macro processor merely resolves the macro to text and passes it to the compiler - it doesn't perform any calculations/etc.!
*SAS knows to resolve the calculation in the where statement, but not in the title
**Advanced topic - optional: what if you want the macro to resolve the macro in the title? SAS macro functions can do this for you
*/
proc freq data=sas.hdrs;
	title "Claim Type Frequencies for Low Bill Claims (under $%eval(&low_bill_limit.))";
	tables ClaimType*TotalPaidAmount/list;
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
**
*/

/*
Reminder: it's good practice to delimit your macro variables with ".". It's not required but can save you a lot of headaches like:
Let's create a data set with the demographic and claim header data for BCBS beneficiaries with claims over the high bill limit we set previously.
*/
proc sort data=sas.demo;
	by ID;
run;
proc sort data=sas.hdrs;
	by ID;
run;

data BCBS_highbills;
	merge sas.demo (in=indemo where=(InsuranceProvider="BCBS")) 
		sas.hdrs (in = inhdrs where=(TotalPaidAmount > &high_bill_limit.));
	by ID;
	if indemo and inhdrs;
	if TotalPaidAmount = . then delete;
run;

proc print data=BCBS_highbills;
	title "BCBS Beneficiaries with Total Paid Amount Claims over $&high_bill_limit.";
run;

/*
Say you want to create this print out for another provider, Aetna
Start with defining your user-defined macro.
*/
%let provider = Aetna;

data &provider_highbills;
	merge sas.demo (in=indemo where=(InsuranceProvider="&provider")) 
		sas.hdrs (in=inhdrs where=(TotalPaidAmount > &high_bill_limit.));
	by ID;
	if indemo and inhdrs;
	if TotalPaidAmount = . then delete;
run;
/*
Check your log - what happened?
SAS tried to find the macro provider_highbills in the global symbol table, but of course it is not there as we did not create a macro by that name!
You can explicitly tell SAS where your macro variable name ends  with a '.'
It is good practice to always delimit your macro variables in your code with a '.', although in many situations it is optional.
Put a '.' after &provider in data step and run it again
*/

proc print data=&provider._highbills;
	title "&provider. Beneficiaries with Total Paid Amount Claims over $&high_bill_limit.";
run;

/*
Example #3: Macro functions
Macro functions can make running the same block of code much easier.
You can create a macro function to call the same code over and over, with parameters or arguments that you can change
Since we already have this working code to get the claims from specific providers over a certain dollar limit, let's make that a macro function.
Start building your macro function with:
%macro macro-function-name(argument1, argument2, argumentN);
*/

/*This macro creates a dataset of the claims over a dollar limit (high_bill_limit) for a certain insurance provider (provider)*/
%macro provider_highbill_claims(provider, high_bill_limit);
	data &provider._highbills;
		merge sas.demo (in=indemo where=(InsuranceProvider="&provider")) 
			sas.hdrs (in=inhdrs where=(TotalPaidAmount > &high_bill_limit.));
		by ID;
		if indemo and inhdrs;
		if TotalPaidAmount = . then delete;
	run;

	proc print data=&provider._highbills;
		title "&provider. Beneficiaries with Total Paid Amount Claims over $&high_bill_limit.";
	run;	
	title;
%mend; 
/*You may see %mend(provider_highbill_claims); or %mend provider_highbill_claims; in others' code. All are valid*/
/*Since we already defined &provider and &high_bill_limit, can we just call:*/
%provider_highbill_claims;
/*
Nope!
The macro parameters are placed in a Local Symbol Table (vs. the Global Symbol Table) and can only be reference within the macro. They are local to the macro function only.

Advanced topic - optional: You can get around this by calling the paramater prior to the macro parameter list, e.g. 
%let global_macro =;
%macro do_this(global_macro);
	~~macro function~~
%mend;
This &global macro is now available outside the macro function, e.g.:
%put &global_macro.;
*/

%provider_highbill_claims(provider=UnitedHealthcare, high_bill_limit=800);

**Advanced topic - optional: you can point macro function parameters to macro variables. Macro variables just resolve to text!;
%let provider=UnitedHealthcare;
%let high_bill_limit=1000;
%provider_highbill_claims(provider=&provider, high_bill_limit=&high_bill_limit);

/*
Example #4: Automate macro functions with %do loops
We can make the high bill claims by provider print outs for every provider, not just one at a time using %do loops
*/
proc freq data=sas.demo;
	tables InsuranceProvider;
run;

/*Sneak peak of the next SUG session, Coming SAS Macros and PROC SQL:
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
/*This macro creates 3 datasets of the claims over a dollar limit (high_bill_limit) for a each insurance provider (provider) in the sas.demo table */
%macro provider_highbill_claims_loop;
	%do i=1 %to 3;
		%let provider = %scan(&distinct_prvdrs., &i);
		data &provider._highbills;
			merge sas.demo (in=indemo where=(InsuranceProvider="&provider")) 
				sas.hdrs (in=inhdrs where=(TotalPaidAmount > &high_bill_limit.));
			by ID;
			if indemo and inhdrs;
			if TotalPaidAmount = . then delete;
		run;

		proc print data=&provider._highbills;
			title "&provider. Beneficiaries with Total Paid Amount Claims over $&high_bill_limit.";
		run;	
		title;
	%end;
%mend;
%provider_highbill_claims_loop;

/*
Tips for Troublshooting Macros in Your Code
*/
/*Options to help you troubleshoot your macros*/
options symbolgen ;
%provider_highbill_claims_loop;
options nosymbolgen;

options mprint;
%provider_highbill_claims_loop;
options nomprint;

options mlogic;
%provider_highbill_claims_loop;
options nomlogic;

/*ALWAYS CHECK YOUR LOG*/
%let claim_types = (1 2 5);
data limited_claimtypes;
	set sas.hdrs;
	where ClaimType in &claim_types.;
run;

proc print data=limited_claimtypes;
	title "Limited Claim Types";
run;
title;

%let claim_types = (1 5);
data limited_claimtypes;
	set sas.hdrs;
	where ClaimType in &claim_type.;
run;

proc print data=limited_claimtypes;
	title "Limited Claim Types";
run;
title;

/*
General Documentation Best Practices
*Always name your macros descriptively. 
Writing out "macro_a" may take less effort than writing "provider_highbill_claims_loop", but ambiguous naming will make your code prone to erros, as well as difficult to update and maintain
*Provide a short description at the top of a macro about what the macro does and what the parameter inputs should be
*/
