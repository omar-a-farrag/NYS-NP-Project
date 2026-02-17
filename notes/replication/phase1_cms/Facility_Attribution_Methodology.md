# Methodology: Facility Attribution & Network Aggregation

## 1. The Attribution Challenge
Public use files do not explicitly link specific claims to specific facilities for independent physicians. However, CMS provides the **Facility Affiliation** dataset, linking National Provider Identifiers (NPI) to CMS Certification Numbers (CCN).

### The "Many-to-Many" Problem
* **Reality:** A single physician (NPI) may be credentialed at multiple hospitals (CCNs).
* **Assumption:** If a hospital credentials a physician, it accepts that physician's clinical "culture" (prescribing habits, billing intensity).
* **Resolution:** We employ an **Unweighted Attribution Model**. A physician's calculated phenotype (e.g., Opioid Rate = 0.45) is linked to *every* facility they are affiliated with in that year.

## 2. Harmonization of Affiliation Data (Script 06)
The raw affiliation files undergo significant schema drift:
* **2014-2016:** "Wide" format. Columns `v30`, `v32`, `v34` represent hospital IDs.
* **2017:** "Wide" format. Columns renamed to `hospitalaffiliationccn1`, etc.
* **2018+:** "Long" format. Column `org_pac_id` represents the hospital ID.

**Solution:** A Python-based harmonization script converts all years to a **Long Format** (Key: `NPI-Year-CCN`). This ensures a consistent network map across the decade.

## 3. Aggregation Logic (The "Roll-Up")
To create the **Facility Master Panel**, we collapse the provider-level data to the `CCN-Year` level using three distinct operations:

| Variable Type | Operation | Logic |
| :--- | :--- | :--- |
| **Clinical Rates**<br>(e.g., Opioid Rate) | **MEAN** | Represents the "Average Clinical Culture" of the medical staff. Unweighted to prevent high-volume specialists from masking the habits of the general staff. |
| **Demographic Proportions**<br>(e.g., % Male) | **MEAN** | Represents the composition of the workforce. |
| **Volume Counts**<br>(e.g., Total Benes) | **SUM** | Represents the total patient load of the facility's network. |
| **Patient Attributes**<br>(e.g., Risk Score) | **WEIGHTED MEAN** | Calculated as $\frac{\sum(Risk \times Patients)}{\sum(Patients)}$. Ensures the facility risk score reflects the actual patient population treated. |