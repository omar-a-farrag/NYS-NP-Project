================================================================================
CMS DATA NETWORK - PIPELINE DOCUMENTATION (PHASE 1)
Principal Investigator: [Your Name]
Date: February 2026
================================================================================

I. PROJECT OVERVIEW
--------------------------------------------------------------------------------
Phase 1 of this project builds the "Provider Node" of the healthcare data network.
It harmonizes raw CMS administrative data (Claims & Summary), calculates clinical
phenotypes (e.g., Opioid Prescribing, Cost Efficiency) for individual physicians,
and aggregates these measures to the facility (hospital) level using a multi-year
network map.

II. DIRECTORY STRUCTURE
--------------------------------------------------------------------------------
/cleaningCode                    -> All scripts listed below
/cms                             -> Raw & Harmonized CMS Provider/Claims Data
/mips                            -> Raw & Harmonized Facility Affiliation Data
/dictionaries_and_crosswalks     -> RBCS, USAN Drug Classes, Cost Thresholds
/outputs_while_cleaning
  /cleaned_data                  -> FINAL MASTER DATASETS (Stata .dta & CSV)
  /tables                        -> Appendix PDFs (Cost Thresholds, RBCS Maps)

III. EXECUTION ORDER
--------------------------------------------------------------------------------

--- PHASE 0: SETUP ---
  * 00_initialize.do
    - Sets global file paths and directory macros. Run this first.

--- PHASE 1: DATA HARMONIZATION ---
  * 06_harmonize_facility_smart_v2.py
    - Intelligent Python script that harmonizes Facility Affiliation files (2014-2023).
    - Solves "Schema Drift" (e.g., v30 -> ccn) and reshapes data to Long format.

  * 08_harmonize_cms.do
    - Standardizes the three core CMS files:
      1. Provider Summary (Demographics, Volume, Risk Scores)
      2. Part D Claims (Drug utilization)
      3. Provider Service Claims (HCPCS/CPT utilization)

--- PHASE 2: METRIC DEFINITION & CALCULATION ---
  * 09_create_targeted_dictionaries.py ("The Microscope")
    - Defines hypothesis-driven clinical flags: Opioids, Toradol, Spine MRI, Cataracts.
  
  * 10_create_systematic_crosswalks.py ("The Telescope")
    - Defines systematic flags: Restructured BETOS (RBCS) categories,
      USAN Therapeutic Classes, and Empirical Cost Percentiles.

  * 11_aggregate_clinical_measures.py
    - The processing engine. Reads millions of claim lines to calculate
      numerator/denominator ratios for every NPI.

  * 12_create_systematic_appendix_tables.py
    - Generates LaTeX/PDF appendix tables documenting the exact cost thresholds 
      and service categories used in the analysis.

--- PHASE 3: NETWORK ASSEMBLY ---
  * 14_create_master_panels_v10.do
    - The Final Assembler.
    - Merges Clinical Measures (Script 11) + Demographics (Script 06) + Volume (Script 08).
    - Creates the "Kitchen Sink" Provider Panel (All variables preserved).
    - Aggregates data to the Facility level (Weighted Averages & Sums).

IV. FINAL OUTPUTS
--------------------------------------------------------------------------------
1. cms_master_provider_panel.dta (NPI-Year Level)
   - The "Atom" of the network. One row per doctor.
2. cms_master_facility_panel.dta (CCN-Year Level)
   - The "Molecule". Aggregated hospital-level data.