*===============================================================================
* SCRIPT: 01_macro_inpatient_stats.do
* PURPOSE: "Kitchen Sink" summary stats for Inpatient Facilities.
*===============================================================================
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

use "$dataRoot/master_facility_inpatient_2013_2023.dta", clear

* --- 1. RE-CREATE THE NP AUTHORITY TAXONOMY ---
gen np_authority = .
replace np_authority = 3 if inlist(state, "AZ", "CO", "CT", "DC", "HI", "ID", "IA", "MD", "MA") | inlist(state, "MN", "MT", "NE", "NV", "NH", "NM", "NY", "ND", "OR") | inlist(state, "RI", "SD", "VT", "WA", "WY")
replace np_authority = 2 if inlist(state, "AL", "AS", "DE", "IL", "IN", "KS", "KY", "LA", "MS") | inlist(state, "NJ", "OH", "PA", "UT", "WI")
replace np_authority = 1 if inlist(state, "CA", "FL", "GA", "MI", "MO", "NC", "OK", "SC", "TN") | inlist(state, "TX", "VA")

label define auth_lbl 1 "Restricted" 2 "Reduced" 3 "Full Practice"
label values np_authority auth_lbl

* --- 2. CONSOLIDATE OWNERSHIP (Journal-Ready 3-Way Split) ---
decode ownership, gen(own_str)
gen own_category = .
replace own_category = 1 if strpos(own_str, "GOVERNMENT") | inlist(own_str, "DEPARTMENT OF DEFENSE", "TRIBAL", "VETERANS HEALTH ADMINISTRATION")
replace own_category = 2 if inlist(own_str, "PROPRIETARY", "PHYSICIAN")
replace own_category = 3 if strpos(own_str, "NON-PROFIT")

label define own_lbl 1 "Government" 2 "For-Profit" 3 "Non-Profit"
label values own_category own_lbl
drop own_str

* --- 3. DEFINE VARIABLES & GROUPS ---
local dep_vars "h_hosp_rating_9_10 hac_total_score rrp_excess_ratio_ami rrp_excess_ratio_hf rrp_excess_ratio_pn mspb_score fac_wgt_em_upcode_rate fac_mips_final_score"
egen auth_owner_group = group(np_authority own_category), label

* --- 4. THE MASTER OUTPUT LOOP ---
foreach var in `dep_vars' {
    
    display "Generating outputs for: `var'..."
    
    *--------------------------------------------------
    * 1. DYNAMIC OBSERVATION COUNT (N)
    *--------------------------------------------------
    quietly count if !missing(`var') & !missing(np_authority) & !missing(own_category)
    local nobs = r(N)
    local n_fmt : display %9.0fc `nobs'
    local n_fmt = trim("`n_fmt'")
    
    *--------------------------------------------------
    * 2. DYNAMIC TITLES & FOOTNOTES
    *--------------------------------------------------
    local clean_title ""
    local dir_note ""

    if "`var'" == "h_hosp_rating_9_10" {
        local clean_title "HCAHPS: Patients Rating Hospital 9 or 10"
        local dir_note "Outcome: Higher values indicate better patient satisfaction."
    }
    else if "`var'" == "hac_total_score" {
        local clean_title "Hospital-Acquired Condition (HAC) Score"
        local dir_note "Outcome: Lower values are better (indicates fewer hospital-acquired infections)."
    }
    else if strpos("`var'", "rrp_excess_ratio") > 0 {
        local disease = upper(substr("`var'", 18, .))
        local clean_title "Readmission Reduction Program: `disease' Excess Ratio"
        local dir_note "Outcome: Lower values are better. Ratio > 1.0 triggers Medicare penalties."
    }
    else if "`var'" == "mspb_score" {
        local clean_title "Medicare Spending Per Beneficiary (MSPB)"
        local dir_note "Outcome: Lower values indicate greater hospital financial efficiency."
    }
    else if "`var'" == "fac_wgt_em_upcode_rate" {
        local clean_title "Facility-Weighted E\&M Upcode Rate"
        local dir_note "Behavior: Higher values indicate higher billing intensity (Level 4/5 visits)."
    }
    else if "`var'" == "fac_mips_final_score" {
        local clean_title "Facility-Weighted MIPS Final Score"
        local dir_note "Outcome: Higher values indicate higher clinical quality across affiliated staff."
    }

    local data_note "Data: CMS Inpatient (2013-2023) | N = `n_fmt' facility-year observations."
    local np_note "NP Law: Restricted (requires supervision), Reduced (collaborative), Full (independent practice)."
    local own_note "Ownership: Gov (Fed/State/Local), For-Profit (Proprietary), Non-Profit (Private/Church)."

    *--------------------------------------------------
    * A. LaTeX TABLES
    *--------------------------------------------------
    estpost tabstat `var', by(np_authority) stat(mean sd n) columns(statistics)
    esttab . using "$outRoot/in_patient/tables/`var'_by_authority.tex", replace ///
        cells("mean(fmt(%9.3f)) sd(fmt(%9.3f)) count(fmt(%9.0fc))") ///
        title("Summary of `clean_title' by State NP Authority") ///
        nomtitle nonumber noobs label booktabs

    estpost tabstat `var', by(auth_owner_group) stat(mean n) columns(statistics)
    esttab . using "$outRoot/in_patient/tables/`var'_by_auth_ownership.tex", replace ///
        cells("mean(fmt(%9.3f)) count(fmt(%9.0fc))") ///
        title("Summary of `clean_title' by Authority and Hospital Ownership") ///
        nomtitle nonumber noobs label booktabs

    *--------------------------------------------------
    * B. BAR GRAPHS
    *--------------------------------------------------
    graph bar (mean) `var', over(own_category, label(angle(0) labsize(small))) ///
        over(np_authority) ///
        ytitle("Mean Value") ///
        title("`clean_title'", size(medium) color(black)) ///
        subtitle("By Hospital Ownership and State NP Law", size(small)) ///
        note("`data_note'" "`dir_note'" "`np_note'" "`own_note'", position(7) justification(left) size(vsmall) margin(t=3)) ///
        blabel(bar, format(%9.2f) size(vsmall)) ///
        graphregion(color(white))
    
    graph export "$outRoot/in_patient/bar_graphs/`var'_bar.png", replace width(2400)
    
    *--------------------------------------------------
    * C. HEATMAPS 
    *--------------------------------------------------
    * Temporary relabel to fix the ugly legend title
    local orig_lbl : variable label `var'
    label variable `var' "Value"

    heatplot `var' i.np_authority i.own_category, ///
        statistic(mean) ///
        color(Blues) ///
        values(format(%9.2f)) ///
        ramp(right) ///
        title("Heatmap: `clean_title'", size(medium)) ///
        note("`data_note'" "`dir_note'" "`np_note'" "`own_note'", position(7) justification(left) size(vsmall) margin(t=3)) ///
        ylabel(, angle(0) labsize(small)) xlabel(, angle(0) labsize(small)) ///
        aspectratio(0.6) graphregion(margin(l=5 r=45) color(white)) 
        
    graph export "$outRoot/in_patient/heatmaps/`var'_heatmap.png", replace width(2400)

    * Restore the original label
    label variable `var' "`orig_lbl'"
}


display "=== INPATIENT MACRO STATS COMPLETE ==="
