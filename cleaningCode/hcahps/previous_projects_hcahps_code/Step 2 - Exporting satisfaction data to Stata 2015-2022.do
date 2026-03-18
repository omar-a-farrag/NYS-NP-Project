cd "~\Dropbox\Honors thesis-Omar Farrag"

********************************************************************
* 			Consumer assessment, 2015-2022
********************************************************************

* https://wayback.archive-it.org/org-551/20160104125435/https://data.medicare.gov/data/archives/hospital-compare

	*** Save csv files as Stata
	
foreach y of numlist 2021/2022 {
	import delimited using "hospitals_10_`y'/HCAHPS-Hospital.csv", clear
	drop address city phonenumber *footnot*
	gen year=`y'
	save "hcahps`y'", replace
	}
foreach y of numlist 2020 {
	import delimited using "hospitals_10_`y'/dgck-syfz.csv", clear
	drop address city phonenumber *footnot*
	gen year=`y'
	save "hcahps`y'", replace
	}
foreach y of numlist 2019 {
	import delimited using "hospitals_10_`y'/HCAHPS - Hospital.csv", clear
	drop address city phonenumber *footnot*
	gen year=`y'
	save "hcahps`y'", replace
	}
foreach y of numlist 2015/2018 {
	import delimited using "hospitals_10_`y'/HCAHPS - Hospital.csv", clear
	drop address city phonenumber *footnot*
	rename providerid facilityid
	tostring facilityid, replace
	replace facilityid="0"+facilityid if strlen(facilityid)==5
	replace facilityid="00"+facilityid if strlen(facilityid)==4
	rename hospitalname facilityname
	rename measurestartdate startdate
	rename measureenddate enddate
	gen year=`y'
	save "hcahps`y'", replace
	}

	*** Satisfaction assessment score

use "hcahps2015.dta", clear
foreach y of numlist 2016/2022 {
	append using "hcahps`y'"
}
order year
format facilityname %30s

// Dates
rename *date *date2
foreach v in startdate enddate {
	gen `v'=date(`v'2,"MDY")
	format `v' %td
}
drop *date2
label var startdate "Start date"
label var enddate "End date"
rename year datayear
gen year=year(enddate)
label var datayear "Year of data file"
label var year "Year of survey"

// Destring
rename hcahpsanswerpercent hcahps_pct
replace hcahps_pct="" if hcahps_pct=="Not Available"
replace hcahps_pct="" if hcahps_pct=="Not Applicable"
destring hcahps_pct, replace

rename surveyresponseratepercent hcahps_resp
replace hcahps_resp="" if hcahps_resp=="Not Available"
destring hcahps_resp, replace
drop hcahpsquestion patientsurveystarrating hcahpslinearmeanvalue numberofcompletedsurveys

// Select consistent measures (10 measures)
tab hcahpsmeasureid year
gen select=.
replace select=1 if strpos(hcahpsmeasureid,"H_COMP")==1
replace select=1 if strpos(hcahpsmeasureid,"H_CLEAN_HSP")==1
replace select=1 if strpos(hcahpsmeasureid,"H_HSP_RATING")==1
replace select=1 if strpos(hcahpsmeasureid,"H_QUIET_HSP")==1
replace select=1 if strpos(hcahpsmeasureid,"H_RECMND")==1
keep if select==1
drop if strpos(hcahpsmeasureid,"H_COMP_4")==1 | strpos(hcahpsmeasureid,"H_COMP_7")==1
drop select
tab hcahpsmeasureid year

drop if facilityid=="010099" & state=="FL"  // drop duplicate ID in 2018
drop if facilityid=="050030" & state=="WA" 
drop if facilityid=="010065" & state=="FL" 

// Overall score
gen substr=substr(hcahpsmeasureid,-4,4)
gen score=10    if substr=="_A_P" | substr=="9_10" | substr=="D_DY" |substr=="7_SA"		// always, strongly agree
replace score=5 if substr=="_U_P" | substr=="_7_8" | substr=="D_PY" |substr=="_7_A"		// usually, agree
replace score=0 if substr=="SN_P" | substr=="_0_6" | substr=="D_DN" | substr=="D_SD"  	// never, disagree or strongly disagree
replace score=10  if substr=="_Y_P"		// yes
replace score=0   if substr=="_N_P"   	// no
gen _score2=score*hcahps_pct/100
egen hcahps_score=total(_score2) if _score2<., by(facilityid year)
label var hcahps_score "Weighted HCAHP score"

// Percent
keep if score==10 & hcahps_score<.
encode hcahpsmeasureid, gen(select)
label list select
drop hcahpsmeasureid hcahpsanswerdescription _score2 score substr
reshape wide hcahps_pct, i(facilityid year) j(select)
label var hcahps_pct1 "Room was always clean"
label var hcahps_pct2 "Nurses always communicated well"
label var hcahps_pct3 "Doctors always communicated well"
label var hcahps_pct4 "Patients always received help"
label var hcahps_pct5 "Staff always explained about medicine before giving them"
label var hcahps_pct6 "Patients were given information about what to do during recovery"  // H_COMP_6_Y_P
label var hcahps_pct7 "Patients who gave a rating of 9 or 10"
label var hcahps_pct8 "Always quiet at night"
label var hcahps_pct9 "Patients would definitely recommend the hospital"

rename zipcode zip_code
rename countyname county_name
order datayear year facilityid facilityname state zip_code county_name hcahps_score hcahps_pct* hcahps_resp

save hcahps_combined_2015_2022.dta, replace



********************************************************************
* 			Basic hospital characteristics, 2015-2022
********************************************************************

foreach y of numlist 2021/2022 {
	import delimited using "hospitals_10_`y'/Hospital_General_Information.csv", clear
	keep facilityid facilityname state zipcode countyname hospitaltype hospitalownership emergencyservices
	des
	save "general`y'", replace
	}
	
