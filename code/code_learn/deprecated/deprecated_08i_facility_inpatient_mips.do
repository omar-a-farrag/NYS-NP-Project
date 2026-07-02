*===============================================================================
* SCRIPT: 08i_facility_inpatient_mips.do
* PURPOSE: Facility-Level Benchmarks for MIPS (Inpatient Aggregates)
* FEATURES: MIPS Sub-Categories, Clean Titles, Strict Journal Formatting
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* --- START LOG ---
local script_name "08i_facility_inpatient_mips"
log using "$logRoot/`script_name'.smcl", replace
* -----------------

capture ssc install binscatter
display "=== STARTING MIPS BENCHMARKS FOR: INPATIENT FACILITIES ==="

* --- 1. EXTRACT DATA FROM PROVIDERS (FACILITY MIPS AGGREGATES) ---
display "1. Aggregating Provider Behaviors, Labor, & MIPS to Facility Level..."
use "$dataRoot/master_provider_inpatient_2013_2023.dta", clear
drop if missing(ccn)

decode cms_specialty, gen(spec_str)
gen prov_type = "MD_DO"
replace prov_type = "NP" if spec_str == "NURSE PRACTITIONER"
replace prov_type = "PA" if spec_str == "PHYSICIAN ASSISTANT"

gen count_md = (prov_type == "MD_DO")
gen count_np = (prov_type == "NP")
gen count_pa = (prov_type == "PA")
gen count_tot = 1

* Collapse Behaviors, Labor Supply, AND the 5 MIPS metrics
collapse (sum) count_* ///
         (mean) partd_opioid_rate partb_em_upcode_rate partb_low_value_rate partb_imaging_adv_rate ///
                mips_final_score mips_quality_score mips_pi_score mips_ia_score mips_cost_score ///
         [aw=tot_benes], by(ccn year)

gen pct_md = count_md / count_tot
gen pct_np = count_np / count_tot
gen pct_pa = count_pa / count_tot

tempfile fac_aggregates
save `fac_aggregates', replace

* --- 2. LOAD FACILITY MASTER & MERGE ---
display "2. Loading Inpatient Facility Master & Merging Aggregates..."
use "$dataRoot/master_facility_inpatient_2013_2023.dta", clear
merge 1:1 ccn year using `fac_aggregates', keep(master match) nogen

* MIPS was implemented in 2017; drop missing/pre-MIPS years
drop if missing(mips_final_score)
drop if mips_final_score < 0

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

* --- 3. GEOGRAPHIC Z-SCORES ---
display "3. Calculating Geographic Z-Scores..."
local m_list "m_final m_qual m_pi m_ia m_cost"

