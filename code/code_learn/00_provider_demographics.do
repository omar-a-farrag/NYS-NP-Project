*===============================================================================
* SCRIPT: 00_provider_demographics.do
* PURPOSE: Extract unique provider headcounts across all subgroups (Yearly & Full).
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* --- START LOG ---
local script_name "00_provider_demographics"
log using "$logRoot/`script_name'.smcl", replace

display "=== STARTING DEMOGRAPHIC COUNTS: INPATIENT & OUTPATIENT ==="


local outDir "$outRoot/summary_stats/demographics"
capture mkdir "`outDir'"
capture mkdir "`outDir'/tables_csv"
capture mkdir "`outDir'/tables_pdf"

* ==============================================================================
* PART 1: INPATIENT PROVIDERS
* ==============================================================================
display "Processing Inpatient Providers..."
use "$dataRoot/master_provider_inpatient_2013_2023.dta", clear

* 1. Merge Facility Data to inherit Hospital Ownership
capture confirm variable ccn
if _rc == 0 {
    preserve
    use "$dataRoot/master_facility_inpatient_2013_2023.dta", clear
    capture keep ccn year ownership
    duplicates drop ccn year, force
    tempfile fac_own
    save `fac_own'
    restore
    merge m:1 ccn year using `fac_own', keep(master match) nogen
}

* 2. Provider Type Taxonomy
capture confirm string variable cms_specialty
if _rc != 0 decode cms_specialty, gen(spec_str)
else gen spec_str = cms_specialty

gen prov_type = 1 
replace prov_type = 2 if strpos(upper(spec_str), "NURSE PRACTITIONER") > 0
replace prov_type = 3 if strpos(upper(spec_str), "PHYSICIAN ASSISTANT") > 0
label define pt_lbl 1 "MD/DO" 2 "Nurse Practitioner" 3 "Physician Assistant"
label values prov_type pt_lbl

* 3. NP Authority Taxonomy
capture confirm string variable cms_state
if _rc != 0 decode cms_state, gen(state_str)
else gen state_str = cms_state
replace state_str = strtrim(strupper(state_str))

gen np_authority = .
replace np_authority = 3 if $cond_full_prac
replace np_authority = 2 if $cond_red_prac
replace np_authority = 1 if $cond_res_prac
label define auth_lbl 1 "Restricted" 2 "Reduced" 3 "Full Practice"
label values np_authority auth_lbl

* 4. Ownership Taxonomy
capture confirm string variable ownership
if _rc == 0 {
    gen own_category = .
    replace own_category = 1 if $cond_own_gov
    replace own_category = 2 if $cond_own_forprof
    replace own_category = 3 if $cond_own_nonprof
    label define own_lbl 1 "Government" 2 "For-Profit" 3 "Non-Profit"
    label values own_category own_lbl
}

* 5. Gender Taxonomy (BULLETPROOFED)
capture rename is_female raw_is_female
gen is_female = "Unknown"

capture confirm string variable nppes_provider_gender
if _rc == 0 {
    replace is_female = "Female" if nppes_provider_gender == "F"
    replace is_female = "Male" if nppes_provider_gender == "M"
}
capture confirm string variable rndrng_prvdr_gndr
if _rc == 0 {
    replace is_female = "Female" if rndrng_prvdr_gndr == "F"
    replace is_female = "Male" if rndrng_prvdr_gndr == "M"
}
capture confirm numeric variable raw_is_female
if _rc == 0 {
    replace is_female = "Female" if raw_is_female == 1 & is_female == "Unknown"
    replace is_female = "Male" if raw_is_female == 0 & is_female == "Unknown"
}
capture confirm string variable raw_is_female
if _rc == 0 {
    replace is_female = "Female" if inlist(raw_is_female, "F", "Female", "1") & is_female == "Unknown"
    replace is_female = "Male" if inlist(raw_is_female, "M", "Male", "0") & is_female == "Unknown"
}

* ---------------------------------------------------------
* 6. YEARLY CUT: Isolate Unique NPIs per Year
* ---------------------------------------------------------
duplicates drop npi year, force

* Create a numeric dummy to sum instead of counting strings
gen n_prov = 1 

preserve
collapse (sum) provider_count=n_prov, by(year np_authority prov_type)
export delimited using "`outDir'/tables_csv/inpatient_auth_x_provtype_year.csv", replace
restore

capture confirm variable own_category
if _rc == 0 {
    preserve
    drop if missing(own_category)
    collapse (sum) provider_count=n_prov, by(year own_category prov_type)
    export delimited using "`outDir'/tables_csv/inpatient_own_x_provtype_year.csv", replace
    restore
}

