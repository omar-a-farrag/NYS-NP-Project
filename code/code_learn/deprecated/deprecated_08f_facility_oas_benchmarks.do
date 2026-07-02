*===============================================================================
* SCRIPT: 08f_facility_oas_benchmarks.do
* PURPOSE: Facility-Level OAS CAHPS Benchmarks (Outcomes, Behaviors, Labor)
* FEATURES: Market-Proxy Merging, Clean Titles, Strict Journal Formatting
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* --- START LOG ---
local script_name "08f_facility_oas_benchmarks"
log using "$logRoot/`script_name'.smcl", replace
* -----------------

capture ssc install binscatter
display "=== STARTING OAS CAHPS BENCHMARKS FOR: OUTPATIENT FACILITIES (ASCS) ==="

* --- 1. EXTRACT DATA FROM PROVIDERS (ZIP-LEVEL MARKET PROXY) ---
display "1. Aggregating Provider Behaviors & Labor Supply to Local Market (ZIP)..."
use "$dataRoot/master_provider_outpatient_asc_2015_2023.dta", clear

capture tostring cms_zip, replace force
replace cms_zip = substr(cms_zip, 1, 5)
drop if missing(cms_zip)

decode cms_specialty, gen(spec_str)
gen prov_type = "MD_DO"
replace prov_type = "NP" if spec_str == "NURSE PRACTITIONER"
replace prov_type = "PA" if spec_str == "PHYSICIAN ASSISTANT"

gen count_md = (prov_type == "MD_DO")
gen count_np = (prov_type == "NP")
gen count_pa = (prov_type == "PA")
gen count_tot = 1

* Collapse Behaviors, Labor Supply, AND the scaled OAS CAHPS metrics to the ZIP level
collapse (sum) count_* ///
         (mean) partd_opioid_rate partb_em_upcode_rate partb_low_value_rate partb_imaging_adv_rate ///
                oas_100_score oas_grp1 oas_grp2 oas_grp3 ///
         [aw=tot_benes], by(cms_zip year)

gen pct_md = count_md / count_tot
gen pct_np = count_np / count_tot
gen pct_pa = count_pa / count_tot

rename cms_zip zipcode
tempfile fac_aggregates
save `fac_aggregates', replace

* --- 2. LOAD FACILITY MASTER & MERGE ---
display "2. Loading ASC Facility Master & Merging Market Aggregates..."
use "$dataRoot/master_facility_outpatient_asc_2015_2024.dta", clear

capture tostring zipcode, replace force
replace zipcode = substr(zipcode, 1, 5)

merge m:1 zipcode year using `fac_aggregates', keep(master match) nogen

drop if missing(oas_100_score)
drop if oas_100_score < 0

* Decode Structural Variables
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

capture replace state_str = strtrim(strupper(state_str))

gen np_auth = "Unknown"
replace np_auth = "Full_Practice" if inlist(state_str, "AZ", "CO", "CT", "DC", "HI", "ID", "IA", "MD", "MA") | inlist(state_str, "MN", "MT", "NE", "NV", "NH", "NM", "NY", "ND", "OR") | inlist(state_str, "RI", "SD", "VT", "WA", "WY")
replace np_auth = "Reduced_Practice" if inlist(state_str, "AL", "AS", "DE", "IL", "IN", "KS", "KY", "LA", "MS") | inlist(state_str, "NJ", "OH", "PA", "UT", "WI")
replace np_auth = "Restricted_Practice" if inlist(state_str, "CA", "FL", "GA", "MI", "MO", "NC", "OK", "SC", "TN") | inlist(state_str, "TX", "VA")

levelsof np_auth, local(auths)

* --- 3. GEOGRAPHIC Z-SCORES ---
display "3. Calculating Geographic Z-Scores..."
local m_list "o100 g1 g2 g3"

