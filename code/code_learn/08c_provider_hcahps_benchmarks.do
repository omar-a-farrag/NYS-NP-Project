*===============================================================================
* SCRIPT: 08c_provider_hcahps_benchmarks.do
* PURPOSE: Provider-Level Behavioral Benchmarks for HCAHPS
* FEATURES: Ultra-Fast Engine, Dynamic Lags, Verified Dictionary (Including Ratings)
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* --- START LOG ---
local script_name "08c_provider_hcahps_benchmarks_test"
log using "$logRoot/`script_name'.smcl", replace
* -----------------

* --- 0. CONTROLS ---
global testing_mode = 1
global lag_years = 2

display "=== STARTING HCAHPS BENCHMARKS FOR: INPATIENT PROVIDERS ==="

* --- 1. DYNAMIC FOLDER CREATION ---
capture mkdir "$outRoot/summary_stats/in_patient/benchmarks_hcahps_provider"
local baseOut "$outRoot/summary_stats/in_patient/benchmarks_hcahps_provider"
capture mkdir "`baseOut'"

* --- 2. LOAD DATA & TEST SAMPLE ---
use "$dataRoot/master_provider_inpatient_2013_2023.dta", clear
capture drop if missing(hcahps_100_score)
capture drop if hcahps_100_score < 0

if $testing_mode == 1 {
    display "TESTING MODE ENABLED: Drawing a 5% sample of unique providers..."
    preserve
    contract npi
    sample 5
    tempfile test_samp
    save `test_samp'
    restore
    merge m:1 npi using `test_samp', keep(match) nogen
}

* --- 3. DECODE STRINGS & CLEAN TAXONOMIES ---
display "Decoding and Formatting Categorical Variables..."
capture confirm string variable cms_specialty
if _rc != 0 {
    decode cms_specialty, gen(spec_str)
}
else {
    gen spec_str = cms_specialty
}

capture confirm string variable gender
if _rc != 0 {
    decode gender, gen(gender_str)
}
else {
    gen gender_str = gender
}

capture confirm string variable ownership
if _rc != 0 {
    decode ownership, gen(own_str)
}
else {
    gen own_str = ownership
}

capture confirm string variable cms_state
if _rc != 0 {
    decode cms_state, gen(state_str)
}
else {
    gen state_str = cms_state
}

replace spec_str = strtrim(strupper(spec_str))
replace own_str = strtrim(strupper(own_str))
replace state_str = strtrim(strupper(state_str))

* Numeric Labeling for Dynamic Legends
gen overall_grp = 1
label define ovr_lbl 1 "National Average"
label values overall_grp ovr_lbl

gen none_grp = 1
label define none_lbl 1 "All"
label values none_grp none_lbl

gen prov_num = 3
replace prov_num = 1 if strpos(spec_str, "NURSE PRACTITIONER") > 0
replace prov_num = 2 if strpos(spec_str, "PHYSICIAN ASSISTANT") > 0
label define pt_lbl 1 "NP" 2 "PA" 3 "MD/DO"
label values prov_num pt_lbl

* --- SPECIALTY GROUPING (3 Categories) ---
* Category 1 — Primary Care:      $cond_prim_care  (Family Practice, General Practice)
* Category 2 — General Medicine:  remaining $cond_gen_med (Emerg. Medicine, Hospitalist,
*                                  Internal Medicine, NP, PA, Pain Management)
* Category 3 — Other Specialties: all remaining CMS specialties not in groups 1-2
gen spec_num = 3
replace spec_num = 1 if $cond_prim_care
replace spec_num = 2 if $cond_gen_med & spec_num == 3
label define sp_lbl 1 "Primary Care" 2 "General Medicine" 3 "Other Specialties"
label values spec_num sp_lbl

gen own_num = 4
replace own_num = 1 if $cond_own_gov
replace own_num = 2 if $cond_own_nonprof
replace own_num = 3 if $cond_own_forprof
label define own_lbl 1 "Government" 2 "Non-Profit" 3 "For-Profit" 4 "Other"
label values own_num own_lbl

