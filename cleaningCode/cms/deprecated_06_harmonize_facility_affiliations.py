import os
import pandas as pd
import glob
import re
import sys
import warnings

# Suppress the SettingWithCopyWarning for cleaner console output
warnings.filterwarnings('ignore', category=pd.errors.SettingWithCopyWarning)

# --- 1. SETUP PATHS ---
script_path = os.path.abspath(__file__)
script_dir = os.path.dirname(script_path)
project_root = os.path.abspath(os.path.join(script_dir, "..", ".."))

base_affil_dir = os.path.join(project_root, "cliniciansAndGroups", "facilityAffiliation")
output_dir = os.path.join(base_affil_dir, "dta", "harmonized")

if not os.path.exists(output_dir): os.makedirs(output_dir)

print(f"=== CMS FACILITY HARMONIZER (FINAL OMNI-SCRIPT) ===")

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
    'group_pac_id': [r'org_?pac_?id', r'grp_?pac_?id', r'group_?practice_?pac_?id'],
    'num_group_members': [r'num_?org_?mem', r'num_?grp', r'number_?of_?group'],
    'state': [r'^st$', r'^state$'],
    'zip_code': [r'^zip$'],
    'accepts_assignment': [r'assgn', r'accepts_?medicare'],
    'quality_participation': [r'pqrs', r'reported_?quality'],
    'ehr_participation': [r'ehr', r'electronic_?health'],
    'heart_participation': [r'million_?hearts', r'heart_?health'],
}

FINAL_COLS = list(SCHEMA_MAP.keys()) + ['ccn', 'year']

def find_match(raw_cols, patterns):
    for pattern in patterns:
        regex = re.compile(pattern)
        for col in raw_cols:
            if regex.search(col.lower()): return col
    return None

def process_dataframe(df, year, fname):
    df['year'] = year
    raw_cols = df.columns.tolist()
    
    rename_dict = {}
    for target, patterns in SCHEMA_MAP.items():
        match = find_match(raw_cols, patterns)
        if match: rename_dict[match] = target
    
    long_ccn_col = find_match(raw_cols, [r'facility.*affiliation.*cert', r'facilitytypecert', r'^facility_?affiliation$']) 
    
    wide_ccn_cols = []
    if find_match(raw_cols, [r'hospitalaffiliationccn1']):
         wide_ccn_cols = [find_match(raw_cols, [f'hospitalaffiliationccn{i}']) for i in range(1,6)]
    elif find_match(raw_cols, [r'hosp_afl_1']):
         wide_ccn_cols = [find_match(raw_cols, [f'hosp_afl_{i}']) for i in range(1,6)]
    elif find_match(raw_cols, [r'claimsbasedhospitalaffiliationcc']):
         wide_ccn_cols = [
             find_match(raw_cols, [r'claimsbasedhospitalaffiliationcc']),
             find_match(raw_cols, [r'v30']),
             find_match(raw_cols, [r'v32']),
             find_match(raw_cols, [r'v34']),
             find_match(raw_cols, [r'v36'])
         ]
    
    df.rename(columns=rename_dict, inplace=True)
    
    # FORMAT NORMALIZATION WITH MEMORY FIX
    if long_ccn_col:
        df.rename(columns={long_ccn_col: 'ccn'}, inplace=True)
        df['ccn'] = df['ccn'].astype(str).str.strip().replace('nan', '')
        df = df[df['ccn'] != ''].copy() # ADDED .COPY() MEMORY FIX
    elif any(wide_ccn_cols):
        valid_wide = [c for c in wide_ccn_cols if c in raw_cols] 
        id_vars = [c for c in df.columns if c in rename_dict.values() or c == 'year']
        df = df.melt(id_vars=id_vars, value_vars=valid_wide, value_name='ccn')
        df.drop(columns=['variable'], inplace=True, errors='ignore') 
        df['ccn'] = df['ccn'].astype(str).str.strip().replace('nan', '')
        df = df[df['ccn'] != ''].copy() # ADDED .COPY() MEMORY FIX
    else:
        df['ccn'] = ""

    # SCHEMA ENFORCEMENT
    for col in FINAL_COLS:
        if col not in df.columns: df[col] = ""
    
    final_df = df[FINAL_COLS].copy()
    for c in final_df.columns:
        if c != 'year': final_df[c] = final_df[c].astype(str).replace('nan', '').replace('.', '')
    
    out_path = os.path.join(output_dir, fname)
    final_df.to_stata(out_path, write_index=False, version=118)
    print(f"  [+] Saved {fname} ({len(final_df)} rows)")


# --- 2. PROCESS PRE-2023 CSV FILES (100% DATA) & BACKFILL 2013 ---
print("\n--- STAGE 1: 2014-2022 100% CSV FILES ---")

files = glob.glob(os.path.join(base_affil_dir, "facility_names_*.csv"))

for f in files:
    fname = os.path.basename(f)
    year_match = re.search(r'20[0-9]{2}', fname)
    year = int(year_match.group(0)) if year_match else 2099
    
    if 2014 <= year <= 2022:
        print(f"Reading {fname} (100% Data)...")
        try:
            # THE FIX: Try UTF-8 first, fallback to Latin1 if it hits special characters
            try:
                df = pd.read_csv(f, dtype=str, on_bad_lines='skip', engine='python')
            except UnicodeDecodeError:
                df = pd.read_csv(f, dtype=str, on_bad_lines='skip', engine='python', encoding='latin1')
            
            save_name = f"{year}_facility_affiliation_harmonized.dta"
            process_dataframe(df, year, save_name)
            
            if year == 2014:
                print(f"  [>] Backfilling 2013 cleanly from fresh 2014 100% data...")
                # Also apply the Latin1 fix to the backfill load just in case!
                try:
                    df_fresh = pd.read_csv(f, dtype=str, on_bad_lines='skip', engine='python')
                except UnicodeDecodeError:
                    df_fresh = pd.read_csv(f, dtype=str, on_bad_lines='skip', engine='python', encoding='latin1')
                process_dataframe(df_fresh, 2013, "2013_facility_affiliation_harmonized.dta")
                
        except Exception as e:
            print(f"  [!] Error: {e}")

# --- 3. PROCESS 2023-2025 RAW CSV FILES ---
print("\n--- STAGE 2: 2023-2025 RAW CSV FILES ---")
def get_npi_col(df):
    for c in df.columns:
        if 'npi' in c.lower().strip(): return c
    return None

for yr in ['2023', '2024', '2025']:
    yr_dir = os.path.join(base_affil_dir, yr)
    if os.path.exists(yr_dir):
        print(f"Reading {yr} CSVs...")
        fac_files = glob.glob(os.path.join(yr_dir, "Facility_Affiliation*.csv"))
        dac_files = glob.glob(os.path.join(yr_dir, "DAC_NationalDownloadableFile*.csv"))
        
        if fac_files and dac_files:
            try:
                # Add Latin1 fallback to modern years just to be completely bulletproof
                try:
                    df_fac = pd.read_csv(fac_files[0], dtype=str, on_bad_lines='skip', engine='python')
                    df_dac = pd.read_csv(dac_files[0], dtype=str, on_bad_lines='skip', engine='python')
                except UnicodeDecodeError:
                    df_fac = pd.read_csv(fac_files[0], dtype=str, on_bad_lines='skip', engine='python', encoding='latin1')
                    df_dac = pd.read_csv(dac_files[0], dtype=str, on_bad_lines='skip', engine='python', encoding='latin1')
                    
                npi_fac = get_npi_col(df_fac)
                npi_dac = get_npi_col(df_dac)
                
                if npi_fac and npi_dac:
                    df_merged = pd.merge(df_dac, df_fac, left_on=npi_dac, right_on=npi_fac, how='left')
                    save_name = f"{yr}_facility_affiliation_harmonized.dta"
                    process_dataframe(df_merged, int(yr), save_name)
                else:
                    print(f"  [!] Could not find NPI columns.")
            except Exception as e:
                print(f"  [!] Error processing {yr}: {e}")

print("\n=== COMPLETE! ===")