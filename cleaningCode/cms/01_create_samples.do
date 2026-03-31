*===============================================================================
* SCRIPT: 01_create_samples.do
* PURPOSE: Creates representative 5% samples from raw CMS CSVs.
* AUTHOR:  Omar Farrag
* DATE:    2026-02-07
*===============================================================================
clear

* --- 0. SET LOGGING COMPONENT ---
global component "cms"
global script_name "01_create_samples"
* --- 1. INITIALIZE ENVIRONMENT ---
* (Keep your absolute path here)
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/general_cms_data/cleaningCode/00_initialize.do"

*===============================================================================
* BEGIN SCRIPT
*===============================================================================

display as text "Starting Sample Creation..."

* Loop through the three main data folders
foreach f in by_provider by_provider_service partD {
    
    display "----------------------------------------------------"
    display "PROCESSING FOLDER: `f'"
    
    * 1. Define Paths
    local sourceDir "$cmsRoot/`f'/all_depts/csv"

    if "$test" == "no" {
        local destDir "$cmsRoot/`f'/dta/full_sample"
        display as text "  > MODE: 100% Full Sample"
    }
    else {
        local destDir "$cmsRoot/`f'/dta/5pct_sample"
        display as text "  > MODE: 5% Testing Sample"
    }
	
    * 2. Create Output Directories
    capture mkdir "$cmsRoot/`f'/dta"
    capture mkdir "`destDir'"
    
    * 3. Get List of CSVs
    local myFiles : dir "`sourceDir'" files "*.csv"
    
    * --- THE FIX IS IN THE LINE BELOW (Removed the word 'local') ---
    foreach file in `myFiles' {
        
        display as text "  > Sampling: `file'..."
        
        * Import
        quietly import delimited "`sourceDir'/`file'", clear varnames(1) case(lower)
		
        
        * Save
        local saveName = subinstr("`file'", ".csv", "", .)
		* CONDITIONALLY Create 5% Sample
		if "$test" == "yes" {
			set seed 12345 
			sample 5
			quietly save "`destDir'/`saveName'_sample.dta", replace
		}
		else {
			quietly save "`destDir'/`saveName'.dta", replace
		}
    }
}

display "----------------------------------------------------"
display "DONE! Check your folders: cms/.../dta/5pct_sample"
log close