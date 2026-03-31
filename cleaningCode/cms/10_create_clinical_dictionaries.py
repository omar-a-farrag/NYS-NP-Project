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
    {"type": "Part D", "keyword": "BUPRENORPHINE", "category": "Opioid", "sub_category": "Schedule III/IV (Weak)", "high_cost": 1, "desc": "Partial Agonist (MAT)"},
    {"type": "Part D", "keyword": "CODEINE",       "category": "Opioid", "sub_category": "Schedule III/IV (Weak)", "high_cost": 0, "desc": "Often combo product"},

    # --- PART D: HIGH RISK (BEERS CRITERIA / CHOOSING WISELY) ---
    {"type": "Part D", "keyword": "KETOROLAC",     "category": "High-Risk", "sub_category": "NSAID", "high_cost": 0, "desc": "Max 5 days use (renal/GI risk)"},
    {"type": "Part D", "keyword": "CARISOPRODOL",  "category": "High-Risk", "sub_category": "Muscle Relaxant", "high_cost": 0, "desc": "High abuse potential (Soma)"},
    {"type": "Part D", "keyword": "ALPRAZOLAM",    "category": "High-Risk", "sub_category": "Benzodiazepine", "high_cost": 0, "desc": "Fall risk in elderly"},
    {"type": "Part D", "keyword": "DIAZEPAM",      "category": "High-Risk", "sub_category": "Benzodiazepine", "high_cost": 0, "desc": "Long half-life"},

    # --- PART D: LOW VALUE / OVERUSED ---
    {"type": "Part D", "keyword": "ESOMEPRAZOLE",  "category": "Low-Value", "sub_category": "PPI", "high_cost": 0, "desc": "Overprescribed for simple GERD"},
    {"type": "Part D", "keyword": "ZOLPIDEM",      "category": "Low-Value", "sub_category": "Sedative", "high_cost": 0, "desc": "Overprescribed for insomnia"},

    # --- PART D: HIGH VALUE (CHRONIC DISEASE MANAGEMENT) ---
    {"type": "Part D", "keyword": "LISINOPRIL",    "category": "High-Value", "sub_category": "ACE Inhibitor", "high_cost": 0, "desc": "First-line HTN/Heart Failure"},
    {"type": "Part D", "keyword": "LOSARTAN",      "category": "High-Value", "sub_category": "ARB", "high_cost": 0, "desc": "First-line HTN/Heart Failure"},
    {"type": "Part D", "keyword": "ATORVASTATIN",  "category": "High-Value", "sub_category": "Statin", "high_cost": 0, "desc": "High-intensity lipid lowering"},
    {"type": "Part D", "keyword": "METFORMIN",     "category": "High-Value", "sub_category": "Biguanide", "high_cost": 0, "desc": "First-line Type 2 Diabetes"}
]

# ==============================================================================
# PART 2: MEDICAL SERVICES (HCPCS) DICTIONARY
# ==============================================================================
service_data = [
    # --- PART B: ADVANCED IMAGING (HIGH VARIATION/COST) ---
    {"type": "Part B", "keyword": "72141", "category": "Imaging", "sub_category": "MRI Cervical Spine", "high_cost": 1, "desc": "w/o contrast"},
    {"type": "Part B", "keyword": "72148", "category": "Imaging", "sub_category": "MRI Lumbar Spine", "high_cost": 1, "desc": "w/o contrast (often low-value for acute back pain)"},
    {"type": "Part B", "keyword": "70450", "category": "Imaging", "sub_category": "CT Head/Brain", "high_cost": 1, "desc": "w/o contrast"},
    {"type": "Part B", "keyword": "71250", "category": "Imaging", "sub_category": "CT Thorax", "high_cost": 1, "desc": "w/o contrast"},
    {"type": "Part B", "keyword": "74176", "category": "Imaging", "sub_category": "CT Abdomen/Pelvis", "high_cost": 1, "desc": "w/o contrast"},
    {"type": "Part B", "keyword": "93306", "category": "Imaging", "sub_category": "Echocardiogram", "high_cost": 1, "desc": "TTE complete w/ Doppler"},

    # --- PART B: HIGH VALUE PREVENTIVE ---
    {"type": "Part B", "keyword": "G0438", "category": "High-Value", "sub_category": "Preventive", "high_cost": 0, "desc": "Annual Wellness Visit (Initial)"},
    {"type": "Part B", "keyword": "G0439", "category": "High-Value", "sub_category": "Preventive", "high_cost": 0, "desc": "Annual Wellness Visit (Subsequent)"},
    {"type": "Part B", "keyword": "G0202", "category": "High-Value", "sub_category": "Screening", "high_cost": 0, "desc": "Screening Mammography"},
    {"type": "Part B", "keyword": "G0105", "category": "High-Value", "sub_category": "Screening", "high_cost": 0, "desc": "Colorectal Cancer Screening (High Risk)"},
    {"type": "Part B", "keyword": "G0121", "category": "High-Value", "sub_category": "Screening", "high_cost": 0, "desc": "Colorectal Cancer Screening (Not High Risk)"},

    # --- PART B: LOW VALUE SERVICES (CHOOSING WISELY) ---
    {"type": "Part B", "keyword": "20610", "category": "Low-Value", "sub_category": "Joint Injection", "high_cost": 0, "desc": "Major joint/bursa injection (Often overused for OA)"},
    {"type": "Part B", "keyword": "77080", "category": "Low-Value", "sub_category": "DEXA Scan", "high_cost": 0, "desc": "Overused in low-risk women <65"},
    {"type": "Part B", "keyword": "80305", "category": "Low-Value", "sub_category": "Urine Drug Screen", "high_cost": 0, "desc": "Presumptive, any number of drug classes (often over-tested)"},
    {"type": "Part B", "keyword": "93000", "category": "Low-Value", "sub_category": "EKG", "high_cost": 0, "desc": "Routine EKG in asymptomatic patients"},
   
    # --- PART B: EVALUATION & MANAGEMENT (UPCODING METRICS) ---
    {"type": "Part B", "keyword": "99212", "category": "E&M", "sub_category": "Established Patient", "high_cost": 0, "desc": "Level 2 (10-19 minutes)"},
    {"type": "Part B", "keyword": "99213", "category": "E&M", "sub_category": "Established Patient", "high_cost": 0, "desc": "Level 3 (20-29 minutes)"},
    {"type": "Part B", "keyword": "99214", "category": "E&M", "sub_category": "Established Patient", "high_cost": 0, "desc": "Level 4 (30-39 mins - High Intensity)"},
    {"type": "Part B", "keyword": "99215", "category": "E&M", "sub_category": "Established Patient", "high_cost": 0, "desc": "Level 5 (40-54 mins - Highest Intensity)"}
]