foreach geo in "nat" "state" {
    preserve
    if "`geo'" == "nat" local byvar "year"
    if "`geo'" == "state" local byvar "state_str year"
    
    if "`geo'" != "nat" { 
        drop if missing(state_str)
    }
    collapse (mean) mean_m_final=mips_final_score mean_m_qual=mips_quality_score mean_m_pi=mips_pi_score mean_m_ia=mips_ia_score mean_m_cost=mips_cost_score ///
             (sd) sd_m_final=mips_final_score sd_m_qual=mips_quality_score sd_m_pi=mips_pi_score sd_m_ia=mips_ia_score sd_m_cost=mips_cost_score, by(`byvar')
    
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
        if "`m'" == "m_final" local v_name "mips_final_score"
        if "`m'" == "m_qual" local v_name "mips_quality_score"
        if "`m'" == "m_pi" local v_name "mips_pi_score"
        if "`m'" == "m_ia" local v_name "mips_ia_score"
        if "`m'" == "m_cost" local v_name "mips_cost_score"
        
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
egen panel_id = group(ccn)
xtset panel_id year

gen m_final_decline = (mips_final_score < L.mips_final_score) if !missing(mips_final_score, L.mips_final_score)
gen m_qual_decline = (mips_quality_score < L.mips_quality_score) if !missing(mips_quality_score, L.mips_quality_score)
gen m_pi_decline = (mips_pi_score < L.mips_pi_score) if !missing(mips_pi_score, L.mips_pi_score)
gen m_ia_decline = (mips_ia_score < L.mips_ia_score) if !missing(mips_ia_score, L.mips_ia_score)
gen m_cost_decline = (mips_cost_score < L.mips_cost_score) if !missing(mips_cost_score, L.mips_cost_score)

gen lag_m_final_decline = L.m_final_decline
gen lag_m_qual_decline = L.m_qual_decline
gen lag_m_pi_decline = L.m_pi_decline
gen lag_m_ia_decline = L.m_ia_decline
gen lag_m_cost_decline = L.m_cost_decline

foreach geo in "nat" "state" {
    foreach m in `m_list' {
        gen lag_bin_`m'_`geo' = L.bin_`m'_`geo'
        label values lag_bin_`m'_`geo' sym_lbl
    }
}

* --- 5. LONG-DIFFERENCE LABOR SUPPLY (MIPS TIMELINE SHIFT) ---
display "4. Calculating Long-Difference Labor Supply Changes (2017+)..."
* MIPS starts in 2017, so pre-periods shift to 2017 baseline
bysort ccn: egen pre_m100_1719 = mean(cond(year>=2017 & year<=2018, mips_final_score, .))
bysort ccn: egen pre_m100_2023 = mean(cond(year>=2017 & year<=2020, mips_final_score, .))

foreach p in "np" "md" "pa" {
    bysort ccn: egen `p'_17 = max(cond(year==2017, pct_`p', .))
    bysort ccn: egen `p'_19 = max(cond(year==2019, pct_`p', .))
    bysort ccn: egen `p'_20 = max(cond(year==2020, pct_`p', .))
    bysort ccn: egen `p'_23 = max(cond(year==2023, pct_`p', .))
    
    gen d_`p'_1719 = `p'_19 - `p'_17
    gen d_`p'_2023 = `p'_23 - `p'_20
}

foreach p_yr in "1719" "2023" {
    egen nat_mean_pre_`p_yr' = mean(pre_m100_`p_yr')
    egen nat_sd_pre_`p_yr' = sd(pre_m100_`p_yr')
    gen z_pre_`p_yr' = (pre_m100_`p_yr' - nat_mean_pre_`p_yr') / nat_sd_pre_`p_yr'

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
display "5. Generating Journal-Ready MIPS Facility Visualizations..."
local baseOut "$outRoot/in_patient/benchmarks_mips_facility"
capture mkdir "`baseOut'"

local cats "universal by_np_auth by_ownership"
foreach c in `cats' {
    capture mkdir "`baseOut'/`c'"
}

* Variables to analyze
local outcome_vars "partd_opioid_rate partb_em_upcode_rate partb_low_value_rate partb_imaging_adv_rate hac_total_score rrp_excess_ratio_ami rrp_excess_ratio_hf rrp_excess_ratio_pn mortality_rate_ami mortality_rate_hf mortality_rate_pn mspb_score hvbp_tps_score pct_np pct_md pct_pa"

