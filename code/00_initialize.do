*===============================================================================
* SCRIPT: 00_initialize.do
* PROJECT: NYS NP Scope of Practice Policy
* PURPOSE: Sets globals, paths, and builds output directory tree.
*===============================================================================
clear all
set more off
set graphics off // Turn off graph rendering to speed up massive loops

* --- 1. SET PROJECT PATHS ---
global projRoot "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/projects/NYS_npPolicy"
global dataRoot "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/general_cms_data/publishable_data"
global outRoot "$projRoot/output"

* --- 2. BUILD THE DIRECTORY TREE ---
local settings "in_patient out_patient"
local formats "tables bar_graphs heatmaps maps"

capture mkdir "$projRoot/output"
capture mkdir "$outRoot"

foreach set of local settings {
    capture mkdir "$outRoot/summary_stats/`set'"
    foreach fmt of local formats {
        capture mkdir "$outRoot/summary_stats//`set'/`fmt'"
    }
}

* --- 3. INSTALL REQUIRED PACKAGES ---
capture ssc install estout, replace
capture ssc install heatplot, replace
capture ssc install palettes, replace
capture ssc install colrspace, replace
capture ssc install maptile, replace
capture ssc install spmap, replace

* Install the US State geography template for maptile (only runs if not installed)
capture maptile_install using "http://fmwww.bc.edu/repec/bocode/g/geo2state.zip"

* ===============================================================================
* LOGGING SETUP
* ===============================================================================
global logRoot "$projRoot/code/logs"
capture mkdir "$logRoot"

* Close any logs left open from previous crashed runs
capture log close _all

*===============================================================================
* MASTER VARIABLE LISTS (Global Macros)
*===============================================================================

* --- PROVIDER OVERLAP (Inpatient & Outpatient Providers) ---
* Means/Rates: Risk scores, upcoding, prescribing, and financial totals
global prov_overlap_means "bene_avg_risk_scre partb_em_upcode_rate partd_opioid_rate partd_opioid_strong_rate partd_generic_rate partd_high_cost_rate tot_sbmtd_chrg tot_pymt_amt partd_cst_total mips_final_score mips_quality_score mips_cost_score mips_pi_score"

* Sums/Counts: Workforce demographics, patient volume, and patient demographics
global prov_overlap_sums  "np_count pa_count md_count female_np_count female_pa_count female_md_count tot_benes bene_dual_cnt bene_race_black_cnt bene_race_hspnc_cnt bene_race_wht_cnt bene_male_cnt"


* --- OUTPATIENT SPECIFIC ---
* Provider Outpatient: MIPS final, quality, cost, and promoting interoperability (PI)
global out_prov_means ""

* Facility ASC: Safety metrics (Burns, Falls, Flu Vac, etc.)
global out_fac_means  "asc_rate_1 asc_rate_2 asc_rate_8"


* --- INPATIENT SPECIFIC ---
* Facility Inpatient: HCAHPS, Infections, Readmissions, Mortality, and Structure
global in_fac_means "h_hosp_rating_9_10 h_hosp_rating_0_6 hac_total_score rrp_excess_ratio_ami rrp_excess_ratio_hf rrp_excess_ratio_pn mortality_rate_ami mortality_rate_hf mortality_rate_pn fac_wgt_em_upcode_rate is_gov"


*===============================================================================
* MASTER FILTER & SUBGROUP LISTS (For Future Analysis)
*===============================================================================
/*
  These dimensions define the specific subpopulations and structural cuts we will 
  evaluate during the outcomes analysis and scoring phase.
  
  1. STATE POLICY ENVIRONMENT:
     - np_authority (Restricted, Reduced, Full Practice)
  
  2. FACILITY OWNERSHIP & STRUCTURE:
     - own_category (Government vs. Non-Profit vs. For-Profit)
     - is_gov (Binary indicator)
  
  3. PROVIDER CHARACTERISTICS:
     - prov_type (MD vs NP vs PA)
     - is_female (Provider Gender)
     - cms_specialty (General Medicine / Primary Care vs. High-Acuity/Surgical)
       * Note: Focus will be on specialties where NPs/PAs have highest authority/volume.
  
  4. PATIENT DEMOGRAPHICS (Panel Level):
     - dual_rate (Proportion of Dual-Eligible/Medicaid patients)
     - pct_female_bene (Proportion of female beneficiaries)
     - pct_minority_bene (Proportion of Black/Hispanic beneficiaries)
*/

* --- SPECIALTY & DEMOGRAPHIC GROUPS ---
global gen_med_specs `" "Family Practice" "Emergency Medicine" "General Practice" "Hospitalist" "Internal Medicine" "Nurse Practitioner" "Pain Management" "Physician Assistant" "'

*===============================================================================
* CENTRALIZED TAXONOMY & LOGIC BLOCKS
*===============================================================================

* 1. NP STATE AUTHORITY LOGIC
global cond_full_prac inlist(state_str, "AZ", "CO", "CT", "DC", "HI", "ID", "IA", "MD", "MA") | inlist(state_str, "MN", "MT", "NE", "NV", "NH", "NM", "NY", "ND", "OR") | inlist(state_str, "RI", "SD", "VT", "WA", "WY")
global cond_red_prac inlist(state_str, "AL", "AS", "DE", "IL", "IN", "KS", "KY", "LA", "MS") | inlist(state_str, "NJ", "OH", "PA", "UT", "WI")
global cond_res_prac inlist(state_str, "CA", "FL", "GA", "MI", "MO", "NC", "OK", "SC", "TN") | inlist(state_str, "TX", "VA")

* 2. GENERAL MEDICINE SPECIALTY LOGIC
global cond_gen_med inlist(trim(upper(spec_str)), "FAMILY PRACTICE","FAMILY MEDICINE", "EMERGENCY MEDICINE", "GENERAL PRACTICE", "HOSPITALIST") | inlist(trim(upper(spec_str)), "INTERNAL MEDICINE", "NURSE PRACTITIONER", "PAIN MANAGEMENT", "PHYSICIAN ASSISTANT")

* 2B. PRIMARY CARE SPECIALTY LOGIC (Subset of Gen Med)
global cond_prim_care inlist(trim(upper(spec_str)), "FAMILY PRACTICE","FAMILY MEDICINE", "GENERAL PRACTICE")

* 3. HOSPITAL OWNERSHIP LOGIC
global cond_own_gov strpos(upper(own_str), "GOVERNMENT") | inlist(upper(own_str), "DEPARTMENT OF DEFENSE", "TRIBAL", "VETERANS HEALTH ADMINISTRATION")
global cond_own_nonprof strpos(upper(own_str), "VOLUNTARY") | strpos(upper(own_str), "NON-PROFIT")
global cond_own_forprof strpos(upper(own_str), "PROPRIETARY") | strpos(upper(own_str), "FOR-PROFIT")

display "=== NYS_npPolicy ENVIRONMENT INITIALIZED & DIRECTORIES BUILT ==="
