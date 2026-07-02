*===============================================================================
* SCRIPT: 06d_hcahps_extended_ts.do
* PURPOSE: 17-Year Time-Series Line Charts for HCAHPS (2007-2024).
* FEATURES: NYS Comparative Benchmarks (NYS vs Nat vs FPA), USDA Fallback
*===============================================================================
set more off, permanently
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* --- START LOG ---
local script_name "06d_hcahps_extended_ts"
log using "$logRoot/`script_name'.smcl", replace
* -----------------

display "=== STARTING EXTENDED HCAHPS TIME SERIES (2007-2024) ==="

local hcahps_vars "hcahps_100_score hcahps_grp1 hcahps_grp2 hcahps_grp3 hcahps_grp4 h_hosp_rating_9_10 h_hosp_rating_0_6"

* --- 1. DYNAMIC FOLDER CREATION ---
local scopes "national new_york"
local subfolders "overall by_ownership by_authority by_geography"

foreach scope in `scopes' {
    capture mkdir "$outRoot/summary_stats/in_patient/time_series/hcahps_extended"
    capture mkdir "$outRoot/summary_stats/in_patient/time_series/hcahps_extended/`scope'"
    foreach sub in `subfolders' {
        capture mkdir "$outRoot/summary_stats/in_patient/time_series/hcahps_extended/`scope'/`sub'"
    }
}

* --- 2. LOAD & PREP DATA ---
use "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/general_cms_data/outputs_while_cleaning/cleaned_data/phase2_hcahps/hcahps_final_panel.dta", clear

* A. State Authority
capture drop state_str np_authority
capture decode state, gen(state_str)
if _rc != 0 {
    capture confirm string variable state
    if _rc == 0 gen state_str = state
    else gen state_str = string(state)
}
replace state_str = strtrim(strupper(state_str))

gen np_authority = .
replace np_authority = 3 if $cond_full_prac
replace np_authority = 2 if $cond_red_prac
replace np_authority = 1 if $cond_res_prac

* B. Ownership
capture drop own_str own_category
gen own_category = .
capture decode ownership, gen(own_str)
if _rc != 0 {
    capture confirm string variable ownership
    if _rc == 0 gen own_str = ownership
    else gen own_str = string(ownership)
}
replace own_category = 1 if $cond_own_gov
replace own_category = 2 if $cond_own_forprof
replace own_category = 3 if $cond_own_nonprof

* C. Geography (Urban vs. Rural via USDA ERS RUCA Codes)
capture drop is_urban
display "Attempting to Download USDA RUCA ZIP Crosswalk..."
preserve
capture copy "https://www.ers.usda.gov/webdocs/DataFiles/53241/RUCA2010zipcode.xlsx" "ruca_temp.xlsx", replace
capture import excel "ruca_temp.xlsx", sheet("Data") firstrow clear
if _rc == 0 {
    keep ZIPCode RUCA1
    rename ZIPCode zip_code
    capture tostring zip_code, replace force
    replace zip_code = string(real(zip_code), "%05.0f")
    gen is_urban = (RUCA1 <= 3) if !missing(RUCA1)
    drop if missing(zip_code)
    duplicates drop zip_code, force
    tempfile ruca
    save `ruca'
}
restore

capture confirm file "`ruca'"
if _rc == 0 {
    capture tostring zip_code, replace force
    replace zip_code = string(real(zip_code), "%05.0f")
    merge m:1 zip_code using `ruca', keep(master match) nogen
    capture erase "ruca_temp.xlsx"
    display "Geography Merge Successful!"
}
else {
    display "WARNING: Web download blocked by firewall. Geography charts will be skipped."
    gen is_urban = .
}

* D. Dynamic 2022 Data Check
quietly count if year == 2022
local gap_note = ""
if r(N) == 0 local gap_note "Gap in 2022 reflects data availability."

tempfile master_clean
save `master_clean', replace

* --- 3. THE VISUALIZATION LOOP ---
foreach scope in `scopes' {
    foreach var in `hcahps_vars' {
        
        * Dictionary
        local clean_title = strproper(subinstr("`var'", "_", " ", .))
        local dir_note "Metric: `var'"
        
        if "`var'" == "hcahps_100_score" {
            local clean_title "Overall HCAHPS Score"
            local dir_note "0-100 linear mean score representing overall patient satisfaction."
        }
        else if "`var'" == "hcahps_grp1" {
            local clean_title "HCAHPS: Staff Comm"
            local dir_note "0-100 composite for Staff Communication (Nurses and Doctors)."
        }
        else if "`var'" == "hcahps_grp2" {
            local clean_title "HCAHPS: Patient Help"
            local dir_note "0-100 composite for Providing Patient Help (Responsiveness & Meds)."
        }
        else if "`var'" == "hcahps_grp3" {
            local clean_title "HCAHPS: Environment"
            local dir_note "0-100 composite for Facility Environment (Cleanliness & Quietness)."
        }
        else if "`var'" == "hcahps_grp4" {
            local clean_title "HCAHPS: Global Rating"
            local dir_note "0-100 composite for Global Rating and Recommendation."
        }
        else if "`var'" == "h_hosp_rating_9_10" {
            local clean_title "HCAHPS: Rating 9 or 10"
            local dir_note "Percentage of patients rating the hospital a 9 or 10 overall."
        }
        else if "`var'" == "h_hosp_rating_0_6" {
            local clean_title "HCAHPS: Rating 0 to 6"
            local dir_note "Percentage of patients rating the hospital a 6 or lower overall."
        }

        local scope_title = proper(subinstr("`scope'", "_", " ", .))
        local full_note "`dir_note' `gap_note'"
        local graph_margin "margin(l+2 r+2 b+15)"

        * 1. Overall / NYS Comparative Benchmark
        use `master_clean', clear
        capture drop if missing(`var')
        
        if "`scope'" == "national" {
            collapse (mean) `var', by(year)
            if _N > 0 {
                twoway (connected `var' year, lcolor(navy) lwidth(medthick) msymbol(O)), ///
                    title("National Trend: `clean_title'", size(medium) color(black)) ///
                    ytitle("Mean Value") xtitle("Year") xlabel(2007(1)2024, angle(45) labsize(vsmall)) ///
                    note("`full_note'", position(7) justification(left) size(vsmall) margin(t=3 l=2) span) ///
                    graphregion(color(white) `graph_margin')
                capture graph export "$outRoot/in_patient/time_series/hcahps_extended/`scope'/overall/ts_overall_`var'.png", replace width(2000)
            }
        }
        else if "`scope'" == "new_york" {
            * Generate 3 Comparative Benchmarks before subsetting
            egen val_nat = mean(`var'), by(year)
            egen val_nys = mean(cond(state_str=="NY", `var', .)), by(year)
            egen val_fpa = mean(cond(np_authority==3, `var', .)), by(year)
            
            collapse (mean) val_nat val_nys val_fpa, by(year)
            drop if missing(val_nys) // Only plot years where NY exists
            
            if _N > 0 {
                twoway (connected val_nys year, lcolor(navy) lwidth(medthick) msymbol(D)) ///
                       (connected val_nat year, lcolor(gs8) lpattern(dash) msymbol(O)) ///
                       (connected val_fpa year, lcolor(emerald) lpattern(dash) msymbol(S)), ///
                    title("NYS vs Benchmarks: `clean_title'", size(medium) color(black)) ///
                    ytitle("Mean Value") xtitle("Year") xlabel(2007(1)2024, angle(45) labsize(vsmall)) ///
                    legend(order(1 "New York" 2 "National Avg" 3 "Full Practice Avg") position(6) rows(1)) ///
                    note("`full_note'", position(7) justification(left) size(vsmall) margin(t=3 l=2) span) ///
                    graphregion(color(white) `graph_margin')
                capture graph export "$outRoot/in_patient/time_series/hcahps_extended/`scope'/overall/ts_overall_`var'.png", replace width(2000)
            }
        }

        * 2. By Ownership
        use `master_clean', clear
        if "`scope'" == "new_york" keep if state_str == "NY"
        capture drop if missing(`var') | missing(own_category)
        count
        if r(N) > 0 {
            collapse (mean) `var', by(year own_category)
            if _N > 0 {
                twoway (connected `var' year if own_category==1, lcolor(navy) msymbol(O)) ///
                       (connected `var' year if own_category==2, lcolor(cranberry) msymbol(S)) ///
                       (connected `var' year if own_category==3, lcolor(emerald) msymbol(D)), ///
                    title("`scope_title': `clean_title' by Ownership", size(medium) color(black)) ///
                    ytitle("Mean Value") xtitle("Year") xlabel(2007(1)2024, angle(45) labsize(vsmall)) ///
                    legend(order(1 "Gov" 2 "For-Profit" 3 "Non-Profit") position(6) rows(1)) ///
                    note("`full_note'", position(7) justification(left) size(vsmall) margin(t=3 l=2) span) ///
                    graphregion(color(white) `graph_margin')
                capture graph export "$outRoot/in_patient/time_series/hcahps_extended/`scope'/by_ownership/ts_own_`var'.png", replace width(2000)
            }
        }

        * 3. By Authority (National Only)
        if "`scope'" == "national" {
            use `master_clean', clear
            capture drop if missing(`var') | missing(np_authority)
            count
            if r(N) > 0 {
                collapse (mean) `var', by(year np_authority)
                if _N > 0 {
                    twoway (connected `var' year if np_authority==1, lcolor(cranberry) msymbol(O)) ///
                           (connected `var' year if np_authority==2, lcolor(orange) msymbol(S)) ///
                           (connected `var' year if np_authority==3, lcolor(emerald) msymbol(D)), ///
                        title("National: `clean_title' by NP Law", size(medium) color(black)) ///
                        ytitle("Mean Value") xtitle("Year") xlabel(2007(1)2024, angle(45) labsize(vsmall)) ///
                        legend(order(1 "Restricted" 2 "Reduced" 3 "Full Practice") position(6) rows(1)) ///
                        note("`full_note' NP Law: Static 2023 status.", position(7) justification(left) size(vsmall) margin(t=3 l=2) span) ///
                        graphregion(color(white) `graph_margin')
                    capture graph export "$outRoot/in_patient/time_series/hcahps_extended/`scope'/by_authority/ts_auth_`var'.png", replace width(2000)
                }
            }
        }

        * 4. By Geography (Urban vs Rural)
        use `master_clean', clear
        if "`scope'" == "new_york" keep if state_str == "NY"
        capture drop if missing(`var') | missing(is_urban)
        count
        if r(N) > 0 {
            collapse (mean) `var', by(year is_urban)
            if _N > 0 {
                twoway (connected `var' year if is_urban==0, lcolor(gs8) lpattern(dash) msymbol(Oh)) ///
                       (connected `var' year if is_urban==1, lcolor(navy) msymbol(D)), ///
                    title("`scope_title': `clean_title' by Geography", size(medium) color(black)) ///
                    ytitle("Mean Value") xtitle("Year") xlabel(2007(1)2024, angle(45) labsize(vsmall)) ///
                    legend(order(1 "Rural" 2 "Urban") position(6) rows(1)) ///
                    note("`full_note'", position(7) justification(left) size(vsmall) margin(t=3 l=2) span) ///
                    graphregion(color(white) `graph_margin')
                capture graph export "$outRoot/in_patient/time_series/hcahps_extended/`scope'/by_geography/ts_geo_`var'.png", replace width(2000)
            }
        }
    }
}
display "=== EXTENDED HCAHPS TIME SERIES COMPLETE ==="
