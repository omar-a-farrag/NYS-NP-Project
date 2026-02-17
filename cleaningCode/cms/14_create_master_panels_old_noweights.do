*===============================================================================
* SCRIPT: 14_create_master_panels_v10.do
* PURPOSE: Creates Master Panels. Handles variable drift & converts PCT to COUNTS.
*===============================================================================

global component "cms"
include "C:/Users/omarf/Dropbox/personal_files_omar_farrag/Research/general_cms_data/cleaningCode/00_initialize.do"

capture mkdir "$outputRoot/cleaned_data"

display as text "Building Master Panels (v10 - The Fix)..."

*-------------------------------------------------------------------------------
* STEP 1: PREPARE AFFILIATION NETWORK (Demographics + Links)
*-------------------------------------------------------------------------------
display "Step 1: Loading Affiliation Data..."
clear
local facilDir "$projectRoot/cliniciansAndGroups/facilityAffiliation/dta/harmonized"
local files : dir "`facilDir'" files "*_harmonized.dta"

tempfile raw_affil
save `raw_affil', emptyok

foreach f in `files' {
    use "`facilDir'/`f'", clear
    capture tostring zip_code, replace
    capture tostring group_pac_id, replace
    capture tostring num_group_members, replace
    append using `raw_affil'
    save `raw_affil', replace
}

use `raw_affil', clear

* A. Unique Affiliation Demographics
preserve
    keep npi year gender grad_year credential ///
         primary_specialty secondary_specialty_* all_secondary_specialties ///
         group_pac_id num_group_members state zip_code ///
         accepts_assignment quality_participation ehr_participation heart_participation
    
    rename primary_specialty affil_primary_spec
    rename state affil_state
    rename zip_code affil_zip
    
    replace gender = upper(gender)
    replace gender = "M" if gender == "MALE"
    replace gender = "F" if gender == "FEMALE"
    
    destring grad_year, replace force
    replace grad_year = . if grad_year < 1920 | grad_year > 2030
    
    duplicates drop npi year, force
    tempfile npi_demos
    save `npi_demos'
restore

* B. Network Link (NPI-CCN)
keep npi year ccn
drop if ccn == ""
duplicates drop npi year ccn, force
tempfile npi_ccn_link
save `npi_ccn_link'

*-------------------------------------------------------------------------------
* STEP 2: PREPARE CLINICAL MEASURES (Python)
*-------------------------------------------------------------------------------
display "Step 2: Importing Python Measures..."
import delimited "$outputRoot/cleaned_data/cms_aggregated_clinical_measures.csv", clear
tostring npi, replace
destring year, replace

gen partd_generic_rate = 1 - (partd_brand_claims / partd_total_claims)
gen partd_high_cost_rate = partd_empirical_high_cost_claims / partd_total_claims
gen partd_opioid_rate = partd_opioid_strong_claims / partd_opioid_claims
gen svc_em_upcode_rate = svc_em_high_intensity / svc_em_total
gen svc_img_adv_rate = svc_imaging_advanced / svc_imaging_total

foreach v of varlist *_rate {
    replace `v' = . if `v' < 0 | `v' > 1
}

tempfile clinical_measures
save `clinical_measures'

*-------------------------------------------------------------------------------
* STEP 3: PREPARE RICH PROVIDER SUMMARY
*-------------------------------------------------------------------------------
display "Step 3: Importing CMS Provider Summary..."
clear
local summaryDir "$cmsRoot/by_provider/dta/harmonized"
local files : dir "`summaryDir'" files "*_harmonized.dta"

