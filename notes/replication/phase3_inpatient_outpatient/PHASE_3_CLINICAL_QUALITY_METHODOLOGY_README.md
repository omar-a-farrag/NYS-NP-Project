# Phase 3: Clinical Quality & Outpatient Environment Methodology

## Overview
Phase 3 expands the environment panel by capturing high-stakes clinical outcomes and financial penalties mandated by the Affordable Care Act, and mapping the rapidly expanding Outpatient/ASC environment.

## Methodology
1. **Inpatient Harvester:** A column-agnostic Python extraction script scraped 17 years of CMS Quality databases. We extracted Readmissions (RRP), Hospital-Acquired Conditions (HAC), Value-Based Purchasing (HVBP), and Medicare Spending per Beneficiary (MSPB). 
2. **Outpatient Bifurcation:** Outpatient facilities exist in two distinct ecosystems. They were processed simultaneously but bifurcated into separate network datasets:
    * **HOPD (Hospital Outpatient Departments):** Share the parent hospital's 6-digit CCN. Metrics include Imaging Efficiency (e.g., OP-8) and ED Wait Times (e.g., OP-18). These were successfully merged directly into the Inpatient Provider and Facility Networks.
    * **ASC (Ambulatory Surgical Centers):** Standalone clinics that utilize a 10-digit alphanumeric identifier. 
3. **The ASC Zip-Code Market Linkage:** Because independent ASC surgeons do not report formal CMS Facility Affiliations in the same way inpatient doctors do, a local-market strategy was deployed. ASC quality metrics (e.g., ASC-1 Complications) were collapsed to the Zip-Code and Year level. These market averages were then successfully merged onto the individual provider's practice Zip Code, generating the dedicated `cms_phase3_outpatient_asc_provider.dta` dataset.