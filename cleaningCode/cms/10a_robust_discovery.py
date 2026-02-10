import pandas as pd
import os
import glob
import time

# --- 1. SETUP PATHS ---
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(script_dir, "..", ".."))

# POINT THIS TO YOUR FULL 5% DATA
# (Ensure this path contains the BIG files, not just the 100-row samples)
cms_provider_dir = os.path.join(project_root, "cms", "by_provider_service", "dta", "5pct_sample")
cms_partd_dir = os.path.join(project_root, "cms", "partD", "dta", "5pct_sample")

output_dir = os.path.join(project_root, "dictionaries_and_crosswalks")
if not os.path.exists(output_dir):
    os.makedirs(output_dir)

print(f"Scanning Provider Data in: {cms_provider_dir}")
print(f"Scanning Part D Data in:   {cms_partd_dir}")

# --- HELPER: SMART COLUMN SELECTOR ---
def get_valid_column(df, candidates):
    """Finds the first candidate column that exists in the dataframe."""
    for col in candidates:
        if col in df.columns:
            return col
        # Case insensitive check
        lower_cols = [c.lower() for c in df.columns]
        if col.lower() in lower_cols:
            return df.columns[lower_cols.index(col.lower())]
    return None

# ==============================================================================
# PART 1: PROVIDER & SERVICE (The "Brittle" Part)
# ==============================================================================
print("\n--- 1. Scanning Provider & Service Files ---")

services_counter = {}
partb_counter = {}

# Get ALL files (csv and dta)
files = glob.glob(os.path.join(cms_provider_dir, "*"))
files = [f for f in files if f.endswith(('.csv', '.dta'))]

if not files:
    print("CRITICAL WARNING: No files found in provider directory!")

for f in files:
    fname = os.path.basename(f)
    print(f"  Checking: {fname}...", end=" ")
    
    try:
        # 1. READ FILE
        if f.endswith('.dta'):
            df = pd.read_stata(f) # Read full to check columns safely
        else:
            # Read header only first to check columns
            header = pd.read_csv(f, nrows=0)
            df = pd.read_csv(f, low_memory=False)

        print(f"Rows: {len(df):,}", end=" | ")

        # 2. IDENTIFY COLUMNS (The Robust Part)
        col_code = get_valid_column(df, ['hcpcs_cd', 'hcpcs_code', 'hcpcs'])
        col_desc = get_valid_column(df, ['hcpcs_desc', 'hcpcs_description', 'description'])
        col_ind  = get_valid_column(df, ['hcpcs_drug_ind', 'drug_ind', 'is_drug'])

        if not (col_code and col_desc and col_ind):
            print(f"SKIPPED (Missing Columns). Found: {list(df.columns)}")
            continue

        print(f"Cols: {col_code}, {col_desc}, {col_ind}")

        # 3. NORMALIZE
        df[col_code] = df[col_code].astype(str).str.upper().str.strip()
        df[col_desc] = df[col_desc].astype(str).str.upper().str.strip()
        
        # Robust Drug Indicator Check (Y, 1, Yes, True)
        # Convert to string, upper, and check against set
        is_drug_mask = df[col_ind].astype(str).str.upper().isin(['Y', '1', 'YES', 'TRUE'])
        
        # 4. AGGREGATE
        # Services
        svc_counts = df[~is_drug_mask].groupby([col_code, col_desc]).size()
        for (code, desc), count in svc_counts.items():
            key = (code, desc)
            services_counter[key] = services_counter.get(key, 0) + count

        # Part B Drugs
        drug_counts = df[is_drug_mask].groupby([col_code, col_desc]).size()
        for (code, desc), count in drug_counts.items():
            key = (code, desc)
            partb_counter[key] = partb_counter.get(key, 0) + count

    except Exception as e:
        print(f"\n    ! Error reading {fname}: {e}")

# Export
df_svc = pd.DataFrame([{'hcpcs_cd': k[0], 'hcpcs_desc': k[1], 'frequency': v} for k, v in services_counter.items()])
if not df_svc.empty:
    df_svc = df_svc.sort_values('frequency', ascending=False)
    df_svc.to_csv(os.path.join(output_dir, "universe_services.csv"), index=False)
    print(f"  > SAVED: {len(df_svc):,} unique Services.")
else:
    print("  > WARNING: No Services found.")

df_partb = pd.DataFrame([{'hcpcs_cd': k[0], 'hcpcs_desc': k[1], 'frequency': v} for k, v in partb_counter.items()])
if not df_partb.empty:
    df_partb = df_partb.sort_values('frequency', ascending=False)
    df_partb.to_csv(os.path.join(output_dir, "universe_partb_drugs.csv"), index=False)
    print(f"  > SAVED: {len(df_partb):,} unique Part B Drugs.")
else:
    print("  > WARNING: No Part B Drugs found.")


# ==============================================================================
# PART 2: PART D (The "Name Change" Part)
# ==============================================================================
print("\n--- 2. Scanning Part D Files ---")

partd_counter = {}
files = glob.glob(os.path.join(cms_partd_dir, "*"))
files = [f for f in files if f.endswith(('.csv', '.dta'))]

for f in files:
    fname = os.path.basename(f)
    print(f"  Checking: {fname}...", end=" ")
    
    try:
        if f.endswith('.dta'):
            df = pd.read_stata(f)
        else:
            df = pd.read_csv(f, low_memory=False)
            
        print(f"Rows: {len(df):,}", end=" | ")
        
        # SMART COLUMN: gnrc_name vs generic_name
        col_name = get_valid_column(df, ['gnrc_name', 'generic_name', 'drug_name'])
        
        if not col_name:
            print(f"SKIPPED (No Drug Name Col). Found: {list(df.columns)}")
            continue

        print(f"Col: {col_name}")

        df[col_name] = df[col_name].astype(str).str.upper().str.strip()
        
        counts = df.groupby(col_name).size()
        for name, count in counts.items():
            partd_counter[name] = partd_counter.get(name, 0) + count
            
    except Exception as e:
        print(f"\n    ! Error reading {fname}: {e}")

df_partd = pd.DataFrame([{'generic_name': k, 'frequency': v} for k, v in partd_counter.items()])
if not df_partd.empty:
    df_partd = df_partd.sort_values('frequency', ascending=False)
    df_partd.to_csv(os.path.join(output_dir, "universe_partd_drugs.csv"), index=False)
    print(f"  > SAVED: {len(df_partd):,} unique Part D Drugs.")
else:
    print("  > WARNING: No Part D Drugs found.")

print("\nDONE. Please check the console output above to confirm row counts.")