tempfile master_vol
save `master_vol', emptyok

foreach f in `files' {
    use "`summaryDir'/`f'", clear
    tostring npi, replace
    
    * --- A. IDENTIFIERS (Handle the variations) ---
    * Some years use "nppes_...", some use "state" directly
    capture rename nppes_provider_last_org_name last_name
    capture rename nppes_provider_first_name first_name
    capture rename nppes_provider_city city
    
    * Handle State/Zip collision (affil vs cms)
    capture rename nppes_provider_state cms_state
    capture rename state cms_state
    capture rename rndrng_prvdr_st1 cms_address
    
    capture rename nppes_provider_zip cms_zip
    capture rename zip_code cms_zip
    
    capture rename provider_type cms_specialty
    capture rename specialty cms_specialty
    
    * --- B. FINANCIALS ---
    capture rename tot_submitted_chrg_amt tot_sbmtd_chrg
    capture rename tot_mdcr_alowd_amt     tot_alowd_amt
    capture rename tot_mdcr_pymt_amt      tot_pymt_amt
    
    * --- C. PATIENT ATTRIBUTES ---
    * (Note: bene_race_*_cnt usually exists as count)
    capture rename bene_race_b_cnt        bene_race_black_cnt
    capture rename bene_race_w_cnt        bene_race_wht_cnt
    capture rename bene_race_h_cnt        bene_race_hspnc_cnt
    capture rename bene_race_o_cnt        bene_race_othr_cnt
    
    * --- D. CHRONIC CONDITIONS (PERCENT TO COUNT CONVERSION) ---
    * The raw files have PCT (0-75 or 0-100). We need counts for aggregation.
    * We try to identify the variable, rename it to a temp name, then convert.
    
    * Depression
    capture rename bene_cc_depression     temp_depr_pct
    capture rename bene_cc_depr           temp_depr_pct
    capture rename bene_cc_bh_depress_v1_pct temp_depr_pct
    
    * Diabetes
    capture rename bene_cc_diabetes       temp_diab_pct
    capture rename bene_cc_diab           temp_diab_pct
    capture rename bene_cc_ph_diabetes_v2_pct temp_diab_pct
    
    * Hypertension
    capture rename bene_cc_hypertension   temp_hyp_pct
    capture rename bene_cc_hypert         temp_hyp_pct
    capture rename bene_cc_ph_hypertension_v2_pct temp_hyp_pct
    
    * Stroke
    capture rename bene_cc_stroke         temp_strk_pct
    capture rename bene_cc_strk           temp_strk_pct
    capture rename bene_cc_ph_stroke_tia_v2_pct temp_strk_pct
    
    * Append
    append using `master_vol'
    save `master_vol', replace
}

