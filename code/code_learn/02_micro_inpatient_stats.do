*===============================================================================
* SCRIPT: 02_micro_inpatient_stats.do
* PURPOSE: Summary stats for Individual Providers (Micro Inpatient Panel).
* FEATURES: Deltas, MIPS Sub-Scores, Timeline CSVs, Subfolders, Full Dictionary
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* --- START LOG ---
local script_name "02_micro_inpatient_stats"
log using "$logRoot/`script_name'.smcl", replace
* -----------------

display "=== STARTING MICRO STATS FOR: INPATIENT PROVIDERS ==="

use "$dataRoot/master_provider_inpatient_2013_2023.dta", clear

capture confirm string variable cms_specialty
if _rc != 0 decode cms_specialty, gen(spec_str)
else gen spec_str = cms_specialty

gen prov_type = 1 
replace prov_type = 2 if strpos(upper(spec_str), "NURSE PRACTITIONER") > 0
replace prov_type = 3 if strpos(upper(spec_str), "PHYSICIAN ASSISTANT") > 0
label define pt_lbl 1 "MD/DO" 2 "Nurse Practitioner" 3 "Physician Assistant"
label values prov_type pt_lbl

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

* Micro Provider Logic: Drop CCN duplicates to isolate pure provider behavior
duplicates drop npi year, force
egen panel_id = group(npi)
xtset panel_id year

local base_vars "partd_generic_rate partd_opioid_rate partb_em_upcode_rate mips_final_score mips_quality_score mips_pi_score mips_ia_score mips_cost_score bene_avg_risk_scre tot_benes tot_sbmtd_chrg"

local all_vars ""
foreach var in `base_vars' {
    capture confirm variable `var'
    if _rc == 0 {
        gen d_`var' = `var' - L.`var'
        local all_vars "`all_vars' `var' d_`var'"
    }
}

local outDir "$outRoot/summary_stats/in_patient/micro_stats"
capture mkdir "`outDir'"
capture mkdir "`outDir'/tables_csv"
capture mkdir "`outDir'/bar_graphs"
capture mkdir "`outDir'/bar_graphs/full_sample"
capture mkdir "`outDir'/bar_graphs/by_year"

