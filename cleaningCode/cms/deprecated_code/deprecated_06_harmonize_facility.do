*===============================================================================
* SCRIPT: 06_harmonize_facility_v5.do
* PURPOSE: Standardizes Facility Affiliation files (2014-2023).
* FEATURES: Captures comprehensive provider attributes & Enforces Schema.
*===============================================================================

global component "mips"
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/general_cms_data/cleaningCode/00_initialize.do"

display as text "Starting Comprehensive Facility Harmonization (v5)..."

local sampleDir "$mipsRoot/facilityAffiliation/dta/5pct_sample"
local destDir   "$mipsRoot/facilityAffiliation/dta/harmonized"
capture mkdir "`destDir'"

local dtaFiles : dir "`sampleDir'" files "*_sample.dta"

foreach file in `dtaFiles' {
    
    quietly use "`sampleDir'/`file'", clear
    display "Processing `file'..."
    
    * --- 0. ADD YEAR ---
    if regexm("`file'", "20[0-9][0-9]") {
        local fileYear = regexs(0)
        gen int year = `fileYear'
    }
    
    *---------------------------------------------------------------------------
    * 1. IDENTIFIERS
    *---------------------------------------------------------------------------
    capture rename npi npi
    
    capture rename pacid pac_id
    capture rename ind_pac_id pac_id
    
    capture rename professionalenrollmentid enrollment_id
    capture rename pecos_id enrollment_id
    
    *---------------------------------------------------------------------------
    * 2. DEMOGRAPHICS
    *---------------------------------------------------------------------------
    capture rename gndr gender
    capture rename phy_gndr gender
    capture rename providergender gender
    
    capture rename cred credential
    capture rename crdntls credential
    capture rename credential credential
    
    capture rename grd_yr grad_year
    capture rename graduationyear grad_year
    
    *---------------------------------------------------------------------------
    * 3. SPECIALTIES
    *---------------------------------------------------------------------------
    capture rename pri_spec primary_specialty
    capture rename primaryspecialty primary_specialty
    
    capture rename sec_spec_1 secondary_specialty_1
    capture rename secondaryspecialty1 secondary_specialty_1
    
    capture rename sec_spec_2 secondary_specialty_2
    capture rename secondaryspecialty2 secondary_specialty_2
    
    capture rename sec_spec_3 secondary_specialty_3
    capture rename secondaryspecialty3 secondary_specialty_3
    
    capture rename sec_spec_4 secondary_specialty_4
    capture rename secondaryspecialty4 secondary_specialty_4
    
    capture rename all_sec_spec all_secondary_specialties
    capture rename allsecondaryspecialties all_secondary_specialties
    
    *---------------------------------------------------------------------------
    * 4. GROUP PRACTICE INFO
    *---------------------------------------------------------------------------
    capture rename grp_pac_id group_pac_id
    capture rename grouppracticepacid group_pac_id
    
    capture rename num_grp_mem num_group_members
    capture rename numberofgrouppracticemembers num_group_members
    
    *---------------------------------------------------------------------------
    * 5. ADDRESS / GEOGRAPHY
    *---------------------------------------------------------------------------
    capture rename st state
    capture rename state state
    
    capture rename zip zip_code
    capture rename zipcode zip_code
    
    *---------------------------------------------------------------------------
    * 6. QUALITY & PARTICIPATION
    *---------------------------------------------------------------------------
    * Medicare Assignment
    capture rename assgn accepts_assignment
    capture rename professionalacceptsmedicareassig accepts_assignment
    
    * Quality / MIPS / PQRS
    capture rename pqrs quality_participation
    capture rename participatinginpqrs quality_participation
    capture rename reportedqualitymeasures quality_participation
    
    * EHR
    capture rename ehr ehr_participation
    capture rename participatinginehr ehr_participation
    capture rename usedelectronichealthrecords ehr_participation
    
    * Million Hearts
    capture rename million_hearts heart_participation
    capture rename participatedinmillionhearts heart_participation
    capture rename committedtothehearthealthroughthe heart_participation
    
    *---------------------------------------------------------------------------
    * 7. HOSPITAL AFFILIATIONS (CCNs)
    *---------------------------------------------------------------------------
    * ERA 1: 2014-2016 (Wide, Cryptic)
    capture rename claimsbasedhospitalaffiliationcc ccn_1
    capture rename v30 ccn_2
    capture rename v32 ccn_3
    capture rename v34 ccn_4
    capture rename v36 ccn_5
    
    * ERA 2: 2017 (Wide, Descriptive)
    capture rename hospitalaffiliationccn1 ccn_1
    capture rename hospitalaffiliationccn2 ccn_2
    capture rename hospitalaffiliationccn3 ccn_3
    capture rename hospitalaffiliationccn4 ccn_4
    capture rename hospitalaffiliationccn5 ccn_5
    
    * ERA 3: 2018+ (Long Format - 'org_pac_id' is usually the facility)
    * We rename org_pac_id to ccn_1 so the reshape works later
    capture rename org_pac_id ccn_1
    capture rename facility_affiliation ccn_1
    
    *---------------------------------------------------------------------------
    * 8. SCHEMA ENFORCEMENT (The Magic Step)
    *---------------------------------------------------------------------------
    * We must ensure ALL variables exist, even if empty, so files match perfectly.
    
    local vars_to_keep "npi pac_id enrollment_id gender credential grad_year primary_specialty secondary_specialty_1 secondary_specialty_2 secondary_specialty_3 secondary_specialty_4 all_secondary_specialties group_pac_id num_group_members state zip_code accepts_assignment quality_participation ehr_participation heart_participation ccn_1 ccn_2 ccn_3 ccn_4 ccn_5 year"
    
    foreach v of local vars_to_keep {
        capture confirm variable `v'
        if _rc {
            * If variable missing, generate it as empty string
            quietly gen `v' = ""
        }
        else {
            * If exists, ensure it is string for safety
            capture tostring `v', replace
            capture replace `v' = "" if `v' == "."
        }
    }
    
    * Keep strictly the schema columns
    keep `vars_to_keep'
    
    * Save
    local saveName = subinstr("`file'", "_sample.dta", "_harmonized.dta", .)
    quietly save "`destDir'/`saveName'", replace
}

display "SUCCESS! Comprehensive Facility Harmonization Complete."