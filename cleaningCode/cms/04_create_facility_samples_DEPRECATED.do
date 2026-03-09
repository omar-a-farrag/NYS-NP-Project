*===============================================================================
* SCRIPT: 03_create_facility_samples_v5.do
* PURPOSE: Samples Facility files with Deduplication Fix & Debug Switch.
* AUTHOR:  Omar Farrag
* DATE:    2026-02-08
*===============================================================================

global component "mips"
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/general_cms_data/cleaningCode/00_initialize.do"

display as text "Starting Facility Affiliation Sampling (v5)..."

* --- DEBUG SWITCH ---
* Set to "no" to skip the 2014-2023 files you have already processed.
global process_early_years "no" 
*global process_early_years "yes"

local facilRoot "$mipsRoot/facilityAffiliation"
local destDir   "`facilRoot'/dta/5pct_sample"

capture mkdir "`facilRoot'/dta"
capture mkdir "`destDir'"

*-------------------------------------------------------------------------------
* PHASE 1: The "Unified" Era (2014-2023)
*-------------------------------------------------------------------------------
if "$process_early_years" == "yes" {
    
    local earlyFiles : dir "`facilRoot'" files "facility_names_*.csv"
    
    foreach file in `earlyFiles' {
        display "----------------------------------------------------"
        display "Processing Unified File: `file'"
        
        * FIX: Check for 2016 (No Header)
        if strpos("`file'", "2016") > 0 {
            display as result "  > DETECTED 2016 (NO HEADER): Applying manual fix..."
            quietly import delimited "`facilRoot'/`file'", clear varnames(nonames) 
            
            * Manual Rename (Matching 2015 structure)
            capture rename v1 npi
            capture rename v2 pac_id
            capture rename v3 professional_enrollment_id
            capture rename v4 last_name
            capture rename v5 first_name
            capture rename v6 middle_name
            capture rename v7 suffix
            capture rename v8 gender
            capture rename v9 credential
            capture rename v10 medical_school_name
            capture rename v11 graduation_year
            capture rename v12 primary_specialty
            capture rename v13 secondary_specialty_1
            capture rename v14 secondary_specialty_2
            capture rename v15 secondary_specialty_3
            capture rename v16 secondary_specialty_4
            capture rename v17 all_secondary_specialties
            capture rename v18 organization_legal_name
            capture rename v19 organization_pac_id
            capture rename v20 number_of_group_practice_members
            capture rename v21 line_1_street_address
            capture rename v22 line_2_street_address
            capture rename v23 marker_of_line_2_street_address_suppression
            capture rename v24 city
            capture rename v25 state
            capture rename v26 zip_code
            capture rename v27 phone_number
        }
        else {
            quietly import delimited "`facilRoot'/`file'", clear varnames(1) case(lower)
        }
        
        set seed 12345 
        sample 5
        
        local saveName = subinstr("`file'", ".csv", "", .)
        quietly save "`destDir'/`saveName'_sample.dta", replace
    }
}
else {
    display "Skipping Phase 1 (2014-2023) as requested..."
}

*-------------------------------------------------------------------------------
* PHASE 2: The "Split" Era (2024+)
*-------------------------------------------------------------------------------
foreach year in 2024 2025 {
    
    * Check for BOTH files (The Merge Condition)
    capture confirm file "`facilRoot'/`year'/DAC_NationalDownloadableFile.csv"
    local hasDAC = (_rc == 0)
    
    capture confirm file "`facilRoot'/`year'/Facility_Affiliation.csv"
    local hasFacil = (_rc == 0)
    
    if `hasFacil' == 1 {
        display "----------------------------------------------------"
        display "Processing Year: `year'"
        
        if `hasDAC' == 1 {
            display as text "  > MERGE DETECTED: Combining Facility + DAC Provider Info..."
            
            * STEP A: Load the Provider Info (DAC) -> The "Using" dataset
            quietly import delimited "`facilRoot'/`year'/DAC_NationalDownloadableFile.csv", clear varnames(1) case(lower)
            
            * Ensure NPI is string/long consistency
            capture tostring npi, replace
            
            * --- FIX FOR ERROR r(459): DEDUPLICATE DAC FILE ---
            * The DAC file has duplicate NPIs (likely multiple addresses).
            * We only need unique demographics, so we keep the first occurrence.
            quietly duplicates drop npi, force
            
            * Save as tempfile
            tempfile provider_demographics
            quietly save `provider_demographics', replace
            
            * STEP B: Load the Facility Affiliation -> The "Master" dataset
            quietly import delimited "`facilRoot'/`year'/Facility_Affiliation.csv", clear varnames(1) case(lower)
            capture tostring npi, replace
            
            * STEP C: Merge m:1 (Many facilities per One provider)
            quietly merge m:1 npi using `provider_demographics'
            
            * Keep matched records (and master if you want facility info even without demographics)
            * _merge == 3 (Matched)
            * _merge == 1 (Facility info exists, but no provider demographics found)
            keep if _merge == 3 | _merge == 1
            drop _merge
            
            display as text "  > Merge Complete. Now Sampling..."
        }
        else {
            display as text "  > No DAC file found. Processing Facility file only..."
            quietly import delimited "`facilRoot'/`year'/Facility_Affiliation.csv", clear varnames(1) case(lower)
        }
        
        * STEP D: Sample and Save
        set seed 12345 
        sample 5
        quietly save "`destDir'/facility_names_`year'_sample.dta", replace
    }
}

display "----------------------------------------------------"
display "DONE! 2024+ Merged and Deduplicated."
log close