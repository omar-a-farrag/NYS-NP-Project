*===============================================================================
* SCRIPT: 06b_facility_time_series.do
* PURPOSE: Time-Series Line Charts for Facility Outcomes.
* FEATURES: Pre-Collapse Count Protections, Clean Footnotes, Ownership Handling
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* Define the variables
local in_vars "hcahps_100_score hcahps_grp1 hcahps_grp2 hcahps_grp3 hcahps_grp4 h_hosp_rating_9_10 h_hosp_rating_0_6 hac_total_score rrp_excess_ratio_ami rrp_excess_ratio_hf rrp_excess_ratio_pn mortality_rate_ami mortality_rate_hf mortality_rate_pn mspb_score hvbp_tps_score fac_mips_final_score fac_mips_quality_score fac_mips_pi_score fac_mips_ia_score fac_mips_cost_score hopd_op_8 hopd_op_10 hopd_op_13 hopd_op_18b hopd_op_22 hopd_op_32 hopd_op_36"
local out_vars "oas_100_score oas_grp1 oas_grp2 oas_grp3 oas_rating_9_10 oas_rating_0_6 asc_rate_1 asc_rate_2 asc_rate_8 fac_mips_final_score fac_mips_quality_score fac_mips_pi_score fac_mips_ia_score fac_mips_cost_score"

