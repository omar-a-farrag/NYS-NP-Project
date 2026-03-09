*===============================================================================
* SCRIPT: 09_append_and_merge.do
* PURPOSE: Appends harmonized files and merges CMS + Facility data.
* AUTHOR:  Omar Farrag
* DATE:    2026-02-08
*===============================================================================

global component "general"
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/general_cms_data/cleaningCode/00_initialize.do"

display as text "Starting Final Merge..."

*-------------------------------------------------------------------------------
* PART 1: APPEND FACILITY DATA (The "Master" List)
*-------------------------------------------------------------------------------
display "Step 1: Appending Facility Data..."
clear

local facilDir "$mipsRoot/facilityAffiliation/dta/harmonized"
local files : dir "`facilDir'" files "*_harmonized.dta"

* Initialize with the first file
local first = 1
foreach f in `files' {
    if `first' == 1 {
        use "`facilDir'/`f'", clear
        local first = 0
    }
    else {
        append using "`facilDir'/`f'"
    }
}

* Deduplicate (Safety check: NPI-Year-Facility should be unique)
duplicates drop npi year org_pac_id, force

save "$outputRoot/tables/facility_panel_master.dta", replace
display "  > Facility Panel Saved: $outputRoot/tables/facility_panel_master.dta"


*-------------------------------------------------------------------------------
* PART 2: APPEND CMS PROVIDER DATA (The "Using" Data)
*-------------------------------------------------------------------------------
display "Step 2: Appending CMS Provider Data..."
clear

local cmsDir "$cmsRoot/by_provider/dta/harmonized"
local files : dir "`cmsDir'" files "*_harmonized.dta"

local first = 1
foreach f in `files' {
    if `first' == 1 {
        use "`cmsDir'/`f'", clear
        local first = 0
    }
    else {
        append using "`cmsDir'/`f'"
    }
}

duplicates drop npi year, force
save "$outputRoot/tables/cms_provider_panel.dta", replace


*-------------------------------------------------------------------------------
* PART 3: THE MERGE
*-------------------------------------------------------------------------------
display "Step 3: Merging Facility (Master) + CMS Provider (Using)..."

use "$outputRoot/tables/facility_panel_master.dta", clear

* Merge m:1 because multiple facilities can link to ONE provider in a year
merge m:1 npi year using "$outputRoot/tables/cms_provider_panel.dta"

* _merge analysis
tab _merge year
label define mlab 1 "Facility Only" 2 "CMS Only" 3 "Matched"
label values _merge mlab

keep if _merge == 3 | _merge == 1  // Keep matches + facility data (our base)
drop _merge

* Save Final Dataset
save "$outputRoot/tables/FINAL_NETWORK_PANEL.dta", replace

display "----------------------------------------------------"
display "MERGE COMPLETE."
display "Final Dataset: $outputRoot/tables/FINAL_NETWORK_PANEL.dta"
log close