import os
import pandas as pd

# --- SETUP ---
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(script_dir, "..",".."))
hcahps_dir = os.path.join(project_root, "hcahps")

print("=== HCAHPS SCHEMA RECONNAISSANCE ===")

# --- 1. SOLVE THE 2020 ANOMALY ---
print("\n--- Hunting for HCAHPS in 2020 ---")
dir_2020 = os.path.join(hcahps_dir, "hcahps2020")
found_2020 = None

if os.path.exists(dir_2020):
    for f in os.listdir(dir_2020):
        if f.endswith('.csv'):
            file_path = os.path.join(dir_2020, f)
            try:
                # Read just the headers
                cols = pd.read_csv(file_path, nrows=0).columns.tolist()
                cols_upper = [c.upper() for c in cols]
                
                # Check if it's the HCAHPS file
                if any("HCAHPS" in c or "HCAHPS_MEASURE_ID" in c or "SURVEY" in c for c in cols_upper):
                    # Exclude the state/national rollups (usually have fewer columns)
                    if "Facility ID" in cols or "Facility_ID" in cols or "Provider ID" in cols:
                        found_2020 = f
                        print(f"[*] FOUND IT! The 2020 HCAHPS file is: {f}")
                        break
            except Exception:
                pass

if not found_2020:
    print("[!] Could not clearly identify the 2020 HCAHPS file.")

# --- 2. PEEK AT THE CSV ERAS ---
files_to_peek = [
    ("2012 (Early Era)", "hcahps2012", "HCAHPS Measures.csv"),
    ("2016 (Standard Era)", "hcahps2016", "HCAHPS - Hospital.csv"),
    ("2020 (Hash Era)", "hcahps2020", found_2020 if found_2020 else "UNKNOWN"),
    ("2022 (Snake Case Era)", "hcahps2022", "Patient_survey__HCAHPS_-Hospital.csv"),
    ("2024 (Modern Era)", "hchaps2024", "HCAHPS-Hospital.csv") # Using your exact folder name
]

print("\n--- COMPARING COLUMN DRIFT ---")
for era_name, folder, filename in files_to_peek:
    if filename == "UNKNOWN":
        continue
        
    filepath = os.path.join(hcahps_dir, folder, filename)
    if os.path.exists(filepath):
        try:
            # Read just the first row to get columns and a sample
            df = pd.read_csv(filepath, nrows=1, encoding='utf-8-sig') # handling potential BOM
            cols = df.columns.tolist()
            print(f"\n{era_name} -> {filename}")
            print(f"Total Columns: {len(cols)}")
            
            # Print the first 10 columns (usually IDs) and a sample of the measure columns
            measure_cols = [c for c in cols if "Measure" in c or "Answer" in c or "Score" in c or "HCAHPS" in c.upper()]
            print(f"ID Columns (first 5): {cols[:5]}")
            print(f"Measure Columns (sample): {measure_cols[:5]}")
            
        except Exception as e:
            try:
                # Fallback for weird encodings like 'cp1252' common in CMS data
                df = pd.read_csv(filepath, nrows=1, encoding='cp1252')
                cols = df.columns.tolist()
                print(f"\n{era_name} -> {filename} (cp1252 encoding)")
                print(f"Total Columns: {len(cols)}")
                print(f"ID Columns (first 5): {cols[:5]}")
            except Exception as e2:
                print(f"\n[!] Could not read {era_name}: {e2}")
    else:
        print(f"\n[!] File not found: {filepath}")

print("\n=== RECON COMPLETE ===")