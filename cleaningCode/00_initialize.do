*===============================================================================
* SECTION 1: MASTER GLOBAL SWITCHES & DYNAMIC PATHS
*===============================================================================
global who = "Omar"
global test = "no" /// enter "yes" for 5pct sample or "no" for full sample

* Root Path
if "$who" == "Omar" {
    global projectRoot "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/general_cms_data"
}

* Dynamic Subpaths
global cmsRoot      "$projectRoot/cms"
global hcahpsRoot   "$projectRoot/hcahps"
global mipsRoot     "$projectRoot/cliniciansAndGroups"
global codeDir      "$projectRoot/cleaningCode"
global outputRoot   "$projectRoot/outputs_while_cleaning" 
global dictionary   "$projectRoot/dictionaries_and_crosswalks"

global phase1		"$outputRoot/cleaned_data/phase1_cms_services"
global phase2		"$outputRoot/cleaned_data/phase2_hcahps"
global phase3		"$outputRoot/cleaned_data/phase3_inpatient_outpatient"
global phase4 		"$outputRoot/cleaned_data/phase4_mips"
global master		"$outputRoot/cleaned_data/master"

global figDir       "$outputRoot/figures"
global tabDir       "$outputRoot/tables"

capture mkdir "$outputRoot"
capture mkdir "$figDir"
capture mkdir "$tabDir"

*===============================================================================
* SECTION 2: HANDLE SAMPLE VS. FULL DATA LOGIC
*===============================================================================
if "$test" == "yes" {
    global loadPath     "dta/5pct_sample"
    global fileSuffix   "_sample"
    global parseType    "TEST (5% Sample)"
}
else {
    global loadPath     "dta/full_sample"
    global fileSuffix   ""
    global parseType    "PRODUCTION (Full Data)"
}

*===============================================================================
* SECTION 3: DYNAMIC LOGGING CONFIGURATION
*===============================================================================
* Ensure component is defined (defaults to 'general' if forgotten)
if "$component" == "" global component "general"

* Define the specific log subfolder based on the component
global logDir "$codeDir/logs/$component"

* Build the directory tree safely
capture mkdir "$codeDir/logs"
capture mkdir "$logDir"

* Close any open logs
capture log close _all

* Ensure script name is defined (defaults to 'log' if forgotten)
if "$script_name" != "" {
    local nameStub "$script_name"
}
else {
    local nameStub "log"
}

* Create the timestamp
local date_stamp : di %tdCCYY.NN.DD date(c(current_date), "DMY")
local time_stamp : di %tcHH.MM.SS clock(c(current_time), "hms")
local datetime "`date_stamp'_`time_stamp'"

* Build final log path and initialize
local logfile "$logDir/`nameStub'_`datetime'.smcl"
log using "`logfile'", replace 

display "----------------------------------------------------------------"
display "  PROJECT:   CMS Provider Data Unification with HCAHPS and MIPS"
display "  PHASE:     $component"
display "  SCRIPT:    `nameStub'"
display "  LOG PATH:  `logfile'"
display "  MODE:      $parseType"
display "----------------------------------------------------------------"