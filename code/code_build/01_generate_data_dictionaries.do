*===============================================================================
* SCRIPT: 01_generate_data_dictionaries.do
* PURPOSE: Automatically extracts all variables and labels from Master Panels.
*===============================================================================
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy/code/00_initialize.do"

* Ensure the output directory exists
capture mkdir "$projRoot/output/data_dictionaries"

display "Starting Data Dictionary Extraction..."

* Loop through each file directly to avoid macro-quote stripping errors
foreach file in "master_facility_inpatient_2013_2023" "master_facility_outpatient_asc_2015_2024" "master_provider_inpatient_2013_2023" "master_provider_outpatient_asc_2015_2023" {
    
    display "  > Processing: `file'"
    
    * Load the dataset
    use "$dataRoot/`file'.dta", clear
    
    * The 'describe, replace' command drops the actual data and replaces 
    * the dataset in memory with a list of the variables and their metadata!
    describe, replace clear
    
    * Keep only the useful metadata columns
    keep name type format varlab
    
    * Rename them to be clean and readable
    rename name Variable_Name
    rename type Data_Type
    rename format Stata_Format
    rename varlab Variable_Label
    
    * Export as a clean CSV
    export delimited using "$projRoot/output/data_dictionaries/`file'_dictionary.csv", replace
}

display "=== SUCCESS: ALL DATA DICTIONARIES GENERATED ==="
