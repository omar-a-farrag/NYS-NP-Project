import os
import pandas as pd
import warnings
try:
    import pyodbc
    HAS_PYODBC = True
except ImportError:
    HAS_PYODBC = False

warnings.filterwarnings("ignore", category=pd.errors.DtypeWarning)

# --- SETUP ---
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(script_dir, "..", "..")) # Adjust if needed
hcahps_dir = os.path.join(project_root, "hcahps")
output_txt_path = os.path.join(project_root,"dictionaries_and_crosswalks", "cms_legacy_peek_results.txt")

print("=== LEGACY INPATIENT DATA PEEK (2008-2012) ===")
print(f"Scanning files and writing results to: {output_txt_path}\n")

# We just need to check one DTA year and one MDB year to get the schema
check_targets = [
    ("2008 (DTA Era)", os.path.join(hcahps_dir, "hcahps2008")),
    ("2012 (MDB Era)", os.path.join(hcahps_dir, "hcahps2012"))
]

with open(output_txt_path, "w", encoding="utf-8") as out_file:
    out_file.write("=== LEGACY INPATIENT DATA PEEK (2008-2012) ===\n\n")

    for era, folder in check_targets:
        print(f"SEARCHING: {era}...")
        out_file.write("="*80 + "\n")
        out_file.write(f"SEARCHING: {era}\n")
        
        if not os.path.exists(folder):
            msg = f"[!] Folder not found: {folder}"
            print("  " + msg)
            out_file.write(msg + "\n")
            continue
            
        files = os.listdir(folder)
        
        # 1. Look for DTA files related to Measures, Mortality, or Readmissions
        dta_files = [f for f in files if f.endswith('.dta') and any(k in f.lower() for k in ['readm', 'mort', 'msr', 'hqi'])]
        
        for dta in dta_files:
            out_file.write(f"\n--- FOUND DTA: {dta} ---\n")
            try:
                df = pd.read_stata(os.path.join(folder, dta))
                out_file.write(f"COLUMNS: {df.columns.tolist()}\n")
                if not df.empty:
                    out_file.write("SAMPLE ROW:\n")
                    out_file.write(str(df.iloc[0].to_dict()) + "\n")
            except Exception as e:
                out_file.write(f"Error reading DTA: {e}\n")
                
        # 2. Look for the MDB file
        mdb_files = [f for f in files if f.endswith('.mdb')]
        for mdb in mdb_files:
            out_file.write(f"\n--- FOUND MDB: {mdb} ---\n")
            if HAS_PYODBC:
                try:
                    conn_str = r'DRIVER={Microsoft Access Driver (*.mdb, *.accdb)};DBQ=' + os.path.join(folder, mdb) + ';'
                    conn = pyodbc.connect(conn_str)
                    cursor = conn.cursor()
                    tables = [table.table_name for table in cursor.tables(tableType='TABLE')]
                    out_file.write(f"TABLES INSIDE MDB: {tables}\n")
                    
                    # Grab relevant tables
                    target_tables = [t for t in tables if any(k in t.lower() for k in ['readm', 'mort', 'msr', 'hqi'])]
                    
                    for target_table in target_tables:
                        out_file.write(f"\nPEEKING INSIDE TABLE: {target_table}\n")
                        df = pd.read_sql(f'SELECT TOP 2 * FROM {target_table}', conn)
                        out_file.write(f"COLUMNS: {df.columns.tolist()}\n")
                        if not df.empty:
                            out_file.write("SAMPLE ROW:\n")
                            out_file.write(str(df.iloc[0].to_dict()) + "\n")
                    
                    conn.close()
                except Exception as e:
                    out_file.write(f"Error reading MDB: {e}\n")
            else:
                out_file.write("[!] pyodbc not installed. Cannot peek inside MDB.\n")
                
        out_file.write("="*80 + "\n\n")

print("\n[+] Peek complete! Open 'cms_legacy_peek_results.txt' to view the schema.")
