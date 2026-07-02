*===============================================================================
* SCRIPT: 06a_provider_time_series.do
* PURPOSE: Time-Series Line Charts for BOTH Inpatient & Outpatient Providers.
* FEATURES: MIPS, Primary Care, Headcounts, Explicit Axes, Nested Subgroups
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"


* --- START LOG ---
local script_name "06a_provider_time_series"
log using "$logRoot/`script_name'.smcl", replace
* -----------------

* Define the variables we want to track over time
local in_vars "partd_generic_rate partd_opioid_rate partb_em_upcode_rate mips_final_score mips_quality_score mips_pi_score mips_ia_score mips_cost_score bene_avg_risk_scre tot_benes tot_sbmtd_chrg"
local out_vars "mips_final_score mips_quality_score mips_pi_score mips_ia_score mips_cost_score tot_benes tot_sbmtd_chrg"

foreach setting in "in_patient" "out_patient" {
    display "=== STARTING TIME SERIES FOR: `setting' PROVIDERS ==="

    * --- 1. DYNAMIC FOLDER CREATION (Nested Subgroups) ---
    local subfolders "overall by_prov_type by_gender by_dept by_ownership by_authority"
    capture mkdir "$outRoot/summary_stats/`setting'/time_series"
    capture mkdir "$outRoot/summary_stats/`setting'/time_series/provider_analysis"
    
    foreach sub in `subfolders' {
        capture mkdir "$outRoot/summary_stats/`setting'/time_series/provider_analysis/`sub'"
        * Create nested provider folders for stratifications
        if "`sub'" != "overall" & "`sub'" != "by_prov_type" {
            capture mkdir "$outRoot/summary_stats/`setting'/time_series/provider_analysis/`sub'/MD_DO"
            capture mkdir "$outRoot/summary_stats/`setting'/time_series/provider_analysis/`sub'/NP"
            capture mkdir "$outRoot/summary_stats/`setting'/time_series/provider_analysis/`sub'/PA"
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

    * A. State Authority 
    capture confirm string variable cms_state
    if _rc != 0 decode cms_state, gen(state_str)
    else gen state_str = cms_state
    replace state_str = strtrim(strupper(state_str))

    gen np_authority = .
    replace np_authority = 3 if $cond_full_prac
    replace np_authority = 2 if $cond_red_prac
    replace np_authority = 1 if $cond_res_prac

    * B. Provider Type & Headcounts
    capture confirm string variable cms_specialty
    if _rc != 0 decode cms_specialty, gen(spec_str)
    else gen spec_str = cms_specialty

    gen prov_type = 1 
    replace prov_type = 2 if strpos(upper(spec_str), "NURSE PRACTITIONER") > 0
    replace prov_type = 3 if strpos(upper(spec_str), "PHYSICIAN ASSISTANT") > 0
    
    gen count_md = (prov_type == 1)
    gen count_np = (prov_type == 2)
    gen count_pa = (prov_type == 3)

    * C. Gender
    capture rename is_female raw_is_female
    gen is_female = .
    capture replace is_female = 1 if nppes_provider_gender == "F"
    capture replace is_female = 0 if nppes_provider_gender == "M"
    capture replace is_female = 1 if rndrng_prvdr_gndr == "F"
    capture replace is_female = 0 if rndrng_prvdr_gndr == "M"
    capture replace is_female = 1 if raw_is_female == 1
    capture replace is_female = 0 if raw_is_female == 0

    * D. Department Logic (Gen Med & Primary Care)
    gen is_gen_med = (strpos(upper(spec_str), "INTERNAL MEDICINE") > 0)
    gen is_primary_care = (strpos(upper(spec_str), "FAMILY PRACTICE") > 0 | strpos(upper(spec_str), "GENERAL PRACTICE") > 0 | is_gen_med == 1)

    * E. Ownership (Inpatient Only)
    if "`setting'" == "in_patient" {
        capture confirm variable ccn
        if _rc == 0 {
            preserve
            use "$dataRoot/master_facility_inpatient_2013_2023.dta", clear
            capture keep ccn year ownership
            duplicates drop ccn year, force
            tempfile fac_own
            save `fac_own'
            restore
            merge m:1 ccn year using `fac_own', keep(master match) nogen
            
            capture confirm string variable ownership
            if _rc != 0 decode ownership, gen(own_str)
            else gen own_str = ownership

            gen own_category = .
            replace own_category = 1 if $cond_own_gov
            replace own_category = 2 if $cond_own_forprof
            replace own_category = 3 if $cond_own_nonprof
        }
    }

    * Micro Data Rule: Isolate pure provider behavior
    duplicates drop npi year, force

    * Save master cleaned panel to a tempfile for lightning-fast reloading
    tempfile master_clean
    save `master_clean', replace

    * --- 3. THE VISUALIZATION LOOP ---
    foreach var in `loop_vars' count_md count_np count_pa {
        
        * ---------------------------------------------------------
        * A. RIGOROUS DICTIONARY
        * ---------------------------------------------------------
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
            local note_text "Hierarchical Condition Category (HCC) risk score. Higher implies a more complex/sicker panel."
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
        collapse (`stat_type') `var', by(year)
        twoway (connected `var' year, lcolor(navy) lwidth(medthick) msymbol(O)), ///
            title("National Trend: `clean_title'", size(medium) color(black)) ///
            ytitle("`y_title'") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
            note("`note_text'", size(vsmall)) graphregion(color(white) margin(small))
        capture graph export "$outRoot/`setting'/time_series/provider_analysis/overall/ts_overall_`var'.png", replace width(2000)

        * ---------------------------------------------------------
        * CHART 2: BY PROVIDER TYPE
        * ---------------------------------------------------------
        if strpos("`var'", "count_") == 0 { 
            use `master_clean', clear
            collapse (`stat_type') `var', by(year prov_type)
            twoway (connected `var' year if prov_type==1, lcolor(navy) msymbol(O)) ///
                   (connected `var' year if prov_type==2, lcolor(emerald) msymbol(D)) ///
                   (connected `var' year if prov_type==3, lcolor(cranberry) msymbol(S)), ///
                title("By Provider Type: `clean_title'", size(medium) color(black)) ///
                ytitle("`y_title'") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                legend(order(1 "MD/DO" 2 "NP" 3 "PA") position(6) rows(1)) ///
                note("`note_text'", size(vsmall)) graphregion(color(white) margin(small))
            capture graph export "$outRoot/`setting'/time_series/provider_analysis/by_prov_type/ts_provtype_`var'.png", replace width(2000)
        }

        * ---------------------------------------------------------
        * CHART 3: BY GENDER (Nested Loop)
        * ---------------------------------------------------------
        use `master_clean', clear
        drop if missing(is_female)

        forvalues p = 0/3 {
            local t_pref "Overall"
            local out_p "$outRoot/`setting'/time_series/provider_analysis/by_gender/ts_gender_`var'.png"
            
            if `p' == 1 { 
                local t_pref "MD/DO"
                local out_p "$outRoot/`setting'/time_series/provider_analysis/by_gender/MD_DO/ts_MD_DO_gender_`var'.png" 
            }
            else if `p' == 2 { 
                local t_pref "NP"
                local out_p "$outRoot/`setting'/time_series/provider_analysis/by_gender/NP/ts_NP_gender_`var'.png" 
            }
            else if `p' == 3 { 
                local t_pref "PA"
                local out_p "$outRoot/`setting'/time_series/provider_analysis/by_gender/PA/ts_PA_gender_`var'.png" 
            }
            
            if `p' > 0 & strpos("`var'", "count_") > 0 {
                continue
            }

            preserve
            if `p' > 0 {
                keep if prov_type == `p'
            }
            collapse (`stat_type') `var', by(year is_female)
            capture count
            if r(N) > 0 {
                twoway (connected `var' year if is_female==0, lcolor(navy) msymbol(O)) ///
                       (connected `var' year if is_female==1, lcolor(purple) msymbol(D)), ///
                    title("`t_pref' By Gender: `clean_title'", size(medium) color(black)) ///
                    ytitle("`y_title'") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                    legend(order(1 "Male" 2 "Female") position(6) rows(1)) ///
                    note("`note_text'", size(vsmall)) graphregion(color(white) margin(small))
                capture graph export "`out_p'", replace width(2000)
            }
            restore
        }

        * ---------------------------------------------------------
        * CHART 4: BY DEPARTMENT (Nested Loop)
        * ---------------------------------------------------------
        use `master_clean', clear

        forvalues p = 0/3 {
            local t_pref "Overall"
            local out_p "$outRoot/`setting'/time_series/provider_analysis/by_dept/ts_dept_`var'.png"
            
            if `p' == 1 { 
                local t_pref "MD/DO"
                local out_p "$outRoot/`setting'/time_series/provider_analysis/by_dept/MD_DO/ts_MD_DO_dept_`var'.png" 
            }
            else if `p' == 2 { 
                local t_pref "NP"
                local out_p "$outRoot/`setting'/time_series/provider_analysis/by_dept/NP/ts_NP_dept_`var'.png" 
            }
            else if `p' == 3 { 
                local t_pref "PA"
                local out_p "$outRoot/`setting'/time_series/provider_analysis/by_dept/PA/ts_PA_dept_`var'.png" 
            }
            
            if `p' > 0 & strpos("`var'", "count_") > 0 {
                continue
            }

            preserve
            if `p' > 0 {
                keep if prov_type == `p'
            }
            collapse (`stat_type') `var', by(year is_primary_care)
            capture count
            if r(N) > 0 {
                twoway (connected `var' year if is_primary_care==0, lcolor(gs8) lpattern(dash) msymbol(Oh)) ///
                       (connected `var' year if is_primary_care==1, lcolor(navy) msymbol(D)), ///
                    title("`t_pref' By Dept: `clean_title'", size(medium) color(black)) ///
                    ytitle("`y_title'") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                    legend(order(1 "Specialty/Other" 2 "Primary Care") position(6) rows(1)) ///
                    note("`note_text'", size(vsmall)) graphregion(color(white) margin(small))
                capture graph export "`out_p'", replace width(2000)
            }
            restore
        }

        * ---------------------------------------------------------
        * CHART 5: BY OWNERSHIP (Inpatient Only)
        * ---------------------------------------------------------
        if "`setting'" == "in_patient" {
            capture confirm variable own_category
            if _rc == 0 {
                use `master_clean', clear
                drop if missing(own_category)
                
                forvalues p = 0/3 {
                    local t_pref "Overall"
                    local out_p "$outRoot/`setting'/time_series/provider_analysis/by_ownership/ts_own_`var'.png"
                    
                    if `p' == 1 { 
                        local t_pref "MD/DO"
                        local out_p "$outRoot/`setting'/time_series/provider_analysis/by_ownership/MD_DO/ts_MD_DO_own_`var'.png" 
                    }
                    else if `p' == 2 { 
                        local t_pref "NP"
                        local out_p "$outRoot/`setting'/time_series/provider_analysis/by_ownership/NP/ts_NP_own_`var'.png" 
                    }
                    else if `p' == 3 { 
                        local t_pref "PA"
                        local out_p "$outRoot/`setting'/time_series/provider_analysis/by_ownership/PA/ts_PA_own_`var'.png" 
                    }
                    
                    if `p' > 0 & strpos("`var'", "count_") > 0 {
                        continue
                    }

                    preserve
                    if `p' > 0 {
                        keep if prov_type == `p'
                    }
                    collapse (`stat_type') `var', by(year own_category)
                    capture count
                    if r(N) > 0 {
                        twoway (connected `var' year if own_category==1, lcolor(navy) msymbol(O)) ///
                               (connected `var' year if own_category==2, lcolor(cranberry) msymbol(S)) ///
                               (connected `var' year if own_category==3, lcolor(emerald) msymbol(D)), ///
                            title("`t_pref' By Ownership: `clean_title'", size(medium) color(black)) ///
                            ytitle("`y_title'") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                            legend(order(1 "Gov" 2 "For-Profit" 3 "Non-Profit") position(6) rows(1)) ///
                            note("`note_text'", size(vsmall)) graphregion(color(white) margin(small))
                        capture graph export "`out_p'", replace width(2000)
                    }
                    restore
                }
            }
        }

        * ---------------------------------------------------------
        * CHART 6: BY STATE AUTHORITY (Nested Loop)
        * ---------------------------------------------------------
        use `master_clean', clear
        drop if missing(np_authority)

        forvalues p = 0/3 {
            local t_pref "Overall"
            local out_p "$outRoot/`setting'/time_series/provider_analysis/by_authority/ts_auth_`var'.png"
            
            if `p' == 1 { 
                local t_pref "MD/DO"
                local out_p "$outRoot/`setting'/time_series/provider_analysis/by_authority/MD_DO/ts_MD_DO_auth_`var'.png" 
            }
            else if `p' == 2 { 
                local t_pref "NP"
                local out_p "$outRoot/`setting'/time_series/provider_analysis/by_authority/NP/ts_NP_auth_`var'.png" 
            }
            else if `p' == 3 { 
                local t_pref "PA"
                local out_p "$outRoot/`setting'/time_series/provider_analysis/by_authority/PA/ts_PA_auth_`var'.png" 
            }
            
            if `p' > 0 & strpos("`var'", "count_") > 0 {
                continue
            }

            preserve
            if `p' > 0 {
                keep if prov_type == `p'
            }
            collapse (`stat_type') `var', by(year np_authority)
            capture count
            if r(N) > 0 {
                twoway (connected `var' year if np_authority==1, lcolor(cranberry) msymbol(O)) ///
                       (connected `var' year if np_authority==2, lcolor(orange) msymbol(S)) ///
                       (connected `var' year if np_authority==3, lcolor(emerald) msymbol(D)), ///
                    title("`t_pref' By NP Law: `clean_title'", size(medium) color(black)) ///
                    ytitle("`y_title'") xtitle("Year") xlabel(2013(1)2024, angle(45) labsize(small)) ///
                    legend(order(1 "Restricted" 2 "Reduced" 3 "Full Practice") position(6) rows(1)) ///
                    note("`note_text'", size(vsmall)) graphregion(color(white) margin(small))
                capture graph export "`out_p'", replace width(2000)
            }
            restore
        }
    }
}
display "=== PROVIDER TIME SERIES COMPLETE ==="
