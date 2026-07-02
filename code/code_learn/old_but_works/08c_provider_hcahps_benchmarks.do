*===============================================================================
* SCRIPT: 08c_provider_hcahps_benchmarks.do
* PURPOSE: Provider-Level Behavioral Benchmarks for HCAHPS (Symmetric Bins)
* FEATURES: Nested Stratifications & Sub-Composite Analysis (Grp 1-4)
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* --- START LOG ---
local script_name "08c_provider_hcahps_benchmarks"
log using "$logRoot/`script_name'.smcl", replace
* -----------------

capture ssc install binscatter
display "=== STARTING HCAHPS BENCHMARKS FOR: INPATIENT PROVIDERS ==="

* --- 1. LOAD DATA & DECODE STRINGS ---
use "$dataRoot/master_provider_inpatient_2013_2023.dta", clear
drop if missing(hcahps_100_score)
drop if hcahps_100_score < 0

display "Decoding and Formatting Categorical Variables..."
decode cms_specialty, gen(spec_str)
decode gender, gen(gender_str)
decode ownership, gen(own_str)
decode cms_state, gen(state_str)

replace spec_str = strtrim(strupper(spec_str))
replace own_str = strtrim(strupper(own_str))

* --- 2. STRATIFICATION PRE-PROCESSING ---
display "Building Clean Stratification Categories..."

gen prov_type = "MD_DO"
replace prov_type = "NP" if spec_str == "NURSE PRACTITIONER"
replace prov_type = "PA" if spec_str == "PHYSICIAN ASSISTANT"

gen spec_cohort = "Other"
replace spec_cohort = "General_Medicine_Broad" if inlist(spec_str, "INTERNAL MEDICINE", "FAMILY PRACTICE", "GENERAL PRACTICE", "EMERGENCY MEDICINE", "HOSPITALIST", "NURSE PRACTITIONER", "PHYSICIAN ASSISTANT", "PAIN MANAGEMENT")
replace spec_cohort = "Primary_Care_Strict" if inlist(spec_str, "FAMILY PRACTICE", "GENERAL PRACTICE")

gen own_cat = "Other"
replace own_cat = "Government" if strmatch(own_str, "*GOVERNMENT*")
replace own_cat = "Non_Profit" if strmatch(own_str, "*NON-PROFIT*")
replace own_cat = "For_Profit" if strmatch(own_str, "*PROPRIETARY*")

gen np_auth = "Unknown"
replace np_auth = "Full_Practice" if inlist(state_str, "AZ", "CO", "CT", "DC", "HI", "ID", "IA", "MD", "MA") | inlist(state_str, "MN", "MT", "NE", "NV", "NH", "NM", "NY", "ND", "OR") | inlist(state_str, "RI", "SD", "VT", "WA", "WY")
replace np_auth = "Reduced_Practice" if inlist(state_str, "AL", "AS", "DE", "IL", "IN", "KS", "KY", "LA", "MS") | inlist(state_str, "NJ", "OH", "PA", "UT", "WI")
replace np_auth = "Restricted_Practice" if inlist(state_str, "CA", "FL", "GA", "MI", "MO", "NC", "OK", "SC", "TN") | inlist(state_str, "TX", "VA")

keep if inlist(spec_cohort, "General_Medicine_Broad", "Primary_Care_Strict")

* --- 3. BUILD GEOGRAPHIC DICTIONARIES (ALL METRICS) ---
display "Calculating Geographic Standard Deviations..."
foreach geo in "nat" "state" "county" "zip" {
    preserve
    if "`geo'" == "nat" local byvar "year"
    if "`geo'" == "state" local byvar "state_str year"
    if "`geo'" == "county" local byvar "county year"
    if "`geo'" == "zip" local byvar "cms_zip year"
    
    if "`geo'" != "nat" { 
        foreach var in `byvar' {
            drop if missing(`var') 
        }
    }
    
    * CRITICAL: Collapse all 5 HCAHPS scores
    collapse (mean) mean_h100=hcahps_100_score mean_g1=hcahps_grp1 mean_g2=hcahps_grp2 mean_g3=hcahps_grp3 mean_g4=hcahps_grp4 ///
             (sd) sd_h100=hcahps_100_score sd_g1=hcahps_grp1 sd_g2=hcahps_grp2 sd_g3=hcahps_grp3 sd_g4=hcahps_grp4 ///
             [aw=tot_benes], by(`byvar')
    
    rename mean_* `geo'_mean_*
    rename sd_* `geo'_sd_*
    
    tempfile bench_`geo'
    save `bench_`geo'', replace
    restore
}

* --- 3.5 MERGE DICTIONARIES BACK ---
merge m:1 year using `bench_nat', nogen
merge m:1 state_str year using `bench_state', nogen
merge m:1 county year using `bench_county', nogen
merge m:1 cms_zip year using `bench_zip', nogen

* --- 4. Z-SCORES & SYMMETRIC BINS ---
display "Applying Symmetric SD Thresholds..."
local m_list "h100 g1 g2 g3 g4"

foreach geo in "nat" "state" "county" "zip" {
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
label define sym_lbl -4 "<-2 SD" -3 "-2to-1" -2 "-1to-.5" -1 "-.5to0" 1 "0to.5" 2 ".5to1" 3 "1to2" 4 ">2 SD"

* --- 5. DECLARE PANEL & CREATE LAGS ---
* Sort by patient volume (highest to lowest) to ensure the primary hospital is retained
gsort npi year -tot_benes

* Force unique provider-years based on primary affiliation
duplicates drop npi year, force
egen panel_id = group(npi)
xtset panel_id year

* Absolute Declines for all 5 measures
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

* Geographic Lag Bins
foreach geo in "nat" "state" "county" "zip" {
    foreach m in `m_list' {
        gen lag_bin_`m'_`geo' = L.bin_`m'_`geo'
        label values lag_bin_`m'_`geo' sym_lbl
    }
}

* --- 6. GRAPHING ENGINE & NESTED LOOPS ---
display "Generating Journal-Ready Stratified Visualizations..."
local behavior_vars "partd_opioid_rate partb_em_upcode_rate partb_low_value_rate partb_imaging_adv_rate"
levelsof prov_type, local(provs)

local baseOut "$outRoot/summary_stats/in_patient/benchmarks_hcahps_provider"
capture mkdir "`baseOut'"

* Outer Loop 1: Provider Behaviors
foreach var in `behavior_vars' {
    
    if "`var'" == "partd_opioid_rate" {
        local c_title "Opioid Rate"
        local v_note "Opioid Rate: Opioid claims as a proportion of total Part D claims."
    }
    else if "`var'" == "partb_em_upcode_rate" {
        local c_title "Upcoding Rate"
        local v_note "Upcoding Rate: Level 4/5 Evaluation & Management visits as a proportion of total E&M visits."
    }
    else if "`var'" == "partb_low_value_rate" {
        local c_title "Low-Value Care"
        local v_note "Low-Value Care: Choosing Wisely discouraged services as a proportion of total Part B services."
    }
    else if "`var'" == "partb_imaging_adv_rate" {
        local c_title "Adv. Imaging"
        local v_note "Advanced Imaging: MRI and CT scans as a proportion of total Part B services."
    }

    * Outer Loop 2: HCAHPS Measures (Overall + Thesis Groups 1-4)
    foreach m in `m_list' {
        if "`m'" == "h100" {
            local m_title "Overall HCAHPS"
            local m_var "hcahps"
            local ft_meas "Metric: Overall 100-Point Composite."
        }
        else if "`m'" == "g1" {
            local m_title "Staff Comm."
            local m_var "g1"
            local ft_meas "Metric: Grp 1 (Staff Communication w/ Patient)."
        }
        else if "`m'" == "g2" {
            local m_title "Patient Help"
            local m_var "g2"
            local ft_meas "Metric: Grp 2 (Providing the Patient Help)."
        }
        else if "`m'" == "g3" {
            local m_title "Environment"
            local m_var "g3"
            local ft_meas "Metric: Grp 3 (Facility Cleanliness/Quietness)."
        }
        else if "`m'" == "g4" {
            local m_title "Global Rating"
            local m_var "g4"
            local ft_meas "Metric: Grp 4 (Global Rating & Recommendation)."
        }
        
        local ft_dec "Decline: Binary (1=Yes) if the facility's `m_title' score dropped from year t-2 to t-1."

        * 6A. UNIVERSAL
        capture mkdir "`baseOut'/universal"
        capture binscatter `var' lag_`m_var'_decline, discrete line(connect) title("`c_title' vs `m_title' Drop", size(medium)) xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", size(vsmall)) graphregion(color(white))
        capture graph export "`baseOut'/universal/decline_`m'_vs_`var'.png", replace width(2000)
        
        foreach geo in "nat" "state" "county" "zip" {
            if "`geo'" == "nat" local gname "National"
            if "`geo'" == "state" local gname "State"
            if "`geo'" == "county" local gname "County"
            if "`geo'" == "zip" local gname "ZIP Code"
            local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
            
            capture binscatter `var' lag_bin_`m'_`geo', discrete line(connect) title("`c_title' vs `gname' `m_title'", size(medium)) xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", size(vsmall)) graphregion(color(white))
            capture graph export "`baseOut'/universal/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
        }

        * 6B. BY PROVIDER TYPE (OVERALL)
        capture mkdir "`baseOut'/by_prov_type"
        foreach p in `provs' {
            capture mkdir "`baseOut'/by_prov_type/`p'"
            capture binscatter `var' lag_`m_var'_decline if prov_type == "`p'", discrete line(connect) title("`c_title' vs `m_title' Drop: `p'", size(medium)) xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", size(vsmall)) graphregion(color(white))
            capture graph export "`baseOut'/by_prov_type/`p'/decline_`m'_vs_`var'.png", replace width(2000)
            
            foreach geo in "nat" "state" "county" "zip" {
                if "`geo'" == "nat" local gname "National"
                if "`geo'" == "state" local gname "State"
                if "`geo'" == "county" local gname "County"
                if "`geo'" == "zip" local gname "ZIP Code"
                local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
                
                capture binscatter `var' lag_bin_`m'_`geo' if prov_type == "`p'", discrete line(connect) title("`c_title' vs `gname' `m_title': `p'", size(medium)) xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", size(vsmall)) graphregion(color(white))
                capture graph export "`baseOut'/by_prov_type/`p'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
            }
        }

        * 6C. SPECIALTY COHORT (Nested)
        capture mkdir "`baseOut'/by_spec_cohort"
        levelsof spec_cohort, local(cohorts)
        foreach c in `cohorts' {
            capture mkdir "`baseOut'/by_spec_cohort/`c'"
            capture binscatter `var' lag_`m_var'_decline if spec_cohort == "`c'", discrete line(connect) title("`c_title' vs `m_title' Drop: `c'", size(medium)) xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", size(vsmall)) graphregion(color(white))
            capture graph export "`baseOut'/by_spec_cohort/`c'/decline_`m'_vs_`var'.png", replace width(2000)
            
            foreach geo in "nat" "state" "county" "zip" {
                if "`geo'" == "nat" local gname "National"
                if "`geo'" == "state" local gname "State"
                if "`geo'" == "county" local gname "County"
                if "`geo'" == "zip" local gname "ZIP Code"
                local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
                
                capture binscatter `var' lag_bin_`m'_`geo' if spec_cohort == "`c'", discrete line(connect) title("`c_title' vs `gname' `m_title': `c'", size(medium)) xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", size(vsmall)) graphregion(color(white))
                capture graph export "`baseOut'/by_spec_cohort/`c'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
            }

            foreach p in `provs' {
                count if spec_cohort == "`c'" & prov_type == "`p'"
                if r(N) > 0 {
                    capture mkdir "`baseOut'/by_spec_cohort/`c'/`p'"
                    capture binscatter `var' lag_`m_var'_decline if spec_cohort == "`c'" & prov_type == "`p'", discrete line(connect) title("`c_title' Drop: `p' in `c'", size(medium)) xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", size(vsmall)) graphregion(color(white))
                    capture graph export "`baseOut'/by_spec_cohort/`c'/`p'/decline_`m'_vs_`var'.png", replace width(2000)
                    
                    foreach geo in "nat" "state" "county" "zip" {
                        if "`geo'" == "nat" local gname "National"
                        if "`geo'" == "state" local gname "State"
                        if "`geo'" == "county" local gname "County"
                        if "`geo'" == "zip" local gname "ZIP Code"
                        local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
                        
                        capture binscatter `var' lag_bin_`m'_`geo' if spec_cohort == "`c'" & prov_type == "`p'", discrete line(connect) title("`gname' `m_title': `p' in `c'", size(medium)) xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", size(vsmall)) graphregion(color(white))
                        capture graph export "`baseOut'/by_spec_cohort/`c'/`p'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
                    }
                }
            }
        }

        * 6D. STATE NP AUTHORITY (Nested)
        capture mkdir "`baseOut'/by_np_auth"
        levelsof np_auth, local(auths)
        foreach a in `auths' {
            capture mkdir "`baseOut'/by_np_auth/`a'"
            capture binscatter `var' lag_`m_var'_decline if np_auth == "`a'", discrete line(connect) title("`c_title' vs `m_title' Drop: `a'", size(medium)) xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", size(vsmall)) graphregion(color(white))
            capture graph export "`baseOut'/by_np_auth/`a'/decline_`m'_vs_`var'.png", replace width(2000)
            
            foreach geo in "nat" "state" "county" "zip" {
                if "`geo'" == "nat" local gname "National"
                if "`geo'" == "state" local gname "State"
                if "`geo'" == "county" local gname "County"
                if "`geo'" == "zip" local gname "ZIP Code"
                local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
                
                capture binscatter `var' lag_bin_`m'_`geo' if np_auth == "`a'", discrete line(connect) title("`c_title' vs `gname' `m_title': `a'", size(medium)) xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", size(vsmall)) graphregion(color(white))
                capture graph export "`baseOut'/by_np_auth/`a'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
            }

            foreach p in `provs' {
                count if np_auth == "`a'" & prov_type == "`p'"
                if r(N) > 0 {
                    capture mkdir "`baseOut'/by_np_auth/`a'/`p'"
                    capture binscatter `var' lag_`m_var'_decline if np_auth == "`a'" & prov_type == "`p'", discrete line(connect) title("`c_title' Drop: `p' in `a'", size(medium)) xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", size(vsmall)) graphregion(color(white))
                    capture graph export "`baseOut'/by_np_auth/`a'/`p'/decline_`m'_vs_`var'.png", replace width(2000)
                    
                    foreach geo in "nat" "state" "county" "zip" {
                        if "`geo'" == "nat" local gname "National"
                        if "`geo'" == "state" local gname "State"
                        if "`geo'" == "county" local gname "County"
                        if "`geo'" == "zip" local gname "ZIP Code"
                        local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
                        
                        capture binscatter `var' lag_bin_`m'_`geo' if np_auth == "`a'" & prov_type == "`p'", discrete line(connect) title("`gname' `m_title': `p' in `a'", size(medium)) xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", size(vsmall)) graphregion(color(white))
                        capture graph export "`baseOut'/by_np_auth/`a'/`p'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
                    }
                }
            }
        }

        * 6E. OWNERSHIP (Nested)
        capture mkdir "`baseOut'/by_ownership"
        levelsof own_cat, local(owns)
        foreach o in `owns' {
            capture mkdir "`baseOut'/by_ownership/`o'"
            capture binscatter `var' lag_`m_var'_decline if own_cat == "`o'", discrete line(connect) title("`c_title' vs `m_title' Drop: `o'", size(medium)) xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", size(vsmall)) graphregion(color(white))
            capture graph export "`baseOut'/by_ownership/`o'/decline_`m'_vs_`var'.png", replace width(2000)
            
            foreach geo in "nat" "state" "county" "zip" {
                if "`geo'" == "nat" local gname "National"
                if "`geo'" == "state" local gname "State"
                if "`geo'" == "county" local gname "County"
                if "`geo'" == "zip" local gname "ZIP Code"
                local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
                
                capture binscatter `var' lag_bin_`m'_`geo' if own_cat == "`o'", discrete line(connect) title("`c_title' vs `gname' `m_title': `o'", size(medium)) xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", size(vsmall)) graphregion(color(white))
                capture graph export "`baseOut'/by_ownership/`o'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
            }

            foreach p in `provs' {
                count if own_cat == "`o'" & prov_type == "`p'"
                if r(N) > 0 {
                    capture mkdir "`baseOut'/by_ownership/`o'/`p'"
                    capture binscatter `var' lag_`m_var'_decline if own_cat == "`o'" & prov_type == "`p'", discrete line(connect) title("`c_title' Drop: `p' in `o'", size(medium)) xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", size(vsmall)) graphregion(color(white))
                    capture graph export "`baseOut'/by_ownership/`o'/`p'/decline_`m'_vs_`var'.png", replace width(2000)
                    
                    foreach geo in "nat" "state" "county" "zip" {
                        if "`geo'" == "nat" local gname "National"
                        if "`geo'" == "state" local gname "State"
                        if "`geo'" == "county" local gname "County"
                        if "`geo'" == "zip" local gname "ZIP Code"
                        local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
                        
                        capture binscatter `var' lag_bin_`m'_`geo' if own_cat == "`o'" & prov_type == "`p'", discrete line(connect) title("`gname' `m_title': `p' in `o'", size(medium)) xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", size(vsmall)) graphregion(color(white))
                        capture graph export "`baseOut'/by_ownership/`o'/`p'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
                    }
                }
            }
        }

        * 6F. GENDER (Nested)
        capture mkdir "`baseOut'/by_gender"
        levelsof gender_str, local(genders)
        foreach g in `genders' {
            if "`g'" != "" {
                capture mkdir "`baseOut'/by_gender/`g'"
                capture binscatter `var' lag_`m_var'_decline if gender_str == "`g'", discrete line(connect) title("`c_title' vs `m_title' Drop: `g'", size(medium)) xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", size(vsmall)) graphregion(color(white))
                capture graph export "`baseOut'/by_gender/`g'/decline_`m'_vs_`var'.png", replace width(2000)
                
                foreach geo in "nat" "state" "county" "zip" {
                    if "`geo'" == "nat" local gname "National"
                    if "`geo'" == "state" local gname "State"
                    if "`geo'" == "county" local gname "County"
                    if "`geo'" == "zip" local gname "ZIP Code"
                    local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
                    
                    capture binscatter `var' lag_bin_`m'_`geo' if gender_str == "`g'", discrete line(connect) title("`c_title' vs `gname' `m_title': `g'", size(medium)) xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", size(vsmall)) graphregion(color(white))
                    capture graph export "`baseOut'/by_gender/`g'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
                }

                foreach p in `provs' {
                    count if gender_str == "`g'" & prov_type == "`p'"
                    if r(N) > 0 {
                        capture mkdir "`baseOut'/by_gender/`g'/`p'"
                        capture binscatter `var' lag_`m_var'_decline if gender_str == "`g'" & prov_type == "`p'", discrete line(connect) title("`c_title' Drop: `p' (`g')", size(medium)) xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", size(vsmall)) graphregion(color(white))
                        capture graph export "`baseOut'/by_gender/`g'/`p'/decline_`m'_vs_`var'.png", replace width(2000)
                        
                        foreach geo in "nat" "state" "county" "zip" {
                            if "`geo'" == "nat" local gname "National"
                            if "`geo'" == "state" local gname "State"
                            if "`geo'" == "county" local gname "County"
                            if "`geo'" == "zip" local gname "ZIP Code"
                            local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
                            
                            capture binscatter `var' lag_bin_`m'_`geo' if gender_str == "`g'" & prov_type == "`p'", discrete line(connect) title("`gname' `m_title': `p' (`g')", size(medium)) xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", size(vsmall)) graphregion(color(white))
                            capture graph export "`baseOut'/by_gender/`g'/`p'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
                        }
                    }
                }
            }
        }
    }
}
display "=== PROVIDER HCAHPS BENCHMARKS COMPLETE ==="
