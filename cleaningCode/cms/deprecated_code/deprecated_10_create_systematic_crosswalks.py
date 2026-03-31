import pandas as pd
import numpy as np
import os
import glob
import time

# --- 1. SETUP PATHS ---
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(script_dir, "..",".."))

dict_dir = os.path.join(project_root, "dictionaries_and_crosswalks")
partd_dir = os.path.join(project_root, "cms", "partD", "dta", "harmonized")
output_dir = dict_dir 

print("--- STARTING SYSTEMATIC CROSSWALK GENERATION ---")

# ==============================================================================
# PART 1: RBCS (BETOS) SERVICES CROSSWALK
# ==============================================================================
print("\n1. Processing RBCS (CMS Official Service Categories)...")
rbcs_path = os.path.join(dict_dir, "RBCS_RY_2025.csv")

try:
    df_rbcs = pd.read_csv(rbcs_path, encoding='latin1', low_memory=False)
    
    # CMS columns: HCPCS_Cd, RBCS_Cat_Desc, RBCS_Subcat_Desc, RBCS_Family_Desc
    cols = ['HCPCS_Cd', 'RBCS_Cat_Desc', 'RBCS_Subcat_Desc', 'RBCS_Family_Desc']
    df_rbcs_clean = df_rbcs[cols].copy()
    df_rbcs_clean.columns = ['hcpcs', 'rbcs_cat', 'rbcs_subcat', 'rbcs_family']
    
    # Keep only the latest assignment per code
    df_rbcs_clean = df_rbcs_clean.drop_duplicates(subset=['hcpcs'], keep='last')
    
    out_path = os.path.join(output_dir, "crosswalk_rbcs_services.csv")
    df_rbcs_clean.to_csv(out_path, index=False)
    print(f"  > SUCCESS: Saved RBCS Map with {len(df_rbcs_clean):,} codes.")
    
except Exception as e:
    print(f"  > ERROR processing RBCS file: {e}\nEnsure RBCS_RY_2025.csv is in {dict_dir}")

# ==============================================================================
# PART 2: PART D USAN STEM CLASSIFIER & EMPIRICAL COSTS
# ==============================================================================
print("\n2. Scanning Part D for Empirical Costs & Therapeutic Classes...")

# Function to map drugs to classes using FDA/WHO USAN Stems
def assign_usan_class(drug_name):
    drug = str(drug_name).upper()
    if any(x in drug for x in ['STATIN', 'PRIL', 'SARTAN', 'DIPINE', 'LOL', 'ZOSIN']): return 'Cardiovascular'
    if any(x in drug for x in ['PRAZOLE', 'TIDINE']): return 'Gastrointestinal'
    if any(x in drug for x in ['FLOXACIN', 'CILLIN', 'CEF', 'MYCIN', 'CYCLINE', 'VIR']): return 'Anti-Infective'
    if any(x in drug for x in ['OXETINE', 'TRIPTYLINE', 'ZODONE', 'LAFAXINE', 'TALOPRAM']): return 'CNS (Antidepressant)'
    if any(x in drug for x in ['ZOLAM', 'AZEPAM']): return 'CNS (Benzodiazepine)'
    if any(x in drug for x in ['CODONE', 'MORPHONE', 'FENTANYL', 'TRAMADOL', 'BUPRENORPHINE']): return 'CNS (Opioid)'
    if any(x in drug for x in ['GABAPENTIN', 'PREGABALIN']): return 'CNS (Gabapentinoid)'
    if any(x in drug for x in ['GLIPTIN', 'GLUTIDE', 'GLIFLOZIN', 'METFORMIN', 'INSULIN']): return 'Metabolic/Diabetes'
    if any(x in drug for x in ['MAB', 'NIB']): return 'Immunology/Oncology'
    if any(x in drug for x in ['SONE', 'LONE']): return 'Corticosteroid'
    return 'Other/Unclassified'

