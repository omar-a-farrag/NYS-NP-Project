# Master Data Dictionary

*Note: All string categories (e.g., `cms_state`, `cms_specialty`, `gender`) have been cleanly `encoded` into Stata integers with attached value labels for memory efficiency.*

## 1. The Base Grain (Individual Provider Metrics)
Variables lacking a prefix represent the individual physician/practitioner (`npi`).

| Variable | Description |
| :--- | :--- |
| `tot_benes` / `tot_srvcs` | Total Medicare beneficiaries treated and services rendered. |
| `bene_avg_risk_scre` | The average Hierarchical Condition Category (HCC) risk score of the provider's patients. |
| `partd_generic_rate` | (Telescope) Ratio of generic drug claims to total Part D claims. |
| `partd_high_cost_rate` | (Telescope) Proportion of prescribed drugs in the top 25th cost percentile for their class. |
| `partd_opioid_rate` | (Microscope) Ratio of Schedule II/III opioid claims to total opioid claims. |
| `svc_em_upcode_rate` | (Microscope) Ratio of Level 4/5 E&M claims to total E&M claims. |

## 2. The Facility Environment (`fac_` Namespace)
These variables exist on the individual provider panel but represent the **aggregate averages** of the hospital (`ccn`) where the provider works.

| Variable | Description |
| :--- | :--- |
| `fac_tot_benes` | The total Medicare footprint (beneficiaries) of the hospital's affiliated staff. |
| `fac_mean_generic_rate` | Unweighted hospital average. Represents the "clinical culture" of the staff. |
| `fac_wgt_generic_rate` | Patient-weighted hospital average. Represents the expected "patient exposure." |
| `fac_prop_female_docs` | The proportion of the hospital's affiliated workforce that is female. |

## 3. Hospital Quality & Patient Experience (`h_` Namespace)
Derived from lagged CMS HCAHPS surveys and Inpatient Quality Reporting (IQR).

| Variable | Description |
| :--- | :--- |
| `h_comp_1_a_p` | % of patients who reported nurses "Always" communicated well. |
| `h_hosp_rating_9_10` | % rating the hospital a 9 or 10 overall. |
| `rrp_excess_ratio_ami` | Readmission Reduction Program ratio for Heart Attacks. `> 1.0` triggers a penalty. |
| `hac_total_score` | Hospital-Acquired Condition Score (1-10). **Higher is worse.** |

## 4. MACRA & QPP Performance (`mips_` Namespace)
Derived from the Merit-based Incentive Payment System. Range: 0-100.

| Variable | Description |
| :--- | :--- |
| `mips_final_score` | The composite score dictating the clinician's Part B payment adjustment. |
| `mips_quality_score` | Performance on clinical outcome and process measures. |
| `mips_cost_score` | Risk-adjusted resource utilization. Often missing during 2020-2021 (EUC). |
| `fac_mips_final_score` | (Facility Panel Only) The volume-weighted average MIPS score of the hospital's staff. |

## 5. Ambulatory Surgical Center Quality (`asc_rate_` Namespace)
Outpatient ASC market-level metrics. Rates are per 1,000 admissions unless otherwise noted.

| Variable | Description |
| :--- | :--- |
| `asc_rate_1` | Patient Burns. |
| `asc_rate_2` | Patient Falls. |
| `asc_rate_3` | Wrong Site / Wrong Patient / Wrong Procedure. |
| `asc_rate_4` | Hospital Admissions / Transfers from the ASC. |
| `asc_rate_8` | Influenza Vaccination Coverage among Personnel (Percentage). |