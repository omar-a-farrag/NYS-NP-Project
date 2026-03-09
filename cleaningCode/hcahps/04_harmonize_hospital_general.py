import os
import pandas as pd
import numpy as np
import re
import warnings

try:
    import pyodbc
    HAS_PYODBC = True
except ImportError:
    HAS_PYODBC = False

warnings.filterwarnings("ignore", category=pd.errors.DtypeWarning)

# --- SETUP ---
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(script_dir, "..", ".."))
hcahps_dir = os.path.join(project_root, "hcahps")
output_dir = os.path.join(hcahps_dir, "harmonized")

if not os.path.exists(output_dir): os.makedirs(output_dir)

print("=== STARTING HOSPITAL STRUCTURAL HARMONIZATION (V4) ===")

def clean_col_name(c): 
    # Removes spaces, underscores, and forward slashes (e.g., 'City/Town' -> 'citytown')
    return str(c).lower().replace(' ', '').replace('_', '').replace('/', '')

def get_year_from_folder(folder_name):
    match = re.search(r'20[0-9]{2}', folder_name)
    return int(match.group(0)) if match else None

# V4 Updates: Added 'citytown' and 'countyparish' for the 2023-2025 folders
COLUMN_MAP = {
    'ccn': ['providernumber', 'providerid', 'facilityid'],
    'hosp_name': ['hospitalname', 'facilityname'],
    'city': ['city', 'citytown'],
    'state': ['state'],
    'zip_code': ['zipcode'],
    'county': ['countyname', 'county', 'countyparish'],
    'hosp_type': ['hospitaltype'],
    'ownership': ['hospitalowner', 'hospitalownership'],
    'emergency_services': ['emergencyservice', 'emergencyservices']
}

folders = [f for f in os.listdir(hcahps_dir) if os.path.isdir(os.path.join(hcahps_dir, f)) and ('hcahps20' in f.lower() or 'hchaps20' in f.lower())]
folders.sort()

all_years_data = []

for folder in folders:
    folder_year = get_year_from_folder(folder)
    if not folder_year: continue
    
    experience_year = folder_year - 1
    
    print(f"\nProcessing {folder} (Mapped to Exp Year: {experience_year})...")
    folder_path = os.path.join(hcahps_dir, folder)
    
    target_file = None
    is_mdb = False
    
    # 1. Look for DTA (Preferred for early years if available)
    dta_path = os.path.join(folder_path, "dbo_vwHQI_HOSP.dta")
    if os.path.exists(dta_path):
        target_file = dta_path
        
    # 2. Look for MDB specifically for 2012/2013 if DTA is missing
    elif folder_year in [2012, 2013]:
        mdb_path = os.path.join(folder_path, f"Hospital{folder_year}.mdb")
        if os.path.exists(mdb_path):
            target_file = mdb_path
            is_mdb = True
            
    # 3. Look for standard or Socrata CSVs
    else:
        for f in os.listdir(folder_path):
            if f.endswith('.csv'):
                f_clean = clean_col_name(f)
                
                # Standard names (Handles 'hospitaldata' for 2012/2013 CSV fallback)
                if 'hospitalgeneralinformation' in f_clean or 'hospitaldata' in f_clean:
                    target_file = os.path.join(folder_path, f)
                    break
                
                # Socrata 2020 Hash Hunter (V4: Now with > 4000 row safeguard)
                if folder_year == 2020:
                    try:
                        cols = pd.read_csv(os.path.join(folder_path, f), nrows=0).columns.tolist()
                        cols_clean = [clean_col_name(c) for c in cols]
                        if ("facilityid" in cols_clean or "providerid" in cols_clean) and "hospitaltype" in cols_clean:
                            # Safeguard: Check if it's the full 4000+ hospital file, not a tiny subset
                            df_temp = pd.read_csv(os.path.join(folder_path, f), usecols=[0])
                            if len(df_temp) > 4000:
                                target_file = os.path.join(folder_path, f)
                                break
                    except: pass
                    
    if not target_file:
        print(f"  [!] Could not locate Structural file.")
        continue
        
    print(f"  Reading: {os.path.basename(target_file)}")
    
    # --- LOAD DATA ---
    try:
        if is_mdb:
            if not HAS_PYODBC:
                print("  [!] pyodbc not installed. Run 'pip install pyodbc' to read the MDB.")
                continue
            conn_str = r'DRIVER={Microsoft Access Driver (*.mdb, *.accdb)};DBQ=' + target_file + ';'
            try:
                conn = pyodbc.connect(conn_str)
                df = pd.read_sql('SELECT * FROM dbo_vwHQI_HOSP', conn)
                conn.close()
            except Exception as e:
                print(f"  [!] ODBC Driver Error: {e}")
                continue
        elif target_file.endswith('.dta'):
            df = pd.read_stata(target_file)
        else:
            try: df = pd.read_csv(target_file, encoding='utf-8-sig')
            except UnicodeDecodeError: df = pd.read_csv(target_file, encoding='cp1252')
    except Exception as e:
        print(f"  [!] Read Error: {e}")
        continue

    # --- HARMONIZE & CLEAN ---
    raw_cols = {clean_col_name(c): c for c in df.columns}
    standardized_df = pd.DataFrame()
    
    for std_name, variations in COLUMN_MAP.items():
        found = False
        for var in variations:
            if var in raw_cols:
                original_col = raw_cols[var]
                standardized_df[std_name] = df[original_col]
                found = True
                break
        if not found:
            standardized_df[std_name] = np.nan

    if 'ccn' not in standardized_df.columns or standardized_df['ccn'].isnull().all():
        print("  [!] CCN column is entirely missing. Skipping.")
        continue

    # Clean Identifiers
    standardized_df['ccn'] = standardized_df['ccn'].astype(str).str.split('.').str[0].str.zfill(6)
    standardized_df['zip_code'] = standardized_df['zip_code'].astype(str).str.split('.').str[0].str.zfill(5)
    
    for col in standardized_df.columns:
        if standardized_df[col].dtype == 'object':
            standardized_df[col] = standardized_df[col].str.strip()

    standardized_df['year'] = experience_year
    standardized_df = standardized_df.dropna(subset=['ccn', 'hosp_name'])
    standardized_df = standardized_df.drop_duplicates(subset=['ccn', 'year'])
    
    all_years_data.append(standardized_df)
    print(f"  Success! Extracted {len(standardized_df)} hospitals.")

# --- COMBINE AND SAVE ---
if all_years_data:
    final_df = pd.concat(all_years_data, ignore_index=True)
    cols = ['ccn', 'year', 'hosp_name', 'city', 'state', 'zip_code', 'county', 'hosp_type', 'ownership', 'emergency_services']
    final_df = final_df[cols]
    save_path = os.path.join(output_dir, "hcahps_structural_panel.csv")
    final_df.to_csv(save_path, index=False)
    print(f"\n=== COMPLETE! Saved {len(final_df)} rows to {save_path} ===")
