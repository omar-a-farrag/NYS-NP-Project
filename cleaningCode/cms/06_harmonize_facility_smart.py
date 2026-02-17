import pandas as pd
import numpy as np
import os
import glob
import re
import sys

# --- 1. SETUP PATHS (ROBUST) ---
# We force the script to look relative to THIS file, not where you ran python from
script_path = os.path.abspath(__file__)
script_dir = os.path.dirname(script_path)
project_root = os.path.abspath(os.path.join(script_dir, "..", "..")) # Up from cleaningCode/mips/

# Define Directories
input_dir = os.path.join(project_root, "cliniciansAndGroups", "facilityAffiliation", "dta", "5pct_sample")
output_dir = os.path.join(project_root, "cliniciansAndGroups", "facilityAffiliation", "dta", "harmonized")

if not os.path.exists(output_dir): os.makedirs(output_dir)

print(f"\n--- DEBUG PATHS ---")
print(f"Script Location: {script_path}")
print(f"Project Root:    {project_root}")
print(f"Looking in:      {input_dir}")

files = glob.glob(os.path.join(input_dir, "*.dta"))
print(f"Found {len(files)} files to process.")

if len(files) == 0:
    print("\n[!] ERROR: No .dta files found!")
    print("    Please verify your folder structure matches the path above.")
    sys.exit()

# --- 2. DEFINE SCHEMA ---
# Regex patterns to find your variables across years
SCHEMA_MAP = {
    'npi': [r'^npi$'],
    'pac_id': [r'pac_?id', r'pacid'],
    'enrollment_id': [r'enrollment_?id', r'pecos'],
    'gender': [r'gndr', r'gender'],
    'credential': [r'cred', r'crdntls'],
    'grad_year': [r'grd_?yr', r'graduation'],
    'primary_specialty': [r'pri_?spec', r'primary_?specialty', r'provider_?type'],
    'secondary_specialty_1': [r'sec.*spec.*1', r'secondary.*specialty.*1'],
    'secondary_specialty_2': [r'sec.*spec.*2', r'secondary.*specialty.*2'],
    'secondary_specialty_3': [r'sec.*spec.*3', r'secondary.*specialty.*3'],
    'secondary_specialty_4': [r'sec.*spec.*4', r'secondary.*specialty.*4'],
    'all_secondary_specialties': [r'all_?sec', r'all_?secondary'],
    'group_pac_id': [r'grp_?pac_?id', r'group_?practice_?pac_?id'],
    'num_group_members': [r'num_?grp', r'number_?of_?group'],
    'state': [r'^st$', r'^state$'],
    'zip_code': [r'zip'],
    'accepts_assignment': [r'assgn', r'accepts_?medicare'],
    'quality_participation': [r'pqrs', r'reported_?quality'],
    'ehr_participation': [r'ehr', r'electronic_?health'],
    'heart_participation': [r'million_?hearts', r'heart_?health'],
}

# The list of columns we WANT in the final file
FINAL_COLS = list(SCHEMA_MAP.keys()) + ['ccn', 'year']

def find_match(raw_cols, patterns):
    for pattern in patterns:
        regex = re.compile(pattern)
        for col in raw_cols:
            if regex.search(col.lower()): return col
    return None

# --- 3. PROCESS FILES ---
print(f"\n--- PROCESSING ---")

for f in files:
    fname = os.path.basename(f)
    print(f"Reading {fname}...", end=" ")
    
    try:
        df = pd.read_stata(f)
        
        # Get Year
        year_match = re.search(r'20[0-9]{2}', fname)
        year = int(year_match.group(0)) if year_match else 2099
        df['year'] = year
        
        # Rename standard columns
        raw_cols = df.columns.tolist()
        rename_dict = {}
        for target, patterns in SCHEMA_MAP.items():
            match = find_match(raw_cols, patterns)
            if match: rename_dict[match] = target
        
        # --- LOGIC: HANDLE WIDE VS LONG CCNs ---
        # 1. Check for "Long" Format (2018+ style)
        long_ccn_col = find_match(raw_cols, [r'org_?pac_?id', r'facility_?affiliation'])
        
        # 2. Check for "Wide" Format (2015-2017 style)
        wide_ccn_cols = []
        # Look for ccn1..5 or v30..v36
        if find_match(raw_cols, [r'hospitalaffiliationccn1']):
             wide_ccn_cols = [find_match(raw_cols, [f'hospitalaffiliationccn{i}']) for i in range(1,6)]
        elif find_match(raw_cols, [r'claimsbasedhospitalaffiliationcc']):
             wide_ccn_cols = [
                 find_match(raw_cols, [r'claimsbasedhospitalaffiliationcc']),
                 find_match(raw_cols, [r'v30']),
                 find_match(raw_cols, [r'v32']),
                 find_match(raw_cols, [r'v34']),
                 find_match(raw_cols, [r'v36'])
             ]
        
        # Apply Base Renames
        df.rename(columns=rename_dict, inplace=True)
        
        # NORMALIZE TO LONG FORMAT
        if long_ccn_col:
            # Already long, just rename identifier to 'ccn'
            df.rename(columns={long_ccn_col: 'ccn'}, inplace=True)
        
        elif any(wide_ccn_cols):
            # Wide format: Melt it down!
            # We filter out None in case some cols are missing
            valid_wide = [c for c in wide_ccn_cols if c in raw_cols] # Use raw names for melt
            
            # Identify ID vars (demographics) to keep fixed
            id_vars = [c for c in df.columns if c in rename_dict.values() or c == 'year']
            
            # Melt
            df = df.melt(id_vars=id_vars, value_vars=valid_wide, value_name='ccn')
            df.drop(columns=['variable'], inplace=True) # Drop the 'variable' column (e.g. 'v30')
            df = df[df['ccn'].notna() & (df['ccn'] != '')] # Remove empty rows
            
        else:
            # No CCNs found (rare but possible)
            df['ccn'] = ""

        # --- FINAL SCHEMA CLEANUP ---
        # Ensure all target columns exist (schema enforcement)
        for col in FINAL_COLS:
            if col not in df.columns:
                df[col] = ""
        
        # Force everything to String to prevent Stata Append Errors
        final_df = df[FINAL_COLS].copy()
        for c in final_df.columns:
            if c != 'year':
                final_df[c] = final_df[c].astype(str).replace('nan', '').replace('.', '')
        
        # Save
        save_name = fname.replace('_sample.dta', '_harmonized.dta')
        final_df.to_stata(os.path.join(output_dir, save_name), write_index=False, version=118)
        print(f"Success. (Rows: {len(final_df)})")

    except Exception as e:
        print(f"\n[!] ERROR in {fname}: {e}")

print("\n--- HARMONIZATION COMPLETE ---")
