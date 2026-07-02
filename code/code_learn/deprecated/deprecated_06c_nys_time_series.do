*===============================================================================
* SCRIPT: 06c_nys_time_series.do
* PURPOSE: Time-Series Line Charts exclusively for New York State.
*===============================================================================
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

*===============================================================================
* PHASE 1: NYS PROVIDERS (Inpatient & Outpatient)
*===============================================================================
foreach setting in "in_patient" "out_patient" {
    display "--- NYS Time Series: `setting' Providers ---"
    
    local subfolders "overall by_prov_type by_gender by_dept by_ownership"
    capture mkdir "$outRoot/`setting'/time_series_nys"
    foreach sub in `subfolders' {
        capture mkdir "$outRoot/`setting'/time_series_nys/`sub'"
    }

    if "`setting'" == "in_patient" {
        use "$dataRoot/master_provider_inpatient_2013_2023.dta", clear
    }
    else {
        use "$dataRoot/master_provider_outpatient_asc_2015_2023.dta", clear
    }

    * The Cascading State Catcher
    capture drop state_str
    capture decode cms_state, gen(state_str)
    capture gen state_str = cms_state 
    capture gen state_str = state 
    capture gen state_str = affil_state 
    keep if state_str == "NY" // ISOLATE NEW YORK

    * Prep Subgroups
    decode credential, gen(cred_str)
    gen prov_type = 1 if inlist(cred_str, "MD", "DO")
    replace prov_type = 2 if cred_str == "NP"
    replace prov_type = 3 if cred_str == "PA"
    label define pt_lbl 1 "MD/DO" 2 "NP" 3 "PA"
    label values prov_type pt_lbl

    decode cms_specialty, gen(spec_str)
    gen is_gen_med = 0
    replace is_gen_med = 1 if $cond_gen_med

    * The Ownership Catcher
    capture drop own_str
    capture decode ownership, gen(own_str)
    capture gen own_str = ownership 
    
    gen own_category = .
    capture confirm variable own_str
    if !_rc {
        replace own_category = 1 if $cond_own_gov
        replace own_category = 2 if $cond_own_nonprof
        replace own_category = 3 if $cond_own_forprof
        label define own_lbl 1 "Gov" 2 "Non-Profit" 3 "For-Profit"
        capture label values own_category own_lbl
    }

    local plot_vars ""
    foreach v in $prov_overlap_means {
        capture confirm variable `v'
        if !_rc {
            local plot_vars "`plot_vars' `v'"
        }
    }

    * Collapse & Graph
    foreach var in `plot_vars' {
        local clean_title = strproper(subinstr("`var'", "_", " ", .))
        
        preserve
        collapse (mean) `var', by(year)
        twoway (connected `var' year, lcolor(navy)), title("NYS Overall: `clean_title'", size(medium)) graphregion(color(white))
        graph export "$outRoot/`setting'/time_series_nys/overall/nys_ts_overall_`var'.png", replace width(2000)
        restore
        
        preserve
        collapse (mean) `var', by(year prov_type)
        drop if missing(prov_type)
        twoway (connected `var' year if prov_type==1, lcolor(navy)) (connected `var' year if prov_type==2, lcolor(maroon)) (connected `var' year if prov_type==3, lcolor(forest_green)), title("NYS by Provider: `clean_title'", size(medium)) legend(order(1 "MD" 2 "NP" 3 "PA") position(6) rows(1)) graphregion(color(white))
        graph export "$outRoot/`setting'/time_series_nys/by_prov_type/nys_ts_prov_`var'.png", replace width(2000)
        restore

        preserve
        collapse (mean) `var', by(year is_female)
        drop if missing(is_female)
        twoway (connected `var' year if is_female==0, lcolor(gs8)) (connected `var' year if is_female==1, lcolor(purple)), title("NYS by Gender: `clean_title'", size(medium)) legend(order(1 "Male" 2 "Female") position(6) rows(1)) graphregion(color(white))
        graph export "$outRoot/`setting'/time_series_nys/by_gender/nys_ts_gender_`var'.png", replace width(2000)
        restore

        preserve
        collapse (mean) `var', by(year is_gen_med)
        twoway (connected `var' year if is_gen_med==0, lcolor(gs10) lpattern(dash)) (connected `var' year if is_gen_med==1, lcolor(blue)), title("NYS by Dept: `clean_title'", size(medium)) legend(order(1 "Other" 2 "Gen Med") position(6) rows(1)) graphregion(color(white))
        graph export "$outRoot/`setting'/time_series_nys/by_dept/nys_ts_dept_`var'.png", replace width(2000)
        restore
        
        capture confirm variable own_category
        if !_rc {
            preserve
            collapse (mean) `var', by(year own_category)
            drop if missing(own_category)
            capture count
            if r(N) > 0 {
                twoway (connected `var' year if own_category==1, lcolor(blue)) (connected `var' year if own_category==2, lcolor(emerald)) (connected `var' year if own_category==3, lcolor(purple)), title("NYS by Ownership: `clean_title'", size(medium)) legend(order(1 "Gov" 2 "Non-Profit" 3 "For-Profit") position(6) rows(1)) graphregion(color(white))
                graph export "$outRoot/`setting'/time_series_nys/by_ownership/nys_ts_own_`var'.png", replace width(2000)
            }
            restore
        }
    }
}

