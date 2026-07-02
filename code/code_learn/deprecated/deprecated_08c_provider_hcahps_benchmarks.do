*===============================================================================
* SCRIPT: 08c_provider_hcahps_benchmarks.do
* PURPOSE: Provider-Level Benchmarks for Facility HCAHPS (Symmetric Bins)
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* --- START LOG ---
local script_name "08c_provider_hcahps_benchmarks"
log using "$logRoot/`script_name'.smcl", replace
* -----------------

capture ssc install binscatter
display "=== STARTING HCAHPS BENCHMARKS FOR: INPATIENT PROVIDERS ==="

* --- 1. FOLDER CREATION ---
capture mkdir "$outRoot/in_patient/benchmarks_hcahps_provider"
capture mkdir "$outRoot/in_patient/benchmarks_hcahps_provider/track1_facility_decline"
capture mkdir "$outRoot/in_patient/benchmarks_hcahps_provider/track2_facility_vs_geography"
foreach geo in "national" "state" "county" "zip" {
    capture mkdir "$outRoot/in_patient/benchmarks_hcahps_provider/track2_facility_vs_geography/`geo'"
}

* --- 2. LOAD DATA & CREATE COMPOSITE SCORE ---
use "$dataRoot/master_provider_inpatient_2013_2023.dta", clear

* Use egen rowmean to prevent missing value propagation wiping the dataset!
egen hcahps_grp1 = rowmean(h_comp_1_a_p h_comp_2_a_p h_comp_6_y_p)
egen hcahps_grp2 = rowmean(h_comp_3_a_p h_comp_4_a_p)
egen hcahps_grp3 = rowmean(h_clean_hosp_a_p h_quiet_hosp_a_p)
egen hcahps_grp4 = rowmean(h_hosp_rating_9_10 h_recmnd_dy)
egen hcahps_100_score = rowmean(hcahps_grp1 hcahps_grp2 hcahps_grp3 hcahps_grp4)

decode cms_state, gen(state_str)
capture confirm variable county
if _rc {
    gen county = .
}

* --- 3. WEIGHTED COLLAPSE TO NPI-YEAR ---
collapse (mean) $prov_overlap_means hcahps_100_score h_hosp_rating_9_10 h_hosp_rating_0_6 ///
         (firstnm) state_str county cms_zip ///
         (rawsum) tot_benes ///
         [aw=tot_benes], by(npi year)

compress
drop if missing(hcahps_100_score)

* --- 4. BUILD GEOGRAPHIC DICTIONARIES ---
foreach geo in "nat" "state" "county" "zip" {
    preserve
    if "`geo'" == "nat" local byvar "year"
    if "`geo'" == "state" local byvar "state_str year"
    if "`geo'" == "county" local byvar "county year"
    if "`geo'" == "zip" local byvar "cms_zip year"
    
    if "`geo'" != "nat" {
        * Safely drop missings by looping through the local components
        foreach var in `byvar' {
            drop if missing(`var')
        }
    }
    
    collapse (mean) mean_h100=hcahps_100_score mean_h910=h_hosp_rating_9_10 mean_h06=h_hosp_rating_0_6 ///
             (sd) sd_h100=hcahps_100_score sd_h910=h_hosp_rating_9_10 sd_h06=h_hosp_rating_0_6 ///
             [aw=tot_benes], by(`byvar')
    
    rename mean_* `geo'_mean_*
    rename sd_* `geo'_sd_*
    
    tempfile bench_`geo'
    save `bench_`geo'', replace
    restore
}

* --- 4.5 MERGE GEOGRAPHIC DICTIONARIES ---
merge m:1 year using `bench_nat', nogen
merge m:1 state_str year using `bench_state', nogen
merge m:1 county year using `bench_county', nogen
merge m:1 cms_zip year using `bench_zip', nogen

* --- 5. CALCULATE Z-SCORES & SYMMETRIC BINS ---
local m_list "h100 h910 h06"

foreach geo in "nat" "state" "county" "zip" {
    foreach m in `m_list' {
        local v_name ""
        if "`m'" == "h100" local v_name "hcahps_100_score"
        if "`m'" == "h910" local v_name "h_hosp_rating_9_10"
        if "`m'" == "h06" local v_name "h_hosp_rating_0_6"
        
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

* --- 6. DECLARE PANEL & CREATE LAGS ---
egen panel_id = group(npi)
xtset panel_id year

gen hcahps_decline = (hcahps_100_score < L.hcahps_100_score) if !missing(hcahps_100_score, L.hcahps_100_score)
gen lag_hcahps_decline = L.hcahps_decline

foreach geo in "nat" "state" "county" "zip" {
    foreach m in "h100" "h910" "h06" {
        gen lag_bin_`m'_`geo' = L.bin_`m'_`geo'
        label values lag_bin_`m'_`geo' sym_lbl
    }
}

* --- 7. GRAPHING LOOPS ---
foreach var in $prov_overlap_means {
    if "`var'" != "mips_final_score" {
        local clean_title = strproper(subinstr("`var'", "_", " ", .))
        
        capture binscatter `var' lag_hcahps_decline, discrete line(connect) title("`clean_title': Facility HCAHPS Decline", size(medium)) xtitle("Prior Year Facility HCAHPS Declined (0=No, 1=Yes)") graphregion(color(white))
        capture graph export "$outRoot/in_patient/benchmarks_hcahps_provider/track1_facility_decline/decline_`var'.png", replace width(2000)

        foreach geo in "nat" "state" "county" "zip" {
            local gname ""
            if "`geo'" == "nat" local gname "national"
            if "`geo'" == "state" local gname "state"
            if "`geo'" == "county" local gname "county"
            if "`geo'" == "zip" local gname "zip"
            
            foreach m in "h100" "h910" "h06" {
                capture binscatter `var' lag_bin_`m'_`geo', discrete line(connect) title("`clean_title' vs Facility `m' (`gname')", size(medium)) xtitle("Facility SDs from `gname' Mean (Prior Year)") ytitle("Provider `clean_title'") graphregion(color(white))
                capture graph export "$outRoot/in_patient/benchmarks_hcahps_provider/track2_facility_vs_geography/`gname'/`m'_vs_`var'.png", replace width(2000)
            }
        }
    }
}
display "=== PROVIDER HCAHPS BENCHMARKS COMPLETE ==="