foreach geo in "nat" "state" {
    preserve
    if "`geo'" == "nat" local byvar "year"
    if "`geo'" == "state" local byvar "state_str year"
    
    if "`geo'" != "nat" { 
        drop if missing(state_str)
    }
    collapse (mean) mean_o100=oas_100_score mean_g1=oas_grp1 mean_g2=oas_grp2 mean_g3=oas_grp3 ///
             (sd) sd_o100=oas_100_score sd_g1=oas_grp1 sd_g2=oas_grp2 sd_g3=oas_grp3, by(`byvar')
    
    rename mean_* `geo'_mean_*
    rename sd_* `geo'_sd_*
    tempfile bench_`geo'
    save `bench_`geo'', replace
    restore
}
merge m:1 year using `bench_nat', nogen
merge m:1 state_str year using `bench_state', nogen

foreach geo in "nat" "state" {
    foreach m in `m_list' {
        if "`m'" == "o100" local v_name "oas_100_score"
        if "`m'" == "g1" local v_name "oas_grp1"
        if "`m'" == "g2" local v_name "oas_grp2"
        if "`m'" == "g3" local v_name "oas_grp3"
        
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

* --- 4. PANEL LAGS (YEAR-OVER-YEAR) ---
egen panel_id = group(asc_id)
xtset panel_id year

gen oas_decline = (oas_100_score < L.oas_100_score) if !missing(oas_100_score, L.oas_100_score)
gen g1_decline = (oas_grp1 < L.oas_grp1) if !missing(oas_grp1, L.oas_grp1)
gen g2_decline = (oas_grp2 < L.oas_grp2) if !missing(oas_grp2, L.oas_grp2)
gen g3_decline = (oas_grp3 < L.oas_grp3) if !missing(oas_grp3, L.oas_grp3)

gen lag_oas_decline = L.oas_decline
gen lag_g1_decline = L.g1_decline
gen lag_g2_decline = L.g2_decline
gen lag_g3_decline = L.g3_decline

foreach geo in "nat" "state" {
    foreach m in `m_list' {
        gen lag_bin_`m'_`geo' = L.bin_`m'_`geo'
        label values lag_bin_`m'_`geo' sym_lbl
    }
}

* --- 5. LONG-DIFFERENCE LABOR SUPPLY (PRE-SAMPLES FOR ASCs) ---
display "4. Calculating Long-Difference Labor Supply Changes..."
bysort asc_id: egen pre_o100_1619 = mean(cond(year>=2015 & year<=2016, oas_100_score, .))
bysort asc_id: egen pre_o100_2023 = mean(cond(year>=2015 & year<=2020, oas_100_score, .))

foreach p in "np" "md" "pa" {
    bysort asc_id: egen `p'_16 = max(cond(year==2016, pct_`p', .))
    bysort asc_id: egen `p'_19 = max(cond(year==2019, pct_`p', .))
    bysort asc_id: egen `p'_20 = max(cond(year==2020, pct_`p', .))
    bysort asc_id: egen `p'_23 = max(cond(year==2023, pct_`p', .))
    
    gen d_`p'_1619 = `p'_19 - `p'_16
    gen d_`p'_2023 = `p'_23 - `p'_20
}

foreach p_yr in "1619" "2023" {
    egen nat_mean_pre_`p_yr' = mean(pre_o100_`p_yr')
    egen nat_sd_pre_`p_yr' = sd(pre_o100_`p_yr')
    gen z_pre_`p_yr' = (pre_o100_`p_yr' - nat_mean_pre_`p_yr') / nat_sd_pre_`p_yr'

    gen bin_pre_`p_yr' = .
    replace bin_pre_`p_yr' = 4 if z_pre_`p_yr' > 2.0 & !missing(z_pre_`p_yr')
    replace bin_pre_`p_yr' = 3 if z_pre_`p_yr' > 1.0 & z_pre_`p_yr' <= 2.0
    replace bin_pre_`p_yr' = 2 if z_pre_`p_yr' > 0.5 & z_pre_`p_yr' <= 1.0
    replace bin_pre_`p_yr' = 1 if z_pre_`p_yr' >= 0 & z_pre_`p_yr' <= 0.5
    replace bin_pre_`p_yr' = -1 if z_pre_`p_yr' >= -0.5 & z_pre_`p_yr' < 0
    replace bin_pre_`p_yr' = -2 if z_pre_`p_yr' >= -1.0 & z_pre_`p_yr' < -0.5
    replace bin_pre_`p_yr' = -3 if z_pre_`p_yr' >= -2.0 & z_pre_`p_yr' < -1.0
    replace bin_pre_`p_yr' = -4 if z_pre_`p_yr' < -2.0
    label values bin_pre_`p_yr' sym_lbl
}

* --- 6. GRAPHING ENGINE ---
display "5. Generating Journal-Ready ASC Visualizations..."
local baseOut "$outRoot/out_patient/benchmarks_oas_facility"
capture mkdir "`baseOut'"

local cats "universal by_np_auth"
foreach c in `cats' {
    capture mkdir "`baseOut'/`c'"
}

* Variables to analyze (Market Behaviors + ASC Outcomes + Market Labor)
local outcome_vars "partd_opioid_rate partb_em_upcode_rate partb_low_value_rate partb_imaging_adv_rate asc_rate_1 asc_rate_2 asc_rate_3 asc_rate_4 pct_np pct_md pct_pa"

