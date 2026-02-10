*===============================================================================
* SCRIPT: 04_facility_diagnostics.do
* PURPOSE: Scans variable names in Facility Affiliation files to detect schema drift.
* AUTHOR:  Omar Farrag
* DATE:    2026-02-08
*===============================================================================

global component "mips"
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/general_cms_data/cleaningCode/00_initialize.do"

clear
tempfile master_list
save `master_list', replace emptyok

display as text "Starting Facility Diagnostic Scan..."

* Point to the new sample folder
local sampleDir "$mipsRoot/facilityAffiliation/dta/5pct_sample"
local dtaFiles : dir "`sampleDir'" files "*_sample.dta"

foreach dta in `dtaFiles' {
    
    quietly use "`sampleDir'/`dta'", clear
    
    * Get variable names
    describe, replace clear
    keep name type format
    
    * Add metadata
    gen folder = "facility_affiliation"
    gen original_file = "`dta'"
    
    * Extract Year (looking for 4 digits in filename)
    gen year = regexs(0) if regexm("`dta'", "[0-9][0-9][0-9][0-9]")
    destring year, replace
    
    append using `master_list'
    save `master_list', replace
}

* --- CREATE THE MATRIX ---
use `master_list', clear
keep name year folder
duplicates drop

gen exists = 1
reshape wide exists, i(name folder) j(year)

foreach v of varlist exists* {
    replace `v' = 0 if `v' == .
}

sort name
export delimited "$logDir/facility_alignment_map.csv", replace

display "----------------------------------------------------"
display "DIAGNOSTIC COMPLETE." 
display "Map saved to: $logDir/facility_alignment_map.csv"
log close