foreach var in `outcome_vars' {
    capture confirm variable `var'
    if _rc == 0 {
        
        * --- TITLE DICTIONARY ---
        if "`var'" == "partd_opioid_rate" {
            local c_title "Opioid Prescribing Rate"
            local v_note "Facility Average: Opioid claims as a proportion of total Part D claims."
        }
        else if "`var'" == "partb_em_upcode_rate" {
            local c_title "Level 4/5 E&M Upcoding Rate"
            local v_note "Facility Average: Level 4/5 E&M visits as a proportion of total E&M visits."
        }
        else if "`var'" == "partb_low_value_rate" {
            local c_title "Low-Value Care Rate"
            local v_note "Facility Average: Choosing Wisely discouraged services as a proportion of Part B services."
        }
        else if "`var'" == "partb_imaging_adv_rate" {
            local c_title "Advanced Imaging Rate"
            local v_note "Facility Average: MRI and CT scans as a proportion of total Part B services."
        }
        else if "`var'" == "hac_total_score" {
            local c_title "HAC Penalty Score"
            local v_note "Outcome: Hospital-Acquired Condition Total Score (Higher is worse)."
        }
        else if "`var'" == "rrp_excess_ratio_ami" {
            local c_title "AMI Readmission Ratio"
            local v_note "Outcome: Readmission Reduction Program Ratio for Heart Attacks (>1.0 is penalized)."
        }
        else if "`var'" == "rrp_excess_ratio_hf" {
            local c_title "Heart Failure Readmission Ratio"
            local v_note "Outcome: Readmission Reduction Program Ratio for Heart Failure (>1.0 is penalized)."
        }
        else if "`var'" == "rrp_excess_ratio_pn" {
            local c_title "Pneumonia Readmission Ratio"
            local v_note "Outcome: Readmission Reduction Program Ratio for Pneumonia (>1.0 is penalized)."
        }
        else if "`var'" == "mortality_rate_ami" {
            local c_title "30-Day AMI Mortality Rate"
            local v_note "Outcome: 30-Day Risk-Standardized Mortality Rate for Heart Attacks."
        }
        else if "`var'" == "mortality_rate_hf" {
            local c_title "30-Day Heart Failure Mortality"
            local v_note "Outcome: 30-Day Risk-Standardized Mortality Rate for Heart Failure."
        }
        else if "`var'" == "mortality_rate_pn" {
            local c_title "30-Day Pneumonia Mortality"
            local v_note "Outcome: 30-Day Risk-Standardized Mortality Rate for Pneumonia."
        }
        else if "`var'" == "mspb_score" {
            local c_title "Medicare Spending Per Beneficiary"
            local v_note "Outcome: MSPB Ratio tracking cost efficiency (Higher indicates excess spending)."
        }
        else if "`var'" == "hvbp_tps_score" {
            local c_title "Value-Based Purchasing Score"
            local v_note "Outcome: HVBP Total Performance Score."
        }
        else if "`var'" == "pct_np" {
            local c_title "Nurse Practitioner % of Staff"
            local v_note "Labor Supply: NPs as a proportion of the facility's total billing workforce."
        }
        else if "`var'" == "pct_md" {
            local c_title "MD/DO % of Staff"
            local v_note "Labor Supply: MD/DOs as a proportion of the facility's total billing workforce."
        }
        else if "`var'" == "pct_pa" {
            local c_title "Physician Assistant % of Staff"
            local v_note "Labor Supply: PAs as a proportion of the facility's total billing workforce."
        }
        else {
            local c_title = strproper(subinstr("`var'", "_", " ", .))
            local v_note "Outcome: `c_title'"
        }

        * --- MIPS METRICS LOOP ---
        foreach m in `m_list' {
            if "`m'" == "m_final" {
                local m_title "Final MIPS Score"
                local m_var "m_final"
                local ft_meas "Metric: Facility Average MIPS Final Payment Adjustment Score."
            }
            else if "`m'" == "m_qual" {
                local m_title "MIPS Quality Score"
                local m_var "m_qual"
                local ft_meas "Metric: Facility Average MIPS Quality Performance Category."
            }
            else if "`m'" == "m_pi" {
                local m_title "Interoperability Score"
                local m_var "m_pi"
                local ft_meas "Metric: Facility Average MIPS Promoting Interoperability Category."
            }
            else if "`m'" == "m_ia" {
                local m_title "Improvement Activities Score"
                local m_var "m_ia"
                local ft_meas "Metric: Facility Average MIPS Improvement Activities Category."
            }
            else if "`m'" == "m_cost" {
                local m_title "MIPS Cost Score"
                local m_var "m_cost"
                local ft_meas "Metric: Facility Average MIPS Cost Performance Category."
            }
            
            local ft_dec "Decline: Binary (1=Yes) if the facility's average `m_title' dropped from two years prior to one year prior."

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

            * 6C. BY OWNERSHIP
            foreach o in `owns' {
                if "`o'" == "Non_Profit" local o_clean "Non-Profit"
                else if "`o'" == "For_Profit" local o_clean "For-Profit"
                else local o_clean "`o'"

                capture mkdir "`baseOut'/by_ownership/`o'"
                capture binscatter `var' lag_`m_var'_decline if own_cat == "`o'", discrete line(connect) title("`c_title' by `m_title' Drop: `o_clean'", size(msmall)) xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") note("`v_note'" "`ft_meas'", size(vsmall)) graphregion(color(white))
                capture graph export "`baseOut'/by_ownership/`o'/decline_`m'_by_`var'.png", replace width(2000)
                
                foreach geo in "nat" "state" {
                    local gname = strproper("`geo'")
                    capture binscatter `var' lag_bin_`m'_`geo' if own_cat == "`o'", discrete line(connect) title("`c_title' by `gname' `m_title': `o_clean'", size(msmall)) xtitle("Standard Deviations from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'", size(vsmall)) graphregion(color(white))
                    capture graph export "`baseOut'/by_ownership/`o'/bin_`m'_`geo'_by_`var'.png", replace width(2000)
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
    local ft_pre1 "Benchmark: Facility's average MIPS SD from National mean during pre-period (2017-2018)."
    local ft_pre2 "Benchmark: Facility's average MIPS SD from National mean during pre-period (2017-2020)."

    * Universal Long-Diff
    capture binscatter d_`l'_1719 bin_pre_1719 if year == 2019, discrete line(connect) title("`l_upper' Shift (2017-2019) by Pre-Sample", size(msmall)) xtitle("Standard Deviations from Nat. Mean (2017-2018 Avg)") ytitle("`c_title'") note("Outcome: Absolute change in `l_upper' proportion (2017-2019)." "`ft_pre1'", size(vsmall)) graphregion(color(white))
    capture graph export "`baseOut'/universal/longdiff_2017_2019_`l'.png", replace width(2000)
    
    capture binscatter d_`l'_2023 bin_pre_2023 if year == 2023, discrete line(connect) title("`l_upper' Shift (2020-2023) by Pre-Sample", size(msmall)) xtitle("Standard Deviations from Nat. Mean (2017-2020 Avg)") ytitle("`c_title'") note("Outcome: Absolute change in `l_upper' proportion (2020-2023)." "`ft_pre2'", size(vsmall)) graphregion(color(white))
    capture graph export "`baseOut'/universal/longdiff_2020_2023_`l'.png", replace width(2000)

    * Stratified Long-Diff (State Authority)
    foreach a in `auths' {
        if "`a'" == "Full_Practice" local a_clean "Full Practice"
        else if "`a'" == "Reduced_Practice" local a_clean "Reduced Practice"
        else if "`a'" == "Restricted_Practice" local a_clean "Restricted Practice"
        else local a_clean "`a'"

        capture mkdir "`baseOut'/by_np_auth/`a'"
        capture binscatter d_`l'_1719 bin_pre_1719 if year == 2019 & np_auth == "`a'", discrete line(connect) title("`l_upper' Shift (2017-2019): `a_clean'", size(msmall)) xtitle("Standard Deviations from Nat. Mean (2017-2018 Avg)") ytitle("`c_title'") graphregion(color(white))
        capture graph export "`baseOut'/by_np_auth/`a'/longdiff_2017_2019_`l'.png", replace width(2000)
        
        capture binscatter d_`l'_2023 bin_pre_2023 if year == 2023 & np_auth == "`a'", discrete line(connect) title("`l_upper' Shift (2020-2023): `a_clean'", size(msmall)) xtitle("Standard Deviations from Nat. Mean (2017-2020 Avg)") ytitle("`c_title'") graphregion(color(white))
        capture graph export "`baseOut'/by_np_auth/`a'/longdiff_2020_2023_`l'.png", replace width(2000)
    }

    * Stratified Long-Diff (Ownership)
    foreach o in `owns' {
        if "`o'" == "Non_Profit" local o_clean "Non-Profit"
        else if "`o'" == "For_Profit" local o_clean "For-Profit"
        else local o_clean "`o'"

        capture mkdir "`baseOut'/by_ownership/`o'"
        capture binscatter d_`l'_1719 bin_pre_1719 if year == 2019 & own_cat == "`o'", discrete line(connect) title("`l_upper' Shift (2017-2019): `o_clean'", size(msmall)) xtitle("Standard Deviations from Nat. Mean (2017-2018 Avg)") ytitle("`c_title'") graphregion(color(white))
        capture graph export "`baseOut'/by_ownership/`o'/longdiff_2017_2019_`l'.png", replace width(2000)
        
        capture binscatter d_`l'_2023 bin_pre_2023 if year == 2023 & own_cat == "`o'", discrete line(connect) title("`l_upper' Shift (2020-2023): `o_clean'", size(msmall)) xtitle("Standard Deviations from Nat. Mean (2017-2020 Avg)") ytitle("`c_title'") graphregion(color(white))
        capture graph export "`baseOut'/by_ownership/`o'/longdiff_2020_2023_`l'.png", replace width(2000)
    }
		* Flush memory after each outcome variable is fully processed
        capture graph drop _all
}
display "=== FACILITY INPATIENT MIPS BENCHMARKS COMPLETE ==="