/*****************************************************************
Project:     Intro to proc sql Brownbag
Program:     intro_to_procsql.sas
Programmer:  Leah Durbak, ldurbak@urban.org
Date:        04/23/2018
Note:        
*****************************************************************/ 

proc contents data=sashelp.class;
run;

/****************************/
/*simple proc sql statements*/
/****************************/
proc sql;
	title "proc sql results";
	select *
	from sashelp.class;
quit;
/*non sql equiv*/
proc print data=sashelp.class;
run;

proc sql;
	select monotonic() as Obs, Name, Height
	from sashelp.class;
quit;
/*non sql equiv*/
proc print data=sashelp.class;
	var Name Height;
run;

/***********************/
/*create a new variable*/
/***********************/
proc sql;
	select Name, Height, (Height*2.54) as Height_cm
	from sashelp.class;
quit;
/*non sql equiv*/
data class;
	set sashelp.class (keep = Name Height);
	Height_cm = Height*2.54;
run;
proc print data=class;
run;

/********************/
/*create a new table*/
/********************/
proc sql outobs=5;
	create table heightcm_meanage_sql as
	select Name, (Height*2.54) as Height_cm, mean(Age) as mean_Age
	from sashelp.class;

	select *
	from heightcm_meanage_sql;
quit;
/*non sql equiv*/
proc means data=sashelp.class;
	var Age;
	output out = class_stats mean = mean_Age;
run;
data heightcm_meanage (keep = Name Height_cm mean_Age);
	if _n_ = 1 then set class_stats (keep = mean_Age);
	set sashelp.class;
	Height_cm = Height*2.54;
run;
proc print data=heightcm_meanage (obs=5);
run;

/*************************/
/*filter data using where*/
/*************************/
proc sql;
	select Name, Sex, Age
	from sashelp.class
	where Height > 60;
quit;
/*non sql equiv*/
proc print data=sashelp.class;
	var Name Sex Age;
	where Height > 60;
run;

/*where can't access calculated variables...unless you tell it!*/
proc sql;
	select *, (Height*2.54) as Height_cm
	from sashelp.class
	where (Height*2.54) <= 155;
quit;
proc sql;
	select *, (Height*2.54) as Height_cm
	from sashelp.class
	where calculated Height_cm <= 155; /*keep in mind this 'calculated' means the query can't be done on the SQL side - this processing will be brought back to SAS*/
quit;
/*non sql equiv*/
data filtered;
	set sashelp.class;
	Height_cm = Height*2.54;
run;
proc print data=filter;
	var Name Sex Age Height_cm;
	where Height_cm <= 155;
run;

/*filter on multiple conditions in where statement*/
proc sql;
	select Name, Age, (Height*2.54) as Height_cm
	from sashelp.class
	where Name in ('Alice','James') or Age > 14;
quit;
/*non sql equiv*/
data filter;
	set sashelp.class;
	Height_cm = Height*2.54;
run;
proc print data=filter;
	var Name Age Height_cm;
	where Name in ('Alice','James') or Age > 14;
run;

/*filter with a subquery*/
data roster;
	input Person $;
	datalines;
	Tiffany 
	Tiffany 
	Barbara
	Henry 
	Carol
	Jane 
	Tiffany 
	Ronald 
	Thomas
	William
	William
	Henry 
	Carol
	Carol
	Ronald 
	Thomas
;

proc sql;
	select *
	from sashelp.class
	where Name in 
		(select distinct Person
		from roster);
quit;
/*non sql equiv*/
data sashelp_class ;
	set sashelp.class;
run;
proc sort data=sashelp_class (rename=(Name=Person));
	by Person;
run;
proc sort data=roster nodupkey;
	by Person;
run;
data merge_subquery;
	merge sashelp_class (in=insashelpclass) roster(in=inroster);
	by Person;
	if insashelpclass and inroster;
run;
proc print data=merge_subquery;run;

/**************/
/*use group by*/
/**************/
proc sql;
	select Name, mean(Height) as mean_Height_Sex
	from sashelp.class
	group by Sex;
quit;
/*non sql equiv*/
proc means data=sashelp.class mean noprint;
	class Sex;
	var Height;
	output out = height_mean (drop = _TYPE_ _FREQ_) mean=mean_Height;
run;
data mean_by_Sex_f;
	if  _n_ = 1 then set height_mean (keep = Sex mean_Height);
	where Sex = 'F';
	set class;
	where Sex = 'F';
run;
data mean_by_Sex_m;
	if  _n_ = 1 then set height_mean (keep = Sex mean_Height);
	where Sex = 'M';
	set class;
	where Sex = 'M';