foreach var in `outcome_vars' {
    capture confirm variable `var'
    if _rc == 0 {
        
        * --- TITLE DICTIONARY (CLEAN AXES) ---
        if "`var'" == "partd_opioid_rate" {
            local c_title "Opioid Prescribing Rate"
            local v_note "Local Market Average: Opioid claims as a proportion of total Part D claims."
        }
        else if "`var'" == "partb_em_upcode_rate" {
            local c_title "Level 4/5 E&M Upcoding Rate"
            local v_note "Local Market Average: Level 4/5 E&M visits as a proportion of total E&M visits."
        }
        else if "`var'" == "partb_low_value_rate" {
            local c_title "Low-Value Care Rate"
            local v_note "Local Market Average: Choosing Wisely discouraged services as a proportion of Part B services."
        }
        else if "`var'" == "partb_imaging_adv_rate" {
            local c_title "Advanced Imaging Rate"
            local v_note "Local Market Average: MRI and CT scans as a proportion of total Part B services."
        }
        else if "`var'" == "asc_rate_1" {
            local c_title "Patient Burn Rate"
            local v_note "Clinical Outcome: Rate of patient burns per ASC admission."
        }
        else if "`var'" == "asc_rate_2" {
            local c_title "Patient Fall Rate"
            local v_note "Clinical Outcome: Rate of patient falls within the ASC facility."
        }
        else if "`var'" == "asc_rate_3" {
            local c_title "Wrong Event Rate"
            local v_note "Clinical Outcome: Rate of wrong site, wrong side, or wrong patient procedures."
        }
        else if "`var'" == "asc_rate_4" {
            local c_title "Hospital Transfer Rate"
            local v_note "Clinical Outcome: All-cause hospital transfer or admission rate originating from the ASC."
        }
        else if "`var'" == "pct_np" {
            local c_title "Nurse Practitioner % of Staff"
            local v_note "Labor Supply: NPs as a proportion of the local market's billing workforce."
        }
        else if "`var'" == "pct_md" {
            local c_title "MD/DO % of Staff"
            local v_note "Labor Supply: MD/DOs as a proportion of the local market's billing workforce."
        }
        else if "`var'" == "pct_pa" {
            local c_title "Physician Assistant % of Staff"
            local v_note "Labor Supply: PAs as a proportion of the local market's billing workforce."
        }
        else {
            local c_title = strproper(subinstr("`var'", "_", " ", .))
            local v_note "Outcome: `c_title'"
        }

        * --- OAS CAHPS METRICS LOOP (Groups 1-3) ---
        foreach m in `m_list' {
            if "`m'" == "o100" {
                local m_title "Overall OAS CAHPS"
                local m_var "oas"
                local ft_meas "Metric: Overall 100-Point OAS Composite."
            }
            else if "`m'" == "g1" {
                local m_title "Professional Care"
                local m_var "g1"
                local ft_meas "Metric: Group 1 (Professional Care and Cleanliness)."
            }
            else if "`m'" == "g2" {
                local m_title "Communication"
                local m_var "g2"
                local ft_meas "Metric: Group 2 (Communication and Expectations)."
            }
            else if "`m'" == "g3" {
                local m_title "Global Rating"
                local m_var "g3"
                local ft_meas "Metric: Group 3 (Global Rating and Recommendation)."
            }
            
            local ft_dec "Decline: Binary (1=Yes) if the market's `m_title' score dropped from two years prior to one year prior."

            * 6A. UNIVERSAL
            capture binscatter `var' lag_`m_var'_decline, discrete line(connect) title("`c_title' by `m_title' Drop", size(msmall)) xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", size(vsmall)) graphregion(color(white))
            capture graph export "`baseOut'/universal/decline_`m'_by_`var'.png", replace width(2000)
            
            foreach geo in "nat" "state" {
                local gname = strproper("`geo'")
                local ft_geo "Benchmark: Standard Deviations from `gname' `m_title' mean in the prior year."
                
                capture binscatter `var' lag_bin_`m'_`geo', discrete line(connect) title("`c_title' by `gname' `m_title'", size(msmall)) xtitle("Standard Deviations from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", size(vsmall)) graphregion(color(white))
                capture graph export "`baseOut'/universal/bin_`m'_`geo'_by_`var'.png", replace width(2000)
            }

            * 6B. BY STATE NP AUTHORITY
            foreach a in `auths' {
                if "`a'" == "Full_Practice" local a_clean "Full Practice"
                else if "`a'" == "Reduced_Practice" local a_clean "Reduced Practice"
                else if "`a'" == "Restricted_Practice" local a_clean "Restricted Practice"
                else local a_clean "`a'"

                capture mkdir "`baseOut'/by_np_auth/`a'"
                capture binscatter `var' lag_`m_var'_decline if np_auth == "`a'", discrete line(connect) title("`c_title' by `m_title' Drop: `a_clean'", size(msmall)) xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") note("`v_note'" "`ft_meas'", size(vsmall)) graphregion(color(white))
                capture graph export "`baseOut'/by_np_auth/`a'/decline_`m'_by_`var'.png", replace width(2000)
                
                foreach geo in "nat" "state" {
                    local gname = strproper("`geo'")
                    capture binscatter `var' lag_bin_`m'_`geo' if np_auth == "`a'", discrete line(connect) title("`c_title' by `gname' `m_title': `a_clean'", size(msmall)) xtitle("Standard Deviations from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'", size(vsmall)) graphregion(color(white))
                    capture graph export "`baseOut'/by_np_auth/`a'/bin_`m'_`geo'_by_`var'.png", replace width(2000)
                }
            }
		* Flush memory after each outcome variable is fully processed
        capture graph drop _all
        }
    }
}

