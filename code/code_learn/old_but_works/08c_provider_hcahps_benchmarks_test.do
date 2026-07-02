*===============================================================================
* SCRIPT: 08c_provider_hcahps_benchmarks.do
* PURPOSE: Provider-Level Behavioral Benchmarks for HCAHPS (Symmetric Bins)
* FEATURES: Centralized Taxonomies, Upgraded Aesthetics, Strict Brace Parsing
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* --- START LOG ---
local script_name "08c_provider_hcahps_benchmarks_test"
log using "$logRoot/`script_name'.smcl", replace
* -----------------

capture ssc install binscatter
display "=== STARTING HCAHPS BENCHMARKS FOR: INPATIENT PROVIDERS ==="

* --- 1. LOAD DATA & DECODE STRINGS ---
use "$dataRoot/master_provider_inpatient_2013_2023.dta", clear
drop if missing(hcahps_100_score)
drop if hcahps_100_score < 0

display "Decoding and Formatting Categorical Variables..."
capture confirm string variable cms_specialty
if _rc != 0 decode cms_specialty, gen(spec_str)
else gen spec_str = cms_specialty

capture confirm string variable gender
if _rc != 0 decode gender, gen(gender_str)
else gen gender_str = gender

capture confirm string variable ownership
if _rc != 0 decode ownership, gen(own_str)
else gen own_str = ownership

capture confirm string variable cms_state
if _rc != 0 decode cms_state, gen(state_str)
else gen state_str = cms_state

replace spec_str = strtrim(strupper(spec_str))
replace own_str = strtrim(strupper(own_str))
replace state_str = strtrim(strupper(state_str))

* --- 2. STRATIFICATION PRE-PROCESSING (VIA 00_INITIALIZE GLOBALS) ---
display "Building Clean Stratification Categories..."

gen prov_type = "MD_DO"
replace prov_type = "NP" if strpos(spec_str, "NURSE PRACTITIONER") > 0
replace prov_type = "PA" if strpos(spec_str, "PHYSICIAN ASSISTANT") > 0

gen spec_cohort = "Other"
replace spec_cohort = "General_Medicine_Broad" if $cond_gen_med
replace spec_cohort = "Primary_Care_Strict" if $cond_prim_care

gen own_cat = "Other"
replace own_cat = "Government" if $cond_own_gov
replace own_cat = "Non_Profit" if $cond_own_nonprof
replace own_cat = "For_Profit" if $cond_own_forprof

gen np_auth = "Unknown"
replace np_auth = "Full_Practice" if $cond_full_prac
replace np_auth = "Reduced_Practice" if $cond_red_prac
replace np_auth = "Restricted_Practice" if $cond_res_prac

capture drop grad_decade
gen grad_decade = .
capture confirm numeric variable grad_year
if _rc == 0 {
    replace grad_decade = 1 if grad_year < 1990
    replace grad_decade = 2 if grad_year >= 1990 & grad_year < 2000
    replace grad_decade = 3 if grad_year >= 2000 & grad_year < 2010
    replace grad_decade = 4 if grad_year >= 2010 & !missing(grad_year)
}

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
gsort npi year -tot_benes
duplicates drop npi year, force
egen panel_id = group(npi)
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

* Uniform aesthetics matching 04_micro_outpatient_stats
local graph_opts "size(medium) color(black)"
local note_opts "position(7) justification(left) size(vsmall) margin(t=3 l=2) span"
local region_opts "color(white) margin(vsmall)"

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

        * ---------------------------------------------------------
        * 6A. UNIVERSAL
        * ---------------------------------------------------------
        capture mkdir "`baseOut'/universal"
        capture binscatter `var' lag_`m_var'_decline, discrete line(connect) title("`c_title' vs `m_title' Drop", `graph_opts') xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", `note_opts') graphregion(`region_opts')
        capture graph export "`baseOut'/universal/decline_`m'_vs_`var'.png", replace width(2000)
        
        foreach geo in "nat" "state" "county" "zip" {
            if "`geo'" == "nat" {
                local gname "National"
            }
            else if "`geo'" == "state" {
                local gname "State"
            }
            else if "`geo'" == "county" {
                local gname "County"
            }
            else if "`geo'" == "zip" {
                local gname "ZIP Code"
            }
            local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
            
            capture binscatter `var' lag_bin_`m'_`geo', discrete line(connect) title("`c_title' vs `gname' `m_title'", `graph_opts') xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", `note_opts') graphregion(`region_opts')
            capture graph export "`baseOut'/universal/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
        }

        * ---------------------------------------------------------
        * 6B. BY PROVIDER TYPE (OVERALL)
        * ---------------------------------------------------------
        capture mkdir "`baseOut'/by_prov_type"
        foreach p in `provs' {
            local p_clean = subinstr("`p'", "_", "/", .)
            capture mkdir "`baseOut'/by_prov_type/`p'"
            capture binscatter `var' lag_`m_var'_decline if prov_type == "`p'", discrete line(connect) title("`c_title' vs `m_title' Drop: `p_clean'", `graph_opts') xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", `note_opts') graphregion(`region_opts')
            capture graph export "`baseOut'/by_prov_type/`p'/decline_`m'_vs_`var'.png", replace width(2000)
            
            foreach geo in "nat" "state" "county" "zip" {
                if "`geo'" == "nat" {
                    local gname "National"
                }
                else if "`geo'" == "state" {
                    local gname "State"
                }
                else if "`geo'" == "county" {
                    local gname "County"
                }
                else if "`geo'" == "zip" {
                    local gname "ZIP Code"
                }
                local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
                
                capture binscatter `var' lag_bin_`m'_`geo' if prov_type == "`p'", discrete line(connect) title("`c_title' vs `gname' `m_title': `p_clean'", `graph_opts') xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", `note_opts') graphregion(`region_opts')
                capture graph export "`baseOut'/by_prov_type/`p'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
            }
        }

        * ---------------------------------------------------------
        * 6C. SPECIALTY COHORT (Nested)
        * ---------------------------------------------------------
        capture mkdir "`baseOut'/by_spec_cohort"
        levelsof spec_cohort, local(cohorts)
        foreach c in `cohorts' {
            local c_clean = subinstr("`c'", "_", " ", .)
            capture mkdir "`baseOut'/by_spec_cohort/`c'"
            capture binscatter `var' lag_`m_var'_decline if spec_cohort == "`c'", discrete line(connect) title("`c_title' vs `m_title' Drop: `c_clean'", `graph_opts') xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", `note_opts') graphregion(`region_opts')
            capture graph export "`baseOut'/by_spec_cohort/`c'/decline_`m'_vs_`var'.png", replace width(2000)
            
            foreach geo in "nat" "state" "county" "zip" {
                if "`geo'" == "nat" {
                    local gname "National"
                }
                else if "`geo'" == "state" {
                    local gname "State"
                }
                else if "`geo'" == "county" {
                    local gname "County"
                }
                else if "`geo'" == "zip" {
                    local gname "ZIP Code"
                }
                local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
                
                capture binscatter `var' lag_bin_`m'_`geo' if spec_cohort == "`c'", discrete line(connect) title("`c_title' vs `gname' `m_title': `c_clean'", `graph_opts') xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", `note_opts') graphregion(`region_opts')
                capture graph export "`baseOut'/by_spec_cohort/`c'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
            }

            foreach p in `provs' {
                local p_clean = subinstr("`p'", "_", "/", .)
                count if spec_cohort == "`c'" & prov_type == "`p'"
                if r(N) > 0 {
                    capture mkdir "`baseOut'/by_spec_cohort/`c'/`p'"
                    capture binscatter `var' lag_`m_var'_decline if spec_cohort == "`c'" & prov_type == "`p'", discrete line(connect) title("`c_title' Drop: `p_clean' (`c_clean')", `graph_opts') xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", `note_opts') graphregion(`region_opts')
                    capture graph export "`baseOut'/by_spec_cohort/`c'/`p'/decline_`m'_vs_`var'.png", replace width(2000)
                    
                    foreach geo in "nat" "state" "county" "zip" {
                        if "`geo'" == "nat" {
                            local gname "National"
                        }
                        else if "`geo'" == "state" {
                            local gname "State"
                        }
                        else if "`geo'" == "county" {
                            local gname "County"
                        }
                        else if "`geo'" == "zip" {
                            local gname "ZIP Code"
                        }
                        local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
                        
                        capture binscatter `var' lag_bin_`m'_`geo' if spec_cohort == "`c'" & prov_type == "`p'", discrete line(connect) title("`gname' `m_title': `p_clean' (`c_clean')", `graph_opts') xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", `note_opts') graphregion(`region_opts')
                        capture graph export "`baseOut'/by_spec_cohort/`c'/`p'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
                    }
                }
            }
        }

        * ---------------------------------------------------------
        * 6D. STATE NP AUTHORITY (Nested)
        * ---------------------------------------------------------
        capture mkdir "`baseOut'/by_np_auth"
        levelsof np_auth, local(auths)
        foreach a in `auths' {
            local a_clean = subinstr("`a'", "_", " ", .)
            capture mkdir "`baseOut'/by_np_auth/`a'"
            capture binscatter `var' lag_`m_var'_decline if np_auth == "`a'", discrete line(connect) title("`c_title' vs `m_title' Drop: `a_clean'", `graph_opts') xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", `note_opts') graphregion(`region_opts')
            capture graph export "`baseOut'/by_np_auth/`a'/decline_`m'_vs_`var'.png", replace width(2000)
            
            foreach geo in "nat" "state" "county" "zip" {
                if "`geo'" == "nat" {
                    local gname "National"
                }
                else if "`geo'" == "state" {
                    local gname "State"
                }
                else if "`geo'" == "county" {
                    local gname "County"
                }
                else if "`geo'" == "zip" {
                    local gname "ZIP Code"
                }
                local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
                
                capture binscatter `var' lag_bin_`m'_`geo' if np_auth == "`a'", discrete line(connect) title("`c_title' vs `gname' `m_title': `a_clean'", `graph_opts') xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", `note_opts') graphregion(`region_opts')
                capture graph export "`baseOut'/by_np_auth/`a'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
            }

            foreach p in `provs' {
                local p_clean = subinstr("`p'", "_", "/", .)
                count if np_auth == "`a'" & prov_type == "`p'"
                if r(N) > 0 {
                    capture mkdir "`baseOut'/by_np_auth/`a'/`p'"
                    capture binscatter `var' lag_`m_var'_decline if np_auth == "`a'" & prov_type == "`p'", discrete line(connect) title("`c_title' Drop: `p_clean' (`a_clean')", `graph_opts') xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", `note_opts') graphregion(`region_opts')
                    capture graph export "`baseOut'/by_np_auth/`a'/`p'/decline_`m'_vs_`var'.png", replace width(2000)
                    
                    foreach geo in "nat" "state" "county" "zip" {
                        if "`geo'" == "nat" {
                            local gname "National"
                        }
                        else if "`geo'" == "state" {
                            local gname "State"
                        }
                        else if "`geo'" == "county" {
                            local gname "County"
                        }
                        else if "`geo'" == "zip" {
                            local gname "ZIP Code"
                        }
                        local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
                        
                        capture binscatter `var' lag_bin_`m'_`geo' if np_auth == "`a'" & prov_type == "`p'", discrete line(connect) title("`gname' `m_title': `p_clean' (`a_clean')", `graph_opts') xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", `note_opts') graphregion(`region_opts')
                        capture graph export "`baseOut'/by_np_auth/`a'/`p'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
                    }
                }
            }
        }

        * ---------------------------------------------------------
        * 6E. OWNERSHIP (Nested)
        * ---------------------------------------------------------
        capture mkdir "`baseOut'/by_ownership"
        levelsof own_cat, local(owns)
        foreach o in `owns' {
            local o_clean = subinstr("`o'", "_", "-", .)
            capture mkdir "`baseOut'/by_ownership/`o'"
            capture binscatter `var' lag_`m_var'_decline if own_cat == "`o'", discrete line(connect) title("`c_title' vs `m_title' Drop: `o_clean'", `graph_opts') xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", `note_opts') graphregion(`region_opts')
            capture graph export "`baseOut'/by_ownership/`o'/decline_`m'_vs_`var'.png", replace width(2000)
            
            foreach geo in "nat" "state" "county" "zip" {
                if "`geo'" == "nat" {
                    local gname "National"
                }
                else if "`geo'" == "state" {
                    local gname "State"
                }
                else if "`geo'" == "county" {
                    local gname "County"
                }
                else if "`geo'" == "zip" {
                    local gname "ZIP Code"
                }
                local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
                
                capture binscatter `var' lag_bin_`m'_`geo' if own_cat == "`o'", discrete line(connect) title("`c_title' vs `gname' `m_title': `o_clean'", `graph_opts') xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", `note_opts') graphregion(`region_opts')
                capture graph export "`baseOut'/by_ownership/`o'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
            }

            foreach p in `provs' {
                local p_clean = subinstr("`p'", "_", "/", .)
                count if own_cat == "`o'" & prov_type == "`p'"
                if r(N) > 0 {
                    capture mkdir "`baseOut'/by_ownership/`o'/`p'"
                    capture binscatter `var' lag_`m_var'_decline if own_cat == "`o'" & prov_type == "`p'", discrete line(connect) title("`c_title' Drop: `p_clean' (`o_clean')", `graph_opts') xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", `note_opts') graphregion(`region_opts')
                    capture graph export "`baseOut'/by_ownership/`o'/`p'/decline_`m'_vs_`var'.png", replace width(2000)
                    
                    foreach geo in "nat" "state" "county" "zip" {
                        if "`geo'" == "nat" {
                            local gname "National"
                        }
                        else if "`geo'" == "state" {
                            local gname "State"
                        }
                        else if "`geo'" == "county" {
                            local gname "County"
                        }
                        else if "`geo'" == "zip" {
                            local gname "ZIP Code"
                        }
                        local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
                        
                        capture binscatter `var' lag_bin_`m'_`geo' if own_cat == "`o'" & prov_type == "`p'", discrete line(connect) title("`gname' `m_title': `p_clean' (`o_clean')", `graph_opts') xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", `note_opts') graphregion(`region_opts')
                        capture graph export "`baseOut'/by_ownership/`o'/`p'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
                    }
                }
            }
        }

        * ---------------------------------------------------------
        * 6F. GENDER (Nested)
        * ---------------------------------------------------------
        capture mkdir "`baseOut'/by_gender"
        levelsof gender_str, local(genders)
        foreach g in `genders' {
            if "`g'" != "" {
                local g_clean = strproper("`g'")

                capture mkdir "`baseOut'/by_gender/`g'"
                capture binscatter `var' lag_`m_var'_decline if gender_str == "`g'", discrete line(connect) title("`c_title' vs `m_title' Drop: `g_clean'", `graph_opts') xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", `note_opts') graphregion(`region_opts')
                capture graph export "`baseOut'/by_gender/`g'/decline_`m'_vs_`var'.png", replace width(2000)
                
                foreach geo in "nat" "state" "county" "zip" {
                    if "`geo'" == "nat" {
                        local gname "National"
                    }
                    else if "`geo'" == "state" {
                        local gname "State"
                    }
                    else if "`geo'" == "county" {
                        local gname "County"
                    }
                    else if "`geo'" == "zip" {
                        local gname "ZIP Code"
                    }
                    local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
                    
                    capture binscatter `var' lag_bin_`m'_`geo' if gender_str == "`g'", discrete line(connect) title("`c_title' vs `gname' `m_title': `g_clean'", `graph_opts') xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", `note_opts') graphregion(`region_opts')
                    capture graph export "`baseOut'/by_gender/`g'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
                }

                foreach p in `provs' {
                    local p_clean = subinstr("`p'", "_", "/", .)
                    count if gender_str == "`g'" & prov_type == "`p'"
                    if r(N) > 0 {
                        capture mkdir "`baseOut'/by_gender/`g'/`p'"
                        capture binscatter `var' lag_`m_var'_decline if gender_str == "`g'" & prov_type == "`p'", discrete line(connect) title("`c_title' Drop: `p_clean' (`g_clean')", `graph_opts') xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", `note_opts') graphregion(`region_opts')
                        capture graph export "`baseOut'/by_gender/`g'/`p'/decline_`m'_vs_`var'.png", replace width(2000)
                        
                        foreach geo in "nat" "state" "county" "zip" {
                            if "`geo'" == "nat" {
                                local gname "National"
                            }
                            else if "`geo'" == "state" {
                                local gname "State"
                            }
                            else if "`geo'" == "county" {
                                local gname "County"
                            }
                            else if "`geo'" == "zip" {
                                local gname "ZIP Code"
                            }
                            local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
                            
                            capture binscatter `var' lag_bin_`m'_`geo' if gender_str == "`g'" & prov_type == "`p'", discrete line(connect) title("`gname' `m_title': `p_clean' (`g_clean')", `graph_opts') xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", `note_opts') graphregion(`region_opts')
                            capture graph export "`baseOut'/by_gender/`g'/`p'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
                        }
                    }
                }
            }
        }

        * ---------------------------------------------------------
        * 6G. GRADUATION DECADE (Nested)
        * ---------------------------------------------------------
        capture mkdir "`baseOut'/by_grad_decade"
        levelsof grad_decade, local(decades)
        foreach d in `decades' {
            if `d' == 1 { 
                local d_clean "Pre-1990" 
                local d_folder "Pre_1990" 
            }
            else if `d' == 2 { 
                local d_clean "1990s" 
                local d_folder "Grads_1990s" 
            }
            else if `d' == 3 { 
                local d_clean "2000s" 
                local d_folder "Grads_2000s" 
            }
            else if `d' == 4 { 
                local d_clean "2010s+" 
                local d_folder "Grads_2010s" 
            }
            else { 
                local d_clean "Unknown" 
                local d_folder "Unknown" 
            }

            capture mkdir "`baseOut'/by_grad_decade/`d_folder'"
            capture binscatter `var' lag_`m_var'_decline if grad_decade == `d', discrete line(connect) title("`c_title' by `m_title' Drop: `d_clean'", `graph_opts') xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", `note_opts') graphregion(`region_opts')
            capture graph export "`baseOut'/by_grad_decade/`d_folder'/decline_`m'_vs_`var'.png", replace width(2000)
            
            foreach geo in "nat" "state" "county" "zip" {
                if "`geo'" == "nat" {
                    local gname "National"
                }
                else if "`geo'" == "state" {
                    local gname "State"
                }
                else if "`geo'" == "county" {
                    local gname "County"
                }
                else if "`geo'" == "zip" {
                    local gname "ZIP Code"
                }
                local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
                
                capture binscatter `var' lag_bin_`m'_`geo' if grad_decade == `d', discrete line(connect) title("`c_title' by `gname' `m_title': `d_clean'", `graph_opts') xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", `note_opts') graphregion(`region_opts')
                capture graph export "`baseOut'/by_grad_decade/`d_folder'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
            }

            foreach p in `provs' {
                local p_clean = subinstr("`p'", "_", "/", .)
                count if grad_decade == `d' & prov_type == "`p'"
                if r(N) > 0 {
                    capture mkdir "`baseOut'/by_grad_decade/`d_folder'/`p'"
                    capture binscatter `var' lag_`m_var'_decline if grad_decade == `d' & prov_type == "`p'", discrete line(connect) title("`c_title' Drop: `p_clean' (`d_clean')", `graph_opts') xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", `note_opts') graphregion(`region_opts')
                    capture graph export "`baseOut'/by_grad_decade/`d_folder'/`p'/decline_`m'_vs_`var'.png", replace width(2000)
                    
                    foreach geo in "nat" "state" "county" "zip" {
                        if "`geo'" == "nat" {
                            local gname "National"
                        }
                        else if "`geo'" == "state" {
                            local gname "State"
                        }
                        else if "`geo'" == "county" {
                            local gname "County"
                        }
                        else if "`geo'" == "zip" {
                            local gname "ZIP Code"
                        }
                        local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean in t-1."
                        
                        capture binscatter `var' lag_bin_`m'_`geo' if grad_decade == `d' & prov_type == "`p'", discrete line(connect) title("`gname' `m_title': `p_clean' (`d_clean')", `graph_opts') xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", `note_opts') graphregion(`region_opts')
                        capture graph export "`baseOut'/by_grad_decade/`d_folder'/`p'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
                    }
                }
            }
        }
        
        * MEMORY FIX: Flush Stata's graph memory after each variable block to prevent crashing
        capture graph drop _all
    }
}
display "=== PROVIDER HCAHPS BENCHMARKS COMPLETE ==="
