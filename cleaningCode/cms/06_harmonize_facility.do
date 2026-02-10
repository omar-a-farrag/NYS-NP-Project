*===============================================================================
* SCRIPT: 06_harmonize_facility_v2.do
* PURPOSE: Standardizes names AND adds 'year' column for appending.
* AUTHOR:  Omar Farrag
* DATE:    2026-02-08
*===============================================================================

global component "mips"
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/general_cms_data/cleaningCode/00_initialize.do"

display as text "Starting Variable Harmonization (v2)..."

local sampleDir "$mipsRoot/facilityAffiliation/dta/5pct_sample"
local destDir   "$mipsRoot/facilityAffiliation/dta/harmonized"

capture mkdir "`destDir'"

local dtaFiles : dir "`sampleDir'" files "*_sample.dta"

foreach file in `dtaFiles' {
    
    display "Harmonizing: `file'..."
    quietly use "`sampleDir'/`file'", clear
    
    * --- 0. ADD YEAR VARIABLE (CRITICAL FOR APPENDING) ---
    if regexm("`file'", "20[0-9][0-9]") {
        local fileYear = regexs(0)
        gen int year = `fileYear'
    }
    
    * --- 1. IDENTIFIERS ---
    capture rename ind_pac_id pac_id
    capture rename individual_pac_id pac_id
    
    * --- 2. DEMOGRAPHICS ---
    capture rename lst_nm last_name
    capture rename lastname last_name
    capture rename providerlastname last_name
    
    capture rename frst_nm first_name
    capture rename firstname first_name
    capture rename providerfirstname first_name
    
    capture rename gndr gender
    capture rename providergender gender
    capture rename providergendercode gender
    
    capture rename grd_yr grad_year
    capture rename graduationyear grad_year
    
    capture rename med_sch med_school
    capture rename medical_school_name med_school
    capture rename medicalschoolname med_school
    
    * --- 3. SPECIALTY ---
    capture rename pri_spec primary_specialty
    capture rename primaryspecialty primary_specialty
    * (Note: 2024+ might use 'provider_type', let's grab that too)
    capture rename provider_type primary_specialty
    
    * --- 4. ORGANIZATION / ADDRESS ---
    capture rename org_nm org_name
    capture rename organization_legal_name org_name
    capture rename organizationlegalname org_name
    
    capture rename cty city
    capture rename citytown city
    
    capture rename st state
    capture rename zip zip_code
    
    * --- 5. CLEANUP ---
    capture tostring zip_code, replace
    capture tostring npi, replace
    capture tostring pac_id, replace
    
    * Save
    local saveName = subinstr("`file'", "_sample.dta", "_harmonized.dta", .)
    quietly save "`destDir'/`saveName'", replace
}

display "----------------------------------------------------"
display "Harmonization Complete. Year column added."
log close