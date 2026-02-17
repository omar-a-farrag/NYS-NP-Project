# Methodology: CMS Data Harmonization & Metric Construction

## 1. Data Sources and Harmonization Strategy
The "Provider Node" of our network is constructed by merging three distinct CMS Public Use Files.

### A. The Provider Summary File
* **Content:** Aggregated volume, total charges, and unique beneficiary counts.
* **Role:** Provides the **Denominator** (Total Patients) and **Controls** (Patient Risk Scores, Demographics).
* **Harmonization Logic:**
    * Variable names standardized to snake_case (e.g., `nppes_provider_last_org_name` $\rightarrow$ `last_name`).
    * Chronic conditions converted from percentages (0-100) to raw counts to allow for weighted aggregation.

### B. The Part D Prescriber File
* **Content:** Line-item data for every drug dispensed by a provider.
* **Role:** Source of **Prescribing Phenotypes**.
* **Harmonization Logic:**
    * Drugs mapped to **USAN Therapeutic Classes** to allow for within-class cost comparisons.
    * Drugs flagged as "Generic" or "Brand" based on NBA/GCN sequence data.

### C. The Physician & Other Practitioners Service File
* **Content:** Line-item data for every HCPCS/CPT code billed.
* **Role:** Source of **Procedural Phenotypes**.
* **Harmonization Logic:**
    * HCPCS codes mapped to **RBCS (Restructured BETOS Classification System)** to group granular codes into clinical concepts (e.g., "Advanced Imaging", "E&M Visits").

---

## 2. Metric Construction: The "Dual Lens" Approach
To characterize provider behavior, we calculate two types of ratios. All ratios are bounded [0, 1].

### Lens 1: The Microscope (Targeted, Hypothesis-Driven)
*Definition:* Specific, high-discretion clinical choices identified in "Choosing Wisely" literature.
* **Opioid Intensity:** (Schedule II & III Opioid Claims) / (Total Opioid Claims).
* **Toradol Usage:** (Count of Ketorolac Injections) / (Total Part B Claims).
* **Low-Value Spine MRI:** (MRI of Spine) / (Total Service Lines). *Note: Denominator is broad to capture overall ordering intensity.*

### Lens 2: The Telescope (Systematic, Data-Driven)
*Definition:* Broad metrics covering the entire universe of claims to characterize cost-consciousness and revenue-seeking behavior.
* **Generic Fill Rate:** $1 - (\frac{\text{Brand Name Claims}}{\text{Total Part D Claims}})$
* **High-Cost Drug Rate:** The proportion of claims where the drug cost is in the top 25th percentile **for its specific therapeutic class**.
* **Upcoding Intensity:** $(\frac{\text{Level 4 \& 5 E\&M Visits}}{\text{Total E\&M Visits}})$. Measures the tendency to bill for higher complexity than average.