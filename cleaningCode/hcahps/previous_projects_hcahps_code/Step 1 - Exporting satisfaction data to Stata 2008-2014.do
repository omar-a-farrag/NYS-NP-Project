cd "~\Dropbox\Honors thesis-Omar Farrag\MDB files"

********************************************************************
* 			Consumer assessment, 2008-2014
********************************************************************

use hcahps2008.dta, clear
gen datayear=2008
foreach y of numlist 2009 {
	append using hcahps`y'
	replace datayear=`y' if datayear==.
	tostring Survey_Response_Rate_Percent, replace
}
foreach y of numlist 2010/2014 {
	append using hcahps`y'
	replace datayear=`y' if datayear==.
}
rename *, lower
drop *footnote* measure_start_date measure_end_date
drop number_of_completed_surveys 

// Hospital ID
gen facilityid = subinstr(provider_number, "'", "",.)
replace facilityid=provider_id if datayear==2014
label var facilityid "Hospital ID"
sort facilityid datayear
drop provider_number provider_id

rename hospital_name facilityname
order datayear facilityid facilityname state 

// Destring
rename hcahps_answer_percent hcahps_pct
replace hcahps_pct="" if hcahps_pct=="Not Available"
replace hcahps_pct="" if hcahps_pct=="N/A"
destring hcahps_pct, replace

rename survey_response_rate_percent hcahps_resp
replace hcahps_resp="" if hcahps_resp=="Not Available"
replace hcahps_resp="" if hcahps_resp=="N/A"
destring hcahps_resp, replace

// HCAHPS measure id (missing in 2008)
gen hcahpsmeasureid=hcahps_measure_code
replace hcahpsmeasureid=hcahps_measure_id if datayear==2014
gen _t1=hcahps_answer_description if datayear<2010
bysort _t1 (datayear): replace hcahpsmeasureid = hcahpsmeasureid[_N] if missing(hcahpsmeasureid) & datayear==2008
drop _t1 hcahps_measure_code hcahps_measure_id
tab hcahpsmeasureid datayear, mis

// Select consistent measures (10 measures)
note : H_COMP_4 available in 2008-2016 (How often was patients pain well controlled?) -> keep since lagged is used
*drop if strpos(hcahpsmeasureid,"H_COMP_4")==1 
note: H_COMP_7 available in 2014-2022 (Patients who "Agree" they understood their care when they left the hospital) -> drop
drop if strpos(hcahpsmeasureid,"H_COMP_7")==1  
tab hcahpsmeasureid datayear

// Check that sum of answers is 100
gen question=substr(hcahpsmeasureid,1,8)
/*
egen temp=total(hcahps_pct), by(facilityid datayear question)
tab temp		// OK
*/

// Assign score for each answer (10 for most favorable answer, 5 for middle, 0 for bottom)
gen substr=substr(hcahpsmeasureid,-4,4)
gen score=10    if substr=="_A_P" | substr=="9_10" | substr=="D_DY" |substr=="7_SA"		// always, strongly agree
replace score=5 if substr=="_U_P" | substr=="_7_8" | substr=="D_PY" |substr=="_7_A"		// usually, agree
replace score=0 if substr=="SN_P" | substr=="_0_6" | substr=="D_DN" | substr=="D_SD"  	// never, disagree or strongly disagree
replace score=10  if substr=="_Y_P"		// yes
replace score=0   if substr=="_N_P"   	// no

// Aggregated scores
gen _score2=score*hcahps_pct/100
egen hscore10=total(_score2) if _score2<., by(facilityid datayear)
egen hscore9=total(_score2) if _score2<. & question~="H_COMP_4", by(facilityid datayear)
egen hscore4=total(_score2) if question=="H_COMP_1" | question=="H_COMP_2" | question=="H_COMP_5" | question=="H_COMP_6", by(facilityid datayear)
label var hscore10 "Weighted HCAHP score, 10 measures"
label var hscore9 "Weighted HCAHP score, 9 measures"
label var hscore4 "Weighted HCAHP communication score, 4 measures"
?
// Percent
keep if score==10
?

duplicates drop datayear facilityid facilityname  

encode hcahpsmeasureid, gen(select)
label list select
drop hcahpsmeasureid *question hcahps_answer_description _score2 score substr
reshape wide hcahps_pct, i(facilityid datayear) j(select)
label var hcahps_pct1 "Room was always clean"
label var hcahps_pct2 "Nurses always communicated well"		// H_COMP_1_A_P
label var hcahps_pct3 "Doctors always communicated well"
label var hcahps_pct4 "Patients always received help"		// H_COMP_3_A_P
label var hcahps_pct5 "Patients pain was well controlled?"	// H_COMP_4_A_P
label var hcahps_pct6 "Staff always explained about medicine before giving them"
label var hcahps_pct7 "Patients were given information about what to do during recovery"		// H_COMP_6_Y_P
label var hcahps_pct8 "Patients who gave a rating of 9 or 10"
label var hcahps_pct9 "Always quiet at night"
label var hcahps_pct10 "Patients would definitely recommend the hospital"

order datayear facilityid facilityname state hcahps_score hcahps_pct* hcahps_resp
save hcahps_combined_2008_2014.dta, replace


********************************************************************
* 			Basic hospital characteristics, 2008-2014
********************************************************************

use general2008.dta, clear
gen datayear=2008
foreach y of numlist 2009/2014 {
	append using general`y'
	replace datayear=`y' if datayear==.
}
rename *, lower
drop address* city phone_number accreditation

destring zip_code, replace
label var state "State"
label var datayear "Year of data"
rename hospital_name hp_name
order datayear provider_number provider_id hp_name state zip_code county_name

// Hospital ID
gen facilityid = subinstr(provider_number, "'", "",.)
replace facilityid=provider_id if datayear==2014
label var facilityid "Hospital ID"
sort facilityid
drop provider_number provider_id
order datayear facilityid hp_name state zip_code county_name

// Hospital type
tab hospital_type datayear
gen hp_critical=(hospital_type=="Critical Access Hospitals" | hospital_type=="Critical Access")
label var hp_critical "=1 if critical access hospital"
drop hospital_type

// Hospital ownership
replace hospital_owner=hospital_ownership if datayear>2009
encode hospital_owner, gen(hp_owner)
label list hp_owner
label define hp_owner 1 "Gov't-Federal" 2 "Gov't-State" 3 "Gov't-Local" 4 "Gov't-District" 5 "Private" 6 "Church" 7 "Other non-profit", modify
recode hp_owner 1 5 6=1 2 7=4 3 8=3 4 9=2  14 17=6  13 15 18=7  10/12 16 19=5
format hp_owner %15.0g
bys hp_owner: tab hospital_owner
drop hospital_ownership hospital_owner
tab hp_owner datayear

// Emergency service
replace emergency_service=emergency_services if datayear==2014
gen hp_emerg=(emergency_service=="Yes")
label var hp_emerg "=1 if hospital has emergency service"
drop emergency_service*
tab hp_emerg datayear   // in 2010, all hospitals have emergency service
compress
sort facilityid datayear

// Add consumer assessment
merge 1:1 ahamcrid datayear using hcahps_combined_2008_2014.dta, keepusing(hcahps*)
gen hcahps_yes=1 if _m==3
replace hcahps_yes=0 if _m==1
drop _m 
label var hcahps_yes "HCAHPS scores are available"

save general_combined_2008_2014.dta, replace


rename facilityid ahamcrid // this is to identify hosps in SASD via AHA survey set

* Changes:
- Kept one measure (2008-2016) How often was patients pain well controlled?