* --- 7. LONG-DIFFERENCE LABOR SUPPLY PLOTS ---
local lab_vars "np md pa"
foreach l in `lab_vars' {
    
    if "`l'" == "np" local l_upper "Nurse Practitioner"
    else if "`l'" == "md" local l_upper "MD/DO"
    else if "`l'" == "pa" local l_upper "Physician Assistant"

    local c_title "Change in `l_upper' % of Staff"
    local ft_pre1 "Benchmark: Facility's average OAS CAHPS SD from National mean during pre-period (2015-2016)."
    local ft_pre2 "Benchmark: Facility's average OAS CAHPS SD from National mean during pre-period (2015-2020)."

    * Universal Long-Diff
    capture binscatter d_`l'_1619 bin_pre_1619 if year == 2019, discrete line(connect) title("`l_upper' Shift (2016-2019) by Pre-Sample", size(msmall)) xtitle("Standard Deviations from Nat. Mean (2015-2016 Avg)") ytitle("`c_title'") note("Outcome: Absolute change in `l_upper' proportion (2016-2019)." "`ft_pre1'", size(vsmall)) graphregion(color(white))
    capture graph export "`baseOut'/universal/longdiff_2016_2019_`l'.png", replace width(2000)
    
    capture binscatter d_`l'_2023 bin_pre_2023 if year == 2023, discrete line(connect) title("`l_upper' Shift (2020-2023) by Pre-Sample", size(msmall)) xtitle("Standard Deviations from Nat. Mean (2015-2020 Avg)") ytitle("`c_title'") note("Outcome: Absolute change in `l_upper' proportion (2020-2023)." "`ft_pre2'", size(vsmall)) graphregion(color(white))
    capture graph export "`baseOut'/universal/longdiff_2020_2023_`l'.png", replace width(2000)

    * Stratified Long-Diff (State Authority)
    foreach a in `auths' {
        if "`a'" == "Full_Practice" local a_clean "Full Practice"
        else if "`a'" == "Reduced_Practice" local a_clean "Reduced Practice"
        else if "`a'" == "Restricted_Practice" local a_clean "Restricted Practice"
        else local a_clean "`a'"

        capture mkdir "`baseOut'/by_np_auth/`a'"
        capture binscatter d_`l'_1619 bin_pre_1619 if year == 2019 & np_auth == "`a'", discrete line(connect) title("`l_upper' Shift (2016-2019): `a_clean'", size(msmall)) xtitle("Standard Deviations from Nat. Mean (2015-2016 Avg)") ytitle("`c_title'") graphregion(color(white))
        capture graph export "`baseOut'/by_np_auth/`a'/longdiff_2016_2019_`l'.png", replace width(2000)
        
        capture binscatter d_`l'_2023 bin_pre_2023 if year == 2023 & np_auth == "`a'", discrete line(connect) title("`l_upper' Shift (2020-2023): `a_clean'", size(msmall)) xtitle("Standard Deviations from Nat. Mean (2015-2020 Avg)") ytitle("`c_title'") graphregion(color(white))
        capture graph export "`baseOut'/by_np_auth/`a'/longdiff_2020_2023_`l'.png", replace width(2000)
    }
		* Flush memory after each outcome variable is fully processed
        capture graph drop _all
}
display "=== FACILITY OAS BENCHMARKS COMPLETE ==="