# ==============================================================================
# PART 3: EXPORT TO CSV
# ==============================================================================
df_drugs = pd.DataFrame(drug_data)
df_drugs.to_csv(os.path.join(csv_dir, "dict_partd_clinical.csv"), index=False)

df_services = pd.DataFrame(service_data)
df_services.to_csv(os.path.join(csv_dir, "dict_partb_clinical.csv"), index=False)

print("Saved clinical dictionaries to CSV.")

# ==============================================================================
# PART 4: GENERATE LATEX APPENDIX TABLES
# ==============================================================================
def create_pdf(df, filename, caption, label, columns, col_names):
    """Generates a professional LaTeX table and compiles a preview PDF."""
    tex_path = os.path.join(tex_dir, filename)
    
    # 1. Export the table fragment
    latex_str = df.to_latex(
        index=False,
        columns=columns,
        header=col_names,
        caption=caption,
        label=label,
        longtable=False,
        escape=True,
        column_format="llp{3cm}p{4cm}",
        position="htbp"
    )
    
    # Add table styling
    latex_str = latex_str.replace("\\toprule", "\\toprule\n\\rowcolor{gray!10}")
    
    with open(tex_path, 'w') as f:
        f.write(latex_str)

    # 2. Create the wrapper
    wrapper_name = filename.replace(".tex", "_preview.tex")
    wrapper_path = os.path.join(tex_dir, wrapper_name)
    wrapper_content = f"""\\documentclass[11pt]{{article}}
\\usepackage[margin=1in]{{geometry}}
\\usepackage{{booktabs}}
\\usepackage{{longtable}}
\\usepackage{{caption}}
\\usepackage[table]{{xcolor}}

\\begin{{document}}
\\listoftables
\\vspace{{1cm}}
\\input{{{filename}}}
\\end{{document}}
"""
    with open(wrapper_path, 'w') as f:
        f.write(wrapper_content)

    # 3. Compile PDF
    print(f"Compiling {filename}...")
    try:
        subprocess.run(['pdflatex', '-interaction=nonstopmode', wrapper_name], 
                       cwd=tex_dir, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        print(f"ERROR compiling {filename}")

# Differentiate Data
df_opioids = df_drugs[df_drugs['category'] == 'Opioid']
df_other_drugs = df_drugs[df_drugs['category'] != 'Opioid']
df_imaging = df_services[df_services['category'] == 'Imaging']
df_other_services = df_services[df_services['category'] != 'Imaging']

drug_cols = ['keyword', 'category', 'sub_category', 'desc']
drug_names = ['Molecule', 'Classification', 'Sub-Class', 'Clinical Rationale']

svc_cols = ['keyword', 'category', 'sub_category', 'desc']
svc_names = ['HCPCS', 'Classification', 'Service Type', 'Clinical Rationale']

# --- DYNAMIC CAPTIONS WITH N-COUNTS ---
n_opioids = len(df_opioids)
cap_opioids = f"Targeted Part D Clinical Phenotype: Schedule II and III Opioids ($N={n_opioids}$ molecules)."
create_pdf(df_opioids, "appendix_partd_opioids.tex", cap_opioids, "tab:opioids", drug_cols, drug_names)

n_drugs = len(df_other_drugs)
cap_drugs = f"Targeted Part D Clinical Phenotypes: High-Value, High-Risk, and Low-Value prescribing ($N={n_drugs}$ molecules)."
create_pdf(df_other_drugs, "appendix_partd_drugs.tex", cap_drugs, "tab:drugs", drug_cols, drug_names)

n_imaging = len(df_imaging)
cap_imaging = f"Targeted Part B Clinical Phenotype: Advanced Imaging Services ($N={n_imaging}$ HCPCS codes)."
create_pdf(df_imaging, "appendix_partb_imaging.tex", cap_imaging, "tab:imaging", svc_cols, svc_names)

n_services = len(df_other_services)
cap_services = f"Targeted Part B Clinical Phenotypes: High-Value and Low-Value Services ($N={n_services}$ HCPCS codes)."
create_pdf(df_other_services, "appendix_services.tex", cap_services, "tab:services", svc_cols, svc_names)

df_em = df_services[df_services['category'] == 'E&M']
n_em = len(df_em)
cap_em = f"Targeted Part B Clinical Phenotype: Evaluation and Management (E\\&M) Office Visits ($N={n_em}$ HCPCS codes)."
create_pdf(df_em, "appendix_partb_em.tex", cap_em, "tab:em_codes", svc_cols, svc_names)

print("\nSUCCESS: All dictionaries and LaTeX previews generated!")