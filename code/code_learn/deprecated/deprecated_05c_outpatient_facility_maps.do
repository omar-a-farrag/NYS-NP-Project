*===============================================================================
* SCRIPT: 05c_outpatient_facility_maps.do
* PURPOSE: Geographic heatmaps for Outpatient Facilities (ASCs).
*===============================================================================
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"
tempfile state_data zip_data

display "--- Building ASC State-Level Panel ---"
use "$dataRoot/master_facility_outpatient_asc_2015_2024.dta", clear

* ASC dataset natively uses 'state' as a string
drop if state == "" | inlist(state, "PR", "VI", "GU", "AS", "MP")

*local asc_vars "asc_rate_1 asc_rate_2 asc_rate_8"
local asc_vars "$out_fac_means"

* Collapse to State-Year, get YoY Change, then Final State Avg
collapse (mean) `asc_vars', by(state year)
sort state year
foreach var in `asc_vars' {
    by state: gen chg_`var' = `var' - `var'[_n-1]
}
collapse (mean) `asc_vars' chg_*, by(state)
save `state_data', replace

* --- MAPPING LOOP ---
foreach var in `asc_vars' {
    local clean_title ""
    if "`var'" == "asc_rate_1" local clean_title "ASC-1: Patient Burns Rate"
    if "`var'" == "asc_rate_2" local clean_title "ASC-2: Patient Falls Rate"
    if "`var'" == "asc_rate_8" local clean_title "ASC-8: Flu Vac. Coverage"

    * National Avg
    use `state_data', clear
    maptile `var', geo(state) fcolor(Blues) nquantiles(5) ///
        twopt(title("9-Yr Avg: `clean_title'", size(medium))) savegraph("$outRoot/out_patient/maps/national_avg_`var'.png") replace
    * National Change
    maptile chg_`var', geo(state) fcolor(Greens) nquantiles(5) ///
        twopt(title("YoY Change: `clean_title'", size(medium))) savegraph("$outRoot/out_patient/maps/national_chg_`var'.png") replace
}

* --- NYS ZIP CODE PANEL ---
display "--- Building NYS Zip-Code Panel ---"
use "$dataRoot/master_facility_outpatient_asc_2015_2024.dta", clear
keep if state == "NY"

capture gen zip_code = zip_code
drop if zipcode == "" | length(zipcode) < 5
gen zip5 = substr(zipcode, 1, 5)
destring zip5, replace force

collapse (mean) `asc_vars', by(zip5 year)
sort zip5 year
foreach var in `asc_vars' {
    by zip5: gen chg_`var' = `var' - `var'[_n-1]
}
collapse (mean) `asc_vars' chg_*, by(zip5)
save `zip_data', replace

foreach var in `asc_vars' {
    local clean_title ""
    if "`var'" == "asc_rate_1" local clean_title "ASC-1: Patient Burns Rate"
    if "`var'" == "asc_rate_2" local clean_title "ASC-2: Patient Falls Rate"
    if "`var'" == "asc_rate_8" local clean_title "ASC-8: Flu Vac. Coverage"
    
    use `zip_data', clear
    maptile `var', geo(zip5) fcolor(Reds) nquantiles(5) ///
        twopt(title("NYS Avg: `clean_title'", size(medium))) savegraph("$outRoot/out_patient/maps/nys_zip_avg_`var'.png") replace
}
display "=== ASC FACILITY MAPS COMPLETE ==="