preserve
drop if is_female == "Unknown"
collapse (sum) provider_count=n_prov, by(year is_female prov_type)
export delimited using "`outDir'/tables_csv/inpatient_gender_x_provtype_year.csv", replace
restore

* ---------------------------------------------------------
* 7. FULL SAMPLE CUT: Isolate Unique Humans (Most Recent Year)
* ---------------------------------------------------------
sort npi year
quietly by npi: keep if _n == _N

preserve
collapse (sum) provider_count=n_prov, by(np_authority prov_type)
export delimited using "`outDir'/tables_csv/inpatient_auth_x_provtype_full.csv", replace
restore

capture confirm variable own_category
if _rc == 0 {
    preserve
    drop if missing(own_category)
    collapse (sum) provider_count=n_prov, by(own_category prov_type)
    export delimited using "`outDir'/tables_csv/inpatient_own_x_provtype_full.csv", replace
    restore
}

preserve
drop if is_female == "Unknown"
collapse (sum) provider_count=n_prov, by(is_female prov_type)
export delimited using "`outDir'/tables_csv/inpatient_gender_x_provtype_full.csv", replace
restore


* ==============================================================================
* PART 2: OUTPATIENT PROVIDERS
* ==============================================================================
display "Processing Outpatient Providers..."
use "$dataRoot/master_provider_outpatient_asc_2015_2023.dta", clear

capture confirm string variable cms_specialty
if _rc != 0 decode cms_specialty, gen(spec_str)
else gen spec_str = cms_specialty

gen prov_type = 1 
replace prov_type = 2 if strpos(upper(spec_str), "NURSE PRACTITIONER") > 0
replace prov_type = 3 if strpos(upper(spec_str), "PHYSICIAN ASSISTANT") > 0
label values prov_type pt_lbl

capture confirm string variable cms_state
if _rc != 0 decode cms_state, gen(state_str)
else gen state_str = cms_state
replace state_str = strtrim(strupper(state_str))

gen np_authority = .
replace np_authority = 3 if $cond_full_prac
replace np_authority = 2 if $cond_red_prac
replace np_authority = 1 if $cond_res_prac
label values np_authority auth_lbl

* Gender Taxonomy (BULLETPROOFED)
capture rename is_female raw_is_female
gen is_female = "Unknown"

capture confirm string variable nppes_provider_gender
if _rc == 0 {
    replace is_female = "Female" if nppes_provider_gender == "F"
    replace is_female = "Male" if nppes_provider_gender == "M"
}
capture confirm string variable rndrng_prvdr_gndr
if _rc == 0 {
    replace is_female = "Female" if rndrng_prvdr_gndr == "F"
    replace is_female = "Male" if rndrng_prvdr_gndr == "M"
}
capture confirm numeric variable raw_is_female
if _rc == 0 {
    replace is_female = "Female" if raw_is_female == 1 & is_female == "Unknown"
    replace is_female = "Male" if raw_is_female == 0 & is_female == "Unknown"
}
capture confirm string variable raw_is_female
if _rc == 0 {
    replace is_female = "Female" if inlist(raw_is_female, "F", "Female", "1") & is_female == "Unknown"
    replace is_female = "Male" if inlist(raw_is_female, "M", "Male", "0") & is_female == "Unknown"
}

* ---------------------------------------------------------
* YEARLY CUT: Isolate Unique NPIs per Year
* ---------------------------------------------------------
duplicates drop npi year, force

* Create a numeric dummy to sum instead of counting strings
gen n_prov = 1 

preserve
collapse (sum) provider_count=n_prov, by(year np_authority prov_type)
export delimited using "`outDir'/tables_csv/outpatient_auth_x_provtype_year.csv", replace
restore

preserve
drop if is_female == "Unknown"
collapse (sum) provider_count=n_prov, by(year is_female prov_type)
export delimited using "`outDir'/tables_csv/outpatient_gender_x_provtype_year.csv", replace
restore

* ---------------------------------------------------------
* FULL SAMPLE CUT: Isolate Unique Humans (Most Recent Year)
* ---------------------------------------------------------
sort npi year
quietly by npi: keep if _n == _N

preserve
collapse (sum) provider_count=n_prov, by(np_authority prov_type)
export delimited using "`outDir'/tables_csv/outpatient_auth_x_provtype_full.csv", replace
restore

preserve
drop if is_female == "Unknown"
collapse (sum) provider_count=n_prov, by(is_female prov_type)
export delimited using "`outDir'/tables_csv/outpatient_gender_x_provtype_full.csv", replace
restore

display "=== DEMOGRAPHIC COUNTS COMPLETE ==="
