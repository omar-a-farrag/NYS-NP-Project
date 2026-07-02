*===============================================================================
* SCRIPT: 06c_nys_provider_time_series.do
* PURPOSE: Time-Series Line Charts exclusively for NYS Providers.
* FEATURES: Strict Brace Parsing, Tempfiles only (No Preserve/Restore)
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

local script_name "06c_nys_provider_time_series"
log using "$logRoot/`script_name'.smcl", replace

display "=== STARTING NYS PROVIDER TIME SERIES ==="

local prov_vars "partd_generic_rate partd_opioid_rate partb_em_upcode_rate bene_avg_risk_scre tot_benes tot_sbmtd_chrg mips_final_score mips_quality_score mips_pi_score mips_ia_score mips_cost_score total_rvu total_services total_medicare_payment"

foreach setting in "in_patient" "out_patient" {
    display "--- NYS Time Series: `setting' Providers ---"
    
    * --- 1. DYNAMIC FOLDER CREATION ---
    local baseDir "$outRoot/summary_stats/`setting'/time_series_nys/provider_analysis"
    capture mkdir "$outRoot/summary_stats/`setting'/time_series_nys"
    capture mkdir "`baseDir'"
    
    foreach sub in "overall" "by_gender" "by_dept" "by_ownership" "by_grad_decade" {
        capture mkdir "`baseDir'/`sub'"
        capture mkdir "`baseDir'/`sub'/all_providers"
        capture mkdir "`baseDir'/`sub'/MD_DO"
        capture mkdir "`baseDir'/`sub'/NP"
        capture mkdir "`baseDir'/`sub'/PA"
        capture mkdir "`baseDir'/`sub'/Pre_1990"
        capture mkdir "`baseDir'/`sub'/Grads_1990s"
        capture mkdir "`baseDir'/`sub'/Grads_2000s"
        capture mkdir "`baseDir'/`sub'/Grads_2010s"
    }

    * --- 2. LOAD & MERGE DATA ---
    if "`setting'" == "in_patient" {
        use "$dataRoot/master_provider_inpatient_2013_2023.dta", clear
        capture confirm variable ccn
        if _rc == 0 {
            tempfile prov_temp fac_own
            save `prov_temp', replace
            
            use "$dataRoot/master_facility_inpatient_2013_2023.dta", clear
            capture keep ccn year ownership
            duplicates drop ccn year, force
            save `fac_own'
            
            use `prov_temp', clear
            merge m:1 ccn year using `fac_own', keep(master match) nogen
        }
    }
    else {
        use "$dataRoot/master_provider_outpatient_asc_2015_2023.dta", clear
    }

    * --- 3. NYS FILTER & TAXONOMIES ---
    capture drop state_str
    capture decode cms_state, gen(state_str)
    if _rc != 0 {
        capture confirm string variable cms_state
        if _rc == 0 {
            gen state_str = cms_state
        }
        else {
            gen state_str = string(cms_state)
        }
    }
    replace state_str = strtrim(strupper(state_str))
    keep if state_str == "NY" 

    capture drop cred_str
    capture decode credential, gen(cred_str)
    if _rc != 0 {
        capture gen cred_str = string(credential)
    }
    gen prov_type = 1 if inlist(cred_str, "MD", "DO")
    replace prov_type = 2 if cred_str == "NP"
    replace prov_type = 3 if cred_str == "PA"

    capture drop spec_str
    capture decode cms_specialty, gen(spec_str)
    if _rc != 0 {
        capture gen spec_str = string(cms_specialty)
    }
    gen dept_cat = 1 
    replace dept_cat = 2 if $cond_gen_med
    replace dept_cat = 3 if strpos(upper(spec_str), "FAMILY PRACTICE") > 0 | strpos(upper(spec_str), "GENERAL PRACTICE") > 0

    capture rename is_female raw_is_female
    gen is_female = "Unknown"
    capture confirm string variable nppes_provider_gender
    if _rc == 0 {
        replace is_female = "Female" if nppes_provider_gender == "F"
        replace is_female = "Male" if nppes_provider_gender == "M"
    }
    capture confirm string variable rndrng_prvdr_gndr
    if _rc == 0 {
        replace is_female = "Female" if rndrng_prvdr_gndr == "F"
        replace is_female = "Male" if rndrng_prvdr_gndr == "M"
    }
    capture confirm numeric variable raw_is_female
    if _rc == 0 {
        replace is_female = "Female" if raw_is_female == 1 & is_female == "Unknown"
        replace is_female = "Male" if raw_is_female == 0 & is_female == "Unknown"
    }
    capture confirm string variable raw_is_female
    if _rc == 0 {
        replace is_female = "Female" if inlist(raw_is_female, "F", "Female", "1") & is_female == "Unknown"
        replace is_female = "Male" if inlist(raw_is_female, "M", "Male", "0") & is_female == "Unknown"
    }
    gen female_num = 1 if is_female == "Female"
    replace female_num = 0 if is_female == "Male"

    capture drop grad_decade
    gen grad_decade = .
    capture confirm numeric variable grad_year
    if _rc == 0 {
        replace grad_decade = 1 if grad_year < 1990
        replace grad_decade = 2 if grad_year >= 1990 & grad_year < 2000
        replace grad_decade = 3 if grad_year >= 2000 & grad_year < 2010
        replace grad_decade = 4 if grad_year >= 2010 & !missing(grad_year)
    }

    capture drop own_str own_category
    gen own_category = .
    if "`setting'" == "in_patient" {
        capture decode ownership, gen(own_str)
        if _rc != 0 {
            capture confirm string variable ownership
            if _rc == 0 {
                gen own_str = ownership
            }
            else {
                capture gen own_str = string(ownership)
            }
        }
        replace own_category = 1 if $cond_own_gov
        replace own_category = 2 if $cond_own_forprof
        replace own_category = 3 if $cond_own_nonprof
    }

    tempfile prov_clean
    save `prov_clean', replace

    local plot_vars ""
    foreach v in `prov_vars' $prov_overlap_means {
        capture confirm variable `v'
        if _rc == 0 {
            local plot_vars "`plot_vars' `v'"
        }
    }
    local plot_vars : list uniq plot_vars

    * --- 4. VISUALIZATION LOOP ---
    foreach var in `plot_vars' {
        
        * [DICTIONARY]
        local clean_title = strproper(subinstr("`var'", "_", " ", .))
        local dir_note "Metric: `var'"

        if "`var'" == "partd_generic_rate" { 
            local clean_title "Generic Prescribing Rate" 
            local dir_note "Rate: Proportion of total Part D prescriptions filled with generic drugs." 
        }
        else if "`var'" == "partd_opioid_rate" { 
            local clean_title "Opioid Prescribing Rate" 
            local dir_note "Rate: Proportion of total Part D claims that are Schedule II/III opioids." 
        }
        else if "`var'" == "partb_em_upcode_rate" { 
            local clean_title "Provider E&M Upcode Rate" 
            local dir_note "Rate: Proportion of total E&M visits billed at the highest intensity (Level 4/5)." 
        }
        else if "`var'" == "bene_avg_risk_scre" { 
            local clean_title "Average Patient Risk Score (HCC)" 
            local dir_note "Score: HCC risk score. Higher implies a more complex panel." 
        }
        else if "`var'" == "tot_benes" { 
            local clean_title "Total Beneficiaries Treated" 
            local dir_note "Count: Total number of unique Medicare beneficiaries treated." 
        }
        else if "`var'" == "tot_sbmtd_chrg" { 
            local clean_title "Total Submitted Charges" 
            local dir_note "Financial: Total dollars billed to Medicare." 
        }
        else if "`var'" == "total_rvu" { 
            local clean_title "Total RVUs" 
            local dir_note "Score: Sum of clinical, practice expense, and malpractice RVUs." 
        }
        else if "`var'" == "total_services" { 
            local clean_title "Total Services Billed" 
            local dir_note "Count: Total count of distinct Medicare Part B services billed." 
        }
        else if "`var'" == "total_medicare_payment" { 
            local clean_title "Total Medicare Payment" 
            local dir_note "Financial: Total dollars paid by Medicare." 
        }
        else if "`var'" == "mips_final_score" { 
            local clean_title "MIPS Final Score" 
            local dir_note "Score: 0-100 composite payment adjustment score." 
        }
        else if "`var'" == "mips_quality_score" { 
            local clean_title "MIPS Quality Domain" 
            local dir_note "Score: 0-100 performance on evidence-based quality measures." 
        }
        else if "`var'" == "mips_pi_score" { 
            local clean_title "MIPS Promoting Interoperability" 
            local dir_note "Score: 0-100 performance on EHR integration." 
        }
        else if "`var'" == "mips_ia_score" { 
            local clean_title "MIPS Improvement Activities" 
            local dir_note "Score: 0-100 performance on practice improvements." 
        }
        else if "`var'" == "mips_cost_score" { 
            local clean_title "MIPS Cost Domain" 
            local dir_note "Score: 0-100 performance on total cost of care / resource use." 
        }

        local graph_margin "margin(l+2 r+2 b+15)"
        
        * ==========================================
        * A. OVERALL CHARTS
        * ==========================================
        use `prov_clean', clear
        capture drop if missing(`var')
        count
        if r(N) > 0 {
            collapse (mean) `var', by(year)
            if _N > 0 {
                twoway (connected `var' year, lcolor(navy) msymbol(O) lwidth(medthick)), ///
                    title("NYS (All Providers): `clean_title'", size(medium) color(black)) ///
                    ytitle("Mean Value") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                    note("`dir_note'", position(7) size(vsmall) margin(t=3 l=2) span) graphregion(color(white) `graph_margin')
                capture graph export "`baseDir'/overall/all_providers/ts_all_`var'.png", replace width(2000)
            }
        }

        use `prov_clean', clear
        capture drop if missing(`var') | missing(prov_type)
        count
        if r(N) > 0 {
            collapse (mean) `var', by(year prov_type)
            if _N > 0 {
                twoway (connected `var' year if prov_type==1, lcolor(navy) msymbol(O)) ///
                       (connected `var' year if prov_type==2, lcolor(maroon) msymbol(S)) ///
                       (connected `var' year if prov_type==3, lcolor(emerald) msymbol(D)), ///
                    title("NYS by Provider Type: `clean_title'", size(medium) color(black)) ///
                    ytitle("Mean Value") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                    legend(order(1 "MD/DO" 2 "NP" 3 "PA") position(6) rows(1)) ///
                    note("`dir_note'", position(7) size(vsmall) margin(t=3 l=2) span) graphregion(color(white) `graph_margin')
                capture graph export "`baseDir'/overall/ts_prov_split_`var'.png", replace width(2000)
            }
        }

        use `prov_clean', clear
        capture drop if missing(`var') | missing(grad_decade)
        count
        if r(N) > 0 {
            collapse (mean) `var', by(year grad_decade)
            if _N > 0 {
                twoway (connected `var' year if grad_decade==1, lcolor(navy) msymbol(O)) ///
                       (connected `var' year if grad_decade==2, lcolor(cranberry) msymbol(S)) ///
                       (connected `var' year if grad_decade==3, lcolor(emerald) msymbol(D)) ///
                       (connected `var' year if grad_decade==4, lcolor(orange) msymbol(T)), ///
                    title("NYS by Grad Decade: `clean_title'", size(medium) color(black)) ///
                    ytitle("Mean Value") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                    legend(order(1 "Pre-1990" 2 "1990s" 3 "2000s" 4 "2010s+") position(6) rows(1)) ///
                    note("`dir_note'", position(7) size(vsmall) margin(t=3 l=2) span) graphregion(color(white) `graph_margin')
                capture graph export "`baseDir'/overall/ts_grad_split_`var'.png", replace width(2000)
            }
        }

        * ==========================================
        * B. SUBGROUP CHARTS (Looping 0=All, 1=MD, 2=NP, 3=PA, 4=Pre90, 5=90s, 6=00s, 7=10s)
        * ==========================================
        forvalues p = 0/7 {
            
            if `p' == 0 { 
                local p_folder "all_providers" 
                local p_title "All Providers" 
            }
            else if `p' == 1 { 
                local p_folder "MD_DO" 
                local p_title "MD/DO" 
            }
            else if `p' == 2 { 
                local p_folder "NP" 
                local p_title "NP" 
            }
            else if `p' == 3 { 
                local p_folder "PA" 
                local p_title "PA" 
            }
            else if `p' == 4 { 
                local p_folder "Pre_1990" 
                local p_title "Pre-1990 Grads" 
            }
            else if `p' == 5 { 
                local p_folder "Grads_1990s" 
                local p_title "1990s Grads" 
            }
            else if `p' == 6 { 
                local p_folder "Grads_2000s" 
                local p_title "2000s Grads" 
            }
            else if `p' == 7 { 
                local p_folder "Grads_2010s" 
                local p_title "2010s+ Grads" 
            }

            * 1. Gender Subgroup
            use `prov_clean', clear
            
            if `p' >= 1 & `p' <= 3 { 
                keep if prov_type == `p' 
            }
            else if `p' == 4 { 
                keep if grad_decade == 1 
            }
            else if `p' == 5 { 
                keep if grad_decade == 2 
            }
            else if `p' == 6 { 
                keep if grad_decade == 3 
            }
            else if `p' == 7 { 
                keep if grad_decade == 4 
            }

            capture drop if missing(`var') | missing(female_num)
            count
            if r(N) > 0 {
                collapse (mean) `var', by(year female_num)
                if _N > 0 {
                    twoway (connected `var' year if female_num==0, lcolor(gs8) msymbol(O)) ///
                           (connected `var' year if female_num==1, lcolor(purple) msymbol(D)), ///
                        title("NYS `p_title': `clean_title' by Gender", size(medium) color(black)) ///
                        ytitle("Mean Value") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                        legend(order(1 "Male" 2 "Female") position(6) rows(1)) ///
                        note("`dir_note'", position(7) size(vsmall) margin(t=3 l=2) span) graphregion(color(white) `graph_margin')
                    capture graph export "`baseDir'/by_gender/`p_folder'/ts_gender_`var'.png", replace width(2000)
                }
            }

            * 2. Department Subgroup
            use `prov_clean', clear
            
            if `p' >= 1 & `p' <= 3 { 
                keep if prov_type == `p' 
            }
            else if `p' == 4 { 
                keep if grad_decade == 1 
            }
            else if `p' == 5 { 
                keep if grad_decade == 2 
            }
            else if `p' == 6 { 
                keep if grad_decade == 3 
            }
            else if `p' == 7 { 
                keep if grad_decade == 4 
            }

            capture drop if missing(`var') | missing(dept_cat)
            count
            if r(N) > 0 {
                collapse (mean) `var', by(year dept_cat)
                if _N > 0 {
                    twoway (connected `var' year if dept_cat==1, lcolor(gs10) msymbol(O) lpattern(dash)) ///
                           (connected `var' year if dept_cat==2, lcolor(navy) msymbol(S)) ///
                           (connected `var' year if dept_cat==3, lcolor(cranberry) msymbol(D)), ///
                        title("NYS `p_title': `clean_title' by Dept", size(medium) color(black)) ///
                        ytitle("Mean Value") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                        legend(order(1 "Specialty/Other" 2 "General Med" 3 "Primary Care") position(6) rows(1)) ///
                        note("`dir_note'", position(7) size(vsmall) margin(t=3 l=2) span) graphregion(color(white) `graph_margin')
                    capture graph export "`baseDir'/by_dept/`p_folder'/ts_dept_`var'.png", replace width(2000)
                }
            }

            * 3. Ownership Subgroup (INPATIENT ONLY)
            if "`setting'" == "in_patient" {
                use `prov_clean', clear
                
                if `p' >= 1 & `p' <= 3 { 
                    keep if prov_type == `p' 
                }
                else if `p' == 4 { 
                    keep if grad_decade == 1 
                }
                else if `p' == 5 { 
                    keep if grad_decade == 2 
                }
                else if `p' == 6 { 
                    keep if grad_decade == 3 
                }
                else if `p' == 7 { 
                    keep if grad_decade == 4 
                }

                capture drop if missing(`var') | missing(own_category)
                count
                if r(N) > 0 {
                    collapse (mean) `var', by(year own_category)
                    if _N > 0 {
                        twoway (connected `var' year if own_category==1, lcolor(navy) msymbol(O)) ///
                               (connected `var' year if own_category==2, lcolor(cranberry) msymbol(S)) ///
                               (connected `var' year if own_category==3, lcolor(emerald) msymbol(D)), ///
                            title("NYS `p_title': `clean_title' by Ownership", size(medium) color(black)) ///
                            ytitle("Mean Value") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                            legend(order(1 "Gov" 2 "For-Profit" 3 "Non-Profit") position(6) rows(1)) ///
                            note("`dir_note'", position(7) size(vsmall) margin(t=3 l=2) span) graphregion(color(white) `graph_margin')
                        capture graph export "`baseDir'/by_ownership/`p_folder'/ts_own_`var'.png", replace width(2000)
                    }
                }
            }
        }
    }
}
display "=== NYS PROVIDER TIME SERIES COMPLETE ==="
