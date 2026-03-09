import os
import pandas as pd
import warnings

warnings.filterwarnings("ignore", category=pd.errors.DtypeWarning)

# --- SETUP ---
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(script_dir, "..",".."))
hcahps_dir = os.path.join(project_root, "hcahps")

TARGET_YEAR = "hcahps2019" # Our representative "Gold Standard" year
CHECK_YEARS = ["hcahps2016", "hchaps2024"] # Used to verify consistency

folder_path = os.path.join(hcahps_dir, TARGET_YEAR)
output_txt_path = os.path.join(project_root,"dictionaries_and_crosswalks", "cms_universal_peek_results.txt")

print(f"=== UNIVERSAL FACILITY DATA PEEK ({TARGET_YEAR}) ===")
print(f"Scanning files and writing results to: {output_txt_path}\n")

if not os.path.exists(folder_path):
    print(f"[!] Folder {TARGET_YEAR} not found.")
else:
    files = os.listdir(folder_path)
    
    # Filter for likely facility-level data files
    facility_files = []
    for f in files:
        f_lower = f.lower()
        if f.endswith('.csv'):
            # Exclude obvious non-facility files (rollups, metadata)
            exclusions = ['state', 'national', 'footnote', 'crosswalk', 'dates', 'dictionary', 'readme']
            if not any(x in f_lower for x in exclusions):
                facility_files.append(f)
    
    facility_files.sort()
    
    # Open the text file to write the results
    with open(output_txt_path, "w", encoding="utf-8") as out_file:
        out_file.write(f"=== UNIVERSAL FACILITY DATA PEEK ({TARGET_YEAR}) ===\n\n")
        
        for f in facility_files:
            print(f"Processing: {f}...") # Console progress tracker
            
            out_file.write("="*100 + "\n")
            out_file.write(f"FILE: {f}\n")
            
            # --- CONSISTENCY CHECK ---
            # Look for a similar file in our check years
            base_name = f.split('.')[0].split('-')[0].strip().lower() 
            consistency = []
            for cy in CHECK_YEARS:
                cy_path = os.path.join(hcahps_dir, cy)
                if os.path.exists(cy_path):
                    found = any(base_name in cf.lower() for cf in os.listdir(cy_path))
                    consistency.append(f"{cy[-4:]}: {'YES' if found else 'NO'}")
            
            out_file.write(f"CONSISTENCY: {', '.join(consistency)}\n")
            out_file.write("-" * 100 + "\n")
            
            # --- DATA EXTRACTION ---
            file_path = os.path.join(folder_path, f)
            try:
                try:
                    df = pd.read_csv(file_path, nrows=5, encoding='utf-8-sig')
                except UnicodeDecodeError:
                    df = pd.read_csv(file_path, nrows=5, encoding='cp1252')
                
                out_file.write(f"TOTAL COLUMNS: {len(df.columns)}\n")
                out_file.write(f"COLUMNS: {df.columns.tolist()}\n\n")
                out_file.write("FIRST 5 ROWS (Transposed):\n")
                out_file.write(df.head().T.to_string() + "\n")
                
            except Exception as e:
                out_file.write(f"[!] Read error: {e}\n")
            
            out_file.write("="*100 + "\n\n")

print(f"\n[+] Peek complete! Open 'cms_universal_peek_results.txt' to view the schema.")