*===============================================================================
* SCRIPT: 07b_nys_3d_heatmaps.do
* PURPOSE: 3D Heatmaps (Year x Prov Type x Ownership) exclusively for NYS.
*===============================================================================
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

capture mkdir "$outRoot/in_patient/advanced_heatmaps_nys"
capture mkdir "$outRoot/in_patient/advanced_heatmaps_nys/all_departments"
capture mkdir "$outRoot/in_patient/advanced_heatmaps_nys/general_medicine"

display "--- Loading Provider Data ---"
use "$dataRoot/master_provider_inpatient_2013_2023.dta", clear

capture decode cms_state, gen(state_str)
if _rc {
    gen state_str = cms_state
}
keep if state_str == "NY" // ISOLATE NEW YORK

* Demographics & Subgroups
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

local plot_vars ""
foreach v in $prov_overlap_means {
    capture confirm variable `v'
    if !_rc {
        local plot_vars "`plot_vars' `v'"
    }
}

* Loop 0 = All Depts, 1 = Gen Med
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
    
    foreach var in `plot_vars' {
        local clean_title = strproper(subinstr("`var'", "_", " ", .))
        local orig_lbl : variable label `var'
        label variable `var' "Value"

        * Faceted by Ownership. X-axis is YEAR, Y-axis is PROVIDER TYPE
        heatplot `var' i.prov_type i.year `condition', ///
            by(own_category, title("NYS: `clean_title'", size(medium)) subtitle("`spec_title'", size(small))) ///
            statistic(mean) color(Reds) values(format(%9.2f) size(vsmall)) ramp(right) ///
            ylabel(, angle(0) labsize(small)) xlabel(, angle(45) labsize(small)) graphregion(color(white)) 
            
        graph export "$outRoot/in_patient/advanced_heatmaps_nys/`folder'/nys_3D_heatmap_`var'.png", replace width(2800)
        label variable `var' "`orig_lbl'"
    }
}
display "=== NYS ADVANCED HEATMAPS COMPLETE ==="