run;
data mean_height_by_sex (keep = Name mean_Height_Sex);
	set mean_by_Sex_m (rename=(mean_Height = mean_Height_Sex)) 
		mean_By_Sex_f (rename=(mean_Height = mean_Height_Sex)) ;
run;
proc print data=mean_height_by_sex;
run;

/*group by and having vs. where and group by*/
proc sql;
	select *, mean(Height) as mean_Height_Sex
	from sashelp.class
	group by Sex
		having Height < 61;
quit;

proc sql;
	select *, mean(Height) as mean_Height_Sex
	from sashelp.class
	where Height < 61
	group by Sex;
quit;

/********************/
/*more complex query*/
/********************/
proc sql;
	select count(Name) as num_Obs, 
		count(distinct Name) as unique_Obs, 
		mean(Age), median(Height) as median_Height, 
		std(Weight) AS stdev_Weight,
		(select count(distinct Name)
			from sashelp.class
			where Sex = "F") as num_Female
	from sashelp.class;
quit;

/**********/
/*order by*/
/**********/
proc sql;
	title greater than 13;
	select *
	from sashelp.class
	where Age > 13
	order by Height;

	title 13 or under;
	select *
	from sashelp.class
	where Age <= 13
	order by Height desc;
quit;
/*non sql equiv*/
proc sort data=sashelp.class out=class_to_sort;
	by Height;
	where Age > 13;
run;
proc print data=class_to_sort;
	title "greater than 13";
run;
proc sort data=sashelp.class out=class_to_sort_desc;
	by descending Height;
	where Age <= 13;
run;
proc print data=class_to_sort_desc;
	title "13 or under";
run;

/*******/
/*joins*/
/*******/
data score;
	input Person $ Score;
	datalines;
	Tiffany 85
	Alfred 85
	Alice 80
	Barbara 95
	Henry 90
	Carol 50
	Jane 60
	James 75
	Janet 70
	Jeffrey 60
	John 45
	Joyce 90
	Judy 75
	Louise 95
	Robert 65
	Ronald 95
	Thomas 85
	William 70
;

/************/
/*Inner join*/
/************/
proc sql;
	select a.Name,a.Age, b.Score
	from sashelp.class as a inner join score as b
	on a.Name = b.Person;
quit;
proc sql;
	select *
	from sashelp.class, class_score
	where Name = Person;
quit;

/*non sql equiv*/
data inner_join (keep = Name Age Score);
	merge sashelp_class (in=insashelp) score_sorted (in = inclassscore);
	by Name;
	if insashelp and inclassscore;
run;
proc print data=inner_join;
run;

/*************/
/*Outer joins*/
/*************/
/***********/
/*Full join*/
/***********/
proc sql;
	select a.Name, a.Age,b.*
	from sashelp.class a full join score b
	on a.Name = b.Person;
quit;
/*non sql equiv*/
proc sort data=score (rename=(Person=Name)) out=score_sorted;
	by Name;
run;
proc sort data=sashelp.class out=sashelp_class;
	by Name;
run;	
data full_outer_join (keep = Name Age Score);
	merge sashelp_class score_sorted;
	by Name;
run;
proc print data=full_outer_join;
run;

/*******************/
/*Outer join - left*/
/*******************/
proc sql;
	select a.Name, a.Age,b.*
	from sashelp.class a left join score b
	on a.Name = b.Person;
quit;
/*non sql equiv*/
data left_merge (keep = Name Age Score);
	merge sashelp_class (in=insashelp) score_sorted (in = inclassscore);
	by Name;
	if insashelp;
run;
proc print data=left_merge;
run;

/************************/
/*Outer join - right sql*/
/************************/
proc sql;
	select a.Name, a.Age, b.*
	from sashelp.class a right join score b
	on a.Name = b.Person;
quit;
/*non sql equiv*/
data right_merge;
	merge sashelp_class (in=insashelp) class_score (in = inclassscore);
	by Name;
	if inclassscore;
run;
proc print data=right_merge;
run;

/*********************************/
/*Join as many tables as you want*/
/*********************************/
proc sql; /*This is an example of creating a new data set using proc sql...as you can see it may be more efficient to use DATALINES instead*/
	create table assign_fruit(Age num, Fruit char);
	insert into assign_fruit
		values (11, "Apples")
		values(12, "Pears")
		values(13, "Oranges")
		values(14, "Bananas")
		values(15, "Kiwis");

	select *
	from assign_fruit;
quit;

proc sql;
	select a.Name, a.Age, b.Score, c.Fruit
	from sashelp_class a, score b, assign_fruit c
	where a.Name = b.Person and
		a.Age = c.Age;
quit;

