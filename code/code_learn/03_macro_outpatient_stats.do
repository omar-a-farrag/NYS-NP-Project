*===============================================================================
* SCRIPT: 03_macro_outpatient_stats.do
* PURPOSE: Summary stats for Outpatient Facilities (Ambulatory Surgical Centers).
* FEATURES: Deltas, Global Macro Integration, OAS CAHPS, Facility MIPS
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* --- START LOG ---
local script_name "03_macro_outpatient_stats"
log using "$logRoot/`script_name'.smcl", replace
* -----------------

display "=== STARTING MACRO STATS FOR: OUTPATIENT FACILITIES (ASC) ==="

* Load the Macro Outpatient ASC Panel
use "$dataRoot/master_facility_outpatient_asc_2015_2024.dta", clear

* --- 1. CREATE NP AUTHORITY TAXONOMY ---
capture confirm string variable state
if _rc != 0 decode state, gen(state_str)
else gen state_str = state
replace state_str = strtrim(strupper(state_str))

gen np_authority = .
replace np_authority = 3 if $cond_full_prac
replace np_authority = 2 if $cond_red_prac
replace np_authority = 1 if $cond_res_prac

label define auth_lbl 1 "Restricted" 2 "Reduced" 3 "Full Practice"
label values np_authority auth_lbl

* --- 2. GENERATE DELTAS (YEAR-OVER-YEAR CHANGE) ---
capture confirm variable ccn
if _rc == 0 {
    duplicates drop ccn year, force
    egen panel_id = group(ccn)
}
else {
    capture confirm variable asc_id
    if _rc == 0 {
        duplicates drop asc_id year, force
        egen panel_id = group(asc_id)
    }
}
capture xtset panel_id year

* ADDED: OAS CAHPS patient experience and Aggregated Facility MIPS scores
local base_vars "asc_rate_1 asc_rate_2 asc_rate_8 oas_100_score oas_grp1 oas_grp2 oas_grp3 oas_rating_9_10 oas_rating_0_6 fac_mips_final_score fac_mips_quality_score fac_mips_ia_score fac_mips_pi_score fac_mips_cost_score"

local all_vars ""
foreach var in `base_vars' {
    capture confirm variable `var'
    if _rc == 0 {
        capture gen d_`var' = `var' - L.`var'
        local all_vars "`all_vars' `var' d_`var'"
    }
}

* --- 3. FOLDER ARCHITECTURE ---
local outDir "$outRoot/summary_stats/out_patient/macro_stats"
capture mkdir "`outDir'"
capture mkdir "`outDir'/tables_csv"
capture mkdir "`outDir'/bar_graphs"
capture mkdir "`outDir'/bar_graphs/full_sample"
capture mkdir "`outDir'/bar_graphs/by_year"

