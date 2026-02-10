*===============================================================================
* SCRIPT: 05_inspect_headers.do
* PURPOSE: Exports the first 5 lines of every Facility CSV to check for headers.
* AUTHOR:  Omar Farrag
* DATE:    2026-02-08
*===============================================================================

global component "mips"
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/general_cms_data/cleaningCode/00_initialize.do"

* Create a simple text log for the inspection
capture log close _all
log using "$logDir/facility_header_inspection.txt", replace text

display "=================================================================="
display "       FACILITY DATA HEADER INSPECTION REPORT"
display "=================================================================="

* --- PHASE 1: Main Folder (2014-2022) ---
local facilRoot "$mipsRoot/facilityAffiliation"
local earlyFiles : dir "`facilRoot'" files "facility_names_*.csv"

foreach file in `earlyFiles' {
    display _newline
    display "------------------------------------------------------------------"
    display "FILE: `file'"
    display "------------------------------------------------------------------"
    
    * Use the 'type' command to show raw lines (first 5)
    type "`facilRoot'/`file'", lines(5)
}

* --- PHASE 2: Subfolders (2023+) ---
foreach year in 2023 2024 2025 {
    
    * Check if file exists
    capture confirm file "`facilRoot'/`year'/Facility_Affiliation.csv"
    
    if _rc == 0 {
        display _newline
        display "------------------------------------------------------------------"
        display "FILE: `year'/Facility_Affiliation.csv"
        display "------------------------------------------------------------------"
        
        type "`facilRoot'/`year'/Facility_Affiliation.csv", lines(5)
    }
    else {
        display _newline "  [No file found for `year']"
    }
}

log close
display "Inspection complete. Open: $logDir/facility_header_inspection.txt"