gen auth_num = 4
replace auth_num = 1 if $cond_full_prac
replace auth_num = 2 if $cond_red_prac
replace auth_num = 3 if $cond_res_prac
label define auth_lbl 1 "Full Practice" 2 "Reduced Practice" 3 "Restricted Practice" 4 "Unknown"
label values auth_num auth_lbl

gen gender_num = .
replace gender_num = 1 if gender_str == "F"
replace gender_num = 2 if gender_str == "M"
label define gen_lbl 1 "Female" 2 "Male"
label values gender_num gen_lbl

capture drop grad_decade
gen grad_decade = 5
capture confirm numeric variable grad_year
if _rc == 0 {
    replace grad_decade = 1 if grad_year < 1990
    replace grad_decade = 2 if grad_year >= 1990 & grad_year < 2000
    replace grad_decade = 3 if grad_year >= 2000 & grad_year < 2010
    replace grad_decade = 4 if grad_year >= 2010 & !missing(grad_year)
}
label define grad_lbl 1 "Pre-1990s" 2 "1990s" 3 "2000s" 4 "2010s+" 5 "Unknown"
label values grad_decade grad_lbl

* --- 4. BUILD GEOGRAPHIC DICTIONARIES ---
display "Calculating Geographic Standard Deviations..."
foreach geo in "nat" "state" "county" "zip" {
    preserve
    if "`geo'" == "nat" {
        local byvar "year"
    }
    else if "`geo'" == "state" {
        local byvar "state_str year"
    }
    else if "`geo'" == "county" {
        local byvar "county year"
    }
    else if "`geo'" == "zip" {
        local byvar "cms_zip year"
    }
    
    if "`geo'" != "nat" { 
        foreach var in `byvar' {
            drop if missing(`var') 
        }
    }
    
    collapse (mean) mean_h100=hcahps_100_score mean_g1=hcahps_grp1 mean_g2=hcahps_grp2 mean_g3=hcahps_grp3 mean_g4=hcahps_grp4 mean_h910=h_hosp_rating_9_10 mean_h06=h_hosp_rating_0_6 ///
             (sd) sd_h100=hcahps_100_score sd_g1=hcahps_grp1 sd_g2=hcahps_grp2 sd_g3=hcahps_grp3 sd_g4=hcahps_grp4 sd_h910=h_hosp_rating_9_10 sd_h06=h_hosp_rating_0_6 ///
             [aw=tot_benes], by(`byvar')
    
    rename mean_* `geo'_mean_*
    rename sd_* `geo'_sd_*
    
    tempfile bench_`geo'
    save `bench_`geo'', replace
    restore
}

merge m:1 year using `bench_nat', nogen
merge m:1 state_str year using `bench_state', nogen
merge m:1 county year using `bench_county', nogen
merge m:1 cms_zip year using `bench_zip', nogen

* --- 5. Z-SCORES & SYMMETRIC BINS ---
display "Applying Symmetric SD Thresholds..."
local m_list "h100 g1 g2 g3 g4 h910 h06"

foreach geo in "nat" "state" "county" "zip" {
    foreach m in `m_list' {
        
        local v_name ""
        if "`m'" == "h100" {
            local v_name "hcahps_100_score"
        }
        else if "`m'" == "g1" {
            local v_name "hcahps_grp1"
        }
        else if "`m'" == "g2" {
            local v_name "hcahps_grp2"
        }
        else if "`m'" == "g3" {
            local v_name "hcahps_grp3"
        }
        else if "`m'" == "g4" {
            local v_name "hcahps_grp4"
        }
        else if "`m'" == "h910" {
            local v_name "h_hosp_rating_9_10"
        }
        else if "`m'" == "h06" {
            local v_name "h_hosp_rating_0_6"
        }
        
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
label define sym_lbl -4 "<-2 SD" -3 "-2 to -1" -2 "-1 to -.5" -1 "-.5 to 0" 1 "0 to .5" 2 ".5 to 1" 3 "1 to 2" 4 ">2 SD"

* --- 6. DECLARE PANEL & CREATE DYNAMIC LAGS ---
gsort npi year -tot_benes
duplicates drop npi year, force
egen panel_id = group(npi)
xtset panel_id year

