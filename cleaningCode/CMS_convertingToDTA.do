/*
****************************************************************************
Converting CSVs to DTA files and Identifying Drugs
Omar Farrag
Created on: 11/19/2025
Last edited on: 

Three CMS datasets: By Provider (P); By Provider and Service (P&S); By Provider and Drug (Part D)
*/
******************************************************************************
clear all
cls
set more off

*===============================================================================
* SECTION 0: Set up directory path and log file
*===============================================================================
local dataDir "D:/Research/data/cms"

cap log close
local datetime : di %tcCCYY.NN.DD!_HH.MM.SS `=clock("$S_DATE $S_TIME", "DMYhms")'
local logfile "D:/Research/data/cleaningCode/logs/CMS_convertToDTA_`datetime'.smcl"
log using "`logfile'", text
display "CMS Conversion log file initiated at: `logfile'"


*===============================================================================
* SECTION 1: Create the dta files
*===============================================================================

* Need to import the Part D CSV files and convert to a data file that Stata can edit
forval yyyy=2013/2021 {
	import delimited using "`dataDir'/partD/Part_D_`yyyy'", clear
	gen Year=`yyyy'
	*destring, replace ignore ("$" "," "%")
	
	drop Prscrbr_Last_Org_Name
	drop Prscrbr_First_Name
	drop Prscrbr_Type_Src
	drop GE65_Sprsn_Flag
	drop GE65_Bene_Sprsn_Flag
     
********************************************************************************
	* Keeping below commented out for now -- thiskeeps only certain drugs and 
	* codes them as either Opioid or Antibiotic. For now I want to look at all 
	* prescribing -- can filter this later. 
********************************************************************************

/*
	keep if gnrc_name=="Hydrocodone/Acetaminophen" | gnrc_name=="Oxycodone Hcl/Acetaminophen" | gnrc_name=="Oxycodone Hcl" | gnrc_name=="Oxymorphone Hcl" | gnrc_name=="Morphine Sulfate"| gnrc_name=="Acetaminophen With Codeine"| gnrc_name=="Acetaminophen with Codeine"| gnrc_name=="Fentanyl" | gnrc_name=="Fentanyl Citrate" | gnrc_name=="Hydromorphone Hcl" | gnrc_name=="Tapentadol Hcl"| gnrc_name=="Methadone Hcl"| gnrc_name=="Amoxicillin"| gnrc_name=="Amoxicillin/Potassium Clav" | gnrc_name=="Doxycycline Hyclate" | gnrc_name=="Doxycycline Monohydrate"| gnrc_name=="Ciprofloxacin Hcl"| gnrc_name=="Cephalexin"| gnrc_name=="Clindamycin Phosphate"| gnrc_name=="Clindamycin Hcl"| gnrc_name=="Metronidazole"| gnrc_name=="Azithromycin"| gnrc_name=="Levofloxacin In Dextrose 5 %"| gnrc_name=="Levofloxacin"
	
	gen byte iAntibiotics = 0
    gen byte iOpioid = 0
	
	replace iAntibiotics = 1 if gnrc_name=="Amoxicillin"| gnrc_name=="Amoxicillin/Potassium Clav" | gnrc_name=="Doxycycline Hyclate" | gnrc_name=="Doxycycline Monohydrate"| gnrc_name=="Ciprofloxacin Hcl"| gnrc_name=="Cephalexin"| gnrc_name=="Clindamycin Phosphate"| gnrc_name=="Clindamycin Hcl"| gnrc_name=="Metronidazole"| gnrc_name=="Azithromycin"| gnrc_name=="Levofloxacin In Dextrose 5 %"| gnrc_name=="Levofloxacin"
	
	replace iOpioid = 1 if gnrc_name=="Hydrocodone/Acetaminophen" | gnrc_name=="Oxycodone Hcl/Acetaminophen" | gnrc_name=="Oxycodone Hcl" | gnrc_name=="Oxymorphone Hcl" | gnrc_name=="Morphine Sulfate"| gnrc_name=="Acetaminophen With Codeine"| gnrc_name=="Acetaminophen with Codeine"| gnrc_name=="Fentanyl" | gnrc_name=="Fentanyl Citrate" | gnrc_name=="Hydromorphone Hcl" | gnrc_name=="Tapentadol Hcl"| gnrc_name=="Methadone Hcl"
*/ 

	* rename for clarity and to match that of the P and P&S sets
	rename *, lower
	rename prscrbr_npi rndrng_npi
	rename prscrbr_state_abrvtn rndrng_prvdr_state_abrvtn
	rename prscrbr_state_fips rndrng_prvdr_state_fips
	rename prscrbr_type rndrng_prvdr_type
	rename prscrbr_state_abrvtn rndrng_prvdr_state_abrvtn

	*gen byte notnumeric = real(rndrng_srvdr_state_fips)==.
	*destring rndrng_prvdr_state_fips, replace ignore ("A" "B" "C" "D" "E")
	*drop notnumeric
	
	save "`dataDir'/partD/Part_D_`yyyy'.dta", replace 
	}

