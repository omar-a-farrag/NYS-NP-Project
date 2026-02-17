*===============================================================================
* SCRIPT: 08_harmonize_cms.do (UPDATED v4)
* PURPOSE: Standardizes variables across CMS files (Provider, Service, Part D).
* AUTHOR:  Omar Farrag
* DATE:    2026-02-10
*===============================================================================

global component "cms"
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/general_cms_data/cleaningCode/00_initialize.do"

display as text "Starting CMS Harmonization (v4 - Complete Variable Map)..."

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
        
        * --- 1. IDENTIFIERS (NPI) ---
        capture rename prscrbr_npi npi      // Part D
        capture rename rndrng_npi npi       // Provider Service
        capture rename prvdr_id npi         // General Provider
        capture tostring npi, replace
        
        * --- 2. DEMOGRAPHICS (LAST NAME / ORG NAME) ---
        capture rename nppes_provider_last_org_name last_name
        capture rename prvdr_last_org_name last_name
        capture rename prscrbr_last_org_name last_name       // Part D
        capture rename rndrng_prvdr_last_org_name last_name  // Provider Service
        
        * --- 3. DEMOGRAPHICS (FIRST NAME) ---
        capture rename nppes_provider_first_name first_name
        capture rename prvdr_first_name first_name
        capture rename prscrbr_first_name first_name         // Part D
        capture rename rndrng_prvdr_first_name first_name    // Provider Service
        
        * --- 4. DEMOGRAPHICS (CITY) ---
        capture rename nppes_provider_city city
        capture rename prvdr_city city
        capture rename prscrbr_city city         // Part D
        capture rename rndrng_prvdr_city city    // Provider Service
        
        * --- 5. DEMOGRAPHICS (STATE) ---
        capture rename nppes_provider_state state
        capture rename prvdr_state_abrvtn state
        capture rename prscrbr_state_abrvtn state        // Part D
        capture rename rndrng_prvdr_state_abrvtn state   // Provider Service
        
        * --- 6. DEMOGRAPHICS (ZIP) ---
        capture rename nppes_provider_zip zip_code
        capture rename nppes_provider_zip5 zip_code
        capture rename prvdr_zip zip_code
        capture rename rndrng_prvdr_zip5 zip_code        // Provider Service
        
        * --- 7. SPECIALTY ---
        capture rename provider_type specialty
        capture rename prvdr_spclty_type specialty
        capture rename cms_specialty_description specialty
        capture rename prscrbr_type specialty            // Part D
        capture rename rndrng_prvdr_type specialty       // Provider Service
        
        * --- 8. ENTITY TYPE (Individual 'I' vs Org 'O') ---
        capture rename nppes_entity_code entity_type
        capture rename entity_cd entity_type
        capture rename rndrng_prvdr_ent_cd entity_type   // Provider Service
        
        * --- 9. CLINICAL VARIABLES ---
        capture rename hcpcs_code hcpcs
        capture rename hcpcs_drug_ind is_drug_ind
        
        * Drug Names (Part D)
        capture rename gnrc_name generic_name
        capture rename drug_name generic_name
        
        * --- 10. CLEANUP ---
        capture tostring zip_code, replace
        capture tostring entity_type, replace
        
        * Save
        local saveName = subinstr("`file'", "_sample.dta", "_harmonized.dta", .)
        quietly save "`destDir'/`saveName'", replace
    }
}

display "----------------------------------------------------"
display "CMS Harmonization Complete. All prefixes (prscrbr/rndrng) handled."
log close