foreach y of numlist 2020 {
	import delimited using "hospitals_10_`y'/xubh-q36u.csv", clear
	keep facilityid facilityname state zipcode countyname hospitaltype hospitalownership emergencyservices
	save "general`y'", replace
	}
	
foreach y of numlist 2019 {
	import delimited using "hospitals_10_`y'/Hospital General Information.csv", clear
	keep facilityid facilityname state zipcode countyname hospitaltype hospitalownership emergencyservices
	des
	tostring facilityid, replace
	replace facilityid="0"+facilityid if strlen(facilityid)==5
	save "general`y'", replace
	}
	
foreach y of numlist 2016/2018 {
	import delimited using "hospitals_10_`y'/Hospital General Information.csv", clear
	keep *id* *name* state zipcode countyname hospitaltype hospitalownership emergencyservices
	des
	rename providerid facilityid
	tostring facilityid, replace
	replace facilityid="0"+facilityid if strlen(facilityid)==5
	rename hospitalname facilityname
	save "general`y'", replace
	}
	
foreach y of numlist 2015 {
	import delimited using "hospitals_10_`y'/Hospital General Information.csv", clear
	keep *id* *name* state zipcode countyname hospitaltype hospitalownership emergencyservices
	des
	rename providerid facilityid
	rename hospitalname facilityname
	save "general`y'", replace
	}

	
// Append	
use general2015.dta, clear
gen datayear=2015
foreach y of numlist 2016/2022 {
	append using general`y'
	replace datayear=`y' if datayear==.
}

rename zipcode zip_code
rename countyname county_name
label var datayear "Year of data"
order datayear facilityid facilityname state zip_code county_name

// Hospital type
tab hospitaltype datayear
gen hp_critical=(hospitaltype=="Critical Access Hospitals")
label var hp_critical "=1 if critical access hospital"
drop hospitaltype

// Hospital ownership
encode hospitalownership, gen(hp_owner)
label list hp_owner
label define hp_owner 1 "Gov't-Federal" 2 "Gov't-State" 3 "Gov't-Local" 4 "Gov't-District" 5 "Private" 6 "Church" 7 "Other non-profit", modify
recode hp_owner 1 2 6=1  3=4  4=3  5=2  7/8 12=5  10=6  9 11=7
format hp_owner %15.0g
bys hp_owner: tab hospitalownership
drop hospitalownership 
tab hp_owner datayear

// Emergency service
gen hp_emerg=(emergencyservices=="Yes")
label var hp_emerg "=1 if hospital has emergency service"
drop emergencyservices
tab hp_emerg datayear   // in 2010, all hospitals have emergency service
compress
sort facilityid datayear

// Add consumer assessment
merge 1:1 facilityid datayear using hcahps_combined_2015_2022.dta, update	
tab datayear _m 		// 120 VA hospitals with satisfaction data but do not have general information in 2018-2022
tab facilityname if _m==2
drop if _m==2
gen hcahps_yes=1 if _m==3
replace hcahps_yes=0 if _m==1
drop _m 
label var hcahps_yes "HCAHPS scores are available"
save general_combined_2015_2022.dta, replace

// Append 2008-2014
use general_combined_2015_2022.dta, clear
append using "MDB files/general_combined_2008_2014.dta"
replace year=datayear-1 if datayear<2015
foreach v of numlist 1/9 {
	tab year, sum(hcahps_pct`v')
}
tab year, sum(hcahps_score)

?

foreach y of numlist 2015/2022 {
	erase "hcahps`y'.dta"
	erase "general`y'.dta"
}
