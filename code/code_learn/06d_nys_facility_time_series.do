*===============================================================================
* SCRIPT: 06d_nys_facility_time_series.do
* PURPOSE: Time-Series Line Charts exclusively for NYS Facilities.
* FEATURES: Memory Bug Fix, Comprehensive Health Outcomes, HCAHPS/OAS, Full Dict.
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

local script_name "06d_nys_facility_time_series"
log using "$logRoot/`script_name'.smcl", replace

display "=== STARTING NYS FACILITY TIME SERIES ==="

local in_fac_vars "hcahps_100_score hcahps_grp1 hcahps_grp2 hcahps_grp3 hcahps_grp4 h_hosp_rating_9_10 h_hosp_rating_0_6 hac_total_score rrp_excess_ratio_ami rrp_excess_ratio_hf rrp_excess_ratio_pn mortality_rate_ami mortality_rate_hf mortality_rate_pn mspb_score hvbp_tps_score fac_mips_final_score fac_mips_quality_score fac_mips_pi_score fac_mips_ia_score fac_mips_cost_score hopd_op_8 hopd_op_10 hopd_op_13 hopd_op_18b hopd_op_22 hopd_op_32 hopd_op_36"
local out_fac_vars "oas_100_score oas_grp1 oas_grp2 oas_grp3 oas_rating_9_10 oas_rating_0_6 asc_rate_1 asc_rate_2 asc_rate_8 fac_mips_final_score fac_mips_quality_score fac_mips_pi_score fac_mips_ia_score fac_mips_cost_score"

foreach setting in "in_patient" "out_patient" {
    display "--- NYS Time Series: `setting' Facilities ---"

    * --- 1. DYNAMIC FOLDER CREATION ---
    local baseDir "$outRoot/summary_stats/`setting'/time_series_nys/facility_analysis"
    capture mkdir "$outRoot/summary_stats/`setting'/time_series_nys"
    capture mkdir "`baseDir'"
    
    local subfolders "overall by_ownership"
    foreach sub in `subfolders' {
        capture mkdir "`baseDir'/`sub'"
    }

    * --- 2. LOAD & NYS FILTER ---
    if "`setting'" == "in_patient" {
        use "$dataRoot/master_facility_inpatient_2013_2023.dta", clear
        local loop_vars "`in_fac_vars'"
        duplicates drop ccn year, force
    }
    else {
        use "$dataRoot/master_facility_outpatient_asc_2015_2024.dta", clear
        local loop_vars "`out_fac_vars'"
        capture confirm variable asc_id
        if _rc == 0 duplicates drop asc_id year, force
        else {
            capture confirm variable ccn
            if _rc == 0 duplicates drop ccn year, force
        }
    }

    capture drop state_str
    local st_var "state"
    capture confirm variable cms_state
    if _rc == 0 local st_var "cms_state"
    
    capture decode `st_var', gen(state_str)
    if _rc != 0 {
        capture confirm string variable `st_var'
        if _rc == 0 gen state_str = `st_var'
        else gen state_str = string(`st_var')
    }
    replace state_str = strtrim(strupper(state_str))
    keep if state_str == "NY"

    * --- 3. OWNERSHIP TAXONOMY (Inpatient Only) ---
    capture drop own_str own_category
    gen own_category = .
    if "`setting'" == "in_patient" {
        capture decode ownership, gen(own_str)
        if _rc != 0 {
            capture confirm string variable ownership
            if _rc == 0 gen own_str = ownership
            else gen own_str = string(ownership)
        }
        replace own_category = 1 if $cond_own_gov
        replace own_category = 2 if $cond_own_forprof
        replace own_category = 3 if $cond_own_nonprof
        label define own_lbl 1 "Government" 2 "For-Profit" 3 "Non-Profit"
        capture label values own_category own_lbl
    }

    tempfile fac_clean
    save `fac_clean', replace

    * FIX: Safely build plotting list before any data collapses occur
    local plot_vars ""
    foreach v in `loop_vars' {
        capture confirm variable `v'
        if _rc == 0 local plot_vars "`plot_vars' `v'"
    }

    * --- 4. VISUALIZATION LOOP ---
    foreach var in `plot_vars' {
        
        * ==========================================
        * COMPREHENSIVE FACILITY DICTIONARY
        * ==========================================
        local clean_title = strproper(subinstr("`var'", "_", " ", .))
        local dir_note "Metric: `var'"

        if "`var'" == "hcahps_100_score" {
            local clean_title "Overall HCAHPS Score"
            local dir_note "Score: 0-100 linear mean score representing patient satisfaction. Higher is better."
        }
        else if "`var'" == "hcahps_grp1" {
            local clean_title "HCAHPS: Staff Communication"
            local dir_note "Score: 0-100 composite for Staff Communication (Nurses and Doctors). Higher is better."
        }
        else if "`var'" == "hcahps_grp2" {
            local clean_title "HCAHPS: Patient Help"
            local dir_note "Score: 0-100 composite for Providing Patient Help (Responsiveness & Meds). Higher is better."
        }
        else if "`var'" == "hcahps_grp3" {
            local clean_title "HCAHPS: Environment"
            local dir_note "Score: 0-100 composite for Facility Environment (Cleanliness & Quietness). Higher is better."
        }
        else if "`var'" == "hcahps_grp4" {
            local clean_title "HCAHPS: Global Rating"
            local dir_note "Score: 0-100 composite for Global Rating and Recommendation. Higher is better."
        }
        else if "`var'" == "h_hosp_rating_9_10" {
            local clean_title "HCAHPS: Rating 9 or 10"
            local dir_note "Rate: Percentage of patients rating the hospital a 9 or 10 overall. Higher is better."
        }
        else if "`var'" == "h_hosp_rating_0_6" {
            local clean_title "HCAHPS: Rating 0 to 6"
            local dir_note "Rate: Percentage of patients rating the hospital a 0 to 6 overall. Lower is better."
        }
        else if "`var'" == "hac_total_score" {
            local clean_title "HAC Penalty Score"
            local dir_note "Score: 1-10 Hospital-Acquired Condition index. Higher means worse safety (penalized > 6.75)."
        }
        else if strpos("`var'", "rrp_excess_ratio") > 0 {
            local disease = upper(substr("`var'", 18, .))
            local clean_title "Readmission Reduction: `disease' Ratio"
            local dir_note "Ratio: Observed divided by Expected (O/E) readmissions. Ratio > 1.0 triggers Medicare penalties."
        }
        else if strpos("`var'", "mortality_rate") > 0 {
            local disease = upper(substr("`var'", 16, .))
            local clean_title "30-Day `disease' Mortality"
            local dir_note "Rate: 30-Day risk-standardized mortality rate. Lower is better."
        }
        else if "`var'" == "mspb_score" {
            local clean_title "Medicare Spending Per Beneficiary"
            local dir_note "Ratio: Hospital spending divided by the national median (1.0 = Average). Lower is more efficient."
        }
        else if "`var'" == "hvbp_tps_score" {
            local clean_title "Value-Based Purchasing Score"
            local dir_note "Score: 0-100 Total Performance Score across efficiency and quality. Higher is better."
        }
        else if "`var'" == "hopd_op_8" {
            local clean_title "HOPD Metric: OP-8"
            local dir_note "Rate: MRI Lumbar Spine for Low Back Pain without prior conservative therapy. Lower is better."
        }
        else if "`var'" == "hopd_op_10" {
            local clean_title "HOPD Metric: OP-10"
            local dir_note "Rate: Abdomen CT with Contrast Material. Lower is better."
        }
        else if "`var'" == "hopd_op_13" {
            local clean_title "HOPD Metric: OP-13"
            local dir_note "Rate: Cardiac Imaging for Preoperative Risk Assessment. Lower is better."
        }
        else if "`var'" == "hopd_op_18b" {
            local clean_title "HOPD Metric: OP-18b"
            local dir_note "Time: Median time from ED arrival to ED departure (in minutes). Lower is better."
        }
        else if "`var'" == "hopd_op_22" {
            local clean_title "HOPD Metric: OP-22"
            local dir_note "Rate: Percentage of patients who left the ED without being seen. Lower is better."
        }
        else if "`var'" == "hopd_op_32" {
            local clean_title "HOPD Metric: OP-32"
            local dir_note "Rate: Facility rate of colonoscopy screening median time. Lower is better."
        }
        else if "`var'" == "hopd_op_36" {
            local clean_title "HOPD Metric: OP-36"
            local dir_note "Rate: Facility rate of unplanned hospital visits after outpatient surgery. Lower is better."
        }
        else if "`var'" == "asc_rate_1" {
            local clean_title "ASC-1: Patient Burns Rate"
            local dir_note "Rate: Percentage of patients experiencing a burn prior to discharge. Lower is better."
        }
        else if "`var'" == "asc_rate_2" {
            local clean_title "ASC-2: Patient Falls Rate"
            local dir_note "Rate: Percentage of patients experiencing a fall within the ASC. Lower is better."
        }
        else if "`var'" == "asc_rate_8" {
            local clean_title "ASC-8: Influenza Vaccination Coverage"
            local dir_note "Rate: Percentage of healthcare personnel vaccinated for influenza. Higher is better."
        }
        else if "`var'" == "oas_100_score" {
            local clean_title "Overall OAS CAHPS Score"
            local dir_note "Score: 0-100 linear mean score representing patient satisfaction at the ASC. Higher is better."
        }
        else if "`var'" == "oas_grp1" {
            local clean_title "OAS CAHPS: Communication"
            local dir_note "Score: 0-100 composite for Patient Communication."
        }
        else if "`var'" == "oas_grp2" {
            local clean_title "OAS CAHPS: Care & Cleanliness"
            local dir_note "Score: 0-100 composite for Professional Care and Facility Cleanliness."
        }
        else if "`var'" == "oas_grp3" {
            local clean_title "OAS CAHPS: Prep & Discharge"
            local dir_note "Score: 0-100 composite for Preparation and Discharge."
        }
        else if "`var'" == "oas_rating_9_10" {
            local clean_title "OAS CAHPS: Rating 9 or 10"
            local dir_note "Rate: Percentage of patients rating the ASC a 9 or 10 overall. Higher is better."
        }
        else if "`var'" == "oas_rating_0_6" {
            local clean_title "OAS CAHPS: Rating 0 to 6"
            local dir_note "Rate: Percentage of patients rating the ASC a 0 to 6 overall. Lower is better."
        }
        else if "`var'" == "fac_mips_final_score" {
            local clean_title "Facility Avg: MIPS Final Score"
            local dir_note "Score: 0-100 weighted facility avg of affiliated providers' MIPS composite score."
        }
        else if "`var'" == "fac_mips_quality_score" {
            local clean_title "Facility Avg: MIPS Quality"
            local dir_note "Score: 0-100 weighted facility avg of affiliated providers' MIPS Quality domain."
        }
        else if "`var'" == "fac_mips_pi_score" {
            local clean_title "Facility Avg: MIPS PI"
            local dir_note "Score: 0-100 weighted facility avg of MIPS Promoting Interoperability (EHR) domain."
        }
        else if "`var'" == "fac_mips_ia_score" {
            local clean_title "Facility Avg: MIPS Improvement"
            local dir_note "Score: 0-100 weighted facility avg of affiliated providers' MIPS Improvement Activities domain."
        }
        else if "`var'" == "fac_mips_cost_score" {
            local clean_title "Facility Avg: MIPS Cost"
            local dir_note "Score: 0-100 weighted facility avg of affiliated providers' MIPS Cost domain."
        }

        local own_note "Ownership: Categorized as Government, For-Profit, or Non-Profit."
        local graph_margin "margin(l+2 r+2 b+15)"
        
        * A. Overall
        use `fac_clean', clear
        capture drop if missing(`var')
        count
        if r(N) > 0 {
            collapse (mean) `var', by(year)
            if _N > 0 {
                twoway (connected `var' year, lcolor(navy) lwidth(medthick) msymbol(O)), ///
                    title("NYS Overall: `clean_title'", size(medium) color(black)) ///
                    ytitle("Mean Value") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                    note("`dir_note'", position(7) size(vsmall) margin(t=3 l=2) span) graphregion(color(white) `graph_margin')
                capture graph export "`baseDir'/overall/ts_overall_`var'.png", replace width(2000)
            }
        }

        * B. By Ownership (INPATIENT ONLY)
        if "`setting'" == "in_patient" {
            use `fac_clean', clear
            capture drop if missing(`var') | missing(own_category)
            count
            if r(N) > 0 {
                collapse (mean) `var', by(year own_category)
                if _N > 0 {
                    twoway (connected `var' year if own_category==1, lcolor(navy) msymbol(O)) ///
                           (connected `var' year if own_category==2, lcolor(cranberry) msymbol(S)) ///
                           (connected `var' year if own_category==3, lcolor(emerald) msymbol(D)), ///
                        title("NYS `clean_title' by Ownership", size(medium) color(black)) ///
                        ytitle("Mean Value") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                        legend(order(1 "Gov" 2 "For-Profit" 3 "Non-Profit") position(6) rows(1)) ///
                        note("`dir_note' `own_note'", position(7) size(vsmall) margin(t=3 l=2) span) graphregion(color(white) `graph_margin')
                    capture graph export "`baseDir'/by_ownership/ts_own_`var'.png", replace width(2000)
                }
            }
        }
    }
}
display "=== NYS FACILITY TIME SERIES COMPLETE ==="
