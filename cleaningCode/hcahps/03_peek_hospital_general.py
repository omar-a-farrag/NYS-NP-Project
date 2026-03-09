import os
import pandas as pd

script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(script_dir, "..",".."))
hcahps_dir = os.path.join(project_root, "hcahps")

print("=== HOSPITAL GENERAL INFO SCHEMA RECONNAISSANCE ===")

files_to_peek = [
    ("2008 (DTA Era)", os.path.join(hcahps_dir, "hcahps2008", "dbo_vwHQI_HOSP.dta")),
    ("2016 (Standard CSV)", os.path.join(hcahps_dir, "hcahps2016", "Hospital General Information.csv")),
    ("2022 (Snake Case CSV)", os.path.join(hcahps_dir, "hcahps2022", "Hospital_General_Information.csv"))
]

for era, filepath in files_to_peek:
    print(f"\n--- PEEKING: {era} ---")
    if os.path.exists(filepath):
        try:
            if filepath.endswith('.dta'):
                df = pd.read_stata(filepath)
            else:
                try: df = pd.read_csv(filepath, nrows=2, encoding='utf-8-sig')
                except UnicodeDecodeError: df = pd.read_csv(filepath, nrows=2, encoding='cp1252')
            
            cols = df.columns.tolist()
            print(f"File: {os.path.basename(filepath)}")
            print(f"Total Columns: {len(cols)}")
            
            # Look for our target keywords
            target_cols = [c for c in cols if any(keyword in c.lower() for keyword in ['provider', 'facility', 'name', 'city', 'state', 'zip', 'county', 'type', 'owner', 'emergency'])]
            print(f"Target Columns Found: {target_cols}")
            
            # Print a sample row of those specific columns
            if not df.empty:
                print(f"Sample Data:\n{df[target_cols].iloc[0].to_dict()}")
                
        except Exception as e:
            print(f"Could not read {os.path.basename(filepath)}: {e}")
    else:
        print(f"[!] File not found: {filepath}")

print("\n=== RECON COMPLETE ===")