#!/bin/bash

# ==============================================================================
# SCRIPT: run_phase1.sh
# PURPOSE: Master execution pipeline for CMS Phase 1 (100% Data)
# ==============================================================================

# Exit the script immediately if any command fails
set -e

# ---> USER CONFIGURATION <---
# Change this path to point to your specific Stata executable
STATA_EXEC="C:/Program Files/Stata18/StataMP-64.exe"

echo "========================================================="
echo "   STARTING CMS PIPELINE - PHASE 1 (100% DATA)           "
echo "========================================================="

echo "[1/7] Creating .dta files (Stata)..."
# The /e flag tells Stata to run silently in the background and exit when done
"$STATA_EXEC" /e do 01_create_samples.do

echo "[2/7] Analyzing variables through time and across our three main CMS sets (Stata)..."
"$STATA_EXEC" /e do 02_variable_diagnostics.do

echo "[3/7] Looking at column names in facility affiliation files through time (Stata)..."
"$STATA_EXEC" /e do 03_inspect_facility_headers.do

echo "[4/7]Running diagnostics on facility affiliation files (Stata)..."
"$STATA_EXEC" /e do 08_harmonize_cms.do

echo "[5/7] Harmonizing Facility Affiliations (Python)..."
python 06_harmonize_facility_affiliations.py

echo "[6/7] Looking at value of care, provider-level (Stata)..."
"$STATA_EXEC" /e do 07a_value_diagnostics.do

echo "[6/7] Looking at value of care, facility-level (Stata)..."
"$STATA_EXEC" /e do 07b_facility_value_diagnostics.do

echo "[5/7] Generating specialty table (Python)..."
python 08_generate_specialty_table.py

echo "[2/7] Harmonizing CMS Claims (Stata)..."
"$STATA_EXEC" /e do 08_harmonize_cms.do

echo "[5/7] Robust discovery (Python)..."
python 09a_robust_discovery.py

echo "[3/7] Generating Systematic Crosswalks (Python)..."
python 10_create_systematic_crosswalks.py

echo "[4/7] Generating Clinical Dictionaries (Python)..."
python 09b_create_clinical_dictionaries.py

echo "[5/7] Generating Appendix Tables (Python)..."
python 12_create_systematic_appendix_tables.py

echo "[6/7] Aggregating Clinical Measures - MP ENGINE (Python)..."
echo "      (Grab a coffee, this will process millions of rows)"
python 11_aggregate_clinical_measures.py

echo "[7/7] Assembling Master Panels (Stata)..."
"$STATA_EXEC" /e do 14_create_master_panels.do

echo "========================================================="
echo "   PHASE 1 COMPLETE!   "
echo "========================================================="