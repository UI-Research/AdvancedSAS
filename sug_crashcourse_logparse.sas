/*look at data*/
proc contents data=sashelp.cars;run;

proc sql outobs=5;
	select * from sashelp.cars;
quit;

/*proc printto example*/
proc printto print="Documents\logparse_listing.lst"
	         log="Documents\logparse.log" NEW;
run;
proc freq data=sashelp.cars;
	table Cylinders;
run;
proc printto;run;

/*produce error message*/
proc print data=sashelp.cars;
	var mpg Cylinders;
run;

/*produce warning message*/
dat cars;
	set sashelp.cars;
run;

/*use PUT statement to generate custom WARNING: message*/
data shoes;   
	set sashelp.shoes;   
	by region subsidiary product;   
	if first.product and not last.product then put 'WARNING: Multiple products in ' subsidiary / product=; 
run;