*===============================================================================
* PHASE 2: NYS FACILITIES (HCAHPS & Master Panel)
*===============================================================================
display "--- NYS Time Series: Facilities ---"
capture mkdir "$outRoot/in_patient/time_series_nys/overall"
capture mkdir "$outRoot/in_patient/time_series_nys/by_ownership"

* 2A. HCAHPS
use "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/general_cms_data/outputs_while_cleaning/cleaned_data/phase2_hcahps/hcahps_final_panel.dta", clear

capture drop state_str
capture gen state_str = state
keep if state_str == "NY" // ISOLATE NEW YORK

capture drop own_str
capture decode ownership, gen(own_str)
capture gen own_str = ownership 
gen own_category = .
replace own_category = 1 if $cond_own_gov
replace own_category = 2 if $cond_own_nonprof
replace own_category = 3 if $cond_own_forprof
capture label values own_category own_lbl

foreach var in "h_hosp_rating_9_10" "h_hosp_rating_0_6" {
    local clean_title = strproper(subinstr("`var'", "_", " ", .))
    preserve
    collapse (mean) `var', by(year)
    twoway (connected `var' year, lcolor(navy)), title("NYS Overall: `clean_title'", size(medium)) graphregion(color(white))
    graph export "$outRoot/in_patient/time_series_nys/overall/nys_ts_overall_`var'.png", replace width(2000)
    restore
}

* 2B. Master Facility 
use "$dataRoot/master_facility_inpatient_2013_2023.dta", clear

capture drop state_str
capture decode state, gen(state_str)
capture gen state_str = state 
keep if state_str == "NY" // ISOLATE NEW YORK

capture drop own_str
capture decode ownership, gen(own_str)
capture gen own_str = ownership 

gen own_category = .
replace own_category = 1 if $cond_own_gov
replace own_category = 2 if $cond_own_nonprof
replace own_category = 3 if $cond_own_forprof
capture label values own_category own_lbl

* Generate the binary is_gov so the facility loop doesn't crash!
gen is_gov = 0
replace is_gov = 1 if $cond_own_gov

foreach var in $in_fac_means {
    if !inlist("`var'", "h_hosp_rating_9_10", "h_hosp_rating_0_6", "is_gov") {
        local clean_title = strproper(subinstr("`var'", "_", " ", .))
        preserve
        collapse (mean) `var', by(year)
        twoway (connected `var' year, lcolor(navy)), title("NYS Overall: `clean_title'", size(medium)) graphregion(color(white))
        graph export "$outRoot/in_patient/time_series_nys/overall/nys_ts_overall_`var'.png", replace width(2000)
        restore
        
        preserve
        collapse (mean) `var', by(year own_category)
        drop if missing(own_category)
        twoway (connected `var' year if own_category==1, lcolor(blue)) (connected `var' year if own_category==2, lcolor(emerald)) (connected `var' year if own_category==3, lcolor(purple)), title("NYS by Ownership: `clean_title'", size(medium)) legend(order(1 "Gov" 2 "Non-Profit" 3 "For-Profit") position(6) rows(1)) graphregion(color(white))
        graph export "$outRoot/in_patient/time_series_nys/by_ownership/nys_ts_own_`var'.png", replace width(2000)
        restore
    }
}
display "=== NYS TIME SERIES COMPLETE ==="