* Do the same for the P&S and P sets

* P&S - import
forval yyyy=2013/2021 {
	import delimited using "`dataDir'/by_provider_service/Provider_Service_`yyyy'.csv", clear
    rename year Year
	*destring, replace ignore ("$" "," "%")
	
	drop Rndrng_Prvdr_Last_Org_Name
	drop Rndrng_Prvdr_First_Name
	drop Rndrng_Prvdr_MI
	drop Rndrng_Prvdr_St1
	drop Rndrng_Prvdr_St2
	
	rename *, lower
	
	*gen byte notnumeric = real(rndrng_srvdr_state_fips)==.
	*destring rndrng_prvdr_state_fips, replace ignore ("A" "B" "C" "D" "E")
	*drop notnumeric
	
********************************************************************************
	* Keeping below commented out for now -- will return when I can identify all
	* opioids and antibiotics in hcpcs codes
********************************************************************************

/*
	gen byte iAntibiotics = 0
    gen byte iOpioid = 0
	replace iOpioid = 1 if inlist(hcpcs_cd,"J0131","J2410","J2270","J2274","J0745","J1170","J1230","J1885","J3010")
	replace iOpioid = 1 if inlist(hcpcs_cd, "J0592", "J0571", "J2175", "J2180", "J1170", "J1230")

	replace iAntibiotics = 1 if inlist(hcpcs_cd, "J0706", "J0456", "Q0144", "J1956", "J0696", "J0278", "J1580", "J1850", "J1840")
	replace iAntibiotics = 1 if inlist(hcpcs_cd, "J7682", "J7685", "J3260", "J3260", "J3000", "J1335", "J1267", "J0743", "J2185")
	replace iAntibiotics = 1 if inlist(hcpcs_cd, "J0690", "J0710", "J1890", "J0694", "J0697", "J0698", "J0713", "J0714", "J0715")
	replace iAntibiotics = 1 if inlist(hcpcs_cd, "J0692", "J0712", "J3370", "J3095", "J0875", "J2407", "J2010", "J0878", "J1364")
	replace iAntibiotics = 1 if inlist(hcpcs_cd, "J3090", "J0290", "J0295", "J2700", "J0561", "J0558", "J2540", "J2510", "J2543")
	replace iAntibiotics = 1 if inlist(hcpcs_cd, "J2543", "J0706", "J1590", "J1956", "J2280", "J2265", "J2460", "J0120", "J3000") 
	replace iAntibiotics = 1 if inlist(hcpcs_cd, "J2770", "J7682", "J3243", "J0696", "J2020", "J0295", "J0720")
	
	collapse (sum) tot_drug_cst tot_benes tot_srvcs, by(rndrng_npi iAntibiotics iOpioid Year)

*/
	
	save "`dataDir'/by_provider_service/Provider_Service_`yyyy'.dta", replace  
	}

* P - import
forval yyyy=2013/2021 {
	import delimited using "`dataDir'/by_provider/Provider_`yyyy'.csv", clear
    rename year Year
	*destring, replace ignore ("$" "," "%")
	
	drop Rndrng_Prvdr_Last_Org_Name
	drop Rndrng_Prvdr_First_Name
	drop Rndrng_Prvdr_MI
	drop Rndrng_Prvdr_St1
	drop Rndrng_Prvdr_St2
	
	rename *, lower

	*gen byte notnumeric = real(rndrng_srvdr_state_fips)==.
	*destring rndrng_prvdr_state_fips, replace ignore ("A" "B" "C" "D" "E")
	*drop notnumeric
	
	save "`dataDir'/by_provider/Provider_`yyyy'.dta", replace  
	}

*===============================================================================
* SECTION 6: HOUSEKEEPING
*===============================================================================
display "Master script finished. Closing log."
log close
exit
	