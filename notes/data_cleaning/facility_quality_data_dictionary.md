# CMS Quality Data Dictionary (Inpatient & Outpatient)

## 1. INPATIENT QUALITY PANEL (`inpatient_quality_panel.csv`)
* **`rrp_excess_ratio_ami`, `_hf`, `_pn`**: Readmission Reduction Program Excess Ratio. (Continuous Ratio). This is the ratio of *predicted* 30-day readmissions to *expected* readmissions for Heart Attacks (AMI), Heart Failure (HF), and Pneumonia (PN). 
  * *Scale:* `1.0` is the national average. A score `< 1.0` means the hospital performed *better* than expected. `> 1.0` triggers a financial penalty.
* **`mortality_rate_ami`, `_hf`, `_pn`**: Risk-Standardized 30-Day Mortality Rate. (Percentage). The percentage of Medicare patients who died within 30 days of admission.
  * *Scale:* Lower is better.
* **`hvbp_tps_score`**: Hospital Value-Based Purchasing Total Performance Score. (Index). A composite score grading the hospital on clinical care, efficiency, and patient experience.
  * *Scale:* `0 to 100`. Higher is better. 
* **`hac_total_score`**: Hospital-Acquired Condition Total Score. (Index). Grades the hospital on rates of infections (CLABSI, CAUTI, MRSA) and surgical complications. 
  * *Scale:* `1 to 10`. **Higher is worse**.
* **`hac_payment_reduction`**: HAC Financial Penalty. (Binary). 
  * *Scale:* `1` = Hospital was in the worst national quartile and received a 1% Medicare payment penalty. `0` = No penalty.
* **`mspb_score`**: Medicare Spending per Beneficiary. (Continuous Ratio). Evaluates a hospital's financial efficiency.
  * *Scale:* `1.0` is the national median. `< 1.0` means the hospital is highly efficient/cheaper than average.

## 2. OUTPATIENT HOPD PANEL (`outpatient_hopd_quality_panel.csv`)
*CMS tracks over 35 distinct Outpatient ("OP") metrics. Because we used a wildcard extractor, your dataset includes all of them. Here are the most critical ones for health economics:*

* **`hopd_op_8_score` / `hopd_op_10_score`**: Outpatient Imaging Efficiency. Tracks the percentage of patients receiving an MRI (OP-8) or Abdomen CT with Contrast (OP-10) without prior conservative therapy. 
  * *Scale:* Percentage. **Higher is worse** (indicates wasteful/defensive medicine).
* **`hopd_op_18_score`**: Median Time from ED Arrival to Departure. 
  * *Scale:* Continuous Minutes. Lower is better.
* **`hopd_op_22_score`**: Left Emergency Department Without Being Seen. 
  * *Scale:* Percentage. Higher indicates severe hospital crowding/capacity failure.
* **`hopd_op_29_score`**: Appropriate Follow-Up Interval for Normal Colonoscopy. 
  * *Scale:* Percentage. Higher is better (indicates doctors are not over-scheduling healthy patients for unnecessary repeat procedures).
* **`hopd_op_32_score`**: Facility 7-Day Risk-Standardized Hospital Visit Rate after Outpatient Surgery. 
  * *Scale:* Percentage. Lower is better (indicates fewer severe post-surgical complications).

## 3. OUTPATIENT ASC PANEL (`outpatient_asc_quality_panel.csv`)
* **`asc_rate_1` through `asc_rate_4`**: Severe Complications. Tracks Patient Burns (1), Patient Falls (2), Wrong Site/Patient surgeries (3), and Hospital Admissions/Transfers (4). 
  * *Scale:* Rate **per 1,000** admissions. Lower is better.
* **`asc_rate_8`**: Influenza Vaccination Coverage among Healthcare Personnel. 
  * *Scale:* Percentage. Higher is better.
* **`asc_rate_9`**: Appropriate Follow-up Interval for Normal Colonoscopy in an ASC. 
  * *Scale:* Percentage. Higher is better.
* **`asc_rate_12`**: Facility 7-Day Risk-Standardized Hospital Visit Rate. Tracks how often patients have to be rushed to an ER or admitted to an inpatient hospital within 7 days of their ASC surgery.
  * *Scale:* Percentage. Lower is better.