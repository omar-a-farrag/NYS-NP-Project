*===============================================================================
* SCRIPT: 05a_facility_maps.do
* PURPOSE: Geographic heatmaps for Inpatient Facility Outcomes & Ownership.
*===============================================================================
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"
tempfile state_data zip_data

display "--- Building Facility State-Level Panel ---"
use "$dataRoot/master_facility_inpatient_2013_2023.dta", clear

* Just drop the territories, the native 'state' variable is already perfect!
drop if state == "" | inlist(state, "PR", "VI", "GU", "AS", "MP")

* Prep Government Ownership Concentration
decode ownership, gen(own_str)
gen is_gov = (strpos(own_str, "GOVERNMENT") | inlist(own_str, "DEPARTMENT OF DEFENSE", "TRIBAL", "VETERANS HEALTH ADMINISTRATION"))
drop own_str

* Variables to Map
*local facility_vars "h_hosp_rating_9_10 h_hosp_rating_0_6 hac_total_score rrp_excess_ratio_ami rrp_excess_ratio_hf rrp_excess_ratio_pn fac_wgt_em_upcode_rate is_gov"
local facility_vars "$in_fac_means"

* Collapse to State-Year, get YoY Change, then Final State Avg
collapse (mean) `facility_vars', by(state year)
sort state year
foreach var in `facility_vars' {
    by state: gen chg_`var' = `var' - `var'[_n-1]
}
collapse (mean) `facility_vars' chg_*, by(state)
save `state_data', replace

* --- MAPPING LOOP ---
foreach var in `facility_vars' {
    local clean_title ""
    if "`var'" == "h_hosp_rating_9_10" local clean_title "HCAHPS: Top Score (9-10)"
    if "`var'" == "h_hosp_rating_0_6" local clean_title "HCAHPS: Bottom Score (0-6)"
    if "`var'" == "hac_total_score" local clean_title "HAC Infection Score"
    if "`var'" == "rrp_excess_ratio_ami" local clean_title "Readmission: Heart Attack"
    if "`var'" == "rrp_excess_ratio_hf" local clean_title "Readmission: Heart Failure"
    if "`var'" == "rrp_excess_ratio_pn" local clean_title "Readmission: Pneumonia"
    if "`var'" == "fac_wgt_em_upcode_rate" local clean_title "Facility E\&M Upcoding"
    if "`var'" == "is_gov" local clean_title "Gov. Hospital Concentration"

    * National Avg
    use `state_data', clear
    maptile `var', geo(state) fcolor(Blues) nquantiles(5) ///
        twopt(title("11-Yr Avg: `clean_title'", size(medium))) savegraph("$outRoot/in_patient/maps/national_avg_`var'.png") replace
    * National Change
    maptile chg_`var', geo(state) fcolor(Greens) nquantiles(5) ///
        twopt(title("YoY Change: `clean_title'", size(medium))) savegraph("$outRoot/in_patient/maps/national_chg_`var'.png") replace
}

* --- NYS ZIP CODE PANEL ---
display "--- Building NYS Zip-Code Panel ---"
use "$dataRoot/master_facility_inpatient_2013_2023.dta", clear

keep if state == "NY"
drop if zip_code == "" | length(zip_code) < 5
gen zip5 = substr(zip_code, 1, 5)
destring zip5, replace // <-- Converts text to numbers!

decode ownership, gen(own_str)
gen is_gov = (strpos(own_str, "GOVERNMENT") | inlist(own_str, "DEPARTMENT OF DEFENSE", "TRIBAL", "VETERANS HEALTH ADMINISTRATION"))

collapse (mean) `facility_vars', by(zip5 year)
sort zip5 year
foreach var in `facility_vars' {
    by zip5: gen chg_`var' = `var' - `var'[_n-1]
}
collapse (mean) `facility_vars' chg_*, by(zip5)
save `zip_data', replace

foreach var in `facility_vars' {
    * Zip Avg
    local clean_title ""
    if "`var'" == "h_hosp_rating_9_10" local clean_title "HCAHPS: Top Score (9-10)"
    if "`var'" == "h_hosp_rating_0_6" local clean_title "HCAHPS: Bottom Score (0-6)"
    if "`var'" == "hac_total_score" local clean_title "HAC Infection Score"
    if "`var'" == "rrp_excess_ratio_ami" local clean_title "Readmission: Heart Attack"
    if "`var'" == "rrp_excess_ratio_hf" local clean_title "Readmission: Heart Failure"
    if "`var'" == "rrp_excess_ratio_pn" local clean_title "Readmission: Pneumonia"
    if "`var'" == "fac_wgt_em_upcode_rate" local clean_title "Facility E\&M Upcoding"
    if "`var'" == "is_gov" local clean_title "Gov. Hospital Concentration"
    
    use `zip_data', clear
    maptile `var', geo(zip5) fcolor(Reds) nquantiles(5) ///
        twopt(title("NYS Avg: `clean_title'", size(medium))) savegraph("$outRoot/in_patient/maps/nys_zip_avg_`var'.png") replace
}
display "=== FACILITY MAPS COMPLETE ==="
