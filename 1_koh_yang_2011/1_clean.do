///* Data cleaning for replicating Koh and Yang (2021) *///

clear
set more off
cd ~

	* 0. We will need to merge KHIES data with cpi data (bok_cpi_all_2000-2013.xlsx)
	* 0-1. First, prepare CPI data. load bok_cpi_all_2000-2013.xlsx and save it as .dta file. 

import excel using "bok_cpi_all_2000-2013.xlsx", firstrow clear
	
tempfile cpi
save `cpi', replace
