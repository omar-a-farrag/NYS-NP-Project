*===============================================================================
* SCRIPT: 08a_provider_quality_curves.do
* PURPOSE: Binscatters mapping Behavior vs MIPS (Both Directions)
* INCLUDES: Memory Compression, Quiet GUI protection, and Explicit Braces.
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

capture ssc install binscatter

foreach setting in "in_patient" "out_patient" {
    display "=== STARTING QUALITY CURVES FOR: `setting' ==="

    * --- 1. DYNAMIC FOLDER CREATION ---
    local directions "mips_predicts_behavior behavior_predicts_mips"
    local timings "current_year lag_prior_year lead_next_year"
    
    capture mkdir "$outRoot/`setting'/quality_curves"
    foreach d in `directions' {
        capture mkdir "$outRoot/`setting'/quality_curves/`d'"
        foreach t in `timings' {
            capture mkdir "$outRoot/`setting'/quality_curves/`d'/`t'"
            capture mkdir "$outRoot/`setting'/quality_curves/`d'/`t'/overall"
            capture mkdir "$outRoot/`setting'/quality_curves/`d'/`t'/by_prov_type"
            capture mkdir "$outRoot/`setting'/quality_curves/`t'/by_authority"
            capture mkdir "$outRoot/`setting'/quality_curves/`t'/by_dept"
            capture mkdir "$outRoot/`setting'/quality_curves/`t'/by_prim_care"
            capture mkdir "$outRoot/`setting'/quality_curves/`t'/by_ownership"
            capture mkdir "$outRoot/`setting'/quality_curves/`t'/by_prov_gen_med"
            capture mkdir "$outRoot/`setting'/quality_curves/`t'/by_prov_prim_care"
        }
    }

    * --- 2. LOAD DATA ---
    if "`setting'" == "in_patient" {
        use "$dataRoot/master_provider_inpatient_2013_2023.dta", clear
    }
    else {
        use "$dataRoot/master_provider_outpatient_asc_2015_2023.dta", clear
    }

    * --- 3. PREP SUBGROUPS ---
    quietly {
        capture drop state_str
        capture decode cms_state, gen(state_str)
        capture gen state_str = cms_state
        capture gen state_str = state
        capture gen state_str = affil_state
        
        gen np_authority = .
        replace np_authority = 3 if $cond_full_prac
        replace np_authority = 2 if $cond_red_prac
        replace np_authority = 1 if $cond_res_prac

        decode credential, gen(cred_str)
        gen prov_type = 1 if inlist(cred_str, "MD", "DO")
        replace prov_type = 2 if cred_str == "NP"
        replace prov_type = 3 if cred_str == "PA"

        decode cms_specialty, gen(spec_str)
        gen is_gen_med = 0
        replace is_gen_med = 1 if $cond_gen_med
        gen is_prim_care = 0
        replace is_prim_care = 1 if $cond_prim_care

        capture drop own_str
        capture decode ownership, gen(own_str)
        capture gen own_str = ownership
        gen own_category = .
        capture confirm variable own_str
        if !_rc {
            replace own_category = 1 if $cond_own_gov
            replace own_category = 2 if $cond_own_nonprof
            replace own_category = 3 if $cond_own_forprof
        }
    }

    * --- 4. THE BULLETPROOF WEIGHTED COLLAPSE ---
    local existing_vars ""
    foreach v in $prov_overlap_means {
        capture confirm variable `v'
        if !_rc {
            local existing_vars "`existing_vars' `v'"
        }
    }
    
    capture confirm variable mips_final_score
    if !_rc {
        local existing_vars "`existing_vars' mips_final_score"
    }
    
    local clean_vars : list uniq existing_vars

    display "Collapsing large panel (this may take a minute)..."
    capture confirm variable tot_benes
    if !_rc {
        collapse (mean) `clean_vars' np_authority prov_type is_gen_med is_prim_care own_category [aw=tot_benes], by(npi year)
    }
    else {
        collapse (mean) `clean_vars' np_authority prov_type is_gen_med is_prim_care own_category, by(npi year)
    }
    
    * CRITICAL MEMORY SAVER
    quietly compress

    quietly {
        foreach cat in np_authority prov_type is_gen_med is_prim_care own_category {
            capture replace `cat' = round(`cat')
        }
    }

    * --- 5. DECLARE PANEL & CREATE LAGS ---
    egen panel_id = group(npi)
    xtset panel_id year

    capture confirm variable mips_final_score
    if !_rc {
        display "Generating Time-Series Lags and Leads (Silently)..."
        quietly {
            gen mips_current = mips_final_score
            gen mips_lag = L.mips_final_score
            gen mips_lead = F.mips_final_score
            
            replace mips_current = . if mips_current < 0 | mips_current > 100
            replace mips_lag = . if mips_lag < 0 | mips_lag > 100
            replace mips_lead = . if mips_lead < 0 | mips_lead > 100

            local plot_vars ""
            foreach v in `clean_vars' {
                if "`v'" != "mips_final_score" {
                    local plot_vars "`plot_vars' `v'"
                    gen lag_`v' = L.`v'
                }
            }
        }

        * --- 6. GRAPHING LOOPS ---
        display "Drawing graphs..."
        foreach var in `plot_vars' {
            local clean_title = strproper(subinstr("`var'", "_", " ", .))
            
            foreach timing in "current" "lag" "lead" {
                
                * Explicit explicit block definitions
                local folder ""
                if "`timing'" == "current" {
                    local folder "current_year"
                }
                if "`timing'" == "lag" {
                    local folder "lag_prior_year"
                }
                if "`timing'" == "lead" {
                    local folder "lead_next_year"
                }

                capture binscatter `var' mips_`timing', line(qfit) title("`clean_title' vs MIPS (`timing')", size(medium)) ytitle("`clean_title'") xtitle("MIPS Score") graphregion(color(white))
                capture graph export "$outRoot/`setting'/quality_curves/mips_predicts_behavior/`folder'/overall/curve_overall_`var'.png", replace width(2000)

                capture binscatter `var' mips_`timing', by(prov_type) line(qfit) title("By Prov: `clean_title'", size(medium)) legend(order(1 "MD" 2 "NP" 3 "PA") position(6) rows(1)) graphregion(color(white))
                capture graph export "$outRoot/`setting'/quality_curves/mips_predicts_behavior/`folder'/by_prov_type/curve_prov_`var'.png", replace width(2000)
                
                capture binscatter `var' mips_`timing' if is_gen_med == 1, by(prov_type) line(qfit) title("Gen Med - By Prov: `clean_title'", size(medium)) legend(order(1 "MD" 2 "NP" 3 "PA") position(6) rows(1)) graphregion(color(white))
                capture graph export "$outRoot/`setting'/quality_curves/mips_predicts_behavior/`folder'/by_prov_gen_med/curve_prov_gm_`var'.png", replace width(2000)

                capture binscatter `var' mips_`timing' if is_prim_care == 1, by(prov_type) line(qfit) title("Prim Care - By Prov: `clean_title'", size(medium)) legend(order(1 "MD" 2 "NP" 3 "PA") position(6) rows(1)) graphregion(color(white))
                capture graph export "$outRoot/`setting'/quality_curves/mips_predicts_behavior/`folder'/by_prov_prim_care/curve_prov_pc_`var'.png", replace width(2000)

                capture binscatter `var' mips_`timing', by(np_authority) line(qfit) title("By Law: `clean_title'", size(medium)) legend(order(1 "Res" 2 "Red" 3 "Full") position(6) rows(1)) graphregion(color(white))
                capture graph export "$outRoot/`setting'/quality_curves/mips_predicts_behavior/`folder'/by_authority/curve_auth_`var'.png", replace width(2000)

                capture binscatter `var' mips_`timing', by(is_gen_med) line(qfit) title("Gen Med: `clean_title'", size(medium)) legend(order(1 "Other" 2 "Gen Med") position(6) rows(1)) graphregion(color(white))
                capture graph export "$outRoot/`setting'/quality_curves/mips_predicts_behavior/`folder'/by_dept/curve_dept_`var'.png", replace width(2000)

                capture binscatter `var' mips_`timing', by(is_prim_care) line(qfit) title("Prim Care: `clean_title'", size(medium)) legend(order(1 "Other" 2 "Prim Care") position(6) rows(1)) graphregion(color(white))
                capture graph export "$outRoot/`setting'/quality_curves/mips_predicts_behavior/`folder'/by_prim_care/curve_prim_`var'.png", replace width(2000)
                
                capture count if !missing(own_category)
                if r(N) > 0 {
                    capture binscatter `var' mips_`timing', by(own_category) line(qfit) title("By Own: `clean_title'", size(medium)) legend(order(1 "Gov" 2 "Non-Prof" 3 "For-Prof") position(6) rows(1)) graphregion(color(white))
                    capture graph export "$outRoot/`setting'/quality_curves/mips_predicts_behavior/`folder'/by_ownership/curve_own_`var'.png", replace width(2000)
                }
            }
            
            capture binscatter mips_current lag_`var', line(qfit) title("MIPS vs Prior Year `clean_title'", size(medium)) ytitle("Current MIPS Score") xtitle("Lagged `clean_title'") graphregion(color(white))
            capture graph export "$outRoot/`setting'/quality_curves/behavior_predicts_mips/lag_prior_year/overall/curve_overall_`var'.png", replace width(2000)

            capture binscatter mips_current lag_`var', by(prov_type) line(qfit) title("By Prov: MIPS vs Prior `clean_title'", size(medium)) legend(order(1 "MD" 2 "NP" 3 "PA") position(6) rows(1)) graphregion(color(white))
            capture graph export "$outRoot/`setting'/quality_curves/behavior_predicts_mips/lag_prior_year/by_prov_type/curve_prov_`var'.png", replace width(2000)
        }
    }
    else {
        display "MIPS variable not found. Skipping."
    }
}
display "=== PROVIDER QUALITY CURVES COMPLETE ==="