use `master_vol', clear
duplicates drop npi year, force
destring year, replace

* --- RECALCULATE COUNTS FROM PERCENTAGES ---
* Ensure tot_benes is numeric
capture destring tot_benes, replace force

* Helper to convert (PCT * BENES) / 100
foreach cond in depr diab hyp strk {
    capture confirm variable temp_`cond'_pct
    if !_rc {
        * Clean "<75" strings if they exist (sometimes CMS suppresses small cells)
        * Assuming variables are numeric or we destring them
        capture destring temp_`cond'_pct, replace force
        
        * Calculate Count
        gen bene_cc_`cond' = (temp_`cond'_pct / 100) * tot_benes
        replace bene_cc_`cond' = round(bene_cc_`cond')
    }
    else {
        gen bene_cc_`cond' = 0
    }
}

* Create Weights for Rollup
gen wgt_risk_score = bene_avg_risk_scre * tot_benes
gen wgt_age = bene_avg_age * tot_benes

* Ensure core variables exist for keep
foreach var in bene_race_black_cnt bene_race_hspnc_cnt bene_dual_cnt tot_benes tot_srvcs tot_sbmtd_chrg tot_alowd_amt tot_pymt_amt {
    capture confirm variable `var'
    if _rc {
        gen `var' = 0
    }
}

* Keep Rich Data
keep npi year entity_type last_name first_name city cms_state cms_zip cms_specialty ///
     tot_benes tot_srvcs tot_sbmtd_chrg tot_alowd_amt tot_pymt_amt ///
     drug_* med_* ///
     bene_avg_age bene_age_* ///
     bene_feml_cnt bene_male_cnt ///
     bene_race_* ///
     bene_dual_cnt bene_ndual_cnt ///
     bene_avg_risk_scre ///
     bene_cc_* wgt_*

tempfile cms_volume
save `cms_volume'

*-------------------------------------------------------------------------------
* STEP 4: CREATE PROVIDER MASTER PANEL
*-------------------------------------------------------------------------------
display "Step 4: Merging Everything..."

use `clinical_measures', clear
merge 1:1 npi year using `cms_volume', keep(master match) nogenerate
merge 1:1 npi year using `npi_demos', keep(master match) nogenerate

* Derived Variables
gen is_male = (gender == "M")
gen is_female = (gender == "F")

gen grad_decade = .
replace grad_decade = 1970 if grad_year < 1980 & !missing(grad_year)
replace grad_decade = 1980 if grad_year >= 1980 & grad_year < 1990
replace grad_decade = 1990 if grad_year >= 1990 & grad_year < 2000
replace grad_decade = 2000 if grad_year >= 2000 & grad_year < 2010
replace grad_decade = 2010 if grad_year >= 2010 & grad_year < 2020
replace grad_decade = 2020 if grad_year >= 2020 & !missing(grad_year)

label define decade_lbl 1970 "Pre-1980" 1980 "1980s" 1990 "1990s" 2000 "2000s" 2010 "2010s" 2020 "2020s"
label values grad_decade decade_lbl

gen grad_pre_1980 = (grad_year < 1980) if !missing(grad_year)
gen grad_1980s    = (grad_year >= 1980 & grad_year < 1990) if !missing(grad_year)
gen grad_1990s    = (grad_year >= 1990 & grad_year < 2000) if !missing(grad_year)
gen grad_2000s    = (grad_year >= 2000 & grad_year < 2010) if !missing(grad_year)
gen grad_2010s    = (grad_year >= 2010 & grad_year < 2020) if !missing(grad_year)
gen grad_2020s    = (grad_year >= 2020) if !missing(grad_year)

order npi year last_name first_name gender grad_year grad_decade ///
      cms_specialty affil_primary_spec credential ///
      city cms_state cms_zip affil_state affil_zip ///
      tot_benes tot_srvcs tot_sbmtd_chrg ///
      bene_avg_risk_scre bene_avg_age

save "$outputRoot/cleaned_data/cms_master_provider_panel.dta", replace
display "  > Saved Provider Panel."

*-------------------------------------------------------------------------------
* STEP 5: CREATE FACILITY MASTER PANEL
*-------------------------------------------------------------------------------
display "Step 5: Creating Facility Panel..."

use `npi_ccn_link', clear
merge m:1 npi year using "$outputRoot/cleaned_data/cms_master_provider_panel.dta"
keep if _merge == 3
drop _merge

collapse (mean) mean_generic_rate=partd_generic_rate ///
                mean_opioid_rate=partd_opioid_rate ///
                mean_upcode_rate=svc_em_upcode_rate ///
                mean_img_adv_rate=svc_img_adv_rate ///
                prop_male_providers=is_male ///
                prop_female_providers=is_female ///
                prop_grad_pre_1980=grad_pre_1980 ///
                prop_grad_1980s=grad_1980s ///
                prop_grad_1990s=grad_1990s ///
                prop_grad_2000s=grad_2000s ///
                prop_grad_2010s=grad_2010s ///
                prop_grad_2020s=grad_2020s ///
         (sum)  hosp_tot_benes=tot_benes ///
                hosp_tot_srvcs=tot_srvcs ///
                hosp_tot_chrg=tot_sbmtd_chrg ///
                hosp_bene_feml=bene_feml_cnt ///
                hosp_bene_male=bene_male_cnt ///
                hosp_bene_black=bene_race_black_cnt ///
                hosp_bene_hspnc=bene_race_hspnc_cnt ///
                hosp_bene_dual=bene_dual_cnt ///
                hosp_cc_depression=bene_cc_depr ///
                hosp_cc_diabetes=bene_cc_diab ///
                hosp_risk_numerator=wgt_risk_score ///
                hosp_age_numerator=wgt_age ///
                doc_count=partd_total_claims, ///
         by(ccn year)

gen hosp_avg_risk_score = hosp_risk_numerator / hosp_tot_benes
gen hosp_avg_age = hosp_age_numerator / hosp_tot_benes
drop hosp_risk_numerator hosp_age_numerator

save "$outputRoot/cleaned_data/cms_master_facility_panel.dta", replace
display "SUCCESS! Master Network Built (v10)."