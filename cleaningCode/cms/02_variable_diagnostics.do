*===============================================================================
* SCRIPT: 02_variable_diagnostics.do
* PURPOSE: Scrapes variable names across years to identify schema changes/drift.
* AUTHOR:  Omar Farrag
* DATE:    2026-02-07
*===============================================================================

* --- 0. SET LOGGING COMPONENT ---
global component "cms"

* --- 1. INITIALIZE ENVIRONMENT ---
* (Paste your absolute path to 00_initialize.do here)
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/general_cms_data/cleaningCode/00_initialize.do"

*===============================================================================
* BEGIN SCRIPT
*===============================================================================

clear
tempfile master_list
save `master_list', replace emptyok

display as text "Starting Diagnostic Scan..."

foreach f in by_provider by_provider_service partD {
    
    display "Scanning folder: `f'..."
    local sampleDir "$cmsRoot/`f'/dta/5pct_sample"
    
    * Get list of .dta files
    local dtaFiles : dir "`sampleDir'" files "*_sample.dta"
    
    * --- FIX: Loop directly over `dtaFiles` (not `local dtaFiles`) ---
    foreach dta in `dtaFiles' {
        
        quietly use "`sampleDir'/`dta'", clear
        
        * Get variable names
        describe, replace clear
        keep name type format
        
        * Add metadata
        gen folder = "`f'"
        gen original_file = "`dta'"
        
        * Extract Year (Looking for 4 digits in filename)
        gen year = regexs(0) if regexm("`dta'", "[0-9][0-9][0-9][0-9]")
        destring year, replace
        
        append using `master_list'
        save `master_list', replace
    }
}

* --- CREATE THE MATRIX ---
use `master_list', clear

* Keep only what we need
keep name year folder
duplicates drop

* Create "Exists" flag
gen exists = 1
reshape wide exists, i(name folder) j(year)

* Clean up output (replace missing with 0)
foreach v of varlist exists* {
    replace `v' = 0 if `v' == .
}

* Sort for readability
sort folder name

* Save the map
export delimited "$logDir/variable_alignment_map.csv", replace

display "----------------------------------------------------"
display "DIAGNOSTIC COMPLETE." 
display "Map saved to: $logDir/variable_alignment_map.csv"
log close