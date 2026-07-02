*===============================================================================
* SCRIPT: 01_macro_inpatient_stats.do
* PURPOSE: "Kitchen Sink" summary stats for Inpatient Facilities (CSV Outputs)
* FEATURES: Deltas, Global Macro Integration, HCAHPS Sub-Metrics
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

display "=== STARTING MACRO STATS FOR: INPATIENT FACILITIES ==="

* --- 1. EXTRACT DATA FROM PROVIDERS (FACILITY AGGREGATES) ---
use "$dataRoot/master_provider_inpatient_2013_2023.dta", clear
drop if missing(ccn)

* Leveraging Initialize globals where applicable
decode cms_specialty, gen(spec_str)
gen prov_type = "MD_DO"
replace prov_type = "NP" if spec_str == "NURSE PRACTITIONER"
replace prov_type = "PA" if spec_str == "PHYSICIAN ASSISTANT"

gen count_md = (prov_type == "MD_DO")
gen count_np = (prov_type == "NP")
gen count_pa = (prov_type == "PA")
gen count_tot = 1

collapse (sum) count_* ///
         (mean) partd_opioid_rate partb_em_upcode_rate partb_low_value_rate partb_imaging_adv_rate ///
                mips_final_score mips_quality_score mips_pi_score mips_ia_score mips_cost_score ///
         [aw=tot_benes], by(ccn year)

gen pct_md = count_md / count_tot
gen pct_np = count_np / count_tot
gen pct_pa = count_pa / count_tot

tempfile fac_aggregates
save `fac_aggregates', replace

* --- 2. LOAD FACILITY MASTER & MERGE ---
use "$dataRoot/master_facility_inpatient_2013_2023.dta", clear
merge 1:1 ccn year using `fac_aggregates', keep(master match) nogen

* --- 3. APPLY TAXONOMIES FROM INITIALIZE.DO ---
capture confirm string variable state
if _rc != 0 decode state, gen(state_str)
else gen state_str = state
replace state_str = strtrim(strupper(state_str))

* Using the globals from 00_initialize.do
gen np_authority = .
replace np_authority = 3 if $cond_full_prac
replace np_authority = 2 if $cond_red_prac
replace np_authority = 1 if $cond_res_prac

label define auth_lbl 1 "Restricted" 2 "Reduced" 3 "Full Practice"
label values np_authority auth_lbl

capture confirm string variable ownership
if _rc != 0 decode ownership, gen(own_str)
else gen own_str = ownership

* Using the globals from 00_initialize.do
gen own_category = .
replace own_category = 1 if $cond_own_gov
replace own_category = 2 if $cond_own_forprof
replace own_category = 3 if $cond_own_nonprof

label define own_lbl 1 "Government" 2 "For-Profit" 3 "Non-Profit"
label values own_category own_lbl

* --- 4. GENERATE DELTAS (YEAR-OVER-YEAR CHANGE) ---
egen panel_id = group(ccn)
xtset panel_id year

local base_vars "hcahps_100_score hcahps_grp1 hcahps_grp2 hcahps_grp3 hcahps_grp4 h_hosp_rating_9_10 h_hosp_rating_0_6 hac_total_score rrp_excess_ratio_ami rrp_excess_ratio_hf rrp_excess_ratio_pn mortality_rate_ami mortality_rate_hf mortality_rate_pn mspb_score hvbp_tps_score partd_opioid_rate partb_em_upcode_rate partb_low_value_rate partb_imaging_adv_rate mips_final_score pct_np pct_md pct_pa hopd_op_8 hopd_op_10 hopd_op_13 hopd_op_18b hopd_op_22 hopd_op_32 hopd_op_36"

local all_vars ""
foreach var in `base_vars' {
    capture confirm variable `var'
    if _rc == 0 {
        gen d_`var' = `var' - L.`var'
        local all_vars "`all_vars' `var' d_`var'"
    }
}

* --- 5. FOLDER ARCHITECTURE ---
local outDir "$outRoot/in_patient/macro_stats"
capture mkdir "`outDir'"
capture mkdir "`outDir'/tables_csv"
capture mkdir "`outDir'/bar_graphs"

