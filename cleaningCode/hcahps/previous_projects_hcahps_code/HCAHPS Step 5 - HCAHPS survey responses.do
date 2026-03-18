cd "~/Dropbox/Overprescription/HCAHP"
 
*  HCAHPS (Hospital Consumer Assessment of Healthcare Providers and Systems survey)
* https://wayback.archive-it.org/org-551/20160104125435/https://data.medicare.gov/data/archives/hospital-compare

********************************************************************
* 				Convert to Stata
********************************************************************

note: data is 1-year lagged, for the previous year January to December
// MDB files
foreach y of numlist 2008/2013 {
	use "hcahps`y'/dbo_vwHQI_HOSP_HCAHPS_MSR.dta", clear
	rename *, lower
	rename *_* **
	rename *_* **
	rename *_* **
	rename (numberofcompletedsurveys surveyresponseratepercent) (hcahps_nsurv hcahps_resp )
	cap rename hcahpsmeasurecode hcahpsmeasureid
	keep providernumber hospitalname hcahps*
	destring providernumber, replace ignore(')
	cap tostring hcahps_resp, replace
	gen datayear=`y'
	des
	save "hcahps`y'", replace
	}
	
// CSV files	
foreach y of numlist 2014/2018 {
	import delimited using "hcahps`y'/HCAHPS - Hospital.csv", clear
	rename (providerid numberofcompletedsurveys surveyresponseratepercent) (providernumber hcahps_nsurv hcahps_resp)
	keep providernumber hospitalname hcahps*
	gen datayear=`y'
	des
	save "hcahps`y'", replace
	}
use hcahps2018.dta, clear
drop if substr(providernumber,-1,1)=="F"
destring providernumber, replace
save, replace

// 2012-2013 horizontal format
foreach y of numlist 2012/2013 {
	import delimited using "hcahps`y'/HCAHPS Measures.csv", clear
	rename (numberofcompletedsurveys surveyresponserate) (hcahps_nsurv hcahps_resp)
	gen datayear=`y'
	tempfile hcahps`y'b
	save `hcahps`y'b'
	}
clear
foreach y of numlist 2012/2013 {
	append using `hcahps`y'b'
}
rename (providernumber v28 v13 v16 v19 v22 v25 percentofpatientsateachhospitalw patientswhogavetheirhospitalarat v31 patientswhoreportedyestheywouldd hospitalfootnote) (provider_id topbox1 topbox2 topbox3 topbox4 topbox5 topbox6 topbox7 topbox8 topbox9 topbox10 footnote)
keep provider_id datayear hospitalname hcahps_nsurv hcahps_resp topbox* footnote

destring hcahps_resp, replace ignore("Not Available")
destring topbox*, replace ignore("Not Available")
label var hcahps_resp "HCAHP survey response rate"
save hcahps2012_2013.dta, replace

********************************************************************
* 			Satisfaction assessment score
********************************************************************

clear
foreach y of numlist 2008/2011 2014/2018 {
	append using "hcahps`y'"
}
rename providernumber provider_id
label var datayear "Year of data file"		// survey year is lagged

// Survey response rate
foreach v in hcahps_resp hcahpsanswerpercent {
	replace `v'="" if `v'=="Not Available"
	replace `v'="" if `v'=="Not Applicable"
	replace `v'="" if `v'=="N/A"
	destring `v', replace
}
label var hcahps_resp "HCAHP survey response rate"

replace hcahpsanswerdescription=subinstr(hcahpsanswerdescription,`"""',"",.)
replace hcahpsanswerdescription=subinstr(hcahpsanswerdescription,"'","",.)
gen dimension=.
replace dimension=1 if strpos(hcahpsanswerdescription,"always clean")~=0
replace dimension=2 if strpos(hcahpsanswerdescription,"Nurses always communicated")~=0
replace dimension=3 if strpos(hcahpsanswerdescription,"Doctors always communicated")~=0
replace dimension=4 if strpos(hcahpsanswerdescription,"always received help")~=0
replace dimension=5 if strpos(hcahpsanswerdescription,"always well controlled")~=0
replace dimension=6 if strpos(hcahpsanswerdescription,"Staff always explained")~=0
replace dimension=7 if strpos(hcahpsanswerdescription,"staff did give patients this information")~=0
replace dimension=8 if strpos(hcahpsanswerdescription,"9 or 10")~=0
replace dimension=9 if strpos(hcahpsanswerdescription,"Always quiet")~=0
replace dimension=10 if strpos(hcahpsanswerdescription,"definitely recommend")~=0
replace dimension=12 if strpos(hcahpsmeasureid,"H_COMP_7_SA")~=0
drop if dimension==.
bys dimension: tab hcahpsanswerdescription

rename hcahpsanswerpercent topbox
rename hcahpsanswerpercentfootnote footnote
drop hcahpsquestion hcahpsanswerdescription hcahpsmeasureid hcahpslinearmeanvalue

reshape wide topbox, i(provider_id datayear) j(dimension) 
append using hcahps2012_2013.dta

egen topbox11=rowmean(topbox1 topbox9)
order topbox11, after(topbox10)
drop topbox1 topbox9

label var topbox2 "Communication with nurses"		// H_COMP_1_A_P
label var topbox3 "Communication with physicians"
label var topbox4 "Responsiveness of hospital staff"	// H_COMP_3_A_P
label var topbox5 "Pain management"					// H_COMP_4_A_P
label var topbox6 "Communication about medications"
label var topbox7 "Discharge information"			// H_COMP_6_Y_P
label var topbox8 "Top overall rating of hospital"
label var topbox10 "Willingness to recommend hospital"
label var topbox11 "Cleanliness and quietness of hospital environment"
label var topbox12 "Transition care"		// H_COMP_7_SA

// Number of completed surveys
rename hcahps_nsurv _hcahps_nsurv
destring _hcahps_nsurv, gen(hcahps_nsurv) force
recode hcahps_nsurv 0/99=1 100/299=2 300/20000=3
replace hcahps_nsurv=1 if _hcahps_nsurv=="FEWER THAN 50" | _hcahps_nsurv=="Fewer than 100"
replace hcahps_nsurv=2 if _hcahps_nsurv=="Between 100 and 299"
replace hcahps_nsurv=3 if _hcahps_nsurv=="300 or More" | _hcahps_nsurv=="300 or more"
replace hcahps_nsurv=99 if _hcahps_nsurv=="Not Available" | _hcahps_nsurv=="N/A"
label define hcahps_nsurv 1 "<100" 2 "100-299" 3 "300+" 99 "Not available"
label values hcahps_nsurv hcahps_nsurv
label var hcahps_nsurv "Number of completed surveys"
tab hcahps_nsurv, mis
drop _*

// Convert percentages into shares
foreach v of numlist 2/8 10/12 {
	replace topbox`v'=topbox`v'/100
}

// Standardized score
egen av_q8=rowmean(topbox11 topbox2 topbox3 topbox4 topbox5 topbox6 topbox7 topbox8) if datayear<2018
egen ps_care=std(av_q8)
label var ps_care "Patient satisfaction with hospital care, 8 measures"
drop av_*

// Achievement score
preserve
import excel using "Thresholds and benchmarks", first clear
keep threshold benchmark datayear dimension
reshape wide threshold benchmark, i(datayear) j(dimension)
expand 5 if datayear==2012
bys datayear: replace datayear=2012-_n+1 if datayear==2012
sort datayear
tempfile benchmark
save `benchmark'
restore

merge m:1 datayear using `benchmark', keep(1 3) nogen
foreach v of numlist 2/8 11 {
	gen performance_rate`v'=topbox`v'*100
	gen achscore_`v'=(performance_rate`v'-threshold`v')*9/(benchmark`v'-threshold`v')+0.5
	replace achscore_`v'=round(achscore_`v',1)
	replace achscore_`v'=10 if performance_rate`v'>benchmark`v' & performance_rate`v'<.
	replace achscore_`v'=0 if performance_rate`v'<threshold`v' & threshold`v'<.
}

egen achscore=rowtotal(achscore_*) if datayear<2018, missing
label var achscore "Achievement score"
drop achscore_* performance_rate* benchmark* threshold*

// Data quality
gen hcahps_categ=99 if hcahps_nsurv==99
replace hcahps_categ=3 if hcahps_nsurv==1
replace hcahps_categ=2 if hcahps_categ==. & substr(footnote,1,2)~=""
replace hcahps_categ=1 if hcahps_categ==.
label define hcahps_categ 1 "Valid score" 2 "Low data quality" 3 "Less than 100 responses" 99 "Missing score", modify
label values hcahps_categ hcahps_categ
label var hcahps_categ "HCAHPS valid responses"
note: CMS uses both 1 and 2 categories in published hospital ratings and calculating payment adjustment factors

gen survyear=datayear-1
label var survyear "Year of HCAHPS survey, 1-yr lag"

rename provider_id provider_id0
sort provider_id0 datayear
order provider_id0 datayear survyear hospitalname hcahps_categ
save "hcahps_score_combined.dta", replace
?
use "hcahps_score_combined.dta", clear
foreach v in topbox1 topbox2 topbox3 topbox4 topbox5 topbox6 topbox7 topbox8 topbox9 topbox10 topbox12 ps_care {
	tab datayear, sum(`v')
}

STOP HERE

/*
*** More recent files (not used in this research)

foreach y of numlist 2019 {
	import delimited using "hospitals_10_`y'/HCAHPS - Hospital.csv", clear
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
foreach y of numlist 2021/2022 {
	import delimited using "hospitals_10_`y'/HCAHPS-Hospital.csv", clear
	drop address city phonenumber *footnot*
	gen year=`y'
	save "hcahps`y'", replace
	}
	note: 2021 data is from July to December of 2020

*/