foreach var in `all_vars' {
    local base_var = "`var'"
    local is_delta = 0
    if substr("`var'", 1, 2) == "d_" {
        local base_var = substr("`var'", 3, .)
        local is_delta = 1
    }

    *--------------------------------------------------
    * A. RIGOROUS DATA DICTIONARY
    *--------------------------------------------------
    if "`base_var'" == "partd_generic_rate" {
        local clean_title "Generic Prescribing Rate"
        local dir_note "Rate: Proportion of total Part D prescriptions filled with generic drugs. Higher implies cost efficiency."
    }
    else if "`base_var'" == "partd_opioid_rate" {
        local clean_title "Opioid Prescribing Rate"
        local dir_note "Rate: Proportion of total Part D claims that are Schedule II/III opioids."
    }
    else if "`base_var'" == "partb_em_upcode_rate" {
        local clean_title "Provider E&M Upcode Rate"
        local dir_note "Rate: Proportion of total E&M visits billed at the highest intensity (Level 4/5)."
    }
    else if "`base_var'" == "mips_final_score" {
        local clean_title "MIPS Final Score"
        local dir_note "Score: 0-100 composite payment adjustment score. Higher reflects better overall clinical value."
    }
    else if "`base_var'" == "mips_quality_score" {
        local clean_title "MIPS Quality Domain"
        local dir_note "Score: 0-100 performance on evidence-based quality measures."
    }
    else if "`base_var'" == "mips_pi_score" {
        local clean_title "MIPS Promoting Interoperability"
        local dir_note "Score: 0-100 performance on EHR integration and patient data access."
    }
    else if "`base_var'" == "mips_ia_score" {
        local clean_title "MIPS Improvement Activities"
        local dir_note "Score: 0-100 performance on practice improvements like care coordination."
    }
    else if "`base_var'" == "mips_cost_score" {
        local clean_title "MIPS Cost Domain"
        local dir_note "Score: 0-100 performance on total cost of care / resource use."
    }
    else if "`base_var'" == "bene_avg_risk_scre" {
        local clean_title "Average Patient Risk Score (HCC)"
        local dir_note "Score: Hierarchical Condition Category (HCC) risk score. Higher implies a more complex/sicker panel."
    }
    else if "`base_var'" == "tot_benes" {
        local clean_title "Total Beneficiaries Treated"
        local dir_note "Count: Total number of unique Medicare beneficiaries treated by the provider."
    }
    else if "`base_var'" == "tot_sbmtd_chrg" {
        local clean_title "Total Submitted Charges"
        local dir_note "Financial: Total dollars billed to Medicare by the provider."
    }
    else {
        local clean_title = strproper(subinstr("`base_var'", "_", " ", .))
        local dir_note "Variable: `base_var'."
    }
    
    if `is_delta' == 1 {
        local clean_title "Change in `clean_title'"
        local dir_note "Outcome represents year-over-year absolute change. Baseline Metric: `dir_note'"
    }

    local np_note "NP Law: Categorization reflects static 2023 regulatory status."
    local prov_note "Provider: MD/DO (Physician), NP (Nurse Practitioner), PA (Physician Assistant)."

    *--------------------------------------------------
    * B. GENERATE RAW CSV TABLES
    *--------------------------------------------------
    preserve
    drop if missing(`var') | missing(np_authority)
    collapse (mean) mean_val=`var' (sd) sd_val=`var' (count) n_val=`var', by(np_authority)
    export delimited using "`outDir'/tables_csv/`var'_by_authority.csv", replace
    restore

    preserve
    drop if missing(`var') | missing(np_authority) | missing(prov_type)
    collapse (mean) mean_val=`var' (sd) sd_val=`var' (count) n_val=`var', by(np_authority prov_type)
    export delimited using "`outDir'/tables_csv/`var'_by_auth_provtype.csv", replace
    restore

    preserve
    drop if missing(`var') | missing(np_authority) | missing(year)
    collapse (mean) mean_val=`var' (sd) sd_val=`var' (count) n_val=`var', by(np_authority year)
    export delimited using "`outDir'/tables_csv/`var'_by_auth_year.csv", replace
    restore

    preserve
    drop if missing(`var')
    gen overall = "National"
    collapse (mean) mean_val=`var' (sd) sd_val=`var' (count) n_val=`var', by(overall)
    export delimited using "`outDir'/tables_csv/`var'_universal.csv", replace
    restore

    preserve
    drop if missing(`var') | missing(year)
    gen overall = "National"
    collapse (mean) mean_val=`var' (sd) sd_val=`var' (count) n_val=`var', by(overall year)
    export delimited using "`outDir'/tables_csv/`var'_universal_by_year.csv", replace
    restore


	*--------------------------------------------------
    * C. BAR GRAPHS
    *--------------------------------------------------
    capture graph bar (mean) `var', over(prov_type, label(angle(0) labsize(small))) ///
        over(np_authority) ytitle("Mean Value (Whole Sample Average)") title("`clean_title'") ///
        note("`dir_note'" "`np_note'" "`prov_note'", size(vsmall)) blabel(bar, format(%9.3f) size(vsmall)) graphregion(color(white) margin(vsmall))
    capture graph export "`outDir'/bar_graphs/full_sample/`var'_overall_bar.png", replace width(2400)

    local blbl ""
    if `is_delta' == 1 { 
        local blbl "blabel(bar, format(%9.3f) size(vsmall))" 
    }
    
    capture graph bar (mean) `var', over(year, label(angle(45) labsize(small))) ///
        over(np_authority) ytitle("Mean Value") title("`clean_title'") ///
        note("`dir_note'" "`np_note'", size(vsmall)) `blbl' graphregion(color(white) margin(vsmall))
    capture graph export "`outDir'/bar_graphs/by_year/`var'_by_year_bar.png", replace width(2400)
    capture graph drop _all
}
display "=== MICRO INPATIENT STATS COMPLETE ==="
