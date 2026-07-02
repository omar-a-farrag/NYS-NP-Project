*===============================================================================
* SCRIPT: 06a_provider_time_series.do
* PURPOSE: Time-Series Line Charts for BOTH Inpatient & Outpatient Providers.
* FEATURES: Tempfile loops (Bulletproof against r(621)), Strict Brace Parsing
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* --- START LOG ---
local script_name "06a_provider_time_series"
log using "$logRoot/`script_name'.smcl", replace
* -----------------

local in_vars "partd_generic_rate partd_opioid_rate partb_em_upcode_rate mips_final_score mips_quality_score mips_pi_score mips_ia_score mips_cost_score bene_avg_risk_scre tot_benes tot_sbmtd_chrg"
local out_vars "mips_final_score mips_quality_score mips_pi_score mips_ia_score mips_cost_score tot_benes tot_sbmtd_chrg"

foreach setting in "in_patient" "out_patient" {
    display "=== STARTING TIME SERIES FOR: `setting' PROVIDERS ==="

    * --- 1. DYNAMIC FOLDER CREATION ---
    local baseDir "$outRoot/summary_stats/`setting'/time_series/provider_analysis"
    capture mkdir "$outRoot/summary_stats/`setting'/time_series"
    capture mkdir "`baseDir'"
    
    local subfolders "overall by_prov_type by_gender by_dept by_ownership by_authority by_grad_decade"
    foreach sub in `subfolders' {
        capture mkdir "`baseDir'/`sub'"
        if "`sub'" != "overall" & "`sub'" != "by_prov_type" & "`sub'" != "by_grad_decade" {
            capture mkdir "`baseDir'/`sub'/MD_DO"
            capture mkdir "`baseDir'/`sub'/NP"
            capture mkdir "`baseDir'/`sub'/PA"
            capture mkdir "`baseDir'/`sub'/Pre_1990"
            capture mkdir "`baseDir'/`sub'/Grads_1990s"
            capture mkdir "`baseDir'/`sub'/Grads_2000s"
            capture mkdir "`baseDir'/`sub'/Grads_2010s"
        }
    }

    * --- 2. LOAD & CLEAN BASE DATA ---
    if "`setting'" == "in_patient" {
        use "$dataRoot/master_provider_inpatient_2013_2023.dta", clear
        local loop_vars "`in_vars'"
    }
    else {
        use "$dataRoot/master_provider_outpatient_asc_2015_2023.dta", clear
        local loop_vars "`out_vars'"
    }

    capture confirm string variable cms_state
    if _rc != 0 {
        decode cms_state, gen(state_str)
    }
    else {
        gen state_str = cms_state
    }
    replace state_str = strtrim(strupper(state_str))

    gen np_authority = .
    replace np_authority = 3 if $cond_full_prac
    replace np_authority = 2 if $cond_red_prac
    replace np_authority = 1 if $cond_res_prac

    capture confirm string variable cms_specialty
    if _rc != 0 {
        decode cms_specialty, gen(spec_str)
    }
    else {
        gen spec_str = cms_specialty
    }

    gen prov_type = 1 
    replace prov_type = 2 if strpos(upper(spec_str), "NURSE PRACTITIONER") > 0
    replace prov_type = 3 if strpos(upper(spec_str), "PHYSICIAN ASSISTANT") > 0
    
    gen count_md = (prov_type == 1)
    gen count_np = (prov_type == 2)
    gen count_pa = (prov_type == 3)

    capture rename is_female raw_is_female
    gen is_female = .
    capture replace is_female = 1 if nppes_provider_gender == "F"
    capture replace is_female = 0 if nppes_provider_gender == "M"
    capture replace is_female = 1 if rndrng_prvdr_gndr == "F"
    capture replace is_female = 0 if rndrng_prvdr_gndr == "M"
    capture replace is_female = 1 if raw_is_female == 1
    capture replace is_female = 0 if raw_is_female == 0

    gen is_gen_med = (strpos(upper(spec_str), "INTERNAL MEDICINE") > 0)
    gen is_primary_care = (strpos(upper(spec_str), "FAMILY PRACTICE") > 0 | strpos(upper(spec_str), "GENERAL PRACTICE") > 0 | is_gen_med == 1)

    capture drop grad_decade
    gen grad_decade = .
    capture confirm numeric variable grad_year
    if _rc == 0 {
        replace grad_decade = 1 if grad_year < 1990
        replace grad_decade = 2 if grad_year >= 1990 & grad_year < 2000
        replace grad_decade = 3 if grad_year >= 2000 & grad_year < 2010
        replace grad_decade = 4 if grad_year >= 2010 & !missing(grad_year)
    }

    * F. Ownership Merge (Bulletproofed to avoid preserve/restore)
    if "`setting'" == "in_patient" {
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
            
            capture confirm string variable ownership
            if _rc != 0 {
                decode ownership, gen(own_str)
            }
            else {
                gen own_str = ownership
            }

            gen own_category = .
            replace own_category = 1 if $cond_own_gov
            replace own_category = 2 if $cond_own_forprof
            replace own_category = 3 if $cond_own_nonprof
        }
    }

    duplicates drop npi year, force

    * Save master cleaned panel to a tempfile for lightning-fast reloading
    tempfile master_clean
    save `master_clean', replace

    * --- 3. THE VISUALIZATION LOOP ---
    foreach var in `loop_vars' count_md count_np count_pa {
        
        if "`var'" == "count_md" {
            local clean_title "Active Workforce: MD/DOs"
            local y_title "Total Provider Headcount"
            local note_text "Count of active MD/DO providers billing in the year."
        }
        else if "`var'" == "count_np" {
            local clean_title "Active Workforce: Nurse Practitioners"
            local y_title "Total Provider Headcount"
            local note_text "Count of active NP providers billing in the year."
        }
        else if "`var'" == "count_pa" {
            local clean_title "Active Workforce: Physician Assistants"
            local y_title "Total Provider Headcount"
            local note_text "Count of active PA providers billing in the year."
        }
        else if "`var'" == "partd_generic_rate" { 
            local clean_title "Generic Prescribing Rate" 
            local y_title "Mean Rate"
            local note_text "Proportion of total Part D prescriptions filled with generic drugs."
        }
        else if "`var'" == "partd_opioid_rate" { 
            local clean_title "Opioid Prescribing Rate" 
            local y_title "Mean Rate"
            local note_text "Proportion of total Part D claims that are Schedule II/III opioids."
        }
        else if "`var'" == "partb_em_upcode_rate" { 
            local clean_title "E&M Upcode Rate" 
            local y_title "Mean Rate"
            local note_text "Proportion of total E&M visits billed at the highest intensity (Level 4/5)."
        }
        else if "`var'" == "mips_final_score" { 
            local clean_title "MIPS Final Score" 
            local y_title "Mean Score (0-100)"
            local note_text "0-100 composite payment adjustment score. Higher reflects better clinical value."
        }
        else if "`var'" == "mips_quality_score" { 
            local clean_title "MIPS Quality Domain" 
            local y_title "Mean Score (0-100)"
            local note_text "0-100 performance on evidence-based quality measures."
        }
        else if "`var'" == "mips_pi_score" { 
            local clean_title "MIPS Promoting Interoperability" 
            local y_title "Mean Score (0-100)"
            local note_text "0-100 performance on EHR integration and patient data access."
        }
        else if "`var'" == "mips_ia_score" { 
            local clean_title "MIPS Improvement Activities" 
            local y_title "Mean Score (0-100)"
            local note_text "0-100 performance on practice improvements like care coordination."
        }
        else if "`var'" == "mips_cost_score" { 
            local clean_title "MIPS Cost Domain" 
            local y_title "Mean Score (0-100)"
            local note_text "0-100 performance on total cost of care / resource use."
        }
        else if "`var'" == "bene_avg_risk_scre" {
            local clean_title "Average Patient Risk Score (HCC)"
            local y_title "Mean HCC Risk Score"
            local note_text "Hierarchical Condition Category (HCC) risk score. Higher implies a more complex panel."
        }
        else if "`var'" == "tot_benes" {
            local clean_title "Total Beneficiaries Treated"
            local y_title "Mean Beneficiaries"
            local note_text "Total number of unique Medicare beneficiaries treated by the provider."
        }
        else if "`var'" == "tot_sbmtd_chrg" {
            local clean_title "Total Submitted Charges"
            local y_title "Mean Charges ($)"
            local note_text "Total dollars billed to Medicare by the provider."
        }
        else {
            local clean_title = strproper(subinstr("`var'", "_", " ", .))
            local y_title "Mean Value"
            local note_text "Variable overview."
        }
        
        local stat_type "mean"
        if strpos("`var'", "count_") > 0 {
            local stat_type "sum"
        }

        * ---------------------------------------------------------
        * CHART 1: OVERALL TREND
        * ---------------------------------------------------------
        use `master_clean', clear
        capture drop if missing(`var')
        count
        if r(N) > 0 {
            collapse (`stat_type') `var', by(year)
            if _N > 0 {
                twoway (connected `var' year, lcolor(navy) lwidth(medthick) msymbol(O)), ///
                    title("National Trend: `clean_title'", size(medium) color(black)) ///
                    ytitle("`y_title'") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                    note("`note_text'", size(vsmall)) graphregion(color(white) margin(small))
                capture graph export "`baseDir'/overall/ts_overall_`var'.png", replace width(2000)
            }
        }

        * ---------------------------------------------------------
        * CHART 2: BY PROVIDER TYPE
        * ---------------------------------------------------------
        if strpos("`var'", "count_") == 0 { 
            use `master_clean', clear
            capture drop if missing(`var') | missing(prov_type)
            count
            if r(N) > 0 {
                collapse (`stat_type') `var', by(year prov_type)
                if _N > 0 {
                    twoway (connected `var' year if prov_type==1, lcolor(navy) msymbol(O)) ///
                           (connected `var' year if prov_type==2, lcolor(emerald) msymbol(D)) ///
                           (connected `var' year if prov_type==3, lcolor(cranberry) msymbol(S)), ///
                        title("By Provider Type: `clean_title'", size(medium) color(black)) ///
                        ytitle("`y_title'") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                        legend(order(1 "MD/DO" 2 "NP" 3 "PA") position(6) rows(1)) ///
                        note("`note_text'", size(vsmall)) graphregion(color(white) margin(small))
                    capture graph export "`baseDir'/by_prov_type/ts_provtype_`var'.png", replace width(2000)
                }
            }
        }

        * ---------------------------------------------------------
        * CHART 3: BY GENDER (Nested Loop)
        * ---------------------------------------------------------
        forvalues p = 0/7 {
            
            if `p' == 0 { 
                local t_pref "Overall" 
                local out_p "`baseDir'/by_gender/ts_gender_`var'.png" 
            }
            else if `p' == 1 { 
                local t_pref "MD/DO" 
                local out_p "`baseDir'/by_gender/MD_DO/ts_MD_DO_gender_`var'.png" 
            }
            else if `p' == 2 { 
                local t_pref "NP" 
                local out_p "`baseDir'/by_gender/NP/ts_NP_gender_`var'.png" 
            }
            else if `p' == 3 { 
                local t_pref "PA" 
                local out_p "`baseDir'/by_gender/PA/ts_PA_gender_`var'.png" 
            }
            else if `p' == 4 { 
                local t_pref "Pre-1990" 
                local out_p "`baseDir'/by_gender/Pre_1990/ts_Pre1990_gender_`var'.png" 
            }
            else if `p' == 5 { 
                local t_pref "1990s" 
                local out_p "`baseDir'/by_gender/Grads_1990s/ts_1990s_gender_`var'.png" 
            }
            else if `p' == 6 { 
                local t_pref "2000s" 
                local out_p "`baseDir'/by_gender/Grads_2000s/ts_2000s_gender_`var'.png" 
            }
            else if `p' == 7 { 
                local t_pref "2010s+" 
                local out_p "`baseDir'/by_gender/Grads_2010s/ts_2010s_gender_`var'.png" 
            }
            
            if `p' > 0 & strpos("`var'", "count_") > 0 { 
                continue 
            }

            use `master_clean', clear
            capture drop if missing(`var') | missing(is_female)

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

            count
            if r(N) > 0 {
                collapse (`stat_type') `var', by(year is_female)
                if _N > 0 {
                    twoway (connected `var' year if is_female==0, lcolor(navy) msymbol(O)) ///
                           (connected `var' year if is_female==1, lcolor(purple) msymbol(D)), ///
                        title("`t_pref' By Gender: `clean_title'", size(medium) color(black)) ///
                        ytitle("`y_title'") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                        legend(order(1 "Male" 2 "Female") position(6) rows(1)) ///
                        note("`note_text'", size(vsmall)) graphregion(color(white) margin(small))
                    capture graph export "`out_p'", replace width(2000)
                }
            }
        }

        * ---------------------------------------------------------
        * CHART 4: BY DEPARTMENT (Nested Loop)
        * ---------------------------------------------------------
        forvalues p = 0/7 {
            
            if `p' == 0 { 
                local t_pref "Overall" 
                local out_p "`baseDir'/by_dept/ts_dept_`var'.png" 
            }
            else if `p' == 1 { 
                local t_pref "MD/DO" 
                local out_p "`baseDir'/by_dept/MD_DO/ts_MD_DO_dept_`var'.png" 
            }
            else if `p' == 2 { 
                local t_pref "NP" 
                local out_p "`baseDir'/by_dept/NP/ts_NP_dept_`var'.png" 
            }
            else if `p' == 3 { 
                local t_pref "PA" 
                local out_p "`baseDir'/by_dept/PA/ts_PA_dept_`var'.png" 
            }
            else if `p' == 4 { 
                local t_pref "Pre-1990" 
                local out_p "`baseDir'/by_dept/Pre_1990/ts_Pre1990_dept_`var'.png" 
            }
            else if `p' == 5 { 
                local t_pref "1990s" 
                local out_p "`baseDir'/by_dept/Grads_1990s/ts_1990s_dept_`var'.png" 
            }
            else if `p' == 6 { 
                local t_pref "2000s" 
                local out_p "`baseDir'/by_dept/Grads_2000s/ts_2000s_dept_`var'.png" 
            }
            else if `p' == 7 { 
                local t_pref "2010s+" 
                local out_p "`baseDir'/by_dept/Grads_2010s/ts_2010s_dept_`var'.png" 
            }
            
            if `p' > 0 & strpos("`var'", "count_") > 0 { 
                continue 
            }

            use `master_clean', clear
            capture drop if missing(`var') | missing(is_primary_care)

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

            count
            if r(N) > 0 {
                collapse (`stat_type') `var', by(year is_primary_care)
                if _N > 0 {
                    twoway (connected `var' year if is_primary_care==0, lcolor(gs8) lpattern(dash) msymbol(Oh)) ///
                           (connected `var' year if is_primary_care==1, lcolor(navy) msymbol(D)), ///
                        title("`t_pref' By Dept: `clean_title'", size(medium) color(black)) ///
                        ytitle("`y_title'") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                        legend(order(1 "Specialty/Other" 2 "Primary Care") position(6) rows(1)) ///
                        note("`note_text'", size(vsmall)) graphregion(color(white) margin(small))
                    capture graph export "`out_p'", replace width(2000)
                }
            }
        }

        * ---------------------------------------------------------
        * CHART 5: BY GRADUATION DECADE (Overall View)
        * ---------------------------------------------------------
        if strpos("`var'", "count_") == 0 { 
            use `master_clean', clear
            capture drop if missing(`var') | missing(grad_decade)
            count
            if r(N) > 0 {
                collapse (`stat_type') `var', by(year grad_decade)
                if _N > 0 {
                    twoway (connected `var' year if grad_decade==1, lcolor(navy) msymbol(O)) ///
                           (connected `var' year if grad_decade==2, lcolor(cranberry) msymbol(S)) ///
                           (connected `var' year if grad_decade==3, lcolor(emerald) msymbol(D)) ///
                           (connected `var' year if grad_decade==4, lcolor(orange) msymbol(T)), ///
                        title("Overall By Grad Decade: `clean_title'", size(medium) color(black)) ///
                        ytitle("`y_title'") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                        legend(order(1 "Pre-1990" 2 "1990s" 3 "2000s" 4 "2010s+") position(6) rows(1)) ///
                        note("`note_text'", size(vsmall)) graphregion(color(white) margin(small))
                    capture graph export "`baseDir'/by_grad_decade/ts_grad_overall_`var'.png", replace width(2000)
                }
            }
        }

        * ---------------------------------------------------------
        * CHART 6: BY OWNERSHIP (Inpatient Only)
        * ---------------------------------------------------------
        if "`setting'" == "in_patient" {
            capture confirm variable own_category
            if _rc == 0 {
                
                forvalues p = 0/7 {
                    
                    if `p' == 0 { 
                        local t_pref "Overall" 
                        local out_p "`baseDir'/by_ownership/ts_own_`var'.png" 
                    }
                    else if `p' == 1 { 
                        local t_pref "MD/DO" 
                        local out_p "`baseDir'/by_ownership/MD_DO/ts_MD_DO_own_`var'.png" 
                    }
                    else if `p' == 2 { 
                        local t_pref "NP" 
                        local out_p "`baseDir'/by_ownership/NP/ts_NP_own_`var'.png" 
                    }
                    else if `p' == 3 { 
                        local t_pref "PA" 
                        local out_p "`baseDir'/by_ownership/PA/ts_PA_own_`var'.png" 
                    }
                    else if `p' == 4 { 
                        local t_pref "Pre-1990" 
                        local out_p "`baseDir'/by_ownership/Pre_1990/ts_Pre1990_own_`var'.png" 
                    }
                    else if `p' == 5 { 
                        local t_pref "1990s" 
                        local out_p "`baseDir'/by_ownership/Grads_1990s/ts_1990s_own_`var'.png" 
                    }
                    else if `p' == 6 { 
                        local t_pref "2000s" 
                        local out_p "`baseDir'/by_ownership/Grads_2000s/ts_2000s_own_`var'.png" 
                    }
                    else if `p' == 7 { 
                        local t_pref "2010s+" 
                        local out_p "`baseDir'/by_ownership/Grads_2010s/ts_2010s_own_`var'.png" 
                    }
                    
                    if `p' > 0 & strpos("`var'", "count_") > 0 { 
                        continue 
                    }

                    use `master_clean', clear
                    capture drop if missing(`var') | missing(own_category)

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

                    count
                    if r(N) > 0 {
                        collapse (`stat_type') `var', by(year own_category)
                        if _N > 0 {
                            twoway (connected `var' year if own_category==1, lcolor(navy) msymbol(O)) ///
                                   (connected `var' year if own_category==2, lcolor(cranberry) msymbol(S)) ///
                                   (connected `var' year if own_category==3, lcolor(emerald) msymbol(D)), ///
                                title("`t_pref' By Ownership: `clean_title'", size(medium) color(black)) ///
                                ytitle("`y_title'") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                                legend(order(1 "Gov" 2 "For-Profit" 3 "Non-Profit") position(6) rows(1)) ///
                                note("`note_text'", size(vsmall)) graphregion(color(white) margin(small))
                            capture graph export "`out_p'", replace width(2000)
                        }
                    }
                }
            }
        }

        * ---------------------------------------------------------
        * CHART 7: BY STATE AUTHORITY (Nested Loop)
        * ---------------------------------------------------------
        forvalues p = 0/7 {
            
            if `p' == 0 { 
                local t_pref "Overall" 
                local out_p "`baseDir'/by_authority/ts_auth_`var'.png" 
            }
            else if `p' == 1 { 
                local t_pref "MD/DO" 
                local out_p "`baseDir'/by_authority/MD_DO/ts_MD_DO_auth_`var'.png" 
            }
            else if `p' == 2 { 
                local t_pref "NP" 
                local out_p "`baseDir'/by_authority/NP/ts_NP_auth_`var'.png" 
            }
            else if `p' == 3 { 
                local t_pref "PA" 
                local out_p "`baseDir'/by_authority/PA/ts_PA_auth_`var'.png" 
            }
            else if `p' == 4 { 
                local t_pref "Pre-1990" 
                local out_p "`baseDir'/by_authority/Pre_1990/ts_Pre1990_auth_`var'.png" 
            }
            else if `p' == 5 { 
                local t_pref "1990s" 
                local out_p "`baseDir'/by_authority/Grads_1990s/ts_1990s_auth_`var'.png" 
            }
            else if `p' == 6 { 
                local t_pref "2000s" 
                local out_p "`baseDir'/by_authority/Grads_2000s/ts_2000s_auth_`var'.png" 
            }
            else if `p' == 7 { 
                local t_pref "2010s+" 
                local out_p "`baseDir'/by_authority/Grads_2010s/ts_2010s_auth_`var'.png" 
            }
            
            if `p' > 0 & strpos("`var'", "count_") > 0 { 
                continue 
            }

            use `master_clean', clear
            capture drop if missing(`var') | missing(np_authority)

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

            count
            if r(N) > 0 {
                collapse (`stat_type') `var', by(year np_authority)
                if _N > 0 {
                    twoway (connected `var' year if np_authority==1, lcolor(cranberry) msymbol(O)) ///
                           (connected `var' year if np_authority==2, lcolor(orange) msymbol(S)) ///
                           (connected `var' year if np_authority==3, lcolor(emerald) msymbol(D)), ///
                        title("`t_pref' By NP Law: `clean_title'", size(medium) color(black)) ///
                        ytitle("`y_title'") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                        legend(order(1 "Restricted" 2 "Reduced" 3 "Full Practice") position(6) rows(1)) ///
                        note("`note_text'", size(vsmall)) graphregion(color(white) margin(small))
                    capture graph export "`out_p'", replace width(2000)
                }
            }
        }
    }
}
display "=== PROVIDER TIME SERIES COMPLETE ==="
