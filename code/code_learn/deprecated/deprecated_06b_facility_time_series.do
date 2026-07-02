*===============================================================================
* SCRIPT: 06b_facility_time_series.do
* PURPOSE: Time-Series Line Charts for Facility Outcomes (HCAHPS & Master Panel)
*===============================================================================
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* --- 1. DYNAMIC FOLDER CREATION ---
local subfolders "overall by_authority by_ownership"
capture mkdir "$outRoot/in_patient/time_series"
foreach sub in `subfolders' {
    capture mkdir "$outRoot/in_patient/time_series/`sub'"
}

*===============================================================================
* PHASE 1: LONG-PANEL HCAHPS (2007-2024)
*===============================================================================
display "--- Processing Extended HCAHPS Data ---"
use "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/general_cms_data/outputs_while_cleaning/cleaned_data/phase2_hcahps/hcahps_final_panel.dta", clear

* Prep string variables to match our global macros
capture gen state_str = state
capture decode ownership, gen(own_str)
if _rc {
    capture gen own_str = ownership // Uses native string if decode fails
}

* Apply Centralized NP Authority Logic
gen np_authority = .
replace np_authority = 3 if $cond_full_prac
replace np_authority = 2 if $cond_red_prac
replace np_authority = 1 if $cond_res_prac
label define auth_lbl 1 "Restricted" 2 "Reduced" 3 "Full Practice"
label values np_authority auth_lbl

* Apply Centralized Ownership Logic
gen own_category = .
replace own_category = 1 if $cond_own_gov
replace own_category = 2 if $cond_own_nonprof
replace own_category = 3 if $cond_own_forprof
label define own_lbl 1 "Government" 2 "Non-Profit" 3 "For-Profit"
label values own_category own_lbl

* Determine variables to plot
local hcahps_vars "h_hosp_rating_9_10 h_hosp_rating_0_6"

foreach var in `hcahps_vars' {
    local clean_title = strproper(subinstr("`var'", "_", " ", .))
    
    * Overall
    preserve
    collapse (mean) `var', by(year)
    twoway (connected `var' year, lcolor(navy)), title("Overall: `clean_title'", size(medium)) graphregion(color(white))
    graph export "$outRoot/in_patient/time_series/overall/ts_overall_`var'.png", replace width(2000)
    restore
    
    * By Authority
    preserve
    collapse (mean) `var', by(year np_authority)
    drop if missing(np_authority)
    twoway (connected `var' year if np_authority==1, lcolor(red)) ///
           (connected `var' year if np_authority==2, lcolor(orange)) ///
           (connected `var' year if np_authority==3, lcolor(green)), ///
        title("By Law: `clean_title'", size(medium)) legend(order(1 "Restricted" 2 "Reduced" 3 "Full") position(6) rows(1)) graphregion(color(white))
    graph export "$outRoot/in_patient/time_series/by_authority/ts_auth_`var'.png", replace width(2000)
    restore
    
    * By Ownership
    preserve
    collapse (mean) `var', by(year own_category)
    drop if missing(own_category)
    twoway (connected `var' year if own_category==1, lcolor(blue)) ///
           (connected `var' year if own_category==2, lcolor(emerald)) ///
           (connected `var' year if own_category==3, lcolor(purple)), ///
        title("By Ownership: `clean_title'", size(medium)) legend(order(1 "Gov" 2 "Non-Profit" 3 "For-Profit") position(6) rows(1)) graphregion(color(white))
    graph export "$outRoot/in_patient/time_series/by_ownership/ts_own_`var'.png", replace width(2000)
    restore
}

*===============================================================================
* PHASE 2: MASTER INPATIENT OUTCOMES (2013-2023)
*===============================================================================
display "--- Processing Master Facility Data ---"
use "$dataRoot/master_facility_inpatient_2013_2023.dta", clear

* Prep string variables to match our global macros
capture gen state_str = state
capture decode ownership, gen(own_str)
if _rc {
    capture gen own_str = ownership
}

* Apply NP Authority & Ownership Logic
gen np_authority = .
replace np_authority = 3 if $cond_full_prac
replace np_authority = 2 if $cond_red_prac
replace np_authority = 1 if $cond_res_prac
label values np_authority auth_lbl

gen own_category = .
gen is_gov = 0
replace is_gov = 1 if $cond_own_gov
replace own_category = 1 if $cond_own_gov
replace own_category = 2 if $cond_own_nonprof
replace own_category = 3 if $cond_own_forprof
label values own_category own_lbl

* Call the global facility list!
local fac_vars "$in_fac_means"

foreach var in `fac_vars' {
    local clean_title = strproper(subinstr("`var'", "_", " ", .))
    
    * Prevent plotting HCAHPS here since we did it above with the long panel!
    if !inlist("`var'", "h_hosp_rating_9_10", "h_hosp_rating_0_6") {
        
        * Overall
        preserve
        collapse (mean) `var', by(year)
        twoway (connected `var' year, lcolor(navy)), title("Overall: `clean_title'", size(medium)) graphregion(color(white))
        graph export "$outRoot/in_patient/time_series/overall/ts_overall_`var'.png", replace width(2000)
        restore
        
        * By Authority
        preserve
        collapse (mean) `var', by(year np_authority)
        drop if missing(np_authority)
        twoway (connected `var' year if np_authority==1, lcolor(red)) ///
               (connected `var' year if np_authority==2, lcolor(orange)) ///
               (connected `var' year if np_authority==3, lcolor(green)), ///
            title("By Law: `clean_title'", size(medium)) legend(order(1 "Restricted" 2 "Reduced" 3 "Full") position(6) rows(1)) graphregion(color(white))
        graph export "$outRoot/in_patient/time_series/by_authority/ts_auth_`var'.png", replace width(2000)
        restore
        
        * By Ownership
        preserve
        collapse (mean) `var', by(year own_category)
        drop if missing(own_category)
        twoway (connected `var' year if own_category==1, lcolor(blue)) ///
               (connected `var' year if own_category==2, lcolor(emerald)) ///
               (connected `var' year if own_category==3, lcolor(purple)), ///
            title("By Ownership: `clean_title'", size(medium)) legend(order(1 "Gov" 2 "Non-Profit" 3 "For-Profit") position(6) rows(1)) graphregion(color(white))
        graph export "$outRoot/in_patient/time_series/by_ownership/ts_own_`var'.png", replace width(2000)
        restore
    }
}
display "=== FACILITY TIME SERIES COMPLETE ==="