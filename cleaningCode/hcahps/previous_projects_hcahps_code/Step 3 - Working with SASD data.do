cd "~\Dropbox\Honors thesis-Omar Farrag\"

****************************************************************************
*						Hospital-level data
****************************************************************************

use "sasd_workfile.dta", clear

gen age65=(age>=65)
gen black=(race==2)
gen hispanic=(race==3)
tab zipinc, gen(zipinc_)
gen medicare=(paymethod==1)
gen medicaid=(paymethod==2)
gen privinsu=(paymethod==3)
gen nvisits=1
rename totchg charge
gen durshort=(los==0)
gen durlong=(los==3)

global means "female age age65 black hispanic zipinc_* medicare medicaid privinsu durshort durlong dhome charge"
collapse (mean) $means (sum) vol_antbio=iAntibiotics vol_opioid=iOpioid exp_antbio=isCanAntibiotics exp_opioid=isCanOpioids nvisits=nvisits, by(ahamcrid ayear amonth yrmon)
*collapse (mean) $means (sum) vol_antbio=iAntibiotics vol_opioid=iOpioid exp_antbio=isCanAntibiotics exp_opioid=isCanOpioids nvisits=nvisits, by(ahamcrid ayear)
label var female "Share of female patients"
label var age "Average age"
label var age65 "Share of older patients, 65+"
label var black "Patients of Black race, share"
label var hispanic "Patients of Hispanic origin, share"
label var zipinc_1 "Share of patients from poorest ZIP codes"
label var zipinc_2 "Share of patients from the 2nd income quartile of ZIP codes"
label var zipinc_3 "Share of patients from the 3rd income quartile of ZIP codes"
label var zipinc_4 "Share of patients from richest ZIP codes"
label var medicare "Share of visits paid through Medicare"
label var medicaid "Share of visits paid through Medicaid"
label var privinsu "Share of visits paid by private insurance"
label var durshort "Share of short stays, <1 day"
label var durlong  "Share of long stays, 3 day"
label var dhome    "Share of patients discharged to home"
label var charge   "Average charge for a hospital visit"
label var nvisits  "Number of visits"
label var vol_antbio "Prescription volume for antibiotics"
label var vol_opioid "Prescription volume for opiodics"
label var exp_antbio "Expected volume for antibiotics based on diagnostics"
label var exp_opioid "Expected volume for opioids based on diagnostics"

clonevar datayear=ayear
merge m:1 ahamcrid datayear using general_combined_2008_2014, keep(1 3) nogen
drop datayear
*save "sasd_hospitals.dta", replace

save "sasd_hospitals_by_month.dta", replace



****************************************************************************
*						Patient-level data
****************************************************************************

use "SASD/SASD_09-14_main_sample.dta", clear
drop if ayear==2008

// ID
gen yrmon=ym(ayear, amonth)
format yrmon %tm
label var yrmon "Year-month of hospital admission"
label var ayear "Year of hospital admission"
label var amonth "Month of hospital admission"
drop year key dhour dmonth dqtr dshospid

// Patient's characteristics
label variable age "Patient's age"
recode race 5/6=5
label define race 1 "White" 2 "Black" 3 "Hispanic" 4 "Asian or Pacific Islander" 5 "Other"
label values race race
label variable race "Patient's race"
label variable female "Patient's gender"

rename zipinc_qrtl zipinc
label define zipinc 1 "First quartile" 2 "Second quartile" 3 "Third quartile" 4 "Fourth quartile"
label values zipinc zipinc
label variable zipinc "Median household income for patient's ZIP Code"

rename pay1 paymethod
recode paymethod 5/6=5
label variable paymethod "Primary payer"
label define paymethod 1 "Medicare" 2 "Medicaid" 3 "Private insurance" 4 "Self-pay" 5 "No charge or other"
label values paymethod paymethod

label var zip "Patient's ZIP code"

drop medincstq homeless ageday agemonth

// Characteristics of visits
rename (cpt1 cpt2 cpt3) (diagnosis1 diagnosis2 diagnosis3)
label variable diagnosis1 "Primary Diagnosis"
label variable diagnosis2 "Secondary Diagnosis"
label variable diagnosis3 "Tertiary Diagnosis"

gen dhome=dispub04==1
label var dhome "Discharged to home"

rename dispuniform dlocation
recode dlocation 7=99
label define dlocation 1 "Routine" 2 "Transfer to Short-term Hospital" 5 "Transfer to Mid- to Long-Term Facility" 6 "Home Health Care" 20 "Died" 99 "Discharge alive, destination other"
label values dlocation dlocation
label var dlocation "Discharge location"
note: Transfer Other: Includes Skilled Nursing Facility (SNF), Intermediate Care Facility (ICF), Another Type of Facility"

recode anesth 0=1 10 30=2 20=3 40=4
label define anesth 1 "None" 2 "Local or regional" 3 "General" 4 "Other"
label values anesth anesth
label var anesth "Anesthesia level"

label var totchg "Total charge for hospital visit"

label var los "Days of stay in ambulatory center"
gen hourstay=int(duration/100)
label var hourstay "Hours of stay in ambulatory center"

drop cpt* ahour aweekend dispub04 died dx1 neomat ortime duration daystoevent

global ID "ahaid ahamcrid yrmon ayear amonth visitlink"
global P "zip female age race zipinc paymethod"			
global V "diagnosis* anesth dhome dlocation totchg los hourstay isCanAntibiotics isCanOpioids nVisits"			// visits
global Y "iAntibiotics iOpioid"

order $ID $P $V $Y

clonevar datayear=ayear
merge m:1 ahamcrid datayear using general_combined_2008_2014, keep(1 3) nogen
drop datayear
save "sasd_patients.dta", replace


