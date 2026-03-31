import os
import pandas as pd
import glob

# Setup paths
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(script_dir, "..", ".."))
affil_dir = os.path.join(project_root, "cliniciansAndGroups", "facilityAffiliation")

print("=== PREPPING 2023-2025 & BACKFILLING 2013 ===")

def find_npi_col(df):
    for c in df.columns:
        if c.lower().strip() == 'npi': return c
    return None

# 1. Merge 2023, 2024, 2025
for yr in ['2023', '2024', '2025']:
    yr_dir = os.path.join(affil_dir, yr)
    if os.path.exists(yr_dir):
        print(f"Processing {yr}...")
        fac_files = glob.glob(os.path.join(yr_dir, "Facility_Affiliation*.csv"))
        dac_files = glob.glob(os.path.join(yr_dir, "DAC_NationalDownloadableFile*.csv"))
        
        if fac_files and dac_files:
            try:
                df_fac = pd.read_csv(fac_files[0], dtype=str)
                df_dac = pd.read_csv(dac_files[0], dtype=str)
                
                npi_fac = find_npi_col(df_fac)
                npi_dac = find_npi_col(df_dac)
                
                if npi_fac and npi_dac:
                    # Merge on NPI
                    df_merged = pd.merge(df_dac, df_fac, left_on=npi_dac, right_on=npi_fac, how='left')
                    out_path = os.path.join(affil_dir, f"facility_names_{yr}.csv")
                    df_merged.to_csv(out_path, index=False)
                    print(f"  [+] Saved {out_path}")
                else:
                    print(f"  [!] Could not find NPI column in {yr} files.")
            except Exception as e:
                print(f"  [!] Error processing {yr}: {e}")

# 2. Backfill 2013 using 2014
print("\nBackfilling 2013...")
file_2014 = os.path.join(affil_dir, "facility_names_2014.csv")
file_2013 = os.path.join(affil_dir, "facility_names_2013.csv")

if os.path.exists(file_2014):
    df_2014 = pd.read_csv(file_2014, dtype=str)
    # If there is a year column, update it
    for c in df_2014.columns:
        if c.lower().strip() == 'year':
            df_2014[c] = '2013'
    df_2014.to_csv(file_2013, index=False)
    print(f"  [+] Successfully cloned 2014 to create {file_2013}")
else:
    print(f"  [!] Could not find {file_2014} to backfill 2013.")

print("=== DONE ===")