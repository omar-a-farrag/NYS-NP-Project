*===============================================================================
* SCRIPT: 06a_provider_time_series.do
* PURPOSE: Time-Series Line Charts for BOTH Inpatient & Outpatient Providers.
*===============================================================================
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

foreach setting in "in_patient" "out_patient" {
    display "=== STARTING TIME SERIES FOR: `setting' ==="

    * --- 1. DYNAMIC FOLDER CREATION ---
    local subfolders "overall by_authority by_prov_type by_gender by_dept by_ownership by_authority_np_only"
    capture mkdir "$outRoot/`setting'/time_series"
    foreach sub in `subfolders' {
        capture mkdir "$outRoot/`setting'/time_series/`sub'"
    }

    * --- 2. LOAD DATA ---
    if "`setting'" == "in_patient" {
        use "$dataRoot/master_provider_inpatient_2013_2023.dta", clear
    }
    else {
        use "$dataRoot/master_provider_outpatient_asc_2015_2023.dta", clear
    }

    * --- 3. APPLY CENTRALIZED TAXONOMY LOGIC ---
    
    * A. State Authority 
    capture drop state_str
    capture decode cms_state, gen(state_str)
    if _rc {
        gen state_str = cms_state // Fallback if already string
    }
    gen np_authority = .
    replace np_authority = 3 if $cond_full_prac
    replace np_authority = 2 if $cond_red_prac
    replace np_authority = 1 if $cond_res_prac
    label define auth_lbl 1 "Restricted" 2 "Reduced" 3 "Full Practice"
    label values np_authority auth_lbl

    * B. Provider Type & Gender
    decode credential, gen(cred_str)
    gen prov_type = 1 if inlist(cred_str, "MD", "DO")
    replace prov_type = 2 if cred_str == "NP"
    replace prov_type = 3 if cred_str == "PA"
    label define pt_lbl 1 "MD/DO" 2 "NP" 3 "PA"
    label values prov_type pt_lbl

    * C. Department (Gen Med vs Other)
    decode cms_specialty, gen(spec_str)
    gen is_gen_med = 0
    replace is_gen_med = 1 if $cond_gen_med

    * D. Hospital Ownership (Because Provider data merged with Facility data)
    capture decode ownership, gen(own_str)
    if _rc {
        capture gen own_str = ownership
    }
    gen own_category = .
    * Only apply if ownership successfully merged into this dataset
    capture confirm variable own_str
    if !_rc {
        replace own_category = 1 if $cond_own_gov
        replace own_category = 2 if $cond_own_nonprof
        replace own_category = 3 if $cond_own_forprof
        label define own_lbl 1 "Government" 2 "Non-Profit" 3 "For-Profit"
        label values own_category own_lbl
    }

    * E. Dynamic Variable Checker (Prevents crashes)
    local target_vars "$prov_overlap_means"
    local plot_vars ""
    foreach v in `target_vars' {
        capture confirm variable `v'
        if !_rc {
            local plot_vars "`plot_vars' `v'"
        }
    }

    * --- 4. COLLAPSE TO TEMP FILES ---
    tempfile ts_overall ts_auth ts_prov ts_gender ts_dept ts_own ts_auth_np
    
    preserve
    collapse (mean) `plot_vars', by(year)
    save `ts_overall', replace
    restore

    preserve
    collapse (mean) `plot_vars', by(year np_authority)
    drop if missing(np_authority)
    save `ts_auth', replace
    restore

    preserve
    collapse (mean) `plot_vars', by(year prov_type)
    drop if missing(prov_type)
    save `ts_prov', replace
    restore

    preserve
    collapse (mean) `plot_vars', by(year is_female)
    drop if missing(is_female)
    save `ts_gender', replace
    restore

    preserve
    collapse (mean) `plot_vars', by(year is_gen_med)
    save `ts_dept', replace
    restore

    * NP-ONLY by Authority (New Request!)
    preserve
    keep if prov_type == 2 // Filter only Nurse Practitioners
    collapse (mean) `plot_vars', by(year np_authority)
    drop if missing(np_authority)
    save `ts_auth_np', replace
    restore

    * Ownership (Only process if variable exists)
    capture confirm variable own_category
    if !_rc {
        preserve
        collapse (mean) `plot_vars', by(year own_category)
        drop if missing(own_category)
        save `ts_own', replace
        restore
    }

    * --- 5. GRAPHING LOOP ---
    foreach var in `plot_vars' {
        local clean_title = strproper(subinstr("`var'", "_", " ", .))
        
        * Overall
        use `ts_overall', clear
        twoway (connected `var' year, lcolor(navy)), ///
            title("Overall: `clean_title'", size(medium)) ytitle("Mean") xtitle("Year") graphregion(color(white))
        graph export "$outRoot/`setting'/time_series/overall/ts_overall_`var'.png", replace width(2000)

        * By Authority
        use `ts_auth', clear
        twoway (connected `var' year if np_authority==1, lcolor(red)) ///
               (connected `var' year if np_authority==2, lcolor(orange)) ///
               (connected `var' year if np_authority==3, lcolor(green)), ///
            title("By Law: `clean_title'", size(medium)) legend(order(1 "Restricted" 2 "Reduced" 3 "Full")) graphregion(color(white))
        graph export "$outRoot/`setting'/time_series/by_authority/ts_auth_`var'.png", replace width(2000)

        * NP-ONLY By Authority
        use `ts_auth_np', clear
        twoway (connected `var' year if np_authority==1, lcolor(red)) ///
               (connected `var' year if np_authority==2, lcolor(orange)) ///
               (connected `var' year if np_authority==3, lcolor(green)), ///
            title("NP-Only by Law: `clean_title'", size(medium)) legend(order(1 "Restricted" 2 "Reduced" 3 "Full")) graphregion(color(white))
        graph export "$outRoot/`setting'/time_series/by_authority_np_only/ts_auth_np_`var'.png", replace width(2000)

        * By Provider
        use `ts_prov', clear
        twoway (connected `var' year if prov_type==1, lcolor(navy)) ///
               (connected `var' year if prov_type==2, lcolor(maroon)) ///
               (connected `var' year if prov_type==3, lcolor(forest_green)), ///
            title("By Provider: `clean_title'", size(medium)) legend(order(1 "MD" 2 "NP" 3 "PA")) graphregion(color(white))
        graph export "$outRoot/`setting'/time_series/by_prov_type/ts_prov_`var'.png", replace width(2000)

        * By Gender
        use `ts_gender', clear
        twoway (connected `var' year if is_female==0, lcolor(gs8)) ///
               (connected `var' year if is_female==1, lcolor(purple)), ///
            title("By Gender: `clean_title'", size(medium)) legend(order(1 "Male" 2 "Female")) graphregion(color(white))
        graph export "$outRoot/`setting'/time_series/by_gender/ts_gender_`var'.png", replace width(2000)

        * By Dept
        use `ts_dept', clear
        twoway (connected `var' year if is_gen_med==0, lcolor(gs10) lpattern(dash)) ///
               (connected `var' year if is_gen_med==1, lcolor(blue)), ///
            title("By Dept: `clean_title'", size(medium)) legend(order(1 "Other" 2 "Gen Med")) graphregion(color(white))
        graph export "$outRoot/`setting'/time_series/by_dept/ts_dept_`var'.png", replace width(2000)

        * By Ownership
        capture confirm variable own_category
        if !_rc {
            use `ts_own', clear
            capture count
            if r(N) > 0 {
                twoway (connected `var' year if own_category==1, lcolor(blue)) ///
                       (connected `var' year if own_category==2, lcolor(emerald)) ///
                       (connected `var' year if own_category==3, lcolor(purple)), ///
                    title("By Ownership: `clean_title'", size(medium)) legend(order(1 "Gov" 2 "Non-Profit" 3 "For-Profit")) graphregion(color(white))
                graph export "$outRoot/`setting'/time_series/by_ownership/ts_own_`var'.png", replace width(2000)
            }
        }
    }
}
display "=== PROVIDER TIME SERIES COMPLETE ==="
