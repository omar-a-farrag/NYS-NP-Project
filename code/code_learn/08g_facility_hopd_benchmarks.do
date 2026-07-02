*===============================================================================
* SCRIPT: 08g_facility_hopd_benchmarks.do
* PURPOSE: Facility-Level Benchmarks for Hospital Outpatient Depts (HOPD)
* FEATURES: HCAHPS Groups 1-4, Clean Titles, Delta Analyses, Memory Safe
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* --- START LOG ---
local script_name "08g_facility_hopd_benchmarks"
log using "$logRoot/`script_name'.smcl", replace
* -----------------

capture ssc install binscatter
display "=== STARTING BENCHMARKS FOR: HOSPITAL OUTPATIENT DEPARTMENTS (HOPD) ==="

* --- 1. LOAD FACILITY MASTER ---
display "1. Loading Inpatient Facility Master for HOPD Analysis..."
use "$dataRoot/master_facility_inpatient_2013_2023.dta", clear

drop if missing(hcahps_100_score)
drop if hcahps_100_score < 0

capture confirm variable cms_state
if _rc == 0 {
    capture confirm string variable cms_state
    if _rc == 0 gen state_str = cms_state
    else decode cms_state, gen(state_str)
}
else {
    capture confirm string variable state
    if _rc == 0 gen state_str = state
    else decode state, gen(state_str)
}

capture confirm variable ownership
if _rc == 0 {
    capture confirm string variable ownership
    if _rc == 0 gen own_str = ownership
    else decode ownership, gen(own_str)
}
else {
    gen own_str = "UNKNOWN"
}

capture replace state_str = strtrim(strupper(state_str))
capture replace own_str = strtrim(strupper(own_str))

gen own_cat = "Other"
replace own_cat = "Government" if strmatch(own_str, "*GOVERNMENT*")
replace own_cat = "Non_Profit" if strmatch(own_str, "*NON-PROFIT*")
replace own_cat = "For_Profit" if strmatch(own_str, "*PROPRIETARY*")

gen np_auth = "Unknown"
replace np_auth = "Full_Practice" if inlist(state_str, "AZ", "CO", "CT", "DC", "HI", "ID", "IA", "MD", "MA") | inlist(state_str, "MN", "MT", "NE", "NV", "NH", "NM", "NY", "ND", "OR") | inlist(state_str, "RI", "SD", "VT", "WA", "WY")
replace np_auth = "Reduced_Practice" if inlist(state_str, "AL", "AS", "DE", "IL", "IN", "KS", "KY", "LA", "MS") | inlist(state_str, "NJ", "OH", "PA", "UT", "WI")
replace np_auth = "Restricted_Practice" if inlist(state_str, "CA", "FL", "GA", "MI", "MO", "NC", "OK", "SC", "TN") | inlist(state_str, "TX", "VA")

levelsof np_auth, local(auths)
levelsof own_cat, local(owns)

* --- 2. GEOGRAPHIC Z-SCORES (HCAHPS) ---
display "2. Calculating Geographic Z-Scores..."
local m_list "h100 g1 g2 g3 g4"

