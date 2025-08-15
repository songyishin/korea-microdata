///* Data cleaning for replicating Koh and Yang (2021) *///

clear
set more off
cd ~

* 0. We will need to merge KHIES data with cpi data (bok_cpi_all_2000-2013.xlsx)
* 0-1. First, prepare CPI data. load bok_cpi_all_2000-2013.xlsx and save it as .dta file. 

import excel using "bok_cpi_all_2000-2013.xlsx", firstrow clear
	
tempfile cpi
save `cpi', replace

*1. load each of 2006-2013 khies data and append them all years of 2006-2013. Then save it as khies2006-2013.dta
	
forval year = 2006/2013 {
	
	clear
	
	* run do from MDIS to convert raw csv to dta

	if `year'<=2010 {
		run "`year'_분기자료(1990~2016)_20240212_52373.do"
	}
	else {
		run "`year'_분기자료(1990~2016)_20240212_23016.do"
	}
	
	* run do for eng label 
	
	if `year'<=2011 {
		do "khies_eng_2006-2011.do"
	}
	else {
		do "khies_eng_2012-2013.do"
	}
	
	* rename variables to those you memorize easily
	* Caution: As we know, we will have the inconsistency of variable names across years. 
	* khies_renamevars.do must be run after making variable names such as v1-v259 consistent across all years.  

	if `year'<=2011 {
					
		forval n = 257(-1)114 {
			local m = `n' + 2
			rename v`n' v`m'
		}
	}
	
	do "khies_renamevars.do"
	
	drop v*
	
	tostring _all, replace /* tostring, not destring */

	tempfile clean_`year'
	save `clean_`year'', replace
}


clear
gen temp = .

forval year = 2006/2013 {
	
	append using `clean_`year''
}

drop temp

destring _all, replace

save khies2006-2013.dta, replace


*2. open khies2006-2013.dta and Merge khies data with cpi data. 
	
use khies2006-2013.dta, clear

merge m:1 year using `cpi'
drop if _merge!=3
drop _merge


*3. restricting the sample
	* the elderly group as households with any members between the ages of 65 and 84 years
	* (household containing at least one person aged between 65 and 84)
	* the nonelderly group as households in which the age of the eldest person was between 45 and 64 years 
	
egen maxage = rowmax(hm1_age hm2_age hm3_age hm4_age hm5_age hm6_age hm7_age hm8_age ) 

	* over65 
gen over65 = (maxage >=65 & maxage <=84)
	
	* sample (teatment group + control group)
gen sam4584 = (maxage>=45 & maxage<=84)
gen sam5574 = (maxage>=55 & maxage<=74)
	
tab over65 sam4584, mi
tab over65 sam5574, mi
	
	* post
gen post = (year>=2009)
	
tab year post, mi

	* time variable: year-quarter: quarter is expressed as 14 24 34 44  
gen yq = yq(year, int(quarter/10)) , after(quarter)
format yq %tq 


*4. generate key variables: 
	
	*4-1 inc_prvtrinc = inc-prvtrinc 
gen inc_prvtrinc = inc - prvtrinc 
label var inc_prvtrinc "inc-prvtrinc"

	*4-2 convert monetary variables to thousand 2010 KRW 	
foreach x in inc prvtrinc boapinc inc_prvtrinc {
		
	local lbl: variable label `x'
	
	replace `x' = `x'/1000 
	label var `x' "`lbl' thousand KRW" 
	
	gen r`x' = `x'*(100/cpi)
	label var r`x' "`lbl' thousand 2010 KRW" 
}
	
	*4-3 convert hm's edu and edustat to education attainment: hm`i'_eduatt and assign label for each value 
	* 0 "less than hsg" 1 "hsg" 2 "some college grad" 3 "college grad." 4 "master+"	
label define eduatt_lbl 0 "less than hsg" 1 "hsg" 2 "some college grad" 3 "college grad." 4 "master+"
		
forval i=1/8 {
	gen hm`i'_eduatt = . , after(hm`i'_edustat)
	
	replace hm`i'_eduatt = 0 if hm`i'_edu <=2 | ///
								(hm`i'_edu==3 & hm`i'_edustat~=1 ) ///
								
								
	replace hm`i'_eduatt = 1 if (hm`i'_edu==3 & hm`i'_edustat==1 ) | ///
								((hm`i'_edu==4 | hm`i'_edu==5) & hm`i'_edustat==3) ///
								
	replace hm`i'_eduatt = 2 if (hm`i'_edu==4 | hm`i'_edu==5) & (hm`i'_edustat==2 | hm`i'_edustat==4)
	
	replace hm`i'_eduatt = 3 if ((hm`i'_edu==4 | hm`i'_edu==5) & hm`i'_edustat==1 ) | ///
								(hm`i'_edu>5 & hm`i'_edustat!=1)
								
	replace hm`i'_eduatt = 4 if hm`i'_edu>5 & hm`i'_edustat==1 
	
	
	replace hm`i'_eduatt = . if hm`i'_edu==. | hm`i'_edustat==.
	
	label value hm`i'_eduatt eduatt_lbl 
}
	
	*4-4 indicator for hm's highschool graduation: hm`i'_hsg 	
forval i = 1/8 {	
	
	gen hm`i'_hsg = (hm`i'_eduatt >=1) if hm`i'_eduatt != . , after(hm`i'_eduatt)
	
	label var hm`i'_hsg "hm`i''s education is at least hsg'"
}

*5 information on the eldest hm's highschool graduation and the relationship to household head.

	*5-1 checking the number of eldest household members(there may be several hm with the same age)		
	
gen eldest_num=0

label var eldest_num "number of the eldest people in a household"

forval i = 1/8 {
	
	replace eldest_num = eldest_num+1 if maxage ==hm`i'_age
}
				
	*5-2 making vars of eldest member's info.
		
sum eldest_num
local eldestmax = r(max)

forval j = 1/`eldestmax' {
	
	gen eldest`j'_hmn =.
	gen eldest`j'_rel =.
	gen eldest`j'_sex =.
	gen eldest`j'_hsg =.
	gen eldest`j'_Iemp =.
}
		
	*5-3 identify household member number of the eldest person in a household 
	*for example, hm1 and hm3 are in the same age and they are oldest, then eldest1_hmn = 1 and eldest2_hmn = 3 	
	
forval i = 1/8 {
	replace eldest1_hmn = `i' if eldest1_hmn==. & maxage==hm`i'_age
}
	
forval j = 2/`eldestmax' {
	
	local k = `j'-1	
	
	forval i = 1/8 {	
		replace eldest`j'_hmn = `i'  if eldest`j'_hmn==. & maxage==hm`i'_age & ///
										eldest`k'_hmn < `i'
	}
}
	
	*5-4 extracts the information on the eldest person. 
forval i = 1/8 {
forval j = 1/3 {
	
		replace eldest`j'_rel = hm`i'_rel if `i'==eldest`j'_hmn
		replace eldest`j'_sex = hm`i'_sex if `i'==eldest`j'_hmn
		replace eldest`j'_hsg = hm`i'_hsg if `i'==eldest`j'_hmn
		replace eldest`j'_Iemp = hm`i'_Iemp if `i'==eldest`j'_hmn
	}
}

*6 Additional information 

	*SES: a dummy taking 1 if eldest person's education attainment is less than hsg

egen eldest_nohs = rowmax(eldest*_hsg)
recode eldest_nohs (0=1) (1=0)
label var eldest_nohs "eldest person's education attainment is less than hsg'"
		
	*SES: a dummy taking 1 if no cars owned by the household

gen nocar = (ncar==0) if ncar!=.
label var nocar "1 if no cars owned by the household"
		
	*X: hh's education, marital status(1 if has a spouse), gender(1 if hm1 is male), number of cars, home ownership(1 if living in an own house) 
		
gen hm1_mar = ( spouse == 1 | spouse ==2 ) if spouse!=.
label var hm1_mar "hm1 has a spouse"

gen Iownhome = (ownhome==1) if ownhome!=.
label var Iownhome "1 if living in an own house"

*7. coresidence with adult child and grand children. 
			*hm*_rel: 
			*2 spouse of hh, 
			*3 unmarried child of hh 
			*4 married child of hh and one's spouse, 
			*5 grand child of hh and one's spouse,   
			*6 parent of hh, parent of spouse of hh 
			*7 grand parent 
			*8 siblings of hh and one's spouse 
			*9 other 
	*7-1 cores1 : 1 if living with a child		
	*7-2 cores2 : 1 if living with a grand child
		* Case 1: household head is the eldest person 
			* living with a child: eldest`j'_rel==1 & (hm`i'_rel==3 | hm`i'_rel==4) 
			* living with a grand child: eldest`j'_rel==1 & (hm`i'_rel==5)
		* Case 2: the eldest person is a parent of hh, or spouse of hh. 
			* living with a child: eldest`j'_rel==6 & (hm`i'_rel==1 | hm`i'_rel==2)
			* living with a grand child: eldest`j'_rel==6 & (hm`i'_rel==3 | hm`i'_rel==4) 
		* Case 3: the eldest person is a grand parent of hh, or spouse of hh. 
			* living with a grand child: eldest`j'_rel==7 & (hm`i'_rel==1 | hm`i'_rel==2 )

		gen cores1 =0
		label var cores1 "1 if living with a child"
		
		gen cores2 =0
		label var cores2 "1 if living with a grand child"

		forval j = 1/`eldestmax' {
			forval i = 1/8 {
				
				replace cores1 = 1 if eldest`j'_rel==1 & (hm`i'_rel==3 | hm`i'_rel==4) 
				replace cores1 = 1 if eldest`j'_rel==6 & (hm`i'_rel==1 | hm`i'_rel==2) 
				
				replace cores2 = 1 if eldest`j'_rel==1 & (hm`i'_rel==5) 
				replace cores2 = 1 if eldest`j'_rel==6 & (hm`i'_rel==3 | hm`i'_rel==4 ) 
				replace cores2 = 1 if eldest`j'_rel==7 & (hm`i'_rel==1 | hm`i'_rel==2 )  

			}
		}
