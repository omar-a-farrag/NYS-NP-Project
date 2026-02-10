*===============================================================================
* SCRIPT: 07b_facility_value_diagnostics_v5.do
* PURPOSE: Tracks SPECIALTY changes (Fixes r(9) via Collapse).
* AUTHOR:  Omar Farrag
* DATE:    2026-02-08
*===============================================================================

global component "mips"
global script_name "07b_facility_value_diagnostics"

* (Ensure this path is correct)
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/general_cms_data/cleaningCode/00_initialize.do"

display as text "Starting Facility Specialty Diagnostics (v5)..."

tempfile facility_specialty_master
save `facility_specialty_master', replace emptyok

local facilDir "$mipsRoot/facilityAffiliation/dta/5pct_sample"
local files : dir "`facilDir'" files "*_sample.dta"

foreach file in `files' {
    
    quietly use "`facilDir'/`file'", clear
    
    * Extract Year
    if regexm("`file'", "20[0-9][0-9]") {
        local fileYear = regexs(0)
    }
    else {
        local fileYear = "9999"
    }
    
    * Detect Specialty Variable
    local specVar ""
    capture confirm variable pri_spec
    if _rc == 0 local specVar "pri_spec"
    
    if "`specVar'" == "" {
        capture confirm variable primaryspecialty
        if _rc == 0 local specVar "primaryspecialty"
    }
    
    if "`specVar'" == "" {
        capture confirm variable primary_specialty
        if _rc == 0 local specVar "primary_specialty"
    }
    
    if "`specVar'" == "" {
        capture confirm variable provider_type
        if _rc == 0 local specVar "provider_type"
    }
    
    * Analyze
    if "`specVar'" != "" {
        display "Scanning `file' (`fileYear') using: `specVar'"
        
        * Collapse to unique values
        contract `specVar'
        
        * Keep only what we need
        keep `specVar'
        
        rename `specVar' specialty
        gen year = `fileYear'
        
        * Clean Strings: Uppercase and TRIM spaces
        replace specialty = upper(strtrim(specialty))
        
        append using `facility_specialty_master'
        save `facility_specialty_master', replace
    }
}

* --- EXPORT ---
use `facility_specialty_master', clear

* Drop any rows where specialty is missing/empty
drop if missing(specialty)

* --- THE NUCLEAR FIX FOR r(9) ---
* Instead of duplicates drop, we COLLAPSE.
* This forces 1 row per Specialty/Year group.
gen exists_flag = 1
collapse (max) exists=exists_flag, by(specialty year)

* Now Reshape (Guaranteed to work)
reshape wide exists, i(specialty) j(year)

* Fill Zeros
foreach v of varlist exists* {
    replace `v' = 0 if `v' == .
}

sort specialty
export delimited "$logDir/facility_specialty_growth_tracker.csv", replace

display "----------------------------------------------------"
display "FACILITY TRACKING COMPLETE."
log close