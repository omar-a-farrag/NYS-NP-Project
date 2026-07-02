*===============================================================================
* SCRIPT: 08b_nys_facility_quality_curves.do
* PURPOSE: Binscatters mapping Facility Behavior vs HCAHPS/OAS CAHPS - NEW YORK STATE ONLY
* FEATURES: Testing Toggle, Both Directions, 1-Year & 2-Year Lags, Extensive Subgroups
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* --- START LOG ---
local script_name "09b_nys_facility_quality_curves"
log using "$logRoot/`script_name'.smcl", replace

* --- 0. TESTING MODE SWITCH ---
* SET TO 1 TO TEST A 5% SAMPLE (Runs fast to verify formatting)
* SET TO 0 FOR FULL PRODUCTION RUN
global testing_mode = 0

capture ssc install binscatter

local in_qual_vars "hcahps_100_score hcahps_grp1 hcahps_grp2 hcahps_grp3 hcahps_grp4"
local in_behav_vars "hac_total_score rrp_excess_ratio_ami rrp_excess_ratio_hf rrp_excess_ratio_pn mortality_rate_ami mortality_rate_hf mortality_rate_pn mspb_score hvbp_tps_score fac_mips_final_score fac_mips_quality_score fac_mips_pi_score fac_mips_ia_score fac_mips_cost_score hopd_op_8 hopd_op_10 hopd_op_13 hopd_op_18b hopd_op_22 hopd_op_32 hopd_op_36"

local out_qual_vars "oas_100_score oas_grp1 oas_grp2 oas_grp3"
local out_behav_vars "asc_rate_1 asc_rate_2 asc_rate_8 fac_mips_final_score fac_mips_quality_score fac_mips_pi_score fac_mips_ia_score fac_mips_cost_score"

