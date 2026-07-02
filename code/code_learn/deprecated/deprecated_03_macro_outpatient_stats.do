*===============================================================================
* SCRIPT: 03_macro_outpatient_stats.do
* PURPOSE: Summary stats for Outpatient Facilities (Ambulatory Surgical Centers).
*===============================================================================
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

use "$dataRoot/master_facility_outpatient_asc_2015_2024.dta", clear

* --- 1. RE-CREATE THE NP AUTHORITY TAXONOMY ---
* (State is already a string in this dataset)
gen np_authority = .
replace np_authority = 3 if inlist(state, "AZ", "CO", "CT", "DC", "HI", "ID", "IA", "MD", "MA") | inlist(state, "MN", "MT", "NE", "NV", "NH", "NM", "NY", "ND", "OR") | inlist(state, "RI", "SD", "VT", "WA", "WY")
replace np_authority = 2 if inlist(state, "AL", "AS", "DE", "IL", "IN", "KS", "KY", "LA", "MS") | inlist(state, "NJ", "OH", "PA", "UT", "WI")
replace np_authority = 1 if inlist(state, "CA", "FL", "GA", "MI", "MO", "NC", "OK", "SC", "TN") | inlist(state, "TX", "VA")

label define auth_lbl 1 "Restricted" 2 "Reduced" 3 "Full Practice"
label values np_authority auth_lbl

* --- 2. DEFINE VARIABLES & GROUPS ---
local dep_vars "asc_rate_1 asc_rate_2 asc_rate_8"
egen auth_year_group = group(np_authority year), label

* --- 3. THE MASTER OUTPUT LOOP ---
foreach var in `dep_vars' {
    
    display "Generating outputs for: `var'..."
    
    *--------------------------------------------------
    * 1. DYNAMIC OBSERVATION COUNT (N)
    *--------------------------------------------------
    quietly count if !missing(`var') & !missing(np_authority) & !missing(year)
    local nobs = r(N)
    local n_fmt : display %9.0fc `nobs'
    local n_fmt = trim("`n_fmt'")
    
    *--------------------------------------------------
    * 2. DYNAMIC TITLES & FOOTNOTES
    *--------------------------------------------------
    local clean_title ""
    local dir_note ""

    if "`var'" == "asc_rate_1" {
        local clean_title "ASC-1: Patient Burns Rate"
        local dir_note "Outcome: Lower values are better (indicates fewer patient burns in surgery)."
    }
    else if "`var'" == "asc_rate_2" {
        local clean_title "ASC-2: Patient Falls Rate"
        local dir_note "Outcome: Lower values are better (indicates fewer patient falls in surgery)."
    }
    else if "`var'" == "asc_rate_8" {
        local clean_title "ASC-8: Influenza Vaccination Coverage"
        local dir_note "Quality: Higher values indicate a safer, better-vaccinated healthcare workforce."
    }

    local data_note "Data: CMS Outpatient ASC (2015-2024) | N = `n_fmt' facility-year observations."
    local np_note "NP Law: Restricted (requires supervision), Reduced (collaborative), Full (independent practice)."
    
    *--------------------------------------------------
    * A. LaTeX TABLES
    *--------------------------------------------------
    estpost tabstat `var', by(np_authority) stat(mean sd n) columns(statistics)
    esttab . using "$outRoot/out_patient/tables/`var'_by_authority.tex", replace ///
        cells("mean(fmt(%9.3f)) sd(fmt(%9.3f)) count(fmt(%9.0fc))") ///
        title("Summary of `clean_title' by State NP Authority") ///
        nomtitle nonumber noobs label booktabs

    estpost tabstat `var', by(auth_year_group) stat(mean n) columns(statistics)
    esttab . using "$outRoot/out_patient/tables/`var'_by_auth_year.tex", replace ///
        cells("mean(fmt(%9.3f)) count(fmt(%9.0fc))") ///
        title("Summary of `clean_title' by Authority and Year") ///
        nomtitle nonumber noobs label booktabs

    *--------------------------------------------------
    * B. BAR GRAPHS (Over Year and Authority)
    *--------------------------------------------------
    graph bar (mean) `var', over(year, label(angle(45) labsize(small))) ///
        over(np_authority) ///
        ytitle("Mean Value") ///
        title("`clean_title'", size(medium) color(black)) ///
        subtitle("By Year and State NP Law", size(small)) ///
        note("`data_note'" "`dir_note'" "`np_note'", position(7) justification(left) size(vsmall) margin(t=3)) ///
        blabel(bar, format(%9.3f) size(vsmall)) ///
        graphregion(color(white))
    
    graph export "$outRoot/out_patient/bar_graphs/`var'_bar.png", replace width(2400)
    
    *--------------------------------------------------
    * C. HEATMAPS 
    *--------------------------------------------------
    local orig_lbl : variable label `var'
    label variable `var' "Value"

    heatplot `var' i.np_authority i.year, ///
        statistic(mean) ///
        color(Greens) ///
        values(format(%9.3f)) ///
        ramp(right) ///
        title("Heatmap: `clean_title'", size(medium)) ///
        note("`data_note'" "`dir_note'" "`np_note'", position(7) justification(left) size(vsmall) margin(t=3)) ///
        ylabel(, angle(0) labsize(small)) xlabel(, angle(45) labsize(small)) ///
        aspectratio(0.6) graphregion(margin(l=5 r=45) color(white)) 
        
    graph export "$outRoot/out_patient/heatmaps/`var'_heatmap.png", replace width(2400)
    label variable `var' "`orig_lbl'"
}

display "=== MACRO OUTPATIENT STATS COMPLETE ==="