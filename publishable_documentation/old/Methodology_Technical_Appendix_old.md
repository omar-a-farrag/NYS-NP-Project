# Technical Appendix: Data Engineering & Attribution Methodology

## 1. Provider Phenotyping: The "Dual Lens" Approach
To characterize provider behavior from raw claims, we aggregated millions of line items using two distinct frameworks to shield against selection bias:

* **Lens 1: The Microscope (Hypothesis-Driven):** We track high-discretion, low-value clinical choices flagged by "Choosing Wisely" literature. This includes specific HCPCS/NDC codes for Schedule II Opioid intensity, Toradol utilization, and low-value Spine MRIs for back pain.
* **Lens 2: The Telescope (Data-Driven):** We calculate systematic metrics covering the entire universe of claims. 
    * *Generic Prescribing Rate:* Using our internal USAN crosswalk.
    * *Empirical High-Cost Rate:* The proportion of a physician's claims where the drug/service cost falls in the top 25th percentile *for its specific therapeutic class*.

## 2. The Attribution Challenge (NPI to Facility)
Linking independent physicians to hospitals requires navigating significant data drift.

* **Inpatient Deterministic Linkage:** We utilized the CMS Facility Affiliation files. Because CMS did not publish CCN affiliations prior to 2018, we systematically backfilled 2013–2017 hospital affiliations assuming standard local stickiness. The resulting `fac_*` variables represent the unweighted and patient-weighted averages of all doctors credentialed at a specific hospital, capturing the "clinical culture" of the facility.
* **Outpatient ASC Geographic Proxy:** Unlike acute care hospitals, ASCs do not feature deterministic NPI-to-facility crosswalks in CMS data. To avoid the ecological fallacy of assigning random neighborhood doctors to surgical centers, ASC quality metrics (e.g., ASC-1 Complications) were collapsed to the ZIP-code level and mapped to providers as a local market proxy rather than a direct affiliation.

## 3. Dealing with CMS Data Chaos
Our Python extraction pipeline (`scripts/02_harmonize_hcahps_smart.py`) was built to handle extreme administrative volatility:
* **HCAHPS File Naming:** Over 15 years, HCAHPS reporting morphed from Microsoft Access `.mdb` files (2008), to generic CSVs, to Socrata Hash anomalies (2020), to snake_case. 
* **Experience Year Lagging:** CMS reports quality metrics with a chronological lag. We explicitly lagged HCAHPS reporting years by $t-1$ to ensure that physician billing behavior in Year $X$ is correlated with the hospital environment of Year $X$.

## 4. Structural Limitations of MIPS
Researchers utilizing the `mips_*` variables must account for three critical structural biases inherent to the MACRA legislation:
1. **The Low Volume Threshold (LVT):** MIPS systemically excludes part-time, rural, or low-Medicare-volume clinicians. The data represents a higher-volume subset of the workforce.
2. **Facility-Based Scoring:** For facility-bound clinicians (e.g., Anesthesiologists), CMS often automatically adopts the hospital's Value-Based Purchasing (VBP) score as the individual's MIPS score, making it difficult to disentangle individual skill from structural quality.
3. **COVID-19 Extreme and Uncontrollable Circumstances (EUC):** Performance years 2020–2022 feature massive, non-random attrition due to EUC exception applications, resulting in category reweighting to zero for many providers.