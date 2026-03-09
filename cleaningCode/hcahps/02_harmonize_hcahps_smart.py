import os
import pandas as pd
import numpy as np
import re
import warnings

warnings.filterwarnings("ignore", category=pd.errors.DtypeWarning)

# --- SETUP ---
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(script_dir, "..",".."))
hcahps_dir = os.path.join(project_root, "hcahps")
output_dir = os.path.join(hcahps_dir, "harmonized")

if not os.path.exists(output_dir): os.makedirs(output_dir)

print("=== STARTING SMART HCAHPS HARMONIZATION (V5) ===")

# --- UNIVERSAL MAPPING DICTIONARY (LOOKAHEAD REGEX) ---
MEASURE_MAP = {
    'h_comp_1_a_p': [r'(?=.*nurse)(?=.*always)'],
    'h_comp_1_u_p': [r'(?=.*nurse)(?=.*usually)'],
    'h_comp_1_sn_p': [r'(?=.*nurse)(?=.*sometimes|.*never)'],
    'h_comp_2_a_p': [r'(?=.*doctor)(?=.*always)'],
    'h_comp_2_u_p': [r'(?=.*doctor)(?=.*usually)'],
    'h_comp_2_sn_p': [r'(?=.*doctor)(?=.*sometimes|.*never)'],
    'h_comp_3_a_p': [r'(?=.*help|.*responsiveness|.*staff)(?=.*always)'],
    'h_comp_3_u_p': [r'(?=.*help|.*responsiveness|.*staff)(?=.*usually)'],
    'h_comp_3_sn_p': [r'(?=.*help|.*responsiveness|.*staff)(?=.*sometimes|.*never)'],
    'h_comp_4_a_p': [r'(?=.*pain)(?=.*always)'],
    'h_comp_4_u_p': [r'(?=.*pain)(?=.*usually)'],
    'h_comp_4_sn_p': [r'(?=.*pain)(?=.*sometimes|.*never)'],
    'h_comp_5_a_p': [r'(?=.*medicine|.*medication)(?=.*always)'],
    'h_comp_5_u_p': [r'(?=.*medicine|.*medication)(?=.*usually)'],
    'h_comp_5_sn_p': [r'(?=.*medicine|.*medication)(?=.*sometimes|.*never)'],
    # Enhanced Discharge Regex to catch early years missing the word "yes"
    'h_comp_6_y_p': [r'(?=.*discharge|.*recovery)(?=.*yes)', r'(?=.*given)(?=.*information)(?=.*recovery)'],
    'h_comp_6_n_p': [r'(?=.*discharge|.*recovery)(?=.*no)', r'(?=.*not given)(?=.*information)(?=.*recovery)'],
    # 7. Care Transitions (Added 2013/2014)
    'h_comp_7_sa_p': [r'(?=.*understand|.*transition)(?=.*strongly agree)'],
    'h_comp_7_a_p': [r'(?=.*understand|.*transition)(?=.*agree)'],
    'h_comp_7_d_sd_p': [r'(?=.*understand|.*transition)(?=.*disagree)'],
    'h_clean_hosp_a_p': [r'(?=.*clean)(?=.*always)'],
    'h_clean_hosp_u_p': [r'(?=.*clean)(?=.*usually)'],
    'h_clean_hosp_sn_p': [r'(?=.*clean)(?=.*sometimes|.*never)'],
    'h_quiet_hosp_a_p': [r'(?=.*quiet)(?=.*always)'],
    'h_quiet_hosp_u_p': [r'(?=.*quiet)(?=.*usually)'],
    'h_quiet_hosp_sn_p': [r'(?=.*quiet)(?=.*sometimes|.*never)'],
    'h_hosp_rating_9_10': [r'(?=.*rating|.*rate)(?=.*9)(?=.*10)'],
    'h_hosp_rating_7_8': [r'(?=.*rating|.*rate)(?=.*7)(?=.*8)'],
    'h_hosp_rating_0_6': [r'(?=.*rating|.*rate)(?=.*0)(?=.*6)'],
    'h_recmnd_dy': [r'(?=.*recommend)(?=.*definitely)(?=.*yes)', r'(?=.*recommend)(?=.*definitely yes)'],
    'h_recmnd_py': [r'(?=.*recommend)(?=.*probably)(?=.*yes)', r'(?=.*recommend)(?=.*probably yes)'],
    'h_recmnd_dn': [r'(?=.*recommend)(?=.*definitely)(?=.*no)', r'(?=.*recommend)(?=.*probably)(?=.*no)']
}

def clean_col(c): return str(c).lower().replace(' ', '').replace('_', '')

def get_year_from_folder(folder_name):
    match = re.search(r'20[0-9]{2}', folder_name)
    return int(match.group(0)) if match else None

def identify_measure(row_text, row_id):
    combined = f"{str(row_text).lower()} {str(row_id).lower()}"
    for measure, patterns in MEASURE_MAP.items():
        if any(re.search(p, combined) for p in patterns):
            return measure
    return None

folders = [f for f in os.listdir(hcahps_dir) if os.path.isdir(os.path.join(hcahps_dir, f)) and ('hcahps20' in f.lower() or 'hchaps20' in f.lower())]
folders.sort()

all_years_data = []