foreach setting in "in_patient" "out_patient" {
    display "=== STARTING NYS QUALITY CURVES FOR: `setting' FACILITIES ==="

    * --- 1. DYNAMIC FOLDER CREATION ---
    local directions "quality_predicts_behavior behavior_predicts_quality"
    local timings "current_year lag_prior_year lead_next_year lag_two_year"
    local subgroups "overall by_authority by_ownership"

    local baseDir "$outRoot/summary_stats/`setting'/quality_curves/facility_analysis_nys"
    capture mkdir "$outRoot/summary_stats/`setting'"
    capture mkdir "$outRoot/summary_stats/`setting'/quality_curves"
    capture mkdir "`baseDir'"

    foreach d in `directions' {
        capture mkdir "`baseDir'/`d'"
        foreach t in `timings' {
            capture mkdir "`baseDir'/`d'/`t'"
            foreach sub in `subgroups' {
                capture mkdir "`baseDir'/`d'/`t'/`sub'"
            }
        }
    }

    * --- 2. LOAD DATA ---
    if "`setting'" == "in_patient" {
        use "$dataRoot/master_facility_inpatient_2013_2023.dta", clear
        local qual_vars "`in_qual_vars'"
        local behav_vars "`in_behav_vars'"
    }
    else {
        use "$dataRoot/master_facility_outpatient_asc_2015_2024.dta", clear
        local qual_vars "`out_qual_vars'"
        local behav_vars "`out_behav_vars'"
    }

    * --- 3. STATE STRING & FILTER TO NEW YORK STATE ---
    capture drop state_str
    local st_var "state"
    capture confirm variable cms_state
    if _rc == 0 local st_var "cms_state"

    capture decode `st_var', gen(state_str)
    if _rc != 0 {
        capture confirm string variable `st_var'
        if _rc == 0 gen state_str = `st_var'
        else capture gen state_str = string(`st_var')
    }
    replace state_str = strtrim(strupper(state_str))
    keep if state_str == "NY"
    display "NYS observations kept: `=_N'"

    * --- TESTING MODE SAMPLE (after NYS filter) ---
    if "`setting'" == "in_patient" {
        if $testing_mode == 1 {
            preserve
            contract ccn
            sample 5
            tempfile test_facs
            save `test_facs'
            restore
            merge m:1 ccn using `test_facs', keep(match) nogen
        }
        duplicates drop ccn year, force
        egen panel_id = group(ccn)
        xtset panel_id year
    }
    else {
        capture confirm variable asc_id
        if _rc == 0 {
            if $testing_mode == 1 {
                preserve
                contract asc_id
                sample 5
                tempfile test_facs
                save `test_facs'
                restore
                merge m:1 asc_id using `test_facs', keep(match) nogen
            }
            duplicates drop asc_id year, force
            egen panel_id = group(asc_id)
        }
        else {
            if $testing_mode == 1 {
                preserve
                contract ccn
                sample 5
                tempfile test_facs
                save `test_facs'
                restore
                merge m:1 ccn using `test_facs', keep(match) nogen
            }
            duplicates drop ccn year, force
            egen panel_id = group(ccn)
        }
        xtset panel_id year
    }

    * --- 4. TAXONOMIES ---
    * np_authority: wrap in capture so a bad global expansion cannot abort the loop
    gen np_authority = .
    capture replace np_authority = 3 if $cond_full_prac
    capture replace np_authority = 2 if $cond_red_prac
    capture replace np_authority = 1 if $cond_res_prac

    capture drop own_str own_category
    gen own_category = .
    if "`setting'" == "in_patient" {
        capture decode ownership, gen(own_str)
        if _rc != 0 {
            capture confirm string variable ownership
            if _rc == 0 gen own_str = ownership
            else capture gen own_str = string(ownership)
        }
        replace own_category = 1 if $cond_own_gov
        replace own_category = 2 if $cond_own_forprof
        replace own_category = 3 if $cond_own_nonprof
    }

    * --- 5. PRE-GENERATE LAGS, 2-YEAR LAGS & LEADS ---
    foreach v in `qual_vars' `behav_vars' {
        capture confirm variable `v'
        if _rc == 0 {
            gen lag_`v'  = L.`v'
            gen lag2_`v' = L2.`v'
            gen lead_`v' = F.`v'
        }
    }

    * --- 6. BINSCATTER LOOPS ---
    foreach q_var in `qual_vars' {
        capture confirm variable `q_var'
        if _rc != 0 continue

        if "`q_var'" == "hcahps_100_score" {
            local q_title "HCAHPS Overall Score"
            local q_desc "HCAHPS: 0-100 linear score for overall patient satisfaction."
        }
        else if "`q_var'" == "hcahps_grp1" {
            local q_title "HCAHPS Staff Comm"
            local q_desc "HCAHPS: 0-100 composite for Staff Communication."
        }
        else if "`q_var'" == "hcahps_grp2" {
            local q_title "HCAHPS Patient Help"
            local q_desc "HCAHPS: 0-100 composite for Patient Responsiveness & Help."
        }
        else if "`q_var'" == "hcahps_grp3" {
            local q_title "HCAHPS Environment"
            local q_desc "HCAHPS: 0-100 composite for Cleanliness & Quietness."
        }
        else if "`q_var'" == "hcahps_grp4" {
            local q_title "HCAHPS Global Rating"
            local q_desc "HCAHPS: 0-100 composite for Hospital Recommendation."
        }
        else if "`q_var'" == "oas_100_score" {
            local q_title "OAS CAHPS Overall"
            local q_desc "OAS CAHPS: 0-100 score for overall ASC satisfaction."
        }
        else if "`q_var'" == "oas_grp1" {
            local q_title "OAS CAHPS Comm"
            local q_desc "OAS CAHPS: 0-100 composite for Patient Communication."
        }
        else if "`q_var'" == "oas_grp2" {
            local q_title "OAS CAHPS Care/Clean"
            local q_desc "OAS CAHPS: 0-100 composite for Care & Cleanliness."
        }
        else if "`q_var'" == "oas_grp3" {
            local q_title "OAS CAHPS Prep/Discharge"
            local q_desc "OAS CAHPS: 0-100 composite for ASC Prep & Discharge."
        }

        foreach b_var in `behav_vars' {
            capture confirm variable `b_var'
            if _rc != 0 continue

            if "`b_var'" == "hac_total_score" {
                local b_title "HAC Penalty Score"
                local b_desc "Safety: 1-10 Hospital-Acquired Condition index. Higher is worse."
            }
            else if strpos("`b_var'", "rrp_excess_ratio") > 0 {
                local dis = upper(substr("`b_var'", 18, .))
                local b_title "Readmission Ratio `dis'"
                local b_desc "Quality: Observed/Expected readmissions. Ratio > 1.0 triggers penalties."
            }
            else if strpos("`b_var'", "mortality_rate") > 0 {
                local dis = upper(substr("`b_var'", 16, .))
                local b_title "Mortality Rate `dis'"
                local b_desc "Quality: 30-Day risk-standardized mortality rate."
            }
            else if "`b_var'" == "mspb_score" {
                local b_title "Medicare Spending Per Bene"
                local b_desc "Efficiency: Hospital spending vs national median (1.0 = Avg)."
            }
            else if "`b_var'" == "hvbp_tps_score" {
                local b_title "Value-Based Purchasing"
                local b_desc "Quality: 0-100 Total Performance Score."
            }
            else if "`b_var'" == "fac_mips_final_score" {
                local b_title "MIPS Final Score"
                local b_desc "MIPS: Facility-weighted avg of providers' composite score."
            }
            else if "`b_var'" == "fac_mips_quality_score" {
                local b_title "MIPS Quality"
                local b_desc "MIPS: Facility-weighted avg of Quality domain."
            }
            else if "`b_var'" == "fac_mips_pi_score" {
                local b_title "MIPS PI"
                local b_desc "MIPS: Facility-weighted avg of Promoting Interoperability."
            }
            else if "`b_var'" == "fac_mips_ia_score" {
                local b_title "MIPS IA"
                local b_desc "MIPS: Facility-weighted avg of Improvement Activities."
            }
            else if "`b_var'" == "fac_mips_cost_score" {
                local b_title "MIPS Cost"
                local b_desc "MIPS: Facility-weighted avg of Cost domain."
            }
            else if "`b_var'" == "asc_rate_1" {
                local b_title "ASC Burns Rate"
                local b_desc "Safety: % of patients experiencing a burn before discharge."
            }
            else if "`b_var'" == "asc_rate_2" {
                local b_title "ASC Falls Rate"
                local b_desc "Safety: % of patients experiencing a fall within the ASC."
            }
            else if "`b_var'" == "asc_rate_8" {
                local b_title "ASC Flu Vax Rate"
                local b_desc "Safety: % of personnel vaccinated for influenza."
            }
            else if strpos("`b_var'", "hopd") > 0 {
                local mtr = upper(substr("`b_var'", 6, .))
                local b_title "HOPD `mtr'"
                local b_desc "Efficiency: Outpatient department imaging/care volume metric."
            }

            foreach d in "quality_predicts_behavior" "behavior_predicts_quality" {
                foreach t in "current" "lag" "lead" "lag2" {

                    * --- Initialize locals to prevent stale values ---
                    local x_var ""
                    local x_label ""
                    local y_var ""
                    local y_label ""
                    local t_dir ""
                    local t_note ""

                    if "`d'" == "quality_predicts_behavior" {
                        local y_var "`b_var'"
                        local y_label "`b_title'"
                        if "`t'" == "current" {
                            local x_var "`q_var'"
                            local x_label "`q_title'"
                            local t_dir "current_year"
                            local t_note "Timing: Both variables represent performance in the concurrent year."
                        }
                        else if "`t'" == "lag" {
                            local x_var "lag_`q_var'"
                            local x_label "Prior Year `q_title'"
                            local t_dir "lag_prior_year"
                            local t_note "Timing: X-Axis (Quality) is lagged. It reflects performance in the PRIOR year."
                        }
                        else if "`t'" == "lead" {
                            local x_var "lead_`q_var'"
                            local x_label "Next Year `q_title'"
                            local t_dir "lead_next_year"
                            local t_note "Timing: X-Axis (Quality) is leading. It reflects performance in the NEXT year."
                        }
                        else if "`t'" == "lag2" {
                            local x_var "lag2_`q_var'"
                            local x_label "2-Year Prior `q_title'"
                            local t_dir "lag_two_year"
                            local t_note "Timing: X-Axis (Quality) is lagged 2 years. It reflects performance TWO years prior."
                        }
                    }
                    else {
                        local y_var "`q_var'"
                        local y_label "`q_title'"
                        if "`t'" == "current" {
                            local x_var "`b_var'"
                            local x_label "`b_title'"
                            local t_dir "current_year"
                            local t_note "Timing: Both variables represent performance in the concurrent year."
                        }
                        else if "`t'" == "lag" {
                            local x_var "lag_`b_var'"
                            local x_label "Prior Year `b_title'"
                            local t_dir "lag_prior_year"
                            local t_note "Timing: X-Axis (Behavior) is lagged. It reflects performance in the PRIOR year."
                        }
                        else if "`t'" == "lead" {
                            local x_var "lead_`b_var'"
                            local x_label "Next Year `b_title'"
                            local t_dir "lead_next_year"
                            local t_note "Timing: X-Axis (Behavior) is leading. It reflects performance in the NEXT year."
                        }
                        else if "`t'" == "lag2" {
                            local x_var "lag2_`b_var'"
                            local x_label "2-Year Prior `b_title'"
                            local t_dir "lag_two_year"
                            local t_note "Timing: X-Axis (Behavior) is lagged 2 years. It reflects performance TWO years prior."
                        }
                    }

                    * --- Guard: skip if locals not set ---
                    if "`x_var'" == "" | "`y_var'" == "" | "`t_dir'" == "" continue

                    local note_str `"note("`b_desc'" "`q_desc'" "`t_note'" "Method: Each dot is the mean y-value within an equal-sized bin (quantile) of the x-variable." "Line is a quadratic fit across all underlying facility-year observations.", size(vsmall))"'
                    local common_opts `"line(qfit) ytitle("`y_label'") xtitle("`x_label'") `note_str' graphregion(color(white) margin(vsmall))"'

                    capture binscatter `y_var' `x_var', title("NYS Overall: `y_label' vs `x_label'", size(medium) color(black)) `common_opts'
                    capture graph export "`baseDir'/`d'/`t_dir'/overall/curve_overall_`y_var'_vs_`x_var'.png", replace width(2000)

                    capture count if !missing(`y_var') & !missing(`x_var') & !missing(np_authority)
                    if r(N) > 0 {
                        capture binscatter `y_var' `x_var', by(np_authority) title("NYS By Law: `y_label' vs `x_label'", size(medium) color(black)) legend(order(1 "Restricted" 2 "Reduced" 3 "Full") position(6) rows(1)) `common_opts'
                        capture graph export "`baseDir'/`d'/`t_dir'/by_authority/curve_auth_`y_var'_vs_`x_var'.png", replace width(2000)
                    }

                    if "`setting'" == "in_patient" {
                        capture count if !missing(`y_var') & !missing(`x_var') & !missing(own_category)
                        if r(N) > 0 {
                            capture binscatter `y_var' `x_var', by(own_category) title("NYS By Own: `y_label' vs `x_label'", size(medium) color(black)) legend(order(1 "Gov" 2 "For-Profit" 3 "Non-Profit") position(6) rows(1)) `common_opts'
                            capture graph export "`baseDir'/`d'/`t_dir'/by_ownership/curve_own_`y_var'_vs_`x_var'.png", replace width(2000)
                        }
                    }
                }
            }
        }
    }
}
display "=== NYS FACILITY QUALITY CURVES COMPLETE ==="