/***************/
/*set operators*/
/***************/
data testa;
	infile datalines delimiter=','; 
	input Name $ DateA  mmddyy10.;
	format DateA mmddyy10. ;
	datalines;
Alfred,4/10/2019
Barbara,4/10/2019
Carol,4/10/2019
Henry,4/10/2019
James,4/10/2019
Jane,4/10/2019
Janet,4/10/2019
Jeffrey,4/10/2019
Joyce,4/10/2019
Judy,4/10/2019
Louise,4/10/2019
Mary,4/10/2019
Philip,4/10/2019
Robert,4/10/2019
Ronald,4/10/2019
William,4/10/2019
;
data testb;
	infile datalines delimiter=','; 
	input Name $ Score $ Date mmddyy10.;
	format Date mmddyy10. ;
	datalines;
Alfred,A,5/10/2019
Alice,A,5/10/2019
Carol,C,5/10/2019
Jane,B,5/10/2019
John,C,5/10/2019
Judy,A,5/10/2019
Louise,B,5/10/2019
Mary,A,5/10/2019
Robert,A,5/10/2019
Ronald,B,5/10/2019
William,C,5/10/2019
Robert, ,4/10/2019
Ronald, ,4/10/2019
William, ,4/10/2019
;

/*union*/
proc sql;
	select * 
	from testa
	union 
	select Name, Date
	from testb;
quit;

/*union corr*/
proc sql;
	select * 
	from testa
	union corr
	select *
	from testb (rename=(Date=DateA));
quit;

/*outer union*/
proc sql;
	select * 
	from testa
	outer union 
	select *
	from testb;
quit;

/*outer union corr*/
proc sql;
	select * 
	from testa
	outer union corr
	select *
	from testb(rename=(Date=DateA));
quit;

/*except*/
proc sql;
	select * 
	from testa
	except
	select Name, Date
	from testb;
quit;

/*except corr*/
proc sql;
	select * 
	from testa
	except corr
	select *
	from testb(rename=(Date=DateA));
quit;

/*intersect*/
proc sql;
	select * 
	from testa
	intersect
	select Name, Date
	from testb;
quit;

/*intersect corr*/
proc sql;
	select * 
	from testa
	intersect corr
	select *
	from testb(rename=(Date=DateA));
quit;

/********************/
/*other useful stuff*/
/********************/
/*count and distinct*/
data class;
	set sashelp.class sashelp.class;
run;
proc sql;
	select count(*) as count_all
	from class;
	
	/*get distinct values of a variable*/
	select distinct age as dist_ages
	from class;
	
	/*get distinct values of a combination of variables*/
	select distinct age, Name, Height
	from class;

	select count(age) as age_count, Name, Height
	from class;
	
	/*count unique records*/
	select count(*) as num_unique_recs
	from (select distinct * from class);
quit;
/*create table like*/
proc sql;
	create table new_class like sashelp.class;
	
	insert into new_class
	select * 
	from sashelp.class
	where Age > 12;

	alter table new_class
	add rownum num;

	select *
	from new_class;
quit;

proc sql;
	update new_class
	set rownum = monotonic();

	select *
	from new_class;
quit;

/*coalesce*/
proc sql; /*create a table with sparsely populated year_of_birth variable*/
	create table class_birthyear_under13 as
	select *,case 
		when Age < 13 then intnx('year',today(),-Age)
		end as year_of_birth format year4.
	from sashelp.class;

	select *
	from class_birthyear_under13;
quit;

proc sql; /*create a table with sparsely populated year_of_birth variable*/
	create table class_birthyear_14over as
	select *,case 
		when Age >= 14 then intnx('year',today(),-Age)
		when Age = 12 then intnx('year',"01jan2017"d,-Age)
		when Age = 11 then intnx('year',today(),-Age)
		end as year_of_birth format year4.
	from sashelp.class;

	select *
	from class_birthyear_14over;
quit;

proc sql;/*coalesce both sparsely populated year_of_birth variables*/
	select a.Name, a.Age, a.year_of_birth, b.year_of_birth, coalesce(a.year_of_birth,b.year_of_birth) as all_year_of_birth format year4.
	from class_birthyear_under13 a, class_birthyear_14over b
	where a.Name = b.Name;
quit;

proc sql; /*create a table with sparsely populated x1 variables where some observations have data in both columns*/
	create table class_birthyear_mixed as
	select *,case 
		when Age < 13 then intnx('year',today(),-Age)
		end as x1 format year4.,
		case 
		when Age >= 14 then intnx('year',today(),-Age)
		end as x2 format year4.
	from sashelp.class;
quit;

proc sql;
	select *, coalesce(x1,x2) as year_of_birth format year4.
	from class_birthyear_mixed;
quit;

