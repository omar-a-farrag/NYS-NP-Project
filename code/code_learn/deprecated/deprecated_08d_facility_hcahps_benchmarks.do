*===============================================================================
* SCRIPT: 08d_facility_hcahps_benchmarks.do
* PURPOSE: Facility-Level HCAHPS Benchmarks (Outcomes, Behaviors, Labor Supply)
* FEATURES: HCAHPS Groups 1-4, Dynamic Clean Titles, YOY Lags & Long-Differences
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* --- START LOG ---
local script_name "08d_facility_hcahps_benchmarks"
log using "$logRoot/`script_name'.smcl", replace
* -----------------

capture ssc install binscatter
display "=== STARTING HCAHPS BENCHMARKS FOR: INPATIENT FACILITIES ==="

* --- 1. EXTRACT DATA FROM PROVIDERS ---
display "1. Aggregating Provider Behaviors & HCAHPS Scores to Facility Level..."
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

collapse (sum) count_* ///
         (mean) partd_opioid_rate partb_em_upcode_rate partb_low_value_rate partb_imaging_adv_rate ///
                hcahps_100_score hcahps_grp1 hcahps_grp2 hcahps_grp3 hcahps_grp4 ///
         [aw=tot_benes], by(ccn year)

gen pct_md = count_md / count_tot
gen pct_np = count_np / count_tot
gen pct_pa = count_pa / count_tot

tempfile fac_aggregates
save `fac_aggregates', replace

* --- 2. LOAD FACILITY MASTER & MERGE ---
display "2. Loading Facility Master & Merging Aggregates..."
use "$dataRoot/master_facility_inpatient_2013_2023.dta", clear
merge 1:1 ccn year using `fac_aggregates', keep(master match) nogen

drop if missing(hcahps_100_score)
drop if hcahps_100_score < 0

* Decode Structural Variables
capture confirm variable cms_state
if _rc == 0 {
    decode cms_state, gen(state_str)
}
else {
    decode state, gen(state_str)
}
capture decode ownership, gen(own_str)

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
local m_list "h100 g1 g2 g3 g4"

foreach geo in "nat" "state" {
    preserve
    if "`geo'" == "nat" local byvar "year"
    if "`geo'" == "state" local byvar "state_str year"
    
    if "`geo'" != "nat" { 
        drop if missing(state_str)
    }
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

foreach geo in "nat" "state" {
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

* --- 4. PANEL LAGS (YEAR-OVER-YEAR) ---
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

foreach geo in "nat" "state" {
    foreach m in `m_list' {
        gen lag_bin_`m'_`geo' = L.bin_`m'_`geo'
        label values lag_bin_`m'_`geo' sym_lbl
    }
}

* --- 5. LONG-DIFFERENCE LABOR SUPPLY (PRE-SAMPLES) ---
display "4. Calculating Long-Difference Labor Supply Changes..."
bysort ccn: egen pre_h100_1519 = mean(cond(year>=2013 & year<=2015, hcahps_100_score, .))
bysort ccn: egen pre_h100_2023 = mean(cond(year>=2013 & year<=2020, hcahps_100_score, .))

foreach p in "np" "md" "pa" {
    bysort ccn: egen `p'_15 = max(cond(year==2015, pct_`p', .))
    bysort ccn: egen `p'_19 = max(cond(year==2019, pct_`p', .))
    bysort ccn: egen `p'_20 = max(cond(year==2020, pct_`p', .))
    bysort ccn: egen `p'_23 = max(cond(year==2023, pct_`p', .))
    
    gen d_`p'_1519 = `p'_19 - `p'_15
    gen d_`p'_2023 = `p'_23 - `p'_20
}

foreach p_yr in "1519" "2023" {
    egen nat_mean_pre_`p_yr' = mean(pre_h100_`p_yr')
    egen nat_sd_pre_`p_yr' = sd(pre_h100_`p_yr')
    gen z_pre_`p_yr' = (pre_h100_`p_yr' - nat_mean_pre_`p_yr') / nat_sd_pre_`p_yr'

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
display "5. Generating Journal-Ready Facility Visualizations..."
local baseOut "$outRoot/in_patient/benchmarks_hcahps_facility"
capture mkdir "`baseOut'"

local cats "universal by_np_auth by_ownership"
foreach c in `cats' {
    capture mkdir "`baseOut'/`c'"
}

* Note: Updated variable names for mortality based on the data dictionary
local outcome_vars "partd_opioid_rate partb_em_upcode_rate partb_low_value_rate partb_imaging_adv_rate hac_total_score rrp_excess_ratio_ami rrp_excess_ratio_hf rrp_excess_ratio_pn mortality_rate_ami mortality_rate_hf mortality_rate_pn mspb_score hvbp_tps_score pct_np pct_md pct_pa"

foreach var in `outcome_vars' {
    capture confirm variable `var'
    if _rc == 0 {
		capture drop d_`var'
        gen d_`var' = `var' - L.`var'
        
        * --- TITLE DICTIONARY (CLEAN AXES) ---
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

        * --- HCAHPS METRICS LOOP (Groups 1-4) ---
        foreach m in `m_list' {
            if "`m'" == "h100" {
                local m_title "Overall HCAHPS"
                local m_var "hcahps"
                local ft_meas "Metric: Overall 100-Point Composite."
            }
            else if "`m'" == "g1" {
                local m_title "Staff Comm."
                local m_var "g1"
                local ft_meas "Metric: Grp 1 (Staff Communication)."
            }
            else if "`m'" == "g2" {
                local m_title "Patient Help"
                local m_var "g2"
                local ft_meas "Metric: Grp 2 (Providing Help)."
            }
            else if "`m'" == "g3" {
                local m_title "Environment"
                local m_var "g3"
                local ft_meas "Metric: Grp 3 (Cleanliness/Quiet)."
            }
            else if "`m'" == "g4" {
                local m_title "Global Rating"
                local m_var "g4"
                local ft_meas "Metric: Grp 4 (Global/Recommend)."
            }
            
            local ft_dec "Decline: Binary (1=Yes) if facility's `m_title' score dropped from t-2 to t-1."

            * 6A. UNIVERSAL
            capture binscatter `var' lag_`m_var'_decline, discrete line(connect) title("`c_title' by `m_title' Drop", size(medium)) xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") xlabel(0 "No Decline" 1 "Declined") note("`v_note'" "`ft_meas'" "`ft_dec'", size(vsmall)) graphregion(color(white))
            capture graph export "`baseOut'/universal/decline_`m'_vs_`var'.png", replace width(2000)
			
            * [NEW] DELTA CHART: Change in outcome by prior year decline
            local ft_delta "Outcome: Year-over-year absolute change in `c_title'."
            capture binscatter d_`var' lag_`m_var'_decline, discrete line(connect) title("Change in `c_title' by `m_title' Drop", size(msmall)) xtitle("Prior Year `m_title' Declined") ytitle("Change in `c_title'") xlabel(0 "No Decline" 1 "Declined") note("`ft_delta'" "`ft_meas'" "`ft_dec'", size(vsmall)) graphregion(color(white))
            capture graph export "`baseOut'/universal/decline_`m'_by_delta_`var'.png", replace width(2000)
			
            foreach geo in "nat" "state" {
                local gname = strproper("`geo'")
                local ft_geo "Benchmark: Facility distance from `gname' `m_title' mean in t-1."
                
                capture binscatter `var' lag_bin_`m'_`geo', discrete line(connect) title("`c_title' by `gname' `m_title'", size(medium)) xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'" "`ft_geo'", size(vsmall)) graphregion(color(white))
                capture graph export "`baseOut'/universal/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
            }

            * 6B. BY STATE NP AUTHORITY
            foreach a in `auths' {
                capture mkdir "`baseOut'/by_np_auth/`a'"
                capture binscatter `var' lag_`m_var'_decline if np_auth == "`a'", discrete line(connect) title("`c_title' Drop: `a'", size(medium)) xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") note("`v_note'" "`ft_meas'", size(vsmall)) graphregion(color(white))
                capture graph export "`baseOut'/by_np_auth/`a'/decline_`m'_vs_`var'.png", replace width(2000)
                
                foreach geo in "nat" "state" {
                    local gname = strproper("`geo'")
                    capture binscatter `var' lag_bin_`m'_`geo' if np_auth == "`a'", discrete line(connect) title("`gname' `m_title': `a'", size(medium)) xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'", size(vsmall)) graphregion(color(white))
                    capture graph export "`baseOut'/by_np_auth/`a'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
                }
            }

            * 6C. BY OWNERSHIP
            foreach o in `owns' {
                capture mkdir "`baseOut'/by_ownership/`o'"
                capture binscatter `var' lag_`m_var'_decline if own_cat == "`o'", discrete line(connect) title("`c_title' Drop: `o'", size(medium)) xtitle("Prior Year `m_title' Declined") ytitle("`c_title'") note("`v_note'" "`ft_meas'", size(vsmall)) graphregion(color(white))
                capture graph export "`baseOut'/by_ownership/`o'/decline_`m'_vs_`var'.png", replace width(2000)
                
                foreach geo in "nat" "state" {
                    local gname = strproper("`geo'")
                    capture binscatter `var' lag_bin_`m'_`geo' if own_cat == "`o'", discrete line(connect) title("`gname' `m_title': `o'", size(medium)) xtitle("SDs from `gname' `m_title' (Prior Year)") ytitle("`c_title'") note("`v_note'" "`ft_meas'", size(vsmall)) graphregion(color(white))
                    capture graph export "`baseOut'/by_ownership/`o'/bin_`m'_`geo'_vs_`var'.png", replace width(2000)
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
    local l_upper = strupper("`l'")
    local c_title "Change in `l_upper' % of Staff"
    local ft_pre1 "Benchmark: Facility's avg HCAHPS SD from National mean during pre-period (2013-2015)."
    local ft_pre2 "Benchmark: Facility's avg HCAHPS SD from National mean during pre-period (2013-2020)."

    * Universal Long-Diff
    capture binscatter d_`l'_1519 bin_pre_1519 if year == 2019, discrete line(connect) title("`l_upper' Shift (2015-2019) by Pre-Sample", size(medium)) xtitle("SDs from Nat. Mean (2013-2015 Avg)") ytitle("`c_title'") note("Outcome: Absolute change in `l_upper' proportion (2015-2019)." "`ft_pre1'", size(vsmall)) graphregion(color(white))
    capture graph export "`baseOut'/universal/longdiff_2015_2019_`l'.png", replace width(2000)
    
    capture binscatter d_`l'_2023 bin_pre_2023 if year == 2023, discrete line(connect) title("`l_upper' Shift (2020-2023) by Pre-Sample", size(medium)) xtitle("SDs from Nat. Mean (2013-2020 Avg)") ytitle("`c_title'") note("Outcome: Absolute change in `l_upper' proportion (2020-2023)." "`ft_pre2'", size(vsmall)) graphregion(color(white))
    capture graph export "`baseOut'/universal/longdiff_2020_2023_`l'.png", replace width(2000)

    * Stratified Long-Diff
    foreach a in `auths' {
        capture mkdir "`baseOut'/by_np_auth/`a'"
        capture binscatter d_`l'_1519 bin_pre_1519 if year == 2019 & np_auth == "`a'", discrete line(connect) title("`l_upper' Shift (2015-2019): `a'", size(medium)) xtitle("SDs from Nat. Mean (2013-2015 Avg)") ytitle("`c_title'") graphregion(color(white))
        capture graph export "`baseOut'/by_np_auth/`a'/longdiff_2015_2019_`l'.png", replace width(2000)
        capture binscatter d_`l'_2023 bin_pre_2023 if year == 2023 & np_auth == "`a'", discrete line(connect) title("`l_upper' Shift (2020-2023): `a'", size(medium)) xtitle("SDs from Nat. Mean (2013-2020 Avg)") ytitle("`c_title'") graphregion(color(white))
        capture graph export "`baseOut'/by_np_auth/`a'/longdiff_2020_2023_`l'.png", replace width(2000)
    }
    foreach o in `owns' {
        capture mkdir "`baseOut'/by_ownership/`o'"
        capture binscatter d_`l'_1519 bin_pre_1519 if year == 2019 & own_cat == "`o'", discrete line(connect) title("`l_upper' Shift (2015-2019): `o'", size(medium)) xtitle("SDs from Nat. Mean (2013-2015 Avg)") ytitle("`c_title'") graphregion(color(white))
        capture graph export "`baseOut'/by_ownership/`o'/longdiff_2015_2019_`l'.png", replace width(2000)
        capture binscatter d_`l'_2023 bin_pre_2023 if year == 2023 & own_cat == "`o'", discrete line(connect) title("`l_upper' Shift (2020-2023): `o'", size(medium)) xtitle("SDs from Nat. Mean (2013-2020 Avg)") ytitle("`c_title'") graphregion(color(white))
        capture graph export "`baseOut'/by_ownership/`o'/longdiff_2020_2023_`l'.png", replace width(2000)
    }
		* Flush memory after each outcome variable is fully processed
        capture graph drop _all
}
display "=== FACILITY HCAHPS BENCHMARKS COMPLETE ==="
