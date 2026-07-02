*===============================================================================
* SCRIPT: 05d_outpatient_provider_maps.do
* PURPOSE: Geographic heatmaps for TRUE Outpatient Provider metrics.
*===============================================================================
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"
tempfile state_data zip_data

display "--- Building Outpatient Provider State-Level Panel ---"
use "$dataRoot/master_provider_outpatient_asc_2015_2023.dta", clear

capture drop state
decode cms_state, gen(state)
drop if state == "" | inlist(state, "PR", "VI", "GU", "AS", "MP")

* Demographics & Workforce
decode credential, gen(cred_str)
gen np_count = (cred_str == "NP")
gen pa_count = (cred_str == "PA")
gen md_count = (inlist(cred_str, "MD", "DO"))

gen female_np_count = (is_female == 1 & np_count == 1)
gen female_pa_count = (is_female == 1 & pa_count == 1)
gen female_md_count = (is_female == 1 & md_count == 1)
drop cred_str

*local mean_vars "partd_opioid_rate partd_generic_rate partd_high_cost_rate partb_em_upcode_rate mips_final_score mips_quality_score bene_avg_risk_scre"
*local sum_vars "np_count pa_count md_count female_np_count female_pa_count female_md_count tot_benes bene_dual_cnt"
local mean_vars "$prov_overlap_means $out_prov_means"
local sum_vars "$prov_overlap_sums"

* Catch missing dual count just in case
capture confirm variable bene_dual_cnt
if _rc {
    capture gen bene_dual_cnt = . 
}

* Collapse to State-Year
collapse (mean) `mean_vars' (sum) `sum_vars', by(state year)

* Calculate Derived Rates
gen np_md_ratio = np_count / md_count
gen pct_female_md = female_md_count / md_count
gen pct_female_np = female_np_count / np_count
gen pct_female_pa = female_pa_count / pa_count
gen dual_rate = bene_dual_cnt / tot_benes

local all_vars "`mean_vars' np_md_ratio pct_female_md pct_female_np pct_female_pa dual_rate"

sort state year
foreach var in `all_vars' {
    by state: gen chg_`var' = `var' - `var'[_n-1]
}
collapse (mean) `all_vars' chg_*, by(state)
save `state_data', replace

* --- STATE MAPPING LOOP ---
foreach var in `all_vars' {
    local clean_title ""
    if "`var'" == "partd_opioid_rate" local clean_title "Opioid Prescribing (Outpatient)"
    if "`var'" == "partd_generic_rate" local clean_title "Generic Prescribing (Outpatient)"
    if "`var'" == "partd_high_cost_rate" local clean_title "High-Cost Drugs (Outpatient)"
    if "`var'" == "partb_em_upcode_rate" local clean_title "E\&M Upcoding (Outpatient)"
    if "`var'" == "mips_final_score" local clean_title "MIPS Final Score (Outpatient)"
    if "`var'" == "mips_quality_score" local clean_title "MIPS Quality Score (Outpatient)"
    if "`var'" == "bene_avg_risk_scre" local clean_title "Patient Risk Score (HCC)"
    if "`var'" == "np_md_ratio" local clean_title "NP to MD Ratio (Outpatient)"
    if "`var'" == "pct_female_md" local clean_title "Female MDs (%)"
    if "`var'" == "pct_female_np" local clean_title "Female NPs (%)"
    if "`var'" == "pct_female_pa" local clean_title "Female PAs (%)"
    if "`var'" == "dual_rate" local clean_title "Dual-Eligible Patients (%)"

    use `state_data', clear
    maptile `var', geo(state) fcolor(Blues) nquantiles(5) ///
        twopt(title("9-Yr Avg: `clean_title'", size(medium))) savegraph("$outRoot/out_patient/maps/national_avg_`var'.png") replace
    
    maptile chg_`var', geo(state) fcolor(Greens) nquantiles(5) ///
        twopt(title("YoY Change: `clean_title'", size(medium))) savegraph("$outRoot/out_patient/maps/national_chg_`var'.png") replace
}

*===============================================================================
* --- NYS ZIP CODE PANEL ---
*===============================================================================
display "--- Building NYS Zip-Code Panel ---"
use "$dataRoot/master_provider_outpatient_asc_2015_2023.dta", clear
capture drop state
decode cms_state, gen(state)
keep if state == "NY"

drop if cms_zip == "" | length(cms_zip) < 5
gen zip5 = substr(cms_zip, 1, 5)
destring zip5, replace force 

decode credential, gen(cred_str)
gen np_count = (cred_str == "NP")
gen pa_count = (cred_str == "PA")
gen md_count = (inlist(cred_str, "MD", "DO"))

gen female_np_count = (is_female == 1 & np_count == 1)
gen female_pa_count = (is_female == 1 & pa_count == 1)
gen female_md_count = (is_female == 1 & md_count == 1)

capture confirm variable bene_dual_cnt
if _rc {
    capture gen bene_dual_cnt = . 
}

collapse (mean) `mean_vars' (sum) `sum_vars', by(zip5 year)

gen np_md_ratio = np_count / md_count
gen pct_female_md = female_md_count / md_count
gen pct_female_np = female_np_count / np_count
gen pct_female_pa = female_pa_count / pa_count
gen dual_rate = bene_dual_cnt / tot_benes

sort zip5 year
foreach var in `all_vars' {
    by zip5: gen chg_`var' = `var' - `var'[_n-1]
}

collapse (mean) `all_vars' chg_*, by(zip5)
save `zip_data', replace

foreach var in `all_vars' {
    local clean_title ""
    if "`var'" == "partd_opioid_rate" local clean_title "Opioid Prescribing"
    if "`var'" == "partd_generic_rate" local clean_title "Generic Prescribing"
    if "`var'" == "partd_high_cost_rate" local clean_title "High-Cost Drugs"
    if "`var'" == "partb_em_upcode_rate" local clean_title "E\&M Upcoding"
    if "`var'" == "mips_final_score" local clean_title "MIPS Final Score"
    if "`var'" == "mips_quality_score" local clean_title "MIPS Quality Score"
    if "`var'" == "bene_avg_risk_scre" local clean_title "Patient Risk Score (HCC)"
    if "`var'" == "np_md_ratio" local clean_title "NP to MD Ratio"
    if "`var'" == "pct_female_md" local clean_title "Female MDs (%)"
    if "`var'" == "pct_female_np" local clean_title "Female NPs (%)"
    if "`var'" == "pct_female_pa" local clean_title "Female PAs (%)"
    if "`var'" == "dual_rate" local clean_title "Dual-Eligible Patients (%)"
    
    use `zip_data', clear
    maptile `var', geo(zip5) fcolor(Reds) nquantiles(5) ///
        twopt(title("NYS Avg: `clean_title'", size(medium))) savegraph("$outRoot/out_patient/maps/nys_zip_avg_`var'.png") replace
        
    maptile chg_`var', geo(zip5) fcolor(Greens) nquantiles(5) ///
        twopt(title("NYS YoY Change: `clean_title'", size(medium))) savegraph("$outRoot/out_patient/maps/nys_zip_chg_`var'.png") replace
}
display "=== OUTPATIENT PROVIDER MAPS COMPLETE ==="