# Dictionary to hold raw data across files
# {generic_name: {'cost': sum, 'claims': sum}}
drug_stats = {}
brand_map = set() # To track brand vs generic names

# Scan a 3-year slice of files to get a stable, massive sample size
files = glob.glob(os.path.join(partd_dir, "*.dta"))[:3] 

for f in files:
    fname = os.path.basename(f)
    print(f"  Scanning {fname}...", end=" ")
    try:
        # We need generic name, brand name, cost, and claims volume
        df = pd.read_stata(f, columns=['generic_name', 'brnd_name', 'tot_drug_cst', 'tot_clms'])
        
        df['generic_name'] = df['generic_name'].astype(str).str.upper().str.strip()
        df['brnd_name'] = df['brnd_name'].astype(str).str.upper().str.strip()
        
        # 1. Update Brand Map (If brand name != generic name, it's a trade name)
        for _, row in df[['brnd_name', 'generic_name']].drop_duplicates().iterrows():
            brand_map.add((row['brnd_name'], row['generic_name']))
        
        # 2. Update Cost Stats
        grp = df.groupby('generic_name')[['tot_drug_cst', 'tot_clms']].sum()
        for name, row in grp.iterrows():
            if name not in drug_stats:
                drug_stats[name] = {'cost': 0.0, 'claims': 0.0}
            drug_stats[name]['cost'] += row['tot_drug_cst']
            drug_stats[name]['claims'] += row['tot_clms']
            
        print("Done.")
    except Exception as e:
        print(f"Error: {e}")

# ==============================================================================
# PART 3: CALCULATE QUARTILES & EXPORT
# ==============================================================================
print("\n3. Calculating Within-Class Cost Percentiles...")

# Compile the cost data
cost_data = []
for name, stats in drug_stats.items():
    if stats['claims'] > 100: # Filter out extremely rare drugs/noise
        avg_cost = stats['cost'] / stats['claims']
        usan_class = assign_usan_class(name)
        cost_data.append({
            'generic_name': name,
            'usan_class': usan_class,
            'avg_cost_per_claim': avg_cost,
            'total_volume': stats['claims']
        })

df_costs = pd.DataFrame(cost_data)

# Calculate Top Quartile (High Cost) *WITHIN* each therapeutic class
df_costs['is_high_cost_in_class'] = 0

for usan_class in df_costs['usan_class'].unique():
    class_mask = df_costs['usan_class'] == usan_class
    
    # If a class has very few drugs, skip percentile logic
    if class_mask.sum() > 5:
        threshold = df_costs.loc[class_mask, 'avg_cost_per_claim'].quantile(0.75)
        
        # Flag drugs above the 75th percentile for their class
        df_costs.loc[class_mask & (df_costs['avg_cost_per_claim'] >= threshold), 'is_high_cost_in_class'] = 1

# Save Empirical Costs Map
df_costs.to_csv(os.path.join(output_dir, "crosswalk_partd_empirical_costs.csv"), index=False)
high_cost_count = df_costs['is_high_cost_in_class'].sum()
print(f"  > SUCCESS: Classified {len(df_costs):,} generic drugs into USAN classes.")
print(f"  > Flagged {high_cost_count:,} drugs as 'Top 25% Cost' for their class.")

# Process Brand Map
print("\n4. Saving Brand vs Generic Map...")
brand_list = []
for brnd, gnrc in brand_map:
    # A drug is considered a "Brand Fill" if the dispensed brand name does not match the generic molecule name
    is_brand_fill = 1 if brnd != gnrc else 0
    brand_list.append({'brnd_name': brnd, 'generic_name': gnrc, 'is_brand_fill': is_brand_fill})

df_brand = pd.DataFrame(brand_list).drop_duplicates()
df_brand.to_csv(os.path.join(output_dir, "crosswalk_partd_brand_generic.csv"), index=False)
print(f"  > SUCCESS: Saved Brand map with {len(df_brand):,} trade names.")

print("\nALL SYSTEMATIC CROSSWALKS CREATED.")