///* Data cleaning for replicating Koh and Yang (2021) *///

clear
set more off
cd ~

/* conver the raw csv to dta */
forval year = 2006/2013 {
	
  clear
	do "분기자료(1990~2016)_`year'_20210906"
	save "`year'.dta", replace
}
