*===============================================================================
* SCRIPT: 08a_provider_quality_curves_2yr_lag.do
* PURPOSE: Binscatters mapping Provider Behavior vs Provider MIPS (2-Year Lag)
* FEATURES: Testing Toggle, Graduation Decade Subgroup, Scoped Footnotes
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* --- START LOG ---
local script_name "08a_provider_quality_curves_2yr_lag"
log using "$logRoot/`script_name'.smcl", replace

* --- 0. TESTING MODE SWITCH ---
* SET TO 1 TO TEST A 1% SAMPLE (Runs fast to verify formatting)
* SET TO 0 FOR FULL PRODUCTION RUN (PAUSE DROPBOX SYNCING BEFORE RUNNING!)
global testing_mode = 0

* INSTALL FASTXTILE: This makes binscatter 10x faster!
capture ssc install fastxtile
capture ssc install binscatter

* STRICTLY PROVIDER LEVEL MIPS & BEHAVIORS
local qual_vars "mips_final_score mips_quality_score mips_pi_score mips_ia_score mips_cost_score"
local behav_vars "partd_generic_rate partd_opioid_rate partb_em_upcode_rate bene_avg_risk_scre tot_benes tot_sbmtd_chrg total_rvu total_services total_medicare_payment"

foreach setting in "in_patient" "out_patient" {
    display "=== STARTING 2-YR LAG QUALITY CURVES FOR: `setting' PROVIDERS ==="

    * --- 1. DYNAMIC FOLDER CREATION ---
    local directions "quality_predicts_behavior behavior_predicts_quality"
    local timings "lag_two_year"
    local subgroups "overall by_prov_type by_gender by_dept by_grad_decade by_authority by_ownership"

    capture mkdir "$outRoot/summary_stats"
    capture mkdir "$outRoot/summary_stats/`setting'"
    capture mkdir "$outRoot/summary_stats/`setting'/quality_curves"
    capture mkdir "$outRoot/summary_stats/`setting'/quality_curves/provider_analysis"
    local baseDir "$outRoot/summary_stats/`setting'/quality_curves/provider_analysis"
    
    foreach d in `directions' {
        capture mkdir "`baseDir'/`d'"
        foreach t in `timings' {
            capture mkdir "`baseDir'/`d'/`t'"
            foreach sub in `subgroups' {
                capture mkdir "`baseDir'/`d'/`t'/`sub'"
            }
        }
    }

    * --- 2. LOAD & SAMPLE DATA ---
    if "`setting'" == "in_patient" {
        use "$dataRoot/master_provider_inpatient_2013_2023.dta", clear
        
        if $testing_mode == 1 {
            preserve
            contract npi
            sample 1
            tempfile test_npis
            save `test_npis'
            restore
            merge m:1 npi using `test_npis', keep(match) nogen
        }
        
        * Merge to inherit ownership for subgroups
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
    }
    else {
        use "$dataRoot/master_provider_outpatient_asc_2015_2023.dta", clear
        
        if $testing_mode == 1 {
            preserve
            contract npi
            sample 1
            tempfile test_npis
            save `test_npis'
            restore
            merge m:1 npi using `test_npis', keep(match) nogen
        }
    }

    * --- 3. TAXONOMIES & SUBGROUPS ---
    capture drop state_str
    capture decode cms_state, gen(state_str)
    if _rc != 0 {
        capture confirm string variable cms_state
        if _rc == 0 gen state_str = cms_state
        else capture gen state_str = string(cms_state)
    }
    replace state_str = strtrim(strupper(state_str))

    gen np_authority = .
    replace np_authority = 3 if $cond_full_prac
    replace np_authority = 2 if $cond_red_prac
    replace np_authority = 1 if $cond_res_prac

    capture drop cred_str
    capture decode credential, gen(cred_str)
    if _rc != 0 capture gen cred_str = string(credential)
    gen prov_type = 1 if inlist(cred_str, "MD", "DO")
    replace prov_type = 2 if cred_str == "NP"
    replace prov_type = 3 if cred_str == "PA"

    capture drop spec_str
    capture decode cms_specialty, gen(spec_str)
    if _rc != 0 capture gen spec_str = string(cms_specialty)
    gen dept_cat = 1 
    replace dept_cat = 2 if $cond_gen_med
    replace dept_cat = 3 if strpos(upper(spec_str), "FAMILY PRACTICE") > 0 | strpos(upper(spec_str), "GENERAL PRACTICE") > 0

    * Bulletproof Gender 
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
    gen female_num = 1 if is_female == "Female"
    replace female_num = 0 if is_female == "Male"
    
    * Graduation Decade
    capture drop grad_decade
    gen grad_decade = .
    capture confirm numeric variable grad_year
    if _rc == 0 {
        replace grad_decade = 1 if grad_year < 1990
        replace grad_decade = 2 if grad_year >= 1990 & grad_year < 2000
        replace grad_decade = 3 if grad_year >= 2000 & grad_year < 2010
        replace grad_decade = 4 if grad_year >= 2010 & !missing(grad_year)
    }

    * Ownership
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

    * --- 4. PRE-GENERATE 2-YEAR LAGS (xtset Safe) ---
    duplicates drop npi year, force
    egen panel_id = group(npi)
    xtset panel_id year

    foreach v in `qual_vars' `behav_vars' {
        capture confirm variable `v'
        if _rc == 0 {
            if strpos("`v'", "mips") > 0 {
                replace `v' = . if `v' < 0 | `v' > 100
            }
            gen lag2_`v' = L2.`v'
        }
    }

    * --- 5. BINSCATTER LOOPS ---
    foreach q_var in `qual_vars' {
        capture confirm variable `q_var'
        if _rc != 0 continue

        if "`q_var'" == "mips_final_score" {
            local q_title "MIPS Final Score"
            local q_desc "Quality: 0-100 composite payment adjustment score."
        }
        else if "`q_var'" == "mips_quality_score" {
            local q_title "MIPS Quality Domain"
            local q_desc "Quality: 0-100 score on evidence-based quality measures."
        }
        else if "`q_var'" == "mips_pi_score" {
            local q_title "MIPS Promoting Interoperability"
            local q_desc "Quality: 0-100 score on EHR integration."
        }
        else if "`q_var'" == "mips_ia_score" {
            local q_title "MIPS Improvement Activities"
            local q_desc "Quality: 0-100 score on practice improvements."
        }
        else if "`q_var'" == "mips_cost_score" {
            local q_title "MIPS Cost Domain"
            local q_desc "Efficiency: 0-100 score on resource use."
        }

        foreach b_var in `behav_vars' {
            capture confirm variable `b_var'
            if _rc != 0 continue

            if "`b_var'" == "partd_generic_rate" {
                local b_title "Generic Prescribing Rate"
                local b_desc "Behavior: % of Part D claims filled as generic."
            }
            else if "`b_var'" == "partd_opioid_rate" {
                local b_title "Opioid Prescribing Rate"
                local b_desc "Behavior: % of Part D claims for Schedule II/III opioids."
            }
            else if "`b_var'" == "partb_em_upcode_rate" {
                local b_title "E&M Upcode Rate"
                local b_desc "Behavior: % of E&M visits billed at highest intensity (Lvl 4/5)."
            }
            else if "`b_var'" == "bene_avg_risk_scre" {
                local b_title "Average Patient Risk Score"
                local b_desc "Behavior: HCC risk score of treated panel."
            }
            else if "`b_var'" == "tot_benes" {
                local b_title "Total Beneficiaries"
                local b_desc "Volume: Total unique Medicare patients treated."
            }
            else if "`b_var'" == "tot_sbmtd_chrg" {
                local b_title "Total Submitted Charges"
                local b_desc "Financial: Total dollars billed to Medicare."
            }
            else if "`b_var'" == "total_rvu" {
                local b_title "Total RVUs"
                local b_desc "Volume: Sum of all Relative Value Units."
            }
            else if "`b_var'" == "total_services" {
                local b_title "Total Services"
                local b_desc "Volume: Total distinct Medicare Part B services billed."
            }
            else if "`b_var'" == "total_medicare_payment" {
                local b_title "Total Medicare Payment"
                local b_desc "Financial: Total dollars paid out by Medicare."
            }

            foreach d in "quality_predicts_behavior" "behavior_predicts_quality" {
                
                if "`d'" == "quality_predicts_behavior" {
                    local y_var "`b_var'"
                    local y_label "`b_title'"
                    local x_var "lag2_`q_var'"
                    local x_label "2-Year Prior `q_title'"
                    local t_dir "lag_two_year"
                    local t_note "Timing: X-Axis (Quality) is lagged by 2 years."
                }
                else {
                    local y_var "`q_var'"
                    local y_label "`q_title'"
                    local x_var "lag2_`b_var'"
                    local x_label "2-Year Prior `b_title'"
                    local t_dir "lag_two_year"
                    local t_note "Timing: X-Axis (Behavior) is lagged by 2 years."
                }

                * FIX: Syntax is stripped of compound quotes so Stata can execute the options
                local note_str `"note("`b_desc'" "`q_desc'" "`t_note'" "Method: Dots represent quantile means. Line represents quadratic fit.", size(vsmall))"'
                local common_opts line(qfit) ytitle("`y_label'") xtitle("`x_label'") `note_str' graphregion(color(white) margin(vsmall))

                capture binscatter `y_var' `x_var', title("Overall: `y_label' vs `x_label'", size(medium) color(black)) `common_opts'
                capture graph export "`baseDir'/`d'/`t_dir'/overall/curve_overall_`y_var'_vs_`x_var'.png", replace width(2000)

                capture count if !missing(`y_var') & !missing(`x_var') & !missing(prov_type)
                if r(N) > 0 {
                    capture binscatter `y_var' `x_var', by(prov_type) title("By Prov: `y_label' vs `x_label'", size(medium) color(black)) legend(order(1 "MD/DO" 2 "NP" 3 "PA") position(6) rows(1)) `common_opts'
                    capture graph export "`baseDir'/`d'/`t_dir'/by_prov_type/curve_prov_`y_var'_vs_`x_var'.png", replace width(2000)
                }

                capture count if !missing(`y_var') & !missing(`x_var') & !missing(female_num)
                if r(N) > 0 {
                    capture binscatter `y_var' `x_var', by(female_num) title("By Gender: `y_label' vs `x_label'", size(medium) color(black)) legend(order(1 "Male" 2 "Female") position(6) rows(1)) `common_opts'
                    capture graph export "`baseDir'/`d'/`t_dir'/by_gender/curve_gen_`y_var'_vs_`x_var'.png", replace width(2000)
                }

                capture count if !missing(`y_var') & !missing(`x_var') & !missing(dept_cat)
                if r(N) > 0 {
                    local d_note `"note("`b_desc'" "`q_desc'" "`t_note'" "Dept: Primary Care = Family/Gen Prac. Gen Med = Internal Med w/o subspec." "Method: Dots represent quantile means. Line represents quadratic fit.", size(vsmall))"'
                    local d_opts line(qfit) ytitle("`y_label'") xtitle("`x_label'") `d_note' graphregion(color(white) margin(vsmall))
                    
                    capture binscatter `y_var' `x_var', by(dept_cat) title("By Dept: `y_label' vs `x_label'", size(medium) color(black)) legend(order(1 "Specialty" 2 "Gen Med" 3 "Primary Care") position(6) rows(1)) `d_opts'
                    capture graph export "`baseDir'/`d'/`t_dir'/by_dept/curve_dept_`y_var'_vs_`x_var'.png", replace width(2000)
                }
                
                capture count if !missing(`y_var') & !missing(`x_var') & !missing(grad_decade)
                if r(N) > 0 {
                    capture binscatter `y_var' `x_var', by(grad_decade) title("By Grad Decade: `y_label' vs `x_label'", size(medium) color(black)) legend(order(1 "Pre-1990" 2 "1990s" 3 "2000s" 4 "2010s+") position(6) rows(1)) `common_opts'
                    capture graph export "`baseDir'/`d'/`t_dir'/by_grad_decade/curve_grad_`y_var'_vs_`x_var'.png", replace width(2000)
                }

                capture count if !missing(`y_var') & !missing(`x_var') & !missing(np_authority)
                if r(N) > 0 {
                    capture binscatter `y_var' `x_var', by(np_authority) title("By Law: `y_label' vs `x_label'", size(medium) color(black)) legend(order(1 "Restricted" 2 "Reduced" 3 "Full") position(6) rows(1)) `common_opts'
                    capture graph export "`baseDir'/`d'/`t_dir'/by_authority/curve_auth_`y_var'_vs_`x_var'.png", replace width(2000)
                }

                if "`setting'" == "in_patient" {
                    capture count if !missing(`y_var') & !missing(`x_var') & !missing(own_category)
                    if r(N) > 0 {
                        capture binscatter `y_var' `x_var', by(own_category) title("By Own: `y_label' vs `x_label'", size(medium) color(black)) legend(order(1 "Gov" 2 "For-Profit" 3 "Non-Profit") position(6) rows(1)) `common_opts'
                        capture graph export "`baseDir'/`d'/`t_dir'/by_ownership/curve_own_`y_var'_vs_`x_var'.png", replace width(2000)
                    }
                }
            }
        }
    }
}
display "=== 2-YR LAG PROVIDER QUALITY CURVES COMPLETE ==="