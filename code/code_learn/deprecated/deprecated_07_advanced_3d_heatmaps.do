*===============================================================================
* SCRIPT: 07_advanced_3d_heatmaps.do
* PURPOSE: 3D Heatmaps (Authority x Prov Type x Ownership) by Specialty.
*===============================================================================
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* --- 1. FOLDER CREATION ---
capture mkdir "$outRoot/in_patient/advanced_heatmaps"
capture mkdir "$outRoot/in_patient/advanced_heatmaps/all_departments"
capture mkdir "$outRoot/in_patient/advanced_heatmaps/general_medicine"

display "--- Loading Provider Data ---"
use "$dataRoot/master_provider_inpatient_2013_2023.dta", clear

* --- 2. APPLY CENTRALIZED MACROS ---
capture decode cms_state, gen(state_str)
if _rc {
    gen state_str = cms_state
}
gen np_authority = .
replace np_authority = 3 if $cond_full_prac
replace np_authority = 2 if $cond_red_prac
replace np_authority = 1 if $cond_res_prac
label define auth_lbl 1 "Restricted" 2 "Reduced" 3 "Full"
label values np_authority auth_lbl

decode credential, gen(cred_str)
gen prov_type = 1 if inlist(cred_str, "MD", "DO")
replace prov_type = 2 if cred_str == "NP"
replace prov_type = 3 if cred_str == "PA"
label define pt_lbl 1 "MD" 2 "NP" 3 "PA"
label values prov_type pt_lbl

capture decode ownership, gen(own_str)
if _rc {
    capture gen own_str = ownership
}
gen own_category = .
replace own_category = 1 if $cond_own_gov
replace own_category = 2 if $cond_own_nonprof
replace own_category = 3 if $cond_own_forprof
label define own_lbl 1 "Government" 2 "Non-Profit" 3 "For-Profit"
label values own_category own_lbl

decode cms_specialty, gen(spec_str)
gen is_gen_med = 0
replace is_gen_med = 1 if $cond_gen_med

* Dynamic Variable Checker
local target_vars "$prov_overlap_means"
local plot_vars ""
foreach v in `target_vars' {
    capture confirm variable `v'
    if !_rc {
        local plot_vars "`plot_vars' `v'"
    }
}

*===============================================================================
* PHASE 3: THE 3D HEATMAP & SPECIALTY LOOP
*===============================================================================
* Loop 0 = All Departments, Loop 1 = Gen Med Only
forvalues spec_filter = 0/1 {
    
    if `spec_filter' == 0 {
        local spec_title "All Departments"
        local folder "all_departments"
        local condition ""
    }
    else {
        local spec_title "General Medicine Only"
        local folder "general_medicine"
        local condition "if is_gen_med == 1"
    }
    
    display "--- Processing: `spec_title' ---"
    
    foreach var in `plot_vars' {
        local clean_title = strproper(subinstr("`var'", "_", " ", .))
        
        * Temporarily relabel to fix the legend title
        local orig_lbl : variable label `var'
        label variable `var' "Value"

        * 3D Faceted Heatplot!
        * Authority on X, Prov Type on Y, faceted by() Ownership
        heatplot `var' i.prov_type i.np_authority `condition', ///
            by(own_category, title("`clean_title'", size(medium)) subtitle("`spec_title'", size(small)) note("Data: CMS Inpatient Providers (2013-2023)", size(vsmall))) ///
            statistic(mean) ///
            color(Reds) ///
            values(format(%9.2f) size(vsmall)) ///
            ramp(right) ///
            ylabel(, angle(0) labsize(small)) xlabel(, angle(0) labsize(small)) ///
            graphregion(color(white)) 
            
        graph export "$outRoot/in_patient/advanced_heatmaps/`folder'/3D_heatmap_`var'.png", replace width(2800)

        label variable `var' "`orig_lbl'"
    }
}

display "=== ADVANCED 3D HEATMAPS COMPLETE ==="