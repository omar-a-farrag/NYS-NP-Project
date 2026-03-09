# Master Data Dictionary

## 1. Provider Behavior & Aggregates (`cms_phase3_inpatient_provider.dta`)
* **`tot_benes` / `tot_srvcs`:** Provider's total Medicare beneficiaries and services.
* **`partd_generic_rate`:** Rate of generic drug prescriptions (0.0 to 1.0).
* **`svc_em_upcode_rate`:** Ratio of high-intensity E&M claims to total E&M claims.
* **`mean_generic_rate` / `mean_upcode_rate`:** The *hospital's average* rates, allowing comparison of an individual provider to their peers at the exact same facility.
* **`prop_male_providers` / `prop_female_providers`:** The gender makeup of the hospital's affiliated staff.

## 2. HCAHPS Patient Satisfaction
* **`h_comp_1_a_p`:** % of patients who reported nurses "Always" communicated well.
* **`h_comp_2_a_p`:** % of patients who reported doctors "Always" communicated well.
* **`h_clean_hosp_a_p` / `h_quiet_hosp_a_p`:** % reporting room was "Always" clean / quiet.
* **`h_hosp_rating_9_10`:** % rating the hospital a 9 or 10 overall.

## 3. Inpatient Clinical Quality
* **`rrp_excess_ratio_ami`, `_hf`, `_pn`:** Readmission Reduction Program Excess Ratio. $> 1.0$ indicates worse than expected performance and triggers a financial penalty.
* **`hac_total_score`:** Hospital-Acquired Condition Score (1-10). Higher is worse (more infections).
* **`hvbp_tps_score`:** Hospital Value-Based Purchasing Score (0-100). Higher is better.
* **`mspb_score`:** Medicare Spending per Beneficiary index. $< 1.0$ is more efficient than average.

## 4. Outpatient Environment (HOPD & ASC)
* **`hopd_op_8_score` / `hopd_op_10_score`:** Imaging Efficiency (MRIs / CTs). Higher % is worse (wasteful/defensive medicine).
* **`hopd_op_18_score`:** Median ED wait time (minutes).
* **`asc_rate_1` - `asc_rate_4`:** Severe freestanding complications (Burns, Falls, Wrong Site, Hospital Transfers). Rate per 1,000 admissions.
* **`asc_rate_12`:** 7-Day Risk-Standardized Hospital Visit Rate after an ASC surgery. Lower is better.