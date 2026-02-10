*===============================================================================
* SCRIPT: 08_harmonize_cms.do
* PURPOSE: Standardizes variables across CMS files (Provider, Service, Part D).
* AUTHOR:  Omar Farrag
* DATE:    2026-02-08
*===============================================================================

global component "cms"
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/general_cms_data/cleaningCode/00_initialize.do"

display as text "Starting CMS Harmonization..."

local folders "by_provider by_provider_service partD"

foreach f in `folders' {
    
    display "----------------------------------------------------"
    display "PROCESSING FOLDER: `f'"
    
    local sampleDir "$cmsRoot/`f'/dta/5pct_sample"
    local destDir   "$cmsRoot/`f'/dta/harmonized"
    
    capture mkdir "$cmsRoot/`f'/dta/harmonized"
    
    local dtaFiles : dir "`sampleDir'" files "*_sample.dta"
    
    foreach file in `dtaFiles' {
        
        quietly use "`sampleDir'/`file'", clear
        
        * --- 0. ADD YEAR VARIABLE ---
        if regexm("`file'", "20[0-9][0-9]") {
            local fileYear = regexs(0)
            gen int year = `fileYear'
        }
        
        * --- 1. IDENTIFIERS ---
        * Target: npi
        * (Part D sometimes uses 'prvdr_id', Provider uses 'npi')
        capture rename prvdr_id npi
        capture tostring npi, replace
        
        * --- 2. DEMOGRAPHICS ---
        * Target: last_name, first_name, gender, entity_type
        
        * Last Name / Org Name
        capture rename nppes_provider_last_org_name last_name
        capture rename prvdr_last_org_name last_name
        
        * First Name
        capture rename nppes_provider_first_name first_name
        capture rename prvdr_first_name first_name
        
        * Gender
        capture rename nppes_provider_gender gender
        capture rename prvdr_gndr gender
        
        * Entity Type (Individual vs Organization)
        capture rename nppes_entity_code entity_type
        capture rename entity_cd entity_type
        
        * --- 3. GEOGRAPHY ---
        * Target: city, state, zip
        capture rename nppes_provider_city city
        capture rename prvdr_city city
        
        capture rename nppes_provider_state state
        capture rename prvdr_state_abrvtn state
        
        capture rename nppes_provider_zip zip_code
        capture rename nppes_provider_zip5 zip_code
        capture rename prvdr_zip zip_code
        
        * --- 4. SPECIALTY ---
        * Target: specialty, hcpcs_code (for service files)
        capture rename provider_type specialty
        capture rename prvdr_spclty_type specialty
        capture rename cms_specialty_description specialty
        
        capture rename hcpcs_code hcpcs
        
        * --- 5. CLEANUP ---
        * Ensure critical identifiers are strings (zips often break if numeric)
        capture tostring zip_code, replace
        capture tostring entity_type, replace
        
        * Save
        local saveName = subinstr("`file'", "_sample.dta", "_harmonized.dta", .)
        quietly save "`destDir'/`saveName'", replace
    }
}

display "----------------------------------------------------"
display "CMS Harmonization Complete. Check dta/harmonized folders."
log close