local l1 = $lag_years
local l2 = $lag_years + 1
local lag_txt = cond($lag_years==1, "1-Yr Lag", "${lag_years}-Yr Lag")

foreach m in `m_list' {
    local v_name ""
    if "`m'" == "h100" {
        local v_name "hcahps_100_score"
    }
    else if "`m'" == "g1" {
        local v_name "hcahps_grp1"
    }
    else if "`m'" == "g2" {
        local v_name "hcahps_grp2"
    }
    else if "`m'" == "g3" {
        local v_name "hcahps_grp3"
    }
    else if "`m'" == "g4" {
        local v_name "hcahps_grp4"
    }
    else if "`m'" == "h910" {
        local v_name "h_hosp_rating_9_10"
    }
    else if "`m'" == "h06" {
        local v_name "h_hosp_rating_0_6"
    }
    
    * Decline Lags
    gen lag_`m'_decline = (L`l1'.`v_name' < L`l2'.`v_name') if !missing(L`l1'.`v_name', L`l2'.`v_name')
    
    * Geo Lags
    foreach geo in "nat" "state" "county" "zip" {
        gen lag_bin_`m'_`geo' = L`l1'.bin_`m'_`geo'
        label values lag_bin_`m'_`geo' sym_lbl
    }
}

tempfile master_clean
save `master_clean', replace

* --- 7. MEGA-LOOP: ULTRA-FAST COLLAPSE GRAPHING ENGINE ---
display "Generating Journal-Ready Stratified Visualizations..."
local behavior_vars "partd_generic_rate partd_opioid_rate partb_em_upcode_rate partb_low_value_rate partb_imaging_adv_rate bene_avg_risk_scre tot_benes tot_sbmtd_chrg tot_srvcs tot_pymt_amt"

local graph_opts "size(medium) color(black)"
local note_opts "position(7) justification(left) size(vsmall) margin(t=3 l=2) span"
local region_opts "color(white) margin(vsmall)"
local line_colors "navy cranberry emerald orange purple maroon gs8"
local line_symbols "O S D T X + *"

local dim_list "overall gender spec auth prov grad own"
local nest_list "none prov grad"

foreach dim in `dim_list' {
    local dim_var ""
    local dim_name ""
    local dim_folder ""
    
    if "`dim'" == "overall" {
        local dim_var "overall_grp"
        local dim_name "Overall"
        local dim_folder "overall"
    }
    else if "`dim'" == "gender" {
        local dim_var "gender_num"
        local dim_name "By Gender"
        local dim_folder "by_gender"
    }
    else if "`dim'" == "spec" {
        local dim_var "spec_num"
        local dim_name "By Dept"
        local dim_folder "by_dept"
    }
    else if "`dim'" == "auth" {
        local dim_var "auth_num"
        local dim_name "By NP Law"
        local dim_folder "by_np_auth"
    }
    else if "`dim'" == "own" {
        local dim_var "own_num"
        local dim_name "By Ownership"
        local dim_folder "by_ownership"
    }
    else if "`dim'" == "prov" {
        local dim_var "prov_num"
        local dim_name "By Prov Type"
        local dim_folder "by_prov_type"
    }
    else if "`dim'" == "grad" {
        local dim_var "grad_decade"
        local dim_name "By Grad Decade"
        local dim_folder "by_grad_decade"
    }
    
    * --- Department-specific footnote (only populated for by_dept charts) ---
    * Groups are defined in 00_initialize.do via $cond_prim_care and $cond_gen_med:
    *   (1) Primary Care:      Family Practice, General Practice
    *   (2) General Medicine:  Emerg. Medicine, Hospitalist, Internal Medicine,
    *                          Nurse Practitioner, Physician Assistant, Pain Management
    *   (3) Other Specialties: all remaining CMS specialties (e.g., Cardiology,
    *                          Orthopedic Surgery, Radiology, Oncology, etc.)
    local dept_note ""
    if "`dim'" == "spec" {
        local dept_note "(1) Primary Care: Family Practice, General Practice. (2) General Medicine: Emerg. Medicine, Hospitalist, Internal Medicine, NP, PA, Pain Management. (3) Other Specialties: e.g., Cardiology, Orthopedic Surgery, Radiology, Oncology."
    }
    
    foreach nest in `nest_list' {
        if "`dim'" == "overall" & "`nest'" != "none" {
            continue
        }
        if "`dim'" == "`nest'" {
            continue
        }
        
        local nest_var ""
        local nest_folder ""
        if "`nest'" == "none" {
            local nest_var "none_grp"
            local nest_folder "overall"
        }
        else if "`nest'" == "prov" {
            local nest_var "prov_num"
            local nest_folder "by_prov_type"
        }
        else if "`nest'" == "grad" {
            local nest_var "grad_decade"
            local nest_folder "by_grad_decade"
        }
        
        * ALWAYS load fresh data before checking levels
        use `master_clean', clear
        quietly levelsof `nest_var', local(nest_lvls)
        
        foreach nv of local nest_lvls {
            
            * RELOAD FRESH DATA TO PREVENT PHANTOM VARIABLE ERROR
            use `master_clean', clear
            
            local n_lbl : label (`nest_var') `nv'
            local n_clean = subinstr(subinstr("`n_lbl'", "/", "_", .), " ", "_", .)
            local n_title ""
            if "`nest'" != "none" {
                local n_title " (`n_lbl')"
            }
            
            capture mkdir "`baseOut'/`dim_folder'"
            capture mkdir "`baseOut'/`dim_folder'/`nest_folder'"
            capture mkdir "`baseOut'/`dim_folder'/`nest_folder'/`n_clean'"
            
            foreach var in `behavior_vars' {
                capture confirm variable `var'
                if _rc != 0 {
                    continue
                }
                
                local c_title ""
                local v_note ""
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
                else if "`var'" == "partd_generic_rate" {
                    local c_title "Generic Rx Rate"
                    local v_note "Generic Rx Rate: Proportion of total Part D claims filled as generic."
                }
                else if "`var'" == "bene_avg_risk_scre" {
                    local c_title "Avg Risk Score"
                    local v_note "Score: HCC Risk Score reflecting patient complexity."
                }
                else if "`var'" == "tot_benes" {
                    local c_title "Total Benes"
                    local v_note "Count: Unique Medicare beneficiaries treated."
                }
                else if "`var'" == "tot_sbmtd_chrg" {
                    local c_title "Total Charges"
                    local v_note "Financial: Total submitted Medicare charges ($)."
                }
                else if "`var'" == "tot_srvcs" {
                    local c_title "Total Services"
                    local v_note "Count: Total Part B services billed."
                }
                else if "`var'" == "tot_pymt_amt" {
                    local c_title "Total Payment"
                    local v_note "Financial: Total Medicare payments ($)."
                }
                else {
                    local c_title "`var'"
                    local v_note "Variable: `var'"
                }
                
                foreach m in `m_list' {
                    local m_title ""
                    local ft_meas ""
                    if "`m'" == "h100" {
                        local m_title "Overall HCAHPS"
                        local ft_meas "Metric: Overall 100-Point Composite."
                    }
                    else if "`m'" == "g1" {
                        local m_title "Staff Comm."
                        local ft_meas "Metric: Grp 1 (Staff Communication w/ Patient)."
                    }
                    else if "`m'" == "g2" {
                        local m_title "Patient Help"
                        local ft_meas "Metric: Grp 2 (Providing the Patient Help)."
                    }
                    else if "`m'" == "g3" {
                        local m_title "Environment"
                        local ft_meas "Metric: Grp 3 (Facility Cleanliness/Quietness)."
                    }
                    else if "`m'" == "g4" {
                        local m_title "Global Rating"
                        local ft_meas "Metric: Grp 4 (Global Rating & Recommendation)."
                    }
                    else if "`m'" == "h910" {
                        local m_title "Rating 9-10"
                        local ft_meas "Metric: % Patients Rating Hospital 9 or 10."
                    }
                    else if "`m'" == "h06" {
                        local m_title "Rating 0-6"
                        local ft_meas "Metric: % Patients Rating Hospital 0 to 6."
                    }
                    
                    local ft_dec "Benchmark: Current year behavior vs prior `lag_txt' decline in `m_title'."
                    
                    * CHART 1: DECLINE
                    use `master_clean', clear
                    keep if `nest_var' == `nv'
                    keep if !missing(`var', lag_`m'_decline, `dim_var')
                    if _N > 0 {
                        collapse (mean) `var', by(lag_`m'_decline `dim_var')
                        
                        quietly levelsof `dim_var', local(dlvls)
                        local tw_cmd ""
                        local l_order ""
                        local c = 1
                        foreach v of local dlvls {
                            local clr : word `c' of `line_colors'
                            local sym : word `c' of `line_symbols'
                            local lbl : label (`dim_var') `v'
                            local tw_cmd `"`tw_cmd' (connected `var' lag_`m'_decline if `dim_var'==`v', lcolor(`clr') msymbol(`sym'))"'
                            local l_order `"`l_order' `c' "`lbl'""'
                            local ++c
                        }
                        
                        * Build note string — append dept footnote only for by_dept charts
                        if "`dim'" == "spec" {
                            local n_dec `""`v_note'" "`ft_meas'" "`ft_dec'" "`dept_note'""'
                        }
                        else {
                            local n_dec `""`v_note'" "`ft_meas'" "`ft_dec'""'
                        }
                        
                        twoway `tw_cmd', title("`c_title' Drop: `dim_name'`n_title'", `graph_opts') ///
                            xtitle("`m_title' Declined (`lag_txt')") ytitle("`c_title'") ///
                            xlabel(0 "No Decline" 1 "Declined") legend(order(`l_order') position(6) rows(1)) ///
                            note(`n_dec', `note_opts') graphregion(`region_opts')
                        capture graph export "`baseOut'/`dim_folder'/`nest_folder'/`n_clean'/decline_`m'_by_`var'.png", replace width(2000)
                    }
                    
                    * CHART 2+: GEO BINS
                    foreach geo in "nat" "state" "county" "zip" {
                        local gname ""
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
                        local ft_geo "Benchmark: SD bins represent distance from `gname' `m_title' mean (`lag_txt')."
                        
                        use `master_clean', clear
                        keep if `nest_var' == `nv'
                        keep if !missing(`var', lag_bin_`m'_`geo', `dim_var')
                        if _N > 0 {
                            collapse (mean) `var', by(lag_bin_`m'_`geo' `dim_var')
                            
                            quietly levelsof `dim_var', local(dlvls)
                            local tw_cmd ""
                            local l_order ""
                            local c = 1
                            foreach v of local dlvls {
                                local clr : word `c' of `line_colors'
                                local sym : word `c' of `line_symbols'
                                local lbl : label (`dim_var') `v'
                                local tw_cmd `"`tw_cmd' (connected `var' lag_bin_`m'_`geo' if `dim_var'==`v', lcolor(`clr') msymbol(`sym'))"'
                                local l_order `"`l_order' `c' "`lbl'""'
                                local ++c
                            }
                            
                            * Build note string — append dept footnote only for by_dept charts
                            if "`dim'" == "spec" {
                                local n_geo `""`v_note'" "`ft_meas'" "`ft_geo'" "`dept_note'""'
                            }
                            else {
                                local n_geo `""`v_note'" "`ft_meas'" "`ft_geo'""'
                            }
                            
                            twoway `tw_cmd', title("`gname' `m_title': `dim_name'`n_title'", `graph_opts') ///
                                xtitle("SDs from `gname' `m_title' (`lag_txt')") ytitle("`c_title'") ///
                                xlabel(-4(1)-1 1(1)4, valuelabel angle(45) labsize(vsmall)) ///
                                legend(order(`l_order') position(6) rows(1)) ///
                                note(`n_geo', `note_opts') graphregion(`region_opts')
                            capture graph export "`baseOut'/`dim_folder'/`nest_folder'/`n_clean'/bin_`m'_`geo'_by_`var'.png", replace width(2000)
                        }
                    }
                }
            }
        }
        
        * MEMORY FIX: Flush Stata's graph memory after each variable block to prevent crashing
        capture graph drop _all
    }
}
display "=== PROVIDER HCAHPS BENCHMARKS COMPLETE ==="
