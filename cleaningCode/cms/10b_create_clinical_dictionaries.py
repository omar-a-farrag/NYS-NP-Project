import pandas as pd
import os
import subprocess

# --- 1. SETUP PATHS ---
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(script_dir, "..",".."))
csv_dir = os.path.join(project_root, "dictionaries_and_crosswalks")
tex_dir = os.path.join(project_root, "outputs_while_cleaning", "tables")

if not os.path.exists(csv_dir): os.makedirs(csv_dir)
if not os.path.exists(tex_dir): os.makedirs(tex_dir)

print(f"Dictionaries: {csv_dir}")
print(f"LaTeX Tables: {tex_dir}")

# ==============================================================================
# PART 1: DRUG DICTIONARY
# ==============================================================================
drug_data = [
    # --- PART D: OPIOIDS ---
    {"type": "Part D", "keyword": "OXYCODONE",     "category": "Opioid", "sub_category": "Schedule II (Strong)", "high_cost": 0, "desc": "High Abuse Potential"},
    {"type": "Part D", "keyword": "HYDROCODONE",   "category": "Opioid", "sub_category": "Schedule II (Strong)", "high_cost": 0, "desc": "High Abuse Potential"},
    {"type": "Part D", "keyword": "FENTANYL",      "category": "Opioid", "sub_category": "Schedule II (Strong)", "high_cost": 0, "desc": "Synthetic / High Potency"},
    {"type": "Part D", "keyword": "HYDROMORPHONE", "category": "Opioid", "sub_category": "Schedule II (Strong)", "high_cost": 0, "desc": "Dilaudid"},
    {"type": "Part D", "keyword": "MORPHINE",      "category": "Opioid", "sub_category": "Schedule II (Strong)", "high_cost": 0, "desc": "Standard Opioid"},
    {"type": "Part D", "keyword": "METHADONE",     "category": "Opioid", "sub_category": "Schedule II (Strong)", "high_cost": 0, "desc": "Long-acting"},
    {"type": "Part D", "keyword": "OXYMORPHONE",   "category": "Opioid", "sub_category": "Schedule II (Strong)", "high_cost": 1, "desc": "High Potency"},
    {"type": "Part D", "keyword": "TRAMADOL",      "category": "Opioid", "sub_category": "Schedule III/IV (Weak)", "high_cost": 0, "desc": "Lower Risk"},
    {"type": "Part D", "keyword": "CODEINE",       "category": "Opioid", "sub_category": "Schedule III/IV (Weak)", "high_cost": 0, "desc": "Cough/Mild Pain"},
    {"type": "Part D", "keyword": "BUPRENORPHINE", "category": "Opioid", "sub_category": "Schedule III/IV (Weak)", "high_cost": 1, "desc": "MAT/Pain"},

    # --- PART D: MUSCLE RELAXANTS & GABAPENTINOIDS ---
    {"type": "Part D", "keyword": "CARISOPRODOL",  "category": "Muscle Relaxant", "sub_category": "High Abuse", "high_cost": 0, "desc": "Soma (Holy Trinity)"},
    {"type": "Part D", "keyword": "CYCLOBENZAPRINE", "category": "Muscle Relaxant", "sub_category": "Standard", "high_cost": 0, "desc": "Flexeril"},
    {"type": "Part D", "keyword": "METHOCARBAMOL", "category": "Muscle Relaxant", "sub_category": "Standard", "high_cost": 0, "desc": "Robaxin"},
    {"type": "Part D", "keyword": "GABAPENTIN",    "category": "Gabapentinoid", "sub_category": "Neuropathic Pain", "high_cost": 0, "desc": "Neurontin"},
    {"type": "Part D", "keyword": "PREGABALIN",    "category": "Gabapentinoid", "sub_category": "Neuropathic Pain", "high_cost": 1, "desc": "Lyrica"},

    # --- PART D: SEDATIVES ---
    {"type": "Part D", "keyword": "ZOLPIDEM",      "category": "Sedative", "sub_category": "Z-Drug", "high_cost": 0, "desc": "Ambien"},
    {"type": "Part D", "keyword": "ESZOPICLONE",   "category": "Sedative", "sub_category": "Z-Drug", "high_cost": 1, "desc": "Lunesta"},
    {"type": "Part D", "keyword": "ALPRAZOLAM",    "category": "Sedative", "sub_category": "Benzodiazepine", "high_cost": 0, "desc": "Xanax"},
    {"type": "Part D", "keyword": "LORAZEPAM",     "category": "Sedative", "sub_category": "Benzodiazepine", "high_cost": 0, "desc": "Ativan"},
    {"type": "Part D", "keyword": "CLONAZEPAM",    "category": "Sedative", "sub_category": "Benzodiazepine", "high_cost": 0, "desc": "Klonopin"},

    # --- PART D: ANTIBIOTICS ---
    {"type": "Part D", "keyword": "AZITHROMYCIN",  "category": "Antibiotic", "sub_category": "Broad Spectrum", "high_cost": 0, "desc": "Z-Pak"},
    {"type": "Part D", "keyword": "LEVOFLOXACIN",  "category": "Antibiotic", "sub_category": "Broad Spectrum", "high_cost": 0, "desc": "Fluoroquinolone"},
    {"type": "Part D", "keyword": "CIPROFLOXACIN", "category": "Antibiotic", "sub_category": "Broad Spectrum", "high_cost": 0, "desc": "Fluoroquinolone"},
    {"type": "Part D", "keyword": "AMOXICILLIN AND CLAVULANATE", "category": "Antibiotic", "sub_category": "Broad Spectrum", "high_cost": 0, "desc": "Augmentin"},
    {"type": "Part D", "keyword": "AMOXICILLIN",   "category": "Antibiotic", "sub_category": "Narrow Spectrum", "high_cost": 0, "desc": "First Line"},
    {"type": "Part D", "keyword": "DOXYCYCLINE",   "category": "Antibiotic", "sub_category": "Narrow Spectrum", "high_cost": 0, "desc": "Tetracycline"},

    # --- PART D: CONTROLS ---
    {"type": "Part D", "keyword": "ATORVASTATIN",  "category": "Control", "sub_category": "Chronic Care", "high_cost": 0, "desc": "Statin"},
    {"type": "Part D", "keyword": "LISINOPRIL",    "category": "Control", "sub_category": "Chronic Care", "high_cost": 0, "desc": "Antihypertensive"},
    {"type": "Part D", "keyword": "METFORMIN",     "category": "Control", "sub_category": "Chronic Care", "high_cost": 0, "desc": "Diabetes"},

    # --- PART B: PAIN & VISCO ---
    {"type": "Part B", "keyword": "J1885", "category": "Pain Injection", "sub_category": "NSAID", "high_cost": 0, "desc": "Toradol"},
    {"type": "Part B", "keyword": "J3301", "category": "Pain Injection", "sub_category": "Steroid", "high_cost": 0, "desc": "Triamcinolone"},
    {"type": "Part B", "keyword": "J1030", "category": "Pain Injection", "sub_category": "Steroid", "high_cost": 0, "desc": "Methylprednisolone"},
    {"type": "Part B", "keyword": "J1100", "category": "Pain Injection", "sub_category": "Steroid", "high_cost": 0, "desc": "Dexamethasone"},
    {"type": "Part B", "keyword": "J7325", "category": "Viscosupplement", "sub_category": "Knee Gel", "high_cost": 1, "desc": "Synvisc ($500+)"},
    {"type": "Part B", "keyword": "J7323", "category": "Viscosupplement", "sub_category": "Knee Gel", "high_cost": 1, "desc": "Euflexxa ($500+)"},
    {"type": "Part B", "keyword": "J7321", "category": "Viscosupplement", "sub_category": "Knee Gel", "high_cost": 1, "desc": "Hyalgan ($300+)"},

    # --- PART B: OPHTHALMOLOGY ---
    {"type": "Part B", "keyword": "J2778", "category": "Ophthalmology", "sub_category": "Macular Degen", "high_cost": 1, "desc": "Lucentis ($1,200)"},
    {"type": "Part B", "keyword": "J0178", "category": "Ophthalmology", "sub_category": "Macular Degen", "high_cost": 1, "desc": "Eylea ($1,800)"},
    {"type": "Part B", "keyword": "J9035", "category": "Ophthalmology", "sub_category": "Macular Degen", "high_cost": 0, "desc": "Avastin ($50) [Control]"},

    # --- PART B: ANTIBIOTICS & CHEMO ---
    {"type": "Part B", "keyword": "J0696", "category": "Antibiotic", "sub_category": "Infection", "high_cost": 0, "desc": "Ceftriaxone"},
    {"type": "Part B", "keyword": "J1580", "category": "Antibiotic", "sub_category": "Infection", "high_cost": 0, "desc": "Gentamicin"},
    {"type": "Part B", "keyword": "J0690", "category": "Antibiotic", "sub_category": "Infection", "high_cost": 0, "desc": "Cefazolin"},
    {"type": "Part B", "keyword": "J0875", "category": "Antibiotic", "sub_category": "Infection", "high_cost": 1, "desc": "Dalbavancin ($1,500+)"},
    {"type": "Part B", "keyword": "J9267", "category": "Chemotherapy", "sub_category": "Chemo", "high_cost": 1, "desc": "Paclitaxel"},
    {"type": "Part B", "keyword": "J9310", "category": "Chemotherapy", "sub_category": "Biologic", "high_cost": 1, "desc": "Rituximab"},
    {"type": "Part B", "keyword": "J1745", "category": "Chemotherapy", "sub_category": "Biologic", "high_cost": 1, "desc": "Infliximab"}
]

# ==============================================================================
# PART 2: SERVICE DICTIONARY
# ==============================================================================
service_data = []

# E&M
for code in ["99202", "99212"]:
    service_data.append({"hcpcs": code, "category": "E&M", "sub_category": "Low Intensity", "high_cost": 0, "desc": "Office Visit (Level 2)"})
for code in ["99203", "99213"]: 
    service_data.append({"hcpcs": code, "category": "E&M", "sub_category": "Standard Visit", "high_cost": 0, "desc": "Office Visit (Level 3)"})
for code in ["99204", "99205", "99214", "99215"]:
    service_data.append({"hcpcs": code, "category": "E&M", "sub_category": "High Intensity", "high_cost": 1, "desc": "Office Visit (Level 4/5)"})
for code in ["99284", "99285"]:
    service_data.append({"hcpcs": code, "category": "E&M", "sub_category": "ED Visit High", "high_cost": 1, "desc": "ED Level 4/5"})

# Imaging
for code in ["72141", "72148", "72158", "72040"]:
    service_data.append({"hcpcs": code, "category": "Imaging", "sub_category": "Low Value Spine", "high_cost": 1, "desc": "Spine MRI/CT"})
for code in ["70450", "70460", "70470"]:
    service_data.append({"hcpcs": code, "category": "Imaging", "sub_category": "Low Value Head", "high_cost": 1, "desc": "Head CT"})

# Testing
for code in ["93306", "93307", "93308"]:
    service_data.append({"hcpcs": code, "category": "Testing", "sub_category": "Cardiac Echo", "high_cost": 1, "desc": "Echocardiogram"})
for code in ["78452", "78451"]:
    service_data.append({"hcpcs": code, "category": "Testing", "sub_category": "Nuclear Stress", "high_cost": 1, "desc": "Nuclear Stress ($400+)"})

# Procedures
service_data.append({"hcpcs": "29881", "category": "Procedure", "sub_category": "Discretionary Ortho", "high_cost": 1, "desc": "Knee Arthroscopy"})
service_data.append({"hcpcs": "17000", "category": "Procedure", "sub_category": "Discretionary Derm", "high_cost": 0, "desc": "Lesion Destruction"})
service_data.append({"hcpcs": "11200", "category": "Procedure", "sub_category": "Discretionary Derm", "high_cost": 0, "desc": "Skin Tag Removal"})
service_data.append({"hcpcs": "66984", "category": "Procedure", "sub_category": "Ophthalmology", "high_cost": 1, "desc": "Cataract Removal"})

# Controls
for code in ["90686", "90688", "G0438", "G0439", "G0008"]:
    service_data.append({"hcpcs": code, "category": "Control", "sub_category": "Preventive", "high_cost": 0, "desc": "Preventive/Vaccine"})

# ==============================================================================
# PART 3: SAVE CSVs
# ==============================================================================
df_drugs = pd.DataFrame(drug_data)
df_services = pd.DataFrame(service_data)
df_drugs.to_csv(os.path.join(csv_dir, "drug_class_map.csv"), index=False)
df_services.to_csv(os.path.join(csv_dir, "service_class_map.csv"), index=False)
print("Saved CSV Maps.")

# ==============================================================================
# PART 4: GENERATE 3 SEPARATE PDF TABLES
# ==============================================================================
def create_pdf(df, filename, caption, label, columns, col_names):
    # Rename for display
    display_df = df[columns].copy()
    display_df.columns = col_names
    
    # Generate LaTeX with basic 'l' columns first
    latex_code = display_df.to_latex(index=False, longtable=True, caption=caption, label=label, escape=True)
    
    # FORMATTING FIX: Force column widths to prevent page overflow
    # We replace the default column spec (e.g. {lllll}) with a custom one
    # Adjust widths: Category (2cm), Sub (3cm), Key (3cm), Cost (1cm), Desc (5cm)
    custom_col_spec = "{p{2cm}p{3.5cm}p{3.5cm}cp{5cm}}"
    if "HCPCS" in col_names: # Adjust for service table
        custom_col_spec = "{p{2cm}p{3.5cm}p{1.5cm}cp{5cm}}"
        
    # Inject custom column spec
    # The default output is \begin{longtable}{lllll}. We replace the content inside {}.
    start_idx = latex_code.find("{longtable}") + 11
    end_idx = latex_code.find("}", start_idx) + 1
    current_spec = latex_code[start_idx:end_idx] # e.g. {lllll}
    latex_code = latex_code.replace(current_spec, custom_col_spec)

    latex_code = "{\\small\n" + latex_code + "\n}"
    
    tex_path = os.path.join(tex_dir, filename)
    with open(tex_path, 'w') as f:
        f.write(latex_code)

    wrapper_name = filename.replace(".tex", "_preview.tex")
    wrapper_path = os.path.join(tex_dir, wrapper_name)
    wrapper_content = f"""
\\documentclass{{article}}
\\usepackage[utf8]{{inputenc}}
\\usepackage[margin=0.5in]{{geometry}}
\\usepackage{{booktabs}}
\\usepackage{{longtable}}
\\usepackage{{array}}
\\title{{Appendix Preview: {label}}}
\\date{{}}
\\begin{{document}}
\\maketitle
\\input{{{filename}}}
\\end{{document}}
    """
    with open(wrapper_path, 'w') as f:
        f.write(wrapper_content)

    print(f"Compiling {filename}...")
    try:
        subprocess.run(["pdflatex", "-interaction=nonstopmode", wrapper_name], cwd=tex_dir, stdout=subprocess.DEVNULL, check=True)
        print(f"SUCCESS! Created {wrapper_name.replace('.tex', '.pdf')}")
    except Exception:
        print(f"ERROR compiling {filename}")

# 1. PART D DRUGS
df_partd = df_drugs[df_drugs['type'] == 'Part D'].sort_values(['category', 'sub_category'])
create_pdf(df_partd, "appendix_partd_drugs.tex", "Part D Drug Classification (Pharmacy)", "tab:partd", 
           ['category', 'sub_category', 'keyword', 'high_cost', 'desc'], 
           ['Category', 'Sub-Category', 'Keyword', 'High Cost', 'Description'])

# 2. PART B DRUGS
df_partb = df_drugs[df_drugs['type'] == 'Part B'].sort_values(['category', 'sub_category'])
create_pdf(df_partb, "appendix_partb_drugs.tex", "Part B Drug Classification (Clinic)", "tab:partb", 
           ['category', 'sub_category', 'keyword', 'high_cost', 'desc'], 
           ['Category', 'Sub-Category', 'J-Code', 'High Cost', 'Description'])

# 3. SERVICES
df_svc = df_services.sort_values(['category', 'sub_category'])
create_pdf(df_svc, "appendix_services.tex", "Service Classification (CPT)", "tab:services", 
           ['category', 'sub_category', 'hcpcs', 'high_cost', 'desc'], 
           ['Category', 'Sub-Category', 'HCPCS', 'High Cost', 'Description'])
