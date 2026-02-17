# Data Dictionary: CMS Master Panels

## 1. Individual Provider Panel (`cms_master_provider_panel.dta`)
*Unit of Observation: One row per NPI per Year.*

### Identifiers & Demographics
| Variable | Description | Source |
| :--- | :--- | :--- |
| `npi` | National Provider Identifier. 10-digit unique ID. | CMS Summary |
| `year` | Calendar year of service. | All |
| `last_name` | Last name of the provider. | CMS Summary |
| `first_name` | First name of the provider. | CMS Summary |
| `gender` | Provider gender (M/F). | Affiliation |
| `grad_year` | Year the provider graduated from medical school. | Affiliation |
| `grad_decade` | Categorical decade of graduation (e.g., "1990s"). | Derived |
| `cms_specialty` | Primary specialty as recorded in Part B claims. | CMS Summary |
| `credential` | Medical credential (MD, DO, NP, PA). | Affiliation |
| `zip_code` | Zip code of the provider's primary practice location. | Affiliation |

### Clinical Phenotypes (The "Lens")
| Variable | Description | Source |
| :--- | :--- | :--- |
| `partd_generic_rate` | **Cost Consciousness.** The ratio of generic claims to total Part D claims. $1 - (Brand / Total)$. | Part D |
| `partd_high_cost_rate` | **Revenue Seeking.** The proportion of drug claims falling into the top 25th percentile of cost *within their specific therapeutic class*. | Part D |
| `partd_opioid_rate` | **Risk Taking.** The ratio of Schedule II/III (Strong) opioids to total opioid claims. | Part D |
| `svc_em_upcode_rate` | **Revenue Seeking.** The ratio of high-complexity (Level 4 & 5) Evaluation & Management visits to total E&M visits. | Service |
| `svc_img_adv_rate` | **Technology Intensity.** The ratio of Advanced Imaging (CT, MRI, PET) to total imaging services. | Service |
| `partb_toradol_count` | **Risk Taking.** Raw count of Ketorolac injections administered. | Part B |
| `svc_mri_spine_count` | **Low Value Care.** Raw count of spine MRIs ordered. | Service |

### Volume & Patient Case Mix
| Variable | Description | Source |
| :--- | :--- | :--- |
| `tot_benes` | The total number of unique Medicare beneficiaries treated. | CMS Summary |
| `tot_srvcs` | The total number of services provided. | CMS Summary |
| `tot_sbmtd_chrg` | Total charges submitted by the provider to Medicare. | CMS Summary |
| `bene_avg_risk_scre` | Average Hierarchical Condition Category (HCC) risk score of the provider's patients. Higher scores indicate sicker patients. | CMS Summary |
| `bene_avg_age` | Average age of beneficiaries treated. | CMS Summary |
| `bene_cc_depr` | Count of beneficiaries with a chronic condition of depression. | CMS Summary |
| `bene_cc_diab` | Count of beneficiaries with a chronic condition of diabetes. | CMS Summary |
| `bene_race_black_cnt`| Count of beneficiaries identified as Black/African American. | CMS Summary |
| `bene_dual_cnt` | Count of beneficiaries dually eligible for Medicare and Medicaid (proxy for low socioeconomic status). | CMS Summary |

---

## 2. Facility Master Panel (`cms_master_facility_panel.dta`)
*Unit of Observation: One row per CCN per Year.*

### Identifiers
| Variable | Description | Source |
| :--- | :--- | :--- |
| `ccn` | CMS Certification Number (Facility ID). | Affiliation |
| `year` | Calendar year. | All |

### "Clinical Culture" (Aggregated Scores)
| Variable | Description | Aggregation Logic |
| :--- | :--- | :--- |
| `mean_generic_rate` | Average Generic Fill Rate of all credentialed providers. | Unweighted Mean |
| `mean_opioid_rate` | Average Opioid Intensity of all credentialed providers. | Unweighted Mean |
| `mean_upcode_rate` | Average E&M Upcoding Rate of all credentialed providers. | Unweighted Mean |
| `prop_male_providers`| Proportion of credentialed providers who are Male. | Unweighted Mean |
| `prop_grad_1990s` | Proportion of credentialed providers who graduated in the 1990s. | Unweighted Mean |

### "Clinical Culture" vs. "Patient Exposure" Metrics
*We calculate clinical phenotypes in two ways to answer different research questions.*

| Variable | Type | Description | Aggregation Logic |
| :--- | :--- | :--- | :--- |
| `mean_generic_rate` | Culture | Average Generic Fill Rate of all credentialed providers. | Unweighted Mean |
| `wgt_generic_rate` | Exposure | Patient-weighted Generic Fill Rate (adjusted by total beneficiaries). | Weighted Mean |
| `mean_opioid_rate` | Culture | Average Opioid Intensity of all credentialed providers. | Unweighted Mean |
| `wgt_opioid_rate` | Exposure | Patient-weighted Opioid Intensity (adjusted by total beneficiaries). | Weighted Mean |
| `mean_highcost_rate` | Culture | Average frequency of prescribing top-tier cost drugs. | Unweighted Mean |
| `wgt_highcost_rate` | Exposure | Patient-weighted frequency of prescribing top-tier cost drugs. | Weighted Mean |
| `mean_upcode_rate` | Culture | Average E&M Upcoding Rate of all credentialed providers. | Unweighted Mean |
| `wgt_upcode_rate` | Exposure | Patient-weighted E&M Upcoding Rate. | Weighted Mean |
| `mean_img_adv_rate` | Culture | Average Advanced Imaging intensity (CT/MRI ratio). | Unweighted Mean |
| `wgt_img_adv_rate` | Exposure | Patient-weighted Advanced Imaging intensity. | Weighted Mean |


### Facility Volume & Patient Mix
| Variable | Description | Aggregation Logic |
| :--- | :--- | :--- |
| `hosp_tot_benes` | Sum of unique beneficiaries treated by all affiliated providers. | Sum |
| `hosp_tot_chrg` | Total charges submitted by all affiliated providers. | Sum |
| `doc_count` | Count of unique NPIs affiliated with this facility. | Count |
| `hosp_avg_risk_score`| Weighted average HCC risk score of the hospital's patient population. | Weighted Mean (by Benes) |
| `hosp_bene_black` | Total number of Black beneficiaries treated by affiliated providers. | Sum |