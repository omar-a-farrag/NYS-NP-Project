cd "~/Dropbox/Overprescription/HCAHP"

********************************************************************
* 				Basic hospital characteristics
********************************************************************

foreach y of numlist 2008/2011 {
	use "hcahps`y'/dbo_vwHQI_HOSP.dta", clear
	rename *, lower
	rename *_* **
	rename (address1 countyname hospitalown emergencyservice) (address county hospitalownership emergencyservices)
	keep providernumber hospitalname address city state zipcode county hospitaltype hospitalownership emergencyservices
	drop if hospitaltype=="Acute Care - VA Medical Center" | hospitaltype== "ACUTE CARE - VETERANS ADMINISTRATION"
	destring providernumber, replace ignore(')
	des
	save "general`y'", replace
	}

foreach y of numlist 2012/2013 {
	import delimited using "hcahps`y'/Hospital_Data.csv", clear
	rename (address1) (address)
	keep providernumber hospitalname address city state zipcode county hospitaltype hospitalownership emergencyservices
	drop if hospitaltype=="ACUTE CARE - VETERANS ADMINISTRATION"
	destring providernumber, replace
	tostring zipcode, replace
	des
	save "general`y'", replace
	}

foreach y of numlist 2014/2015 {
	import delimited using "hcahps`y'/Hospital General Information.csv", clear
	rename (providerid countyname) (providernumber county)
	keep providernumber hospitalname address city state zipcode county hospitaltype hospitalownership emergencyservices
	drop if hospitaltype=="ACUTE CARE - VETERANS ADMINISTRATION"
	destring providernumber, replace
	tostring zipcode, replace
	des
	save "general`y'", replace
	}
	
foreach y of numlist 2016/2018 {
	import delimited using "hcahps`y'/Hospital General Information.csv", clear
	rename (providerid hospitaloverallrating hospitaloverallratingfootnote patientexperiencenationalcompari v22 countyname) (providernumber hrating hrating_missing patexp_compare patexp_missing county)
	keep providernumber hospitalname address city state zipcode county hospitaltype hospitalownership emergencyservices hrating* patexp*
	tostring zipcode, replace
	des
	save "general`y'", replace
	}
	
	
		***	Combining files
	
use "general2008.dta", clear
gen datayear=2008
foreach y of numlist 2009/2018 {
	append using "general`y'"
	replace datayear=`y' if datayear==.
}
label var datayear "Year of data"
label var address "Hospital address"
label var city "Hospital city"
label var state "Hospital state"
label var county "Hospital county"
rename providernumber provider_id
order datayear 

// Emergency service
gen emergencyserv=(emergencyservices=="Yes")
label var emergencyserv "Hospital has emergency service"
drop emergencyservices
order emergencyserv, after(hospitalownership)

sort provider_id datayear
save "hcahps_general_combined.dta", replace

note: information from this file is stored in "Crosswalks/Concordance provider_id and ahaid.xlsx" -> it will not be used any further

STOP HERE

		*** Check
		
use "hcahps_general_combined.dta", clear
keep if state=="NY"
gen provider_id0=provider_id
merge 1:1 provider_id0 datayear using hvbp_combined.dta
tab datayear _m
order datayear paymyear
* paymyear=datayear+1=survyear+2
/*
tab paymyear _m

  Year of |         merge
      data | Master on  Matched ( |     Total
-----------+----------------------+----------
      2008 |       194          0 |       194 
      2009 |       181          0 |       181 
      2010 |       182          0 |       182 
      2011 |       179          0 |       179 
      2012 |        24        153 |       177 
      2013 |        26        148 |       174 
      2014 |        26        147 |       173 
      2015 |        29        141 |       170 
      2016 |        32        142 |       174 
      2017 |        31        140 |       171 
      2018 |        35        135 |       170 
-----------+----------------------+----------
     Total |       939      1,006 |     1,945 

	 ed datayear hospitalname hospitaltype hrating hrating_missing patexp_compare patexp_missing hcahps_base hcahps_consistency if datayear==2016 & hcahps_base==.
	 * missing HVBP score: critical access hospitals, children hospital, 8 hospitals with missing rating due to small N of responses or not participating in IQR or OQR programs, and also for 5 hospitals for unknown reason

	 ed datayear hospitalname hospitaltype hrating hrating_missing patexp_compare patexp_missing hcahps_base hcahps_consistency if datayear==2017 & hcahps_base==.
	 * missing HVBP score: critical access hospitals, children hospital, 8 hospitals with missing rating due to small N of responses or not participating in IQR or OQR programs, and also for 4 hosptals for unknown reason

	 */

	 
/*

*** More recent files (not used in this research)

foreach y of numlist 2019 {
	import delimited using "hospitals_10_`y'/Hospital General Information.csv", clear
	keep facilityid facilityname state zipcode countyname hospitaltype hospitalownership emergencyservices
	des
	tostring facilityid, replace
	replace facilityid="0"+facilityid if strlen(facilityid)==5
	save "general`y'", replace
	}	

foreach y of numlist 2020 {
	import delimited using "hospitals_10_`y'/xubh-q36u.csv", clear
	keep facilityid facilityname state zipcode countyname hospitaltype hospitalownership emergencyservices
	save "general`y'", replace
	}

	foreach y of numlist 2021/2022 {
	import delimited using "hospitals_10_`y'/Hospital_General_Information.csv", clear
	keep facilityid facilityname state zipcode countyname hospitaltype hospitalownership emergencyservices
	des
	save "general`y'", replace
	}	
*/

