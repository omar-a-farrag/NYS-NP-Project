*===============================================================================
* SCRIPT: 07_value_diagnostics.do
* PURPOSE: Tracks changes in value sets (Specialties) over time.
* AUTHOR:  Omar Farrag
* DATE:    2026-02-08
*===============================================================================

global component "cms"
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/general_cms_data/cleaningCode/00_initialize.do"

display as text "Starting Value Diagnostics (Specialty Drift)..."

* Define where we want to save the results
tempfile specialty_master
save `specialty_master', replace emptyok

* Loop through the Main CMS Provider Files (using the 5% samples)
* Note: 'by_provider' usually contains the primary 'provider_type' variable
local providerDir "$cmsRoot/by_provider/dta/5pct_sample"
local files : dir "`providerDir'" files "*_sample.dta"

foreach file in `files' {
    
    quietly use "`providerDir'/`file'", clear
    
    * Extract Year
    gen year = regexs(0) if regexm("`file'", "20[0-9][0-9]")
    
    * Identify the Specialty Variable
    * (It is usually 'provider_type', but might be 'provider_type_description' or similar)
    * We try to find it dynamically:
    
    local specVar ""
    capture confirm variable provider_type
    if _rc == 0 local specVar "provider_type"
    
    if "`specVar'" == "" {
        capture confirm variable provider_type_description
        if _rc == 0 local specVar "provider_type_description"
    }
    
    * If we found the specialty variable, analyze it
    if "`specVar'" != "" {
        display "Scanning `file' (Year: `year') for: `specVar'"
        
        * Collapse to get unique list of specialties for this year
        contract `specVar'
        keep `specVar'
        
        * Rename to a standard 'specialty' for appending
        rename `specVar' specialty
        gen year = "`year'"
        
        * Clean up strings (uppercase for consistency)
        replace specialty = upper(specialty)
        
        * Add to master list
        append using `specialty_master'
        save `specialty_master', replace
    }
    else {
        display as error "  > WARNING: No specialty variable found in `file'"
    }
}

* --- EXPORT THE TRACKER ---
use `specialty_master', clear

* Sort so we can see when new ones appear
sort specialty year
duplicates drop

* Reshape to make it readable (Rows = Specialty, Cols = Year Presence)
gen exists = 1
destring year, replace
reshape wide exists, i(specialty) j(year)

* Clean up output
foreach v of varlist exists* {
    replace `v' = 0 if `v' == .
}

export delimited "$logDir/specialty_growth_tracker.csv", replace

display "----------------------------------------------------"
display "TRACKING COMPLETE."
display "See: $logDir/specialty_growth_tracker.csv" 
log close