foreach geo in "nat" "state" "county" {
    preserve
    if "`geo'" == "nat" local byvar "year"
    if "`geo'" == "state" local byvar "state_str year"
    if "`geo'" == "county" local byvar "county year"
    
    if "`geo'" != "nat" drop if missing(state_str)
    
    collapse (mean) mean_h100=hcahps_100_score mean_g1=hcahps_grp1 mean_g2=hcahps_grp2 mean_g3=hcahps_grp3 mean_g4=hcahps_grp4 ///
             (sd) sd_h100=hcahps_100_score sd_g1=hcahps_grp1 sd_g2=hcahps_grp2 sd_g3=hcahps_grp3 sd_g4=hcahps_grp4, by(`byvar')
    
    rename mean_* `geo'_mean_*
    rename sd_* `geo'_sd_*
    tempfile bench_`geo'
    save `bench_`geo'', replace
    restore
}
merge m:1 year using `bench_nat', nogen
merge m:1 state_str year using `bench_state', nogen
merge m:1 county year using `bench_county', nogen

foreach geo in "nat" "state" "county" {
    foreach m in `m_list' {
        if "`m'" == "h100" local v_name "hcahps_100_score"
        if "`m'" == "g1" local v_name "hcahps_grp1"
        if "`m'" == "g2" local v_name "hcahps_grp2"
        if "`m'" == "g3" local v_name "hcahps_grp3"
        if "`m'" == "g4" local v_name "hcahps_grp4"
        
        gen z_`m'_`geo' = (`v_name' - `geo'_mean_`m') / `geo'_sd_`m'
        gen bin_`m'_`geo' = .
        replace bin_`m'_`geo' = 4 if z_`m'_`geo' > 2.0 & !missing(z_`m'_`geo')
        replace bin_`m'_`geo' = 3 if z_`m'_`geo' > 1.0 & z_`m'_`geo' <= 2.0
        replace bin_`m'_`geo' = 2 if z_`m'_`geo' > 0.5 & z_`m'_`geo' <= 1.0
        replace bin_`m'_`geo' = 1 if z_`m'_`geo' >= 0 & z_`m'_`geo' <= 0.5
        replace bin_`m'_`geo' = -1 if z_`m'_`geo' >= -0.5 & z_`m'_`geo' < 0
        replace bin_`m'_`geo' = -2 if z_`m'_`geo' >= -1.0 & z_`m'_`geo' < -0.5
        replace bin_`m'_`geo' = -3 if z_`m'_`geo' >= -2.0 & z_`m'_`geo' < -1.0
        replace bin_`m'_`geo' = -4 if z_`m'_`geo' < -2.0
    }
}

* --- 3. PANEL LAGS (YEAR-OVER-YEAR) ---
egen panel_id = group(ccn)
xtset panel_id year

gen hcahps_decline = (hcahps_100_score < L.hcahps_100_score) if !missing(hcahps_100_score, L.hcahps_100_score)
gen g1_decline = (hcahps_grp1 < L.hcahps_grp1) if !missing(hcahps_grp1, L.hcahps_grp1)
gen g2_decline = (hcahps_grp2 < L.hcahps_grp2) if !missing(hcahps_grp2, L.hcahps_grp2)
gen g3_decline = (hcahps_grp3 < L.hcahps_grp3) if !missing(hcahps_grp3, L.hcahps_grp3)
gen g4_decline = (hcahps_grp4 < L.hcahps_grp4) if !missing(hcahps_grp4, L.hcahps_grp4)

gen lag_hcahps_decline = L.hcahps_decline
gen lag_g1_decline = L.g1_decline
gen lag_g2_decline = L.g2_decline
gen lag_g3_decline = L.g3_decline
gen lag_g4_decline = L.g4_decline

foreach geo in "nat" "state" "county" {
    foreach m in `m_list' {
        gen lag_bin_`m'_`geo' = L.bin_`m'_`geo'
    }
}

* --- 4. GRAPHING ENGINE ---
display "4. Generating Journal-Ready HOPD Visualizations with Deltas..."
local baseOut "$outRoot/summary_stats/out_patient/benchmarks_hopd_facility"
capture mkdir "`baseOut'"

local cats "universal by_np_auth by_ownership"
foreach c in `cats' {
    capture mkdir "`baseOut'/`c'"
}

local hopd_vars "hopd_op_8 hopd_op_10 hopd_op_13 hopd_op_18b hopd_op_22 hopd_op_32 hopd_op_36"

foreach var in `hopd_vars' {
    capture confirm variable `var'
    if _rc == 0 {
        
        * --- DELTA CALCULATION ---
        capture drop d_`var'
        gen d_`var' = `var' - L.`var'

        * --- TITLE DICTIONARY ---
        if "`var'" == "hopd_op_8" {
            local c_title "Lumbar Spine MRI Rate"
            local v_note "Outpatient Outcome (OP-8): Rate of MRI Lumbar Spine for Low Back Pain."
        }
        else if "`var'" == "hopd_op_10" {
            local c_title "Abdomen CT Contrast Rate"
            local v_note "Outpatient Outcome (OP-10): Rate of Abdomen CT with Contrast Material."
        }
        else if "`var'" == "hopd_op_13" {
            local c_title "Outpatient Cardiac Imaging Rate"
            local v_note "Outpatient Outcome (OP-13): Cardiac Imaging for Preoperative Risk Assessment."
        }
        else if "`var'" == "hopd_op_18b" {
            local c_title "ED Median Time to Departure"
            local v_note "Outpatient Outcome (OP-18b): Median Time from ED Arrival to ED Departure (Minutes)."
        }
        else if "`var'" == "hopd_op_22" {
            local c_title "Left ED Without Being Seen Rate"
            local v_note "Outpatient Outcome (OP-22): Percentage of patients who left the ED without being seen."
        }
        else if "`var'" == "hopd_op_32" {
            local c_title "Post-Colonoscopy Hospital Visit"
            local v_note "Outpatient Outcome (OP-32): 7-Day Risk-Standardized Hospital Visit Rate."
        }
        else if "`var'" == "hopd_op_36" {
            local c_title "Post-Outpatient Surgery Visit"
            local v_note "Outpatient Outcome (OP-36): Hospital Visits after Hospital Outpatient Surgery."
        }
        else {
            local c_title = strproper(subinstr("`var'", "_", " ", .))
            local v_note "Outcome: `c_title'"
        }

        local ft_delta "Outcome: Year-over-year absolute change in `c_title'."

        * --- HCAHPS METRICS LOOP ---
        foreach m in `m_list' {
            if "`m'" == "h100" {
                local m_title "Overall HCAHPS"
                local m_var "hcahps"
                local ft_meas "Metric: Overall 100-Point Hospital HCAHPS Composite."
            }
            else if "`m'" == "g1" {
                local m_title "Staff Comm."
                local m_var "g1"
                local ft_meas "Metric: Group 1 (Staff Communication with Patient)."
            }
            else if "`m'" == "g2" {
                local m_title "Patient Help"
                local m_var "g2"
                local ft_meas "Metric: Group 2 (Providing the Patient Help)."
            }
            else if "`m'" == "g3" {
                local m_title "Environment"
                local m_var "g3"
                local ft_meas "Metric: Group 3 (Facility Cleanliness/Quietness)."
            }
            else if "`m'" == "g4" {
                local m_title "Global Rating"
                local m_var "g4"
                local ft_meas "Metric: Group 4 (Global Rating and Recommendation)."
            }
            
            local ft_dec "Decline: Binary (1=Yes) if the hospital's `m_title' score dropped from two years prior to one year prior."

            * 4A. UNIVERSAL
            capture binscatter `var' lag_`m_var'_decline, discrete line(connect) title("`c_title' by `m_title' Drop", size(msmall)) xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", size(vsmall)) graphregion(color(white))
            capture graph export "`baseOut'/universal/decline_`m'_by_`var'.png", replace width(2000)
            
            capture binscatter d_`var' lag_`m_var'_decline, discrete line(connect) title("Change in `c_title' by `m_title' Drop", size(msmall)) xtitle("Prior Year `m_title' Declined") ytitle("Change in `c_title'") xlabel(0 "No Decline" 1 "Declined") note("`ft_delta'" "`ft_meas'" "`ft_dec'", size(vsmall)) graphregion(color(white))
            capture graph export "`baseOut'/universal/decline_`m'_by_delta_`var'.png", replace width(2000)

            foreach geo in "nat" "state" "county" {
                local gname = strproper("`geo'")
                local ft_geo "Benchmark: Standard Deviations from `gname' `m_title' mean in the prior year."
                
                capture binscatter `var' lag_bin_`m'_`geo', discrete line(connect) title("`c_title' by `gname' `m_title'", size(msmall)) xtitle("Standard Deviations from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", size(vsmall)) graphregion(color(white))
                capture graph export "`baseOut'/universal/bin_`m'_`geo'_by_`var'.png", replace width(2000)
                
                capture binscatter d_`var' lag_bin_`m'_`geo', discrete line(connect) title("Change in `c_title' by `gname' `m_title'", size(msmall)) xtitle("Standard Deviations from `gname' `m_title' (Prior Year)") ytitle("Change in `c_title'") note("`ft_delta'" "`ft_meas'" "`ft_geo'", size(vsmall)) graphregion(color(white))
                capture graph export "`baseOut'/universal/bin_`m'_`geo'_by_delta_`var'.png", replace width(2000)
            }

            * 4B. BY STATE NP AUTHORITY
            foreach a in `auths' {
                if "`a'" == "Full_Practice" local a_clean "Full Practice"
                else if "`a'" == "Reduced_Practice" local a_clean "Reduced Practice"
                else if "`a'" == "Restricted_Practice" local a_clean "Restricted Practice"
                else local a_clean "`a'"

                capture mkdir "`baseOut'/by_np_auth/`a'"
                capture binscatter `var' lag_`m_var'_decline if np_auth == "`a'", discrete line(connect) title("`c_title' by `m_title' Drop: `a_clean'", size(msmall)) xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") note("`v_note'" "`ft_meas'", size(vsmall)) graphregion(color(white))
                capture graph export "`baseOut'/by_np_auth/`a'/decline_`m'_by_`var'.png", replace width(2000)
                
                capture binscatter d_`var' lag_`m_var'_decline if np_auth == "`a'", discrete line(connect) title("Change in `c_title' by Drop: `a_clean'", size(msmall)) xtitle("Prior Year `m_title' Declined") ytitle("Change in `c_title'") note("`ft_delta'" "`ft_meas'", size(vsmall)) graphregion(color(white))
                capture graph export "`baseOut'/by_np_auth/`a'/decline_`m'_by_delta_`var'.png", replace width(2000)

                foreach geo in "nat" "state" "county" {
                    local gname = strproper("`geo'")
                    capture binscatter `var' lag_bin_`m'_`geo' if np_auth == "`a'", discrete line(connect) title("`c_title' by `gname' `m_title': `a_clean'", size(msmall)) xtitle("Standard Deviations from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'", size(vsmall)) graphregion(color(white))
                    capture graph export "`baseOut'/by_np_auth/`a'/bin_`m'_`geo'_by_`var'.png", replace width(2000)
                    
                    capture binscatter d_`var' lag_bin_`m'_`geo' if np_auth == "`a'", discrete line(connect) title("Change in `c_title' by `gname' `m_title': `a_clean'", size(msmall)) xtitle("Standard Deviations from `gname' `m_title' (Prior Year)") ytitle("Change in `c_title'") note("`ft_delta'" "`ft_meas'", size(vsmall)) graphregion(color(white))
                    capture graph export "`baseOut'/by_np_auth/`a'/bin_`m'_`geo'_by_delta_`var'.png", replace width(2000)
                }
            }

            * 4C. BY OWNERSHIP
            foreach o in `owns' {
                if "`o'" == "Non_Profit" local o_clean "Non-Profit"
                else if "`o'" == "For_Profit" local o_clean "For-Profit"
                else local o_clean "`o'"

                capture mkdir "`baseOut'/by_ownership/`o'"
                capture binscatter `var' lag_`m_var'_decline if own_cat == "`o'", discrete line(connect) title("`c_title' by `m_title' Drop: `o_clean'", size(msmall)) xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") note("`v_note'" "`ft_meas'", size(vsmall)) graphregion(color(white))
                capture graph export "`baseOut'/by_ownership/`o'/decline_`m'_by_`var'.png", replace width(2000)
                
                capture binscatter d_`var' lag_`m_var'_decline if own_cat == "`o'", discrete line(connect) title("Change in `c_title' by Drop: `o_clean'", size(msmall)) xtitle("Prior Year `m_title' Declined") ytitle("Change in `c_title'") note("`ft_delta'" "`ft_meas'", size(vsmall)) graphregion(color(white))
                capture graph export "`baseOut'/by_ownership/`o'/decline_`m'_by_delta_`var'.png", replace width(2000)

                foreach geo in "nat" "state" "county" {
                    local gname = strproper("`geo'")
                    capture binscatter `var' lag_bin_`m'_`geo' if own_cat == "`o'", discrete line(connect) title("`c_title' by `gname' `m_title': `o_clean'", size(msmall)) xtitle("Standard Deviations from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'", size(vsmall)) graphregion(color(white))
                    capture graph export "`baseOut'/by_ownership/`o'/bin_`m'_`geo'_by_`var'.png", replace width(2000)
                    
                    capture binscatter d_`var' lag_bin_`m'_`geo' if own_cat == "`o'", discrete line(connect) title("Change in `c_title' by `gname' `m_title': `o_clean'", size(msmall)) xtitle("Standard Deviations from `gname' `m_title' (Prior Year)") ytitle("Change in `c_title'") note("`ft_delta'" "`ft_meas'", size(vsmall)) graphregion(color(white))
                    capture graph export "`baseOut'/by_ownership/`o'/bin_`m'_`geo'_by_delta_`var'.png", replace width(2000)
                }
            }
        }
        * MEMORY FIX
        capture graph drop _all
    }
}
display "=== FACILITY HOPD BENCHMARKS COMPLETE ==="