* --- 4. THE MASTER OUTPUT LOOP ---
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
    if "`base_var'" == "asc_rate_1" {
        local clean_title "ASC-1: Patient Burns Rate"
        local dir_note "Rate: Percentage of patients experiencing a burn prior to discharge. Lower is better."
    }
    else if "`base_var'" == "asc_rate_2" {
        local clean_title "ASC-2: Patient Falls Rate"
        local dir_note "Rate: Percentage of patients experiencing a fall within the ASC. Lower is better."
    }
    else if "`base_var'" == "asc_rate_8" {
        local clean_title "ASC-8: Influenza Vaccination Coverage"
        local dir_note "Rate: Percentage of healthcare personnel vaccinated for influenza. Higher is better."
    }
    else if "`base_var'" == "oas_100_score" {
        local clean_title "Overall OAS CAHPS Score"
        local dir_note "Score: 0-100 linear mean score representing patient satisfaction at the ASC. Higher is better."
    }
    else if "`base_var'" == "oas_grp1" {
        local clean_title "OAS CAHPS: Communication"
        local dir_note "Score: 0-100 composite for Patient Communication."
    }
    else if "`base_var'" == "oas_grp2" {
        local clean_title "OAS CAHPS: Care & Cleanliness"
        local dir_note "Score: 0-100 composite for Professional Care and Facility Cleanliness."
    }
    else if "`base_var'" == "oas_grp3" {
        local clean_title "OAS CAHPS: Prep & Discharge"
        local dir_note "Score: 0-100 composite for Preparation and Discharge."
    }
    else if "`base_var'" == "oas_rating_9_10" {
        local clean_title "OAS CAHPS: Rating 9 or 10"
        local dir_note "Rate: Percentage of patients rating the ASC a 9 or 10 overall. Higher is better."
    }
    else if "`base_var'" == "oas_rating_0_6" {
        local clean_title "OAS CAHPS: Rating 0 to 6"
        local dir_note "Rate: Percentage of patients rating the ASC a 0 to 6 overall. Lower is better."
    }
    else if "`base_var'" == "fac_mips_final_score" {
        local clean_title "Facility Avg: MIPS Final Score"
        local dir_note "Score: 0-100 weighted facility average of affiliated providers' MIPS composite score."
    }
    else if "`base_var'" == "fac_mips_quality_score" {
        local clean_title "Facility Avg: MIPS Quality"
        local dir_note "Score: 0-100 weighted facility average of affiliated providers' MIPS Quality domain."
    }
    else if "`base_var'" == "fac_mips_ia_score" {
        local clean_title "Facility Avg: MIPS Improvement"
        local dir_note "Score: 0-100 weighted facility average of affiliated providers' MIPS Improvement Activities domain."
    }
    else if "`base_var'" == "fac_mips_pi_score" {
        local clean_title "Facility Avg: MIPS PI"
        local dir_note "Score: 0-100 weighted facility avg of MIPS Promoting Interoperability (EHR) domain."
    }
    else if "`base_var'" == "fac_mips_cost_score" {
        local clean_title "Facility Avg: MIPS Cost"
        local dir_note "Score: 0-100 weighted facility average of affiliated providers' MIPS Cost domain."
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

	*--------------------------------------------------
    * B. GENERATE RAW CSV TABLES
    *--------------------------------------------------
    * 1. Full Sample by Authority
    preserve
    drop if missing(`var') | missing(np_authority)
    collapse (mean) mean_val=`var' (sd) sd_val=`var' (count) n_val=`var', by(np_authority)
    export delimited using "`outDir'/tables_csv/`var'_by_authority.csv", replace
    restore

    * 2. Timeline by Authority & Year
    preserve
    drop if missing(`var') | missing(np_authority) | missing(year)
    collapse (mean) mean_val=`var' (sd) sd_val=`var' (count) n_val=`var', by(np_authority year)
    export delimited using "`outDir'/tables_csv/`var'_by_auth_year.csv", replace
    restore

    * 3. Universal Average (Full Sample)
    preserve
    drop if missing(`var')
    gen overall = "National"
    collapse (mean) mean_val=`var' (sd) sd_val=`var' (count) n_val=`var', by(overall)
    export delimited using "`outDir'/tables_csv/`var'_universal.csv", replace
    restore

    * 4. Universal Average (By Year)
    preserve
    drop if missing(`var') | missing(year)
    gen overall = "National"
    collapse (mean) mean_val=`var' (sd) sd_val=`var' (count) n_val=`var', by(overall year)
    export delimited using "`outDir'/tables_csv/`var'_universal_by_year.csv", replace
    restore
	
	*--------------------------------------------------
    * C. BAR GRAPHS
    *--------------------------------------------------
    
    * 1. WHOLE SAMPLE (Overall Average)
    * Always keep the bar labels here since there is plenty of space
    capture graph bar (mean) `var', over(np_authority, label(angle(0) labsize(small))) ///
        ytitle("Mean Value (Whole Sample Average)") ///
        title("`clean_title'", size(medium) color(black)) ///
        subtitle("Overall Average by State NP Law (2015-2024)", size(small)) ///
        note("`dir_note'" "`np_note'", position(7) justification(left) size(vsmall) margin(t=3 l=2) span) ///
        blabel(bar, format(%9.3f) size(vsmall)) ///
        graphregion(color(white) margin(vsmall))
    
	capture graph export "`outDir'/bar_graphs/full_sample/`var'_overall_bar.png", replace width(2400)
	
    * 2. BY-YEAR TIMELINE
    * Only apply bar labels if it is a Delta variable to prevent text overlap on the levels
    local blabel_cmd ""
    if `is_delta' == 1 {
        local blabel_cmd "blabel(bar, format(%9.3f) size(vsmall))"
    }

    capture graph bar (mean) `var', over(year, label(angle(45) labsize(small))) ///
        over(np_authority) ///
        ytitle("Mean Value") ///
        title("`clean_title'", size(medium) color(black)) ///
        subtitle("By Year and State NP Law", size(small)) ///
        note("`dir_note'" "`np_note'", position(7) justification(left) size(vsmall) margin(t=3 l=2) span) ///
        `blabel_cmd' ///
        graphregion(color(white) margin(vsmall))
    
	capture graph export "`outDir'/bar_graphs/by_year/`var'_by_year_bar.png", replace width(2400)    
    
    capture graph drop _all
}

display "=== MACRO OUTPATIENT STATS COMPLETE ==="