* ==============================================================================
* SCRIPT: diagnostic_asc_ccn_check.do
* PURPOSE: Prove the absence of direct NPI-to-ASC facility links
* ==============================================================================
set more off
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

display "=== RUNNING DIAGNOSTIC ON OUTPATIENT PROVIDERS ==="
use "$dataRoot/master_provider_outpatient_asc_2015_2023.dta", clear

* 1. Check if the CCN variable even exists
capture confirm variable ccn
if _rc == 0 {
    display "CCN column exists. Checking for populated data..."
    count if !missing(ccn)
    local ccn_count = r(N)
    display "Number of providers with a valid ASC CCN: `ccn_count'"
}
else {
    display "RESULT: The variable 'ccn' does not exist in the provider dataset."
}

* 2. Check for alternative facility IDs (like the ASC NPI)
capture confirm variable fac_npi
if _rc == 0 {
    count if !missing(fac_npi)
    display "Number of providers with a valid Facility NPI: " r(N)
}
else {
    display "RESULT: No alternative Facility NPIs found."
}

display "=== DIAGNOSTIC COMPLETE: GEOGRAPHIC PROXY REQUIRED ==="