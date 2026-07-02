*===============================================================================
* SCRIPT: 00b_facility_ownership_demographics.do
* PURPOSE: Extract facility headcounts across fine and grouped ownership categories.
* OUTPUTS: Full-sample tables, Yearly tables, and Time-Series Headcount Charts.
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* --- START LOG ---
local script_name "00b_facility_ownership_demographics"
log using "$logRoot/`script_name'.smcl", replace
* -----------------


display "=== STARTING FACILITY OWNERSHIP DEMOGRAPHICS ==="

local outDir "$outRoot/summary_stats/in_patient/demographics"
capture mkdir "`outDir'"
capture mkdir "`outDir'/tables_csv"
capture mkdir "`outDir'/time_series"
capture mkdir "`outDir'/time_series/headcounts"

* Load the extended 2007-2024 panel
use "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/general_cms_data/outputs_while_cleaning/cleaned_data/phase2_hcahps/hcahps_final_panel.dta", clear

* 1. Decode & Standardize Finer Ownership
capture drop own_str
capture decode ownership, gen(own_str)
if _rc != 0 {
    capture confirm string variable ownership
    if _rc == 0 gen own_str = ownership
    else gen own_str = string(ownership)
}
replace own_str = strtrim(strupper(own_str))
drop if missing(own_str)

* 2. Apply Grouped Ownership Taxonomy
gen own_category = .
replace own_category = 1 if $cond_own_gov
replace own_category = 2 if $cond_own_forprof
replace own_category = 3 if $cond_own_nonprof
label define own_lbl 1 "Government" 2 "For-Profit" 3 "Non-Profit"
capture label values own_category own_lbl

* Generate Dummy Counter
gen fac_count = 1


* ==============================================================================
* OUTPUT 1: UNIQUE FACILITY COUNTS (2007-2024)
* ==============================================================================

preserve
    duplicates drop ccn, force
    * We use the dummy 'fac_count' we generated earlier (which is = 1)
    * Summing 'fac_count' gives the total number of unique CCNS per category
    collapse (sum) fac_count, by(own_str)
    export delimited using "`outDir'/tables_csv/ownership_fine_unique_full_sample.csv", replace
restore

preserve
    duplicates drop ccn, force
    collapse (sum) fac_count, by(own_category)
    export delimited using "`outDir'/tables_csv/ownership_grouped_unique_full_sample.csv", replace
restore


* ==============================================================================
* OUTPUT 2: YEARLY COUNTS (LONG FORMAT FOR PYTHON PIVOT)
* ==============================================================================
preserve
collapse (sum) fac_count, by(year own_str)
export delimited using "`outDir'/tables_csv/ownership_fine_by_year.csv", replace
restore

preserve
collapse (sum) fac_count, by(year own_category)
export delimited using "`outDir'/tables_csv/ownership_grouped_by_year.csv", replace
restore

* ==============================================================================
* OUTPUT 3: TIME SERIES CHARTS (HEADCOUNTS)
* ==============================================================================
local note_text "Metric: Total Active Facilities. Sample: Extended HCAHPS Panel (2007-2024)."

preserve
collapse (sum) fac_count, by(year own_category)
twoway (connected fac_count year if own_category==1, lcolor(navy) msymbol(O)) ///
       (connected fac_count year if own_category==2, lcolor(cranberry) msymbol(S)) ///
       (connected fac_count year if own_category==3, lcolor(emerald) msymbol(D)), ///
    title("Active Facilities by Ownership", size(medium) color(black)) ///
    ytitle("Total Facility Count") xtitle("Year") xlabel(2007(1)2024, angle(45) labsize(vsmall)) ///
    legend(order(1 "Government" 2 "For-Profit" 3 "Non-Profit") position(6) rows(1)) ///
    note("`note_text'", size(vsmall) span) graphregion(color(white) margin(l+2 r+2 b+10))
graph export "`outDir'/time_series/headcounts/ts_fac_count_by_ownership.png", replace width(2000)
restore

display "=== FACILITY OWNERSHIP DEMOGRAPHICS COMPLETE ==="