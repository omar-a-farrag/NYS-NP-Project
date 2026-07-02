*===============================================================================
* SCRIPT: 08b_facility_quality_curves.do
* PURPOSE: Binscatters mapping Facility Behavior vs HCAHPS Scores 
* Tests Both Directions: HCAHPS predicting Behavior AND Behavior predicting HCAHPS
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

capture ssc install binscatter

display "=== STARTING QUALITY CURVES FOR: FACILITIES (HCAHPS) ==="

* --- 1. DYNAMIC FOLDER CREATION ---
local directions "hcahps_predicts_behavior behavior_predicts_hcahps"
local timings "current_year lag_prior_year lead_next_year"

capture mkdir "$outRoot/in_patient/quality_curves"
foreach d in `directions' {
    capture mkdir "$outRoot/in_patient/quality_curves/`d'"
    foreach t in `timings' {
        capture mkdir "$outRoot/in_patient/quality_curves/`d'/`t'"
        capture mkdir "$outRoot/in_patient/quality_curves/`d'/`t'/overall"
        capture mkdir "$outRoot/in_patient/quality_curves/`d'/`t'/by_authority"
        capture mkdir "$outRoot/in_patient/quality_curves/`d'/`t'/by_ownership"
    }
}

* --- 2. LOAD DATA ---
use "$dataRoot/master_facility_inpatient_2013_2023.dta", clear

* --- 3. PREP SUBGROUPS ---
quietly {
    * State Authority
    capture drop state_str
    capture decode state, gen(state_str)
    capture gen state_str = state
        
    gen np_authority = .
    replace np_authority = 3 if $cond_full_prac
    replace np_authority = 2 if $cond_red_prac
    replace np_authority = 1 if $cond_res_prac

    * Ownership 
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

* --- 4. DECLARE PANEL ---
* Convert CCN (Hospital ID) to numeric panel ID
egen panel_id = group(ccn)
xtset panel_id year

* --- 5. DEFINE QUALITY & BEHAVIOR VARIABLES ---
* We test both Top Box (9-10) and Bottom Box (0-6)
local quality_scores "h_hosp_rating_9_10 h_hosp_rating_0_6"

* Define the behaviors to test against HCAHPS
local behavior_vars "fac_wgt_em_upcode_rate fac_mean_opioid_rate fac_mean_highcost_rate hac_total_score rrp_excess_ratio_ami fac_avg_risk_score"

* Ensure only variables that actually exist in the data are plotted
local plot_vars ""
foreach v in `behavior_vars' {
    capture confirm variable `v'
    if !_rc { 
        local plot_vars "`plot_vars' `v'" 
    }
}

* --- 6. GENERATE TIMING VARIABLES (LAGS/LEADS) ---
display "Generating Time-Series Lags and Leads (Silently)..."
quietly {
    foreach q in `quality_scores' {
        capture confirm variable `q'
        if !_rc {
            gen `q'_current = `q'
            gen `q'_lag = L.`q'
            gen `q'_lead = F.`q'
        }
    }

    foreach b in `plot_vars' {
        gen lag_`b' = L.`b'
    }
}

* --- 7. GRAPHING LOOPS (Protected by Capture) ---
display "Drawing graphs..."
foreach q in `quality_scores' {
    capture confirm variable `q'
    if !_rc {
        local q_title = strproper(subinstr("`q'", "_", " ", .))
        
        foreach var in `plot_vars' {
            local b_title = strproper(subinstr("`var'", "_", " ", .))
            
            * ==========================================
            * DIRECTION 1: HCAHPS Predicts Behavior
            * ==========================================
            foreach timing in "current" "lag" "lead" {
                
                * Explicit braces to prevent Stata r(198) crash
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

                * Overall
                capture binscatter `var' `q'_`timing', line(qfit) title("`b_title' vs `q_title' (`timing')", size(medium)) ytitle("`b_title'") xtitle("`q_title'") graphregion(color(white))
                capture graph export "$outRoot/in_patient/quality_curves/hcahps_predicts_behavior/`folder'/overall/curve_overall_`var'_vs_`q'.png", replace width(2000)

                * By Authority
                capture binscatter `var' `q'_`timing', by(np_authority) line(qfit) title("By Law: `b_title'", size(medium)) legend(order(1 "Res" 2 "Red" 3 "Full") position(6) rows(1)) graphregion(color(white))
                capture graph export "$outRoot/in_patient/quality_curves/hcahps_predicts_behavior/`folder'/by_authority/curve_auth_`var'_vs_`q'.png", replace width(2000)

                * By Ownership
                capture count if !missing(own_category)
                if r(N) > 0 {
                    capture binscatter `var' `q'_`timing', by(own_category) line(qfit) title("By Own: `b_title'", size(medium)) legend(order(1 "Gov" 2 "Non-Prof" 3 "For-Prof") position(6) rows(1)) graphregion(color(white))
                    capture graph export "$outRoot/in_patient/quality_curves/hcahps_predicts_behavior/`folder'/by_ownership/curve_own_`var'_vs_`q'.png", replace width(2000)
                }
            }
            
            * ==========================================
            * DIRECTION 2: Lagged Behavior Predicts HCAHPS
            * ==========================================
            * Overall
            capture binscatter `q'_current lag_`var', line(qfit) title("`q_title' vs Prior Year `b_title'", size(medium)) ytitle("Current `q_title'") xtitle("Lagged `b_title'") graphregion(color(white))
            capture graph export "$outRoot/in_patient/quality_curves/behavior_predicts_hcahps/lag_prior_year/overall/curve_overall_`q'_vs_`var'.png", replace width(2000)

            * By Authority
            capture binscatter `q'_current lag_`var', by(np_authority) line(qfit) title("By Law: `q_title' vs Prior `b_title'", size(medium)) legend(order(1 "Res" 2 "Red" 3 "Full") position(6) rows(1)) graphregion(color(white))
            capture graph export "$outRoot/in_patient/quality_curves/behavior_predicts_hcahps/lag_prior_year/by_authority/curve_auth_`q'_vs_`var'.png", replace width(2000)

            * By Ownership
            capture count if !missing(own_category)
            if r(N) > 0 {
                capture binscatter `q'_current lag_`var', by(own_category) line(qfit) title("By Own: `q_title' vs Prior `b_title'", size(medium)) legend(order(1 "Gov" 2 "Non-Prof" 3 "For-Prof") position(6) rows(1)) graphregion(color(white))
                capture graph export "$outRoot/in_patient/quality_curves/behavior_predicts_hcahps/lag_prior_year/by_ownership/curve_own_`q'_vs_`var'.png", replace width(2000)
            }
        }
    }
}
display "=== FACILITY QUALITY CURVES COMPLETE ==="
