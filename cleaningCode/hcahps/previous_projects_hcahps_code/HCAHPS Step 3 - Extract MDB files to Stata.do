global main "~/Dropbox/Overprescription/HCAHP"

*** 2008
cd "$main/hcahps2008"
foreach v in dbo_vwHQI_FTNT dbo_vwHQI_HOSP dbo_vwHQI_HOSP_MSR_XWLK dbo_vwHQI_PCTL_MSR_XWLK dbo_vwHQI_HOSP_MORTALITY_XWLK dbo_vwHQI_HOSP_HCAHPS_MSR dbo_vwHQI_HOSP_MPV_MSR {
	clear
	odbc load, table("`v'")
	save `v'.dta, replace
}

*** 2009
cd "$main/hcahps2009"
foreach v in dbo_vwHQI_FTNT dbo_vwHQI_HOSP dbo_vwHQI_HOSP_HCAHPS_MSR  dbo_vwHQI_HOSP_MORTALITY_READM_XWLK  dbo_vwHQI_HOSP_MPV_MSR dbo_vwHQI_HOSP_MSR_XWLK  dbo_vwHQI_HOSP_MSR_XWLK  dbo_vwHQI_PCTL_MSR_XWLK  {
	clear
	odbc load, table("`v'")
	save `v'.dta, replace
}

*** 2010
cd "$main/hcahps2010"
foreach v in dbo_vwHQI_FTNT dbo_vwHQI_HOSP dbo_vwHQI_HOSP_HCAHPS_MSR dbo_vwHQI_HOSP_IMG_XWLK  dbo_vwHQI_HOSP_MORTALITY_READM_XWLK   dbo_vwHQI_HOSP_MPV_MSR  dbo_vwHQI_HOSP_MSR_XWLK  dbo_vwHQI_HOSP_STRUCTURAL_XWLK dbo_vwHQI_PCTL_MSR_XWLK  {
	clear
	odbc load, table("`v'")
	save `v'.dta, replace
}

*** 2011
cd "$main/hcahps2011"
foreach v in dbo_vwHQI_FTNT dbo_vwHQI_HOSP dbo_vwHQI_HOSP_HCAHPS_MSR dbo_vwHQI_HOSP_IMG_XWLK  dbo_vwHQI_HOSP_MORTALITY_READM_XWLK   dbo_vwHQI_HOSP_MPV_MSR  dbo_vwHQI_HOSP_MSR_XWLK  dbo_vwHQI_HOSP_STRUCTURAL_XWLK dbo_vwHQI_PCTL_MSR_XWLK vwHQI_HOSP_HAC vwMeasure_Dates vwHQI_HOSP_AHRQ {
	clear
	odbc load, table("`v'")
	save `v', replace
}

*** The following not needed

/*
*** 2012
cd "$main/hcahps2012"
foreach v in dbo_vwHQI_FTNT dbo_vwHQI_HOSP dbo_vwHQI_HOSP_HCAHPS_MSR dbo_vwHQI_HOSP_IMG_XWLK  dbo_vwHQI_HOSP_MORTALITY_READM_XWLK   dbo_vwHQI_HOSP_MPV_MSR  dbo_vwHQI_HOSP_MSR_XWLK  dbo_vwHQI_HOSP_STRUCTURAL_XWLK dbo_vwHQI_PCTL_MSR_XWLK vwHQI_HOSP_HAC vwMeasure_Dates vwHQI_HOSP_AHRQ vwHQI_HOSP_HAI vwHQI_HOSP_SPP dbo_vwHQI_HOSP_ED dbo_vwHQI_HOSP_IMM vwHQI_READM_REDUCTION {
	clear
	odbc load, table("`v'")
	save `v', replace
}
*** 2012
cd "$main/hcahps2012"
foreach v in dbo_vwHQI_HOSP_HCAHPS_MSR {
	clear
	odbc load, table("`v'")
	save `v', replace
}


*** 2013
cd "$main/hcahps2013"
foreach v in dbo_vwHQI_HOSP vwMeasure_Dates dbo_vwHQI_FTNT vwHQI_HOSP_AHRQ dbo_vwHQI_HOSP_ED vwHQI_HOSP_HAC vwHQI_HOSP_HAI dbo_vwHQI_HOSP_HCAHPS_MSR Hvbp_ami_05_28_2013 Hvbp_hai_05_28_2013 Hvbp_hcahps_05_28_2013 Hvbp_hf_05_28_2013 Hvbp_pn_05_28_2013 Hvbp_scip_05_28_2013 Hvbp_tps_05_28_2013 dbo_vwHQI_HOSP_IMG_XWLK dbo_vwHQI_HOSP_IMM dbo_vwHQI_HOSP_MORTALITY_READM_XWLK dbo_vwHQI_HOSP_MPV_MSR vwHQI_HOSP_SPP dbo_vwHQI_HOSP_STRUCTURAL_XWLK vwHQI_READM_REDUCTION dbo_vwHQI_HOSP_MSR_XWLK dbo_vwHQI_PCTL_MSR_XWLK  {
	clear
	odbc load, table("`v'")
	save `v', replace
}
*** 2013
cd "$main/hcahps2013"
foreach v in dbo_vwHQI_HOSP_HCAHPS_MSR {
	clear
	odbc load, table("`v'")
	save `v', replace
}

*** 2014
cd "$main/hcahps2014"
foreach v in FY2013_Distribution_of_Net_Change_in_Base_Op_DRG_Payment_Amt FY2013_Net_Change_in_Base_Op_DRG_Payment_Amt  FY2013_Percent_Change_in_Base_Operating_DRG_Payment_Amount  FY2013_Value_Based_Incentive_Payment_Amount HOSPITAL_QUARTERLY_HAC_DOMAIN_HOSPITAL_11_24_2014  HOSPITAL_QUARTERLY_QUALITYMEASURE_IPFQR_HOSPITAL HQI_FTNT HQI_HOSP  HQI_HOSP_AMI_Payment  HQI_HOSP_HAI  HQI_HOSP_HCAHPS  HQI_HOSP_IMG  HQI_HOSP_MSPB  HQI_HOSP_MV  HQI_HOSP_ReadmCompDeath  HQI_HOSP_STRUCTURAL HQI_HOSP_TimelyEffectiveCare HQI_OP_Procedure_Volume Hvbp_ami_10_28_2014 Hvbp_efficiency_10_28_2014 Hvbp_hai_10_28_2014 Hvbp_hcahps_10_28_2014 Hvbp_hf_10_28_2014 Hvbp_outcome_10_28_2014 Hvbp_pn_10_28_2014 Hvbp_quarters Hvbp_scip_10_28_2014 HVBP_TPS_10_28_2014 Measure_Dates PCH_CancerSpecificMeasures_Hospital vwHQI_READM_REDUCTION  { 
	clear
	odbc load, table("`v'")
	save `v', replace
}

