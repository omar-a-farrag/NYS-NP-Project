clear all
set more off

* ==============================================================================
* 1. INITIALIZE ENVIRONMENT 
* ==============================================================================
global component "mips"
global script_name "01_harmonize_mips"

* Hardcode the path to the initialize script JUST ONCE per do-file
* This makes the script immune to working directory errors
do "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/general_cms_data/cleaningCode/00_initialize.do"

* ==============================================================================
* 2. EXECUTE DATA HARMONIZATION
* ==============================================================================
* Define specific paths using the globals from 00_initialize.do
global RAW_MIPS "$mipsRoot/mipsClinician_overallPerformance"

* Reserve the temporary file name
tempfile mips_appended

* Loop through years 2017 to 2023
local is_first = 1

forvalues yr = 2017/2023 {
    
    if `yr' == 2017 {
        local fname "ec_scores.csv"
    }
    else {
        local fname "ec_score_file.csv"
    }
    
    * Import the raw CSV
    import delimited "$RAW_MIPS/`yr'py/`fname'", clear stringcols(_all) bindquotes(strict)
    
    * Aggressively clean variable names
    rename *, lower
    foreach var of varlist _all {
        local newname = strtrim("`var'")
        local newname = subinstr("`newname'", " ", "_", .)
        local newname = subinstr("`newname'", "-", "_", .)
        
        if substr("`newname'", 1, 1) == "_" {
            local newname = substr("`newname'", 2, .)
        }
        capture rename `var' `newname'
    }

    gen year = `yr'
    
    * Standardize core variables based on the diagnostic script
    capture rename provider_npi npi
    capture rename final_mips_score mips_final_score
    capture rename quality_category_score mips_quality_score
    capture rename ia_category_score mips_ia_score
    capture rename cost_category_score mips_cost_score
    
    * Handle the ACI to PI name change
    capture rename aci_category_score mips_pi_score
    capture rename pi_category_score mips_pi_score
    
    * Handle the CCN structural drift
    capture rename facility_based_scoring_certification_number ccn
    capture rename facility_ccn ccn

    * NEW LOGIC: Guarantee every core variable exists before keeping
    foreach v in mips_final_score mips_quality_score mips_ia_score mips_pi_score mips_cost_score ccn {
        capture confirm variable `v'
        if _rc {
            gen `v' = ""
        }
    }

    * Keep exactly the columns we want
    keep npi year mips_final_score mips_quality_score mips_ia_score mips_pi_score mips_cost_score ccn
    
    * Force numeric conversion for scores
    destring mips_final_score mips_quality_score mips_ia_score mips_pi_score mips_cost_score, replace force ignore("N/A" "NA" "Null" "*")
    
    * Force string conversion for identifiers to prevent append mismatches
    tostring npi ccn, replace force

    * Handle NPI Duplicates (Collapse to highest score per NPI/Year)
    collapse (max) mips_final_score mips_quality_score mips_ia_score mips_pi_score mips_cost_score (firstnm) ccn, by(npi year)

    * Smart Append Logic (replaces the 'emptyok' approach)
    if `is_first' == 1 {
        save `mips_appended', replace
        local is_first = 0
    }
    else {
        * Using 'force' allows Stata to smoothly join string lengths (e.g., str4 with str5)
        append using `mips_appended', force
        save `mips_appended', replace
    }
    
    di "Year `yr' Harmonized and Appended!"
}

* Final Polish on Master Panel
use `mips_appended', clear
order npi year ccn mips_final_score mips_quality_score mips_pi_score mips_ia_score mips_cost_score
sort npi year

* Save the unified master MIPS panel
save "$phase4/mips_clinician_master_panel_2017_2023$fileSuffix.dta", replace