*===============================================================================
* SCRIPT: 02_micro_inpatient_stats.do
* PURPOSE: Summary stats for Individual Providers (Micro Inpatient Panel).
*===============================================================================
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* Load the Micro/Provider Inpatient Panel
use "$dataRoot/master_provider_inpatient_2013_2023.dta", clear

* --- 1. DECODE VARIABLES ---
decode credential, gen(cred_str)
decode cms_state, gen(state_str)

* --- 2. CREATE PROVIDER TYPE TAXONOMY ---
gen prov_type = .
replace prov_type = 1 if cred_str == "MD" | cred_str == "DO"
replace prov_type = 2 if cred_str == "NP"
replace prov_type = 3 if cred_str == "PA"

label define pt_lbl 1 "MD/DO" 2 "Nurse Practitioner" 3 "Physician Assistant"
label values prov_type pt_lbl

* --- 3. CREATE NP AUTHORITY TAXONOMY ---
gen np_authority = .
replace np_authority = 3 if inlist(state_str, "AZ", "CO", "CT", "DC", "HI", "ID", "IA", "MD", "MA") | inlist(state_str, "MN", "MT", "NE", "NV", "NH", "NM", "NY", "ND", "OR") | inlist(state_str, "RI", "SD", "VT", "WA", "WY")
replace np_authority = 2 if inlist(state_str, "AL", "AS", "DE", "IL", "IN", "KS", "KY", "LA", "MS") | inlist(state_str, "NJ", "OH", "PA", "UT", "WI")
replace np_authority = 1 if inlist(state_str, "CA", "FL", "GA", "MI", "MO", "NC", "OK", "SC", "TN") | inlist(state_str, "TX", "VA")

label define auth_lbl 1 "Restricted" 2 "Reduced" 3 "Full Practice"
label values np_authority auth_lbl

drop cred_str state_str

* --- 4. DEFINE VARIABLES & GROUPS ---
* Note: Pulled exactly from your data dictionary for this panel
local dep_vars "partd_generic_rate partd_opioid_rate partb_em_upcode_rate mips_final_score bene_avg_risk_scre tot_benes tot_sbmtd_chrg"

egen auth_prov_group = group(np_authority prov_type), label

* --- 5. THE MASTER OUTPUT LOOP ---
foreach var in `dep_vars' {
    
    display "Generating outputs for: `var'..."
    
    *--------------------------------------------------
    * 1. DYNAMIC OBSERVATION COUNT (N)
    *--------------------------------------------------
    quietly count if !missing(`var') & !missing(np_authority) & !missing(prov_type)
    local nobs = r(N)
    local n_fmt : display %9.0fc `nobs'
    local n_fmt = trim("`n_fmt'")
    
    *--------------------------------------------------
    * 2. DYNAMIC TITLES & FOOTNOTES
    *--------------------------------------------------
    local clean_title ""
    local dir_note ""

    if "`var'" == "partd_generic_rate" {
        local clean_title "Generic Prescribing Rate"
        local dir_note "Behavior: Higher values indicate cost-conscious prescribing (generic vs. brand)."
    }
    else if "`var'" == "partd_opioid_rate" {
        local clean_title "Opioid Prescribing Rate"
        local dir_note "Behavior: Proportion of total prescriptions that are Schedule II/III opioids."
    }
    else if "`var'" == "partb_em_upcode_rate" {
        * Escaped the ampersand for LaTeX!
        local clean_title "Provider E\&M Upcode Rate"
        local dir_note "Behavior: Proportion of total E\&M visits billed at the highest intensity (Level 4/5)."
    }
    else if "`var'" == "mips_final_score" {
        local clean_title "MIPS Final Score"
        local dir_note "Outcome: Higher values reflect better clinical quality, value, and efficiency."
    }
    else if "`var'" == "bene_avg_risk_scre" {
        local clean_title "Average Patient Risk Score (HCC)"
        local dir_note "Demographic: Higher values indicate a sicker, more clinically complex patient panel."
    }
    else if "`var'" == "tot_benes" {
        local clean_title "Total Beneficiaries Treated"
        local dir_note "Volume: Number of unique Medicare patients seen by the provider."
    }
    else if "`var'" == "tot_sbmtd_chrg" {
        local clean_title "Total Submitted Charges ($)"
        local dir_note "Financial: Total dollars billed to Medicare by the provider."
    }

    local data_note "Data: CMS Provider Panel (2013-2023) | N = `n_fmt' provider-year observations."
    local np_note "NP Law: Restricted (requires supervision), Reduced (collaborative), Full (independent practice)."
    local prov_note "Providers: MD/DO (Physician), NP (Nurse Practitioner), PA (Physician Assistant)."

    *--------------------------------------------------
    * A. LaTeX TABLES
    *--------------------------------------------------
    estpost tabstat `var', by(prov_type) stat(mean sd n) columns(statistics)
    esttab . using "$outRoot/in_patient/tables/`var'_by_provtype.tex", replace ///
        cells("mean(fmt(%9.3f)) sd(fmt(%9.3f)) count(fmt(%9.0fc))") ///
        title("Summary of `clean_title' by Provider Type") ///
        nomtitle nonumber noobs label booktabs

    estpost tabstat `var', by(auth_prov_group) stat(mean n) columns(statistics)
    esttab . using "$outRoot/in_patient/tables/`var'_by_auth_provtype.tex", replace ///
        cells("mean(fmt(%9.3f)) count(fmt(%9.0fc))") ///
        title("Summary of `clean_title' by Authority and Provider Type") ///
        nomtitle nonumber noobs label booktabs

    *--------------------------------------------------
    * B. BAR GRAPHS
    *--------------------------------------------------
    graph bar (mean) `var', over(prov_type, label(angle(0) labsize(small))) ///
        over(np_authority) ///
        ytitle("Mean Value") ///
        title("`clean_title'", size(medium) color(black)) ///
        subtitle("By Provider Type and State NP Law", size(small)) ///
        note("`data_note'" "`dir_note'" "`np_note'" "`prov_note'", position(7) justification(left) size(vsmall) margin(t=3)) ///
        blabel(bar, format(%9.3f) size(vsmall)) ///
        graphregion(color(white))
    
    graph export "$outRoot/in_patient/bar_graphs/`var'_bar.png", replace width(2400)
    
    *--------------------------------------------------
    * C. HEATMAPS 
    *--------------------------------------------------
    * Temporary relabel to fix the legend title
    local orig_lbl : variable label `var'
    label variable `var' "Value"

    heatplot `var' i.np_authority i.prov_type, ///
        statistic(mean) ///
        color(Reds) ///
        values(format(%9.3f)) ///
        ramp(right) ///
        title("Heatmap: `clean_title'", size(medium)) ///
        note("`data_note'" "`dir_note'" "`np_note'" "`prov_note'", position(7) justification(left) size(vsmall) margin(t=3)) ///
        ylabel(, angle(0) labsize(small)) xlabel(, angle(0) labsize(small)) ///
        aspectratio(0.6) graphregion(margin(l=5 r=45) color(white)) 
        
    graph export "$outRoot/in_patient/heatmaps/`var'_heatmap.png", replace width(2400)

    * Restore original label
    label variable `var' "`orig_lbl'"
}

display "=== MICRO INPATIENT STATS COMPLETE ==="