foreach setting in "in_patient" "out_patient" {
    display "=== STARTING TIME SERIES FOR: `setting' FACILITIES ==="

    * --- 1. DYNAMIC FOLDER CREATION ---
    local subfolders "overall by_ownership by_authority"
    foreach sub in `subfolders' {
        capture mkdir "$outRoot/summary_stats/`setting'/time_series/facility_analysis/`sub'"
    }

    * --- 2. LOAD & CLEAN DATA ---
    if "`setting'" == "in_patient" {
        use "$dataRoot/master_facility_inpatient_2013_2023.dta", clear
        local loop_vars "`in_vars'"
        duplicates drop ccn year, force
    }
    else {
        use "$dataRoot/master_facility_outpatient_asc_2015_2024.dta", clear
        local loop_vars "`out_vars'"
        capture confirm variable asc_id
        if _rc == 0 duplicates drop asc_id year, force
        else {
            capture confirm variable ccn
            if _rc == 0 duplicates drop ccn year, force
        }
    }

    * A. State Authority 
    capture drop state_str np_authority
    
    local st_var "state"
    capture confirm variable cms_state
    if _rc == 0 local st_var "cms_state"
    
    capture decode `st_var', gen(state_str)
    capture gen state_str = `st_var'
    replace state_str = strtrim(strupper(state_str))
    
    gen np_authority = .
    replace np_authority = 3 if $cond_full_prac
    replace np_authority = 2 if $cond_red_prac
    replace np_authority = 1 if $cond_res_prac
    label define auth_lbl 1 "Restricted" 2 "Reduced" 3 "Full Practice"
    capture label values np_authority auth_lbl

    * B. Ownership (Inpatient ONLY)
    capture drop own_str own_category
    gen own_category = .
    
    if "`setting'" == "in_patient" {
        capture decode ownership, gen(own_str)
        capture gen own_str = ownership
        
        replace own_category = 1 if $cond_own_gov
        replace own_category = 2 if $cond_own_forprof
        replace own_category = 3 if $cond_own_nonprof
        label define own_lbl 1 "Government" 2 "For-Profit" 3 "Non-Profit"
        capture label values own_category own_lbl
    }

    tempfile master_clean
    save `master_clean', replace

    * --- 3. VISUALIZATION LOOP ---
    foreach var in `loop_vars' {
        
        * A. RIGOROUS DICTIONARY 
        local clean_title = strproper(subinstr("`var'", "_", " ", .))
        local dir_note "Metric: `var'"
        
        if "`var'" == "hcahps_100_score" | "`var'" == "oas_100_score" {
            local clean_title "Overall Patient Satisfaction Score"
            local dir_note "0-100 linear mean score representing overall patient satisfaction."
        }
        else if strpos("`var'", "rrp_excess_ratio") > 0 {
            local disease = upper(substr("`var'", 18, .))
            local clean_title "Readmission Ratio: `disease'"
            local dir_note "Observed/Expected readmissions for `disease'. >1.0 triggers penalties."
        }
        else if strpos("`var'", "mortality_rate") > 0 {
            local disease = upper(substr("`var'", 16, .))
            local clean_title "Mortality Rate: `disease'"
            local dir_note "30-Day risk-standardized mortality rate for `disease'."
        }
        else if strpos("`var'", "mips") > 0 {
            local clean_title "Facility MIPS: `var'"
            local dir_note "Weighted facility average of affiliated providers' MIPS domains."
        }
        else if strpos("`var'", "asc_rate") > 0 {
            local clean_title "ASC Safety Rate: `var'"
            local dir_note "Percentage rate of adverse outpatient safety events (e.g., burns, falls)."
        }
        else if "`var'" == "hac_total_score" {
            local clean_title "HAC Penalty Score"
            local dir_note "1-10 Hospital-Acquired Condition index. Higher reflects worse safety."
        }

        local np_note "NP Law: Categorization reflects static 2023 regulatory status."
        local own_note "Ownership: Categorized as Government, For-Profit, or Non-Profit."

        * B. Overall Trend
        use `master_clean', clear
        capture drop if missing(`var')
        
        * FIX: Check if observations exist BEFORE collapse
        count
        if r(N) > 0 {
            collapse (mean) `var', by(year)
            if _N > 0 {
                twoway (connected `var' year, lcolor(navy) lwidth(medthick) msymbol(O)), ///
                    title("`clean_title'", size(medium) color(black)) ///
                    ytitle("Mean Value") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                    note("`dir_note'" "`np_note'", position(7) justification(left) size(vsmall) margin(t=3 l=2) span) ///
                    graphregion(color(white) margin(vsmall))
                capture graph export "$outRoot/`setting'/time_series/facility_analysis/overall/ts_overall_`var'.png", replace width(2000)
            }
        }

        * C. By Ownership 
        capture confirm variable own_category
        if _rc == 0 {
            use `master_clean', clear
            capture drop if missing(`var') | missing(own_category)
            
            * FIX: Check if observations exist BEFORE collapse
            count
            if r(N) > 0 {
                collapse (mean) `var', by(year own_category)
                if _N > 0 {
                    twoway (connected `var' year if own_category==1, lcolor(navy) msymbol(O)) ///
                           (connected `var' year if own_category==2, lcolor(cranberry) msymbol(S)) ///
                           (connected `var' year if own_category==3, lcolor(emerald) msymbol(D)), ///
                        title("`clean_title' by Ownership", size(medium) color(black)) ///
                        ytitle("Mean Value") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                        legend(order(1 "Gov" 2 "For-Profit" 3 "Non-Profit") position(6) rows(1)) ///
                        note("`dir_note'" "`own_note'", position(7) justification(left) size(vsmall) margin(t=3 l=2) span) ///
                        graphregion(color(white) margin(vsmall))
                    capture graph export "$outRoot/`setting'/time_series/facility_analysis/by_ownership/ts_own_`var'.png", replace width(2000)
                }
            }
        }

        * D. By Authority
        use `master_clean', clear
        capture drop if missing(`var') | missing(np_authority)
        
        * FIX: Check if observations exist BEFORE collapse
        count
        if r(N) > 0 {
            collapse (mean) `var', by(year np_authority)
            if _N > 0 {
                twoway (connected `var' year if np_authority==1, lcolor(cranberry) msymbol(O)) ///
                       (connected `var' year if np_authority==2, lcolor(orange) msymbol(S)) ///
                       (connected `var' year if np_authority==3, lcolor(emerald) msymbol(D)), ///
                    title("`clean_title' by NP Law", size(medium) color(black)) ///
                    ytitle("Mean Value") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                    legend(order(1 "Restricted" 2 "Reduced" 3 "Full Practice") position(6) rows(1)) ///
                    note("`dir_note'" "`np_note'", position(7) justification(left) size(vsmall) margin(t=3 l=2) span) ///
                    graphregion(color(white) margin(vsmall))
                capture graph export "$outRoot/`setting'/time_series/facility_analysis/by_authority/ts_auth_`var'.png", replace width(2000)
            }
        }
    }
}
display "=== FACILITY TIME SERIES COMPLETE ==="