* --- 6. THE MASTER OUTPUT LOOP ---
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
    if "`base_var'" == "hcahps_100_score" {
        local clean_title "Overall HCAHPS Score"
        local dir_note "Score: 0-100 linear mean score representing patient satisfaction. Higher is better."
    }
    else if "`base_var'" == "hcahps_grp1" {
        local clean_title "HCAHPS: Staff Communication"
        local dir_note "Score: 0-100 composite for Staff Communication (Nurses and Doctors). Higher is better."
    }
    else if "`base_var'" == "hcahps_grp2" {
        local clean_title "HCAHPS: Patient Help"
        local dir_note "Score: 0-100 composite for Providing Patient Help (Responsiveness & Meds). Higher is better."
    }
    else if "`base_var'" == "hcahps_grp3" {
        local clean_title "HCAHPS: Environment"
        local dir_note "Score: 0-100 composite for Facility Environment (Cleanliness & Quietness). Higher is better."
    }
    else if "`base_var'" == "hcahps_grp4" {
        local clean_title "HCAHPS: Global Rating"
        local dir_note "Score: 0-100 composite for Global Rating and Recommendation. Higher is better."
    }
    else if "`base_var'" == "h_hosp_rating_9_10" {
        local clean_title "HCAHPS: Rating 9 or 10"
        local dir_note "Rate: Percentage of patients rating the hospital a 9 or 10 overall. Higher is better."
    }
    else if "`base_var'" == "h_hosp_rating_0_6" {
        local clean_title "HCAHPS: Rating 0 to 6"
        local dir_note "Rate: Percentage of patients rating the hospital a 0 to 6 overall. Lower is better."
    }
    else if "`base_var'" == "hac_total_score" {
        local clean_title "HAC Penalty Score"
        local dir_note "Score: 1-10 Hospital-Acquired Condition index. Higher means worse safety (penalized > 6.75)."
    }
    else if strpos("`base_var'", "rrp_excess_ratio") > 0 {
        local disease = upper(substr("`base_var'", 18, .))
        local clean_title "Readmission Reduction: `disease' Ratio"
        local dir_note "Ratio: Observed divided by Expected (O/E) readmissions. Ratio > 1.0 triggers Medicare penalties."
    }
    else if strpos("`base_var'", "mortality_rate") > 0 {
        local disease = upper(substr("`base_var'", 16, .))
        local clean_title "30-Day `disease' Mortality"
        local dir_note "Rate: 30-Day risk-standardized mortality rate. Lower is better."
    }
    else if "`base_var'" == "mspb_score" {
        local clean_title "Medicare Spending Per Beneficiary"
        local dir_note "Ratio: Hospital spending divided by the national median (1.0 = Average). Lower is more efficient."
    }
    else if "`base_var'" == "hvbp_tps_score" {
        local clean_title "Value-Based Purchasing Score"
        local dir_note "Score: 0-100 Total Performance Score across efficiency and quality. Higher is better."
    }
    else if "`base_var'" == "partb_em_upcode_rate" {
        local clean_title "Facility Average: E&M Upcode Rate"
        local dir_note "Rate: Percentage of E&M visits billed as high-intensity Level 4/5 by affiliated staff."
    }
    else if "`base_var'" == "partd_opioid_rate" {
        local clean_title "Opioid Prescribing Rate"
        local dir_note "Rate: Percentage of total Part D claims for opioids by affiliated staff."
    }
    else if "`base_var'" == "partb_low_value_rate" {
        local clean_title "Low-Value Care Rate"
        local dir_note "Rate: Percentage of services categorized as 'Choosing Wisely' discouraged."
    }
    else if "`base_var'" == "partb_imaging_adv_rate" {
        local clean_title "Advanced Imaging Rate"
        local dir_note "Rate: Percentage of imaging claims representing CT/MRI/PET vs standard x-ray."
    }
    else if "`base_var'" == "mips_final_score" {
        local clean_title "Facility Average: MIPS Final Score"
        local dir_note "Score: 0-100 composite payment adjustment score for affiliated staff. Higher is better."
    }
    else if "`base_var'" == "pct_np" {
        local clean_title "Workforce Proportion: NPs"
        local dir_note "Percentage: NPs divided by total billing MD/DO/PA/NPs at the facility."
    }
    else if "`base_var'" == "pct_pa" {
        local clean_title "Workforce Proportion: PAs"
        local dir_note "Percentage: PAs divided by total billing MD/DO/PA/NPs at the facility."
    }
    else if "`base_var'" == "pct_md" {
        local clean_title "Workforce Proportion: MD/DOs"
        local dir_note "Percentage: MD/DOs divided by total billing MD/DO/PA/NPs at the facility."
    }
    else if "`base_var'" == "hopd_op_8" {
        local clean_title "HOPD Metric: OP-8"
        local dir_note "Rate: MRI Lumbar Spine for Low Back Pain without prior conservative therapy. Lower is better."
    }
    else if "`base_var'" == "hopd_op_10" {
        local clean_title "HOPD Metric: OP-10"
        local dir_note "Rate: Abdomen CT with Contrast Material. Lower is better."
    }
    else if "`base_var'" == "hopd_op_13" {
        local clean_title "HOPD Metric: OP-13"
        local dir_note "Rate: Cardiac Imaging for Preoperative Risk Assessment. Lower is better."
    }
    else if "`base_var'" == "hopd_op_18b" {
        local clean_title "HOPD Metric: OP-18b"
        local dir_note "Time: Median time from ED arrival to ED departure (in minutes). Lower is better."
    }
    else if "`base_var'" == "hopd_op_22" {
        local clean_title "HOPD Metric: OP-22"
        local dir_note "Rate: Percentage of patients who left the ED without being seen. Lower is better."
    }
    else if "`base_var'" == "hopd_op_32" {
        local clean_title "HOPD Metric: OP-32"
        local dir_note "Rate: Unplanned hospital visits within 7 days of outpatient colonoscopy. Lower is better."
    }
    else if "`base_var'" == "hopd_op_36" {
        local clean_title "HOPD Metric: OP-36"
        local dir_note "Rate: Unplanned hospital visits within 7 days of outpatient surgery. Lower is better."
    }
    else {
        local clean_title = strproper(subinstr("`base_var'", "_", " ", .))
        local dir_note "Variable: `base_var'."
    }

    if `is_delta' == 1 {
        local clean_title "Change in `clean_title'"
        local dir_note "Outcome represents year-over-year absolute change. Baseline Metric: `dir_note'"
    }

    * Note text for Stata drafts (will be fully expanded in Python)
    local np_note "NP Law: Categorization reflects static 2023 regulatory status."
    local own_note "Ownership: Gov (Fed/State/Local), For-Profit (Proprietary), Non-Profit (Private/Church)."

    *--------------------------------------------------
    * B. GENERATE RAW CSV TABLES
    *--------------------------------------------------
    preserve
    drop if missing(`var') | missing(np_authority)
    collapse (mean) mean_val=`var' (sd) sd_val=`var' (count) n_val=`var', by(np_authority)
    export delimited using "`outDir'/tables_csv/`var'_by_authority.csv", replace
    restore

    preserve
    drop if missing(`var') | missing(np_authority) | missing(own_category)
    collapse (mean) mean_val=`var' (sd) sd_val=`var' (count) n_val=`var', by(np_authority own_category)
    export delimited using "`outDir'/tables_csv/`var'_by_auth_ownership.csv", replace
    restore

    preserve
    drop if missing(`var')
    gen overall = "National"
    collapse (mean) mean_val=`var' (sd) sd_val=`var' (count) n_val=`var', by(overall)
    export delimited using "`outDir'/tables_csv/`var'_universal.csv", replace
    restore

    *--------------------------------------------------
    * C. BAR GRAPHS
    *--------------------------------------------------
    capture graph bar (mean) `var', over(own_category, label(angle(0) labsize(small))) ///
        over(np_authority) ///
        ytitle("Mean Value") ///
        title("`clean_title'", size(medium) color(black)) ///
        subtitle("By Hospital Ownership and State NP Law", size(small)) ///
        note("`dir_note'" "`np_note'" "`own_note'", position(7) justification(left) size(vsmall) margin(t=3 l=2) span) ///
        blabel(bar, format(%9.3f) size(vsmall)) ///
        graphregion(color(white) margin(vsmall))
    
    capture graph export "`outDir'/bar_graphs/`var'_bar.png", replace width(2400)
    capture graph drop _all
}

display "=== INPATIENT MACRO STATS COMPLETE ==="