for folder in folders:
    folder_year = get_year_from_folder(folder)
    if not folder_year: continue
    
    # --- EXPERIENCE YEAR SHIFT ---
    # We lag the year by 1 to align performance period with claims data
    experience_year = folder_year - 1
    
    print(f"\nProcessing {folder} (Mapped to Experience Year: {experience_year})...")
    folder_path = os.path.join(hcahps_dir, folder)
    
    # 1. FIND THE TARGET FILE
    target_file = None
    if folder_year <= 2013:
        target_file = os.path.join(folder_path, "dbo_vwHQI_HOSP_HCAHPS_MSR.dta")
        if not os.path.exists(target_file):
            print(f"  [!] Missing DTA file for {folder_year}.")
            continue
    elif folder_year == 2020:
        # STRICTER 2020 FINDER: Must contain Percentages, not just Dimension Linear Scores
        for f in os.listdir(folder_path):
            if f.endswith('.csv'):
                try:
                    cols = pd.read_csv(os.path.join(folder_path, f), nrows=0).columns.tolist()
                    cols_upper = [c.upper() for c in cols]
                    if "FACILITY ID" in cols_upper or "PROVIDER ID" in cols_upper:
                        if any("PERCENT" in c for c in cols_upper) or any("ALWAYS" in c for c in cols_upper) or "HCAHPS MEASURE ID" in cols_upper:
                            target_file = os.path.join(folder_path, f)
                            break
                except: pass
    else:
        for f in os.listdir(folder_path):
            f_lower = f.lower()
            if f.endswith('.csv') and 'hcahps' in f_lower:
                if 'state' not in f_lower and 'national' not in f_lower and 'footnote' not in f_lower:
                    target_file = os.path.join(folder_path, f)
                    break
                    
    if not target_file:
        print(f"  [!] Could not locate target file.")
        continue
        
    print(f"  Reading: {os.path.basename(target_file)}")
    
    try:
        if target_file.endswith('.dta'):
            df = pd.read_stata(target_file)
        else:
            try: df = pd.read_csv(target_file, encoding='utf-8-sig')
            except UnicodeDecodeError: df = pd.read_csv(target_file, encoding='cp1252')
    except Exception as e:
        print(f"  [!] Read Error: {e}")
        continue

    # 3. HARMONIZE COLUMNS
    raw_cols = {clean_col(c): c for c in df.columns}
    
    ccn_col = None
    for c in ['providernumber', 'providerid', 'facilityid']:
        if c in raw_cols: ccn_col = raw_cols[c]; break
    if not ccn_col:
        print("  [!] Could not find CCN column.")
        continue

    # --- 2020 WIDE FORMAT MELT ---
    if 'communicationwithnursesdimensionscore' in raw_cols or 'always' in str(df.columns).lower():
        print("  Melting Wide Format (Socrata)...")
        # <--- FIX: Using ccn_col properly
        id_vars = [ccn_col] 
        value_vars = [c for c in df.columns if c != ccn_col]
        df = df.melt(id_vars=id_vars, value_vars=value_vars, var_name='Measure_Desc', value_name='Score')
        df['Measure_ID'] = ''
        score_col = 'Score'
        desc_col = 'Measure_Desc'
        id_col = 'Measure_ID'
    else:
        id_col, desc_col, score_col = None, None, None
        for c in ['measureid', 'hcahpsmeasureid']:
            if c in raw_cols: id_col = raw_cols[c]; break
        for c in ['hcahpsanswerdescription', 'answerdescription']:
            if c in raw_cols: desc_col = raw_cols[c]; break
        for c in ['hcahpsanswerpercent', 'patientratings', 'score', 'answerpercent', 'hcahpsanswerpercentorlinearscore']:
            if c in raw_cols: score_col = raw_cols[c]; break

    if not score_col:
        print("  [!] Could not find Score column.")
        continue

    if id_col: df[id_col] = df[id_col].fillna('')
    else: df['temp_id'] = ''; id_col = 'temp_id'
        
    if desc_col: df[desc_col] = df[desc_col].fillna('')
    else: df['temp_desc'] = ''; desc_col = 'temp_desc'

    print("  Mapping metrics...")
    df['std_measure'] = df.apply(lambda row: identify_measure(row[desc_col], row[id_col]), axis=1)
    df = df.dropna(subset=['std_measure'])
    
    df['clean_score'] = pd.to_numeric(df[score_col].astype(str).str.replace(r'Not Applicable|Not Available|N/A|\*|%', '', regex=True).str.strip(), errors='coerce')
    
    # <--- FIX: Using ccn_col directly here as well
    pivot_df = df.pivot_table(index=ccn_col, columns='std_measure', values='clean_score', aggfunc='mean').reset_index()
    pivot_df.rename(columns={ccn_col: 'ccn'}, inplace=True)
    pivot_df['year'] = experience_year
    pivot_df['ccn'] = pivot_df['ccn'].astype(str).str.zfill(6)
    
    all_years_data.append(pivot_df)
    print(f"  Success! Extracted {len(pivot_df)} hospitals.")

# --- 7. COMBINE AND SAVE ---
if all_years_data:
    final_df = pd.concat(all_years_data, ignore_index=True)
    save_path = os.path.join(output_dir, "hcahps_master_panel.csv")
    final_df.to_csv(save_path, index=False)
    print(f"\n=== COMPLETE! Saved {len(final_df)} rows to {save_path} ===")
else:
    print("\n[!] No data was successfully processed.")
