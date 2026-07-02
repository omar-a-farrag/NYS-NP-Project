import os
import glob
import pandas as pd
import subprocess

# --- 1. DEFINE PATHS ---
base_dir = r"C:\Users\omarf\Dropbox\personal_files_omar_farrag\Research\projects\NYS_npPolicy\output\summary_stats\demographics"
csv_dir = os.path.join(base_dir, "tables_csv")
pdf_dir = os.path.join(base_dir, "tables_pdf")
os.makedirs(pdf_dir, exist_ok=True)

# Maps for clean labeling
auth_map = {"1": "Restricted", "1.0": "Restricted", "2": "Reduced", "2.0": "Reduced", "3": "Full Practice", "3.0": "Full Practice"}
own_map = {"1": "Government", "1.0": "Government", "2": "For-Profit", "2.0": "For-Profit", "3": "Non-Profit", "3.0": "Non-Profit"}
prov_map = {"1": "MD/DO", "1.0": "MD/DO", "2": "Nurse Practitioner", "2.0": "Nurse Practitioner", "3": "Physician Assistant", "3.0": "Physician Assistant"}

def generate_full_latex(df, row_var_name, title_desc, filename):
    headers = " & ".join([f"\\textbf{{{c}}}" for c in df.columns])
    rows = ""
    for idx in df.index:
        row_vals = []
        for col in df.columns:
            val = df.loc[idx, col]
            row_vals.append("-" if pd.isna(val) else f"{int(val):,}")
        rows += f"        {idx} & " + " & ".join(row_vals) + " \\\\\n"

    latex = f"""\\begin{{table}}[htbp]
    \\centering
    \\caption{{Full Sample Unique Provider Count: {title_desc}}}
    \\vspace{{0.2cm}}
    \\begin{{tabular}}{{l{"c" * len(df.columns)}}}
        \\toprule
        \\textbf{{{row_var_name}}} & {headers} \\\\
        \\midrule
{rows}        \\bottomrule
    \\end{{tabular}}
    \\vspace{{0.1cm}}
    \\begin{{minipage}}{{0.6\\textwidth}}
        \\footnotesize \\textit{{Notes:}} Counts represent total unique human providers across the panel (based on their most recent observed year).
    \\end{{minipage}}
\\end{{table}}"""

    # Compile PDF (Portrait)
    tex_path = os.path.join(pdf_dir, f"{filename}.tex")
    with open(tex_path, 'w') as f:
        f.write(f"\\documentclass[12pt]{{article}}\n\\usepackage{{booktabs}}\n\\usepackage{{geometry}}\n\\usepackage{{caption}}\n\\geometry{{margin=1in}}\n\\begin{{document}}\n\\thispagestyle{{empty}}\n\\vspace*{{2cm}}\n{latex}\n\\end{{document}}")
    try:
        subprocess.run(['pdflatex', '-interaction=nonstopmode', f'-output-directory={pdf_dir}', tex_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for ext in ['.aux', '.log', '.tex']:
            if os.path.exists(os.path.join(pdf_dir, f"{filename}{ext}")): os.remove(os.path.join(pdf_dir, f"{filename}{ext}"))
    except: pass


def generate_yearly_latex(df, row_var_name, valid_row_idx, title_desc, filename):
    years = [str(y) for y in df.columns]
    headers = " & ".join([f"\\textbf{{{y}}}" for y in years])
    
    # Build Multi-Level Rows
    rows = ""
    for prov in ["MD/DO", "Nurse Practitioner", "Physician Assistant"]:
        if prov in df.index.get_level_values(0):
            rows += f"        \\multicolumn{{{len(years) + 1}}}{{l}}{{\\textbf{{{prov}}}}} \\\\\n        \\midrule\n"
            for r_idx in valid_row_idx:
                if (prov, r_idx) in df.index:
                    row_vals = []
                    for col in df.columns:
                        val = df.loc[(prov, r_idx), col]
                        row_vals.append("-" if pd.isna(val) else f"{int(val):,}")
                    rows += f"        \\hspace{{0.5cm}} {r_idx} & " + " & ".join(row_vals) + " \\\\\n"
            rows += "        \\midrule\n"

    latex = f"""\\begin{{table}}[htbp]
    \\centering
    \\caption{{Yearly Active Provider Count: {title_desc}}}
    \\vspace{{0.2cm}}
    \\resizebox{{\\textwidth}}{{!}}{{
    \\begin{{tabular}}{{l{"c" * len(years)}}}
        \\toprule
        \\textbf{{{row_var_name}}} & {headers} \\\\
        \\midrule
{rows}        \\bottomrule
    \\end{{tabular}}
    }}
    \\vspace{{0.1cm}}
    \\begin{{minipage}}{{\\textwidth}}
        \\footnotesize \\textit{{Notes:}} Yearly counts represent active billing providers per year (duplicates dropped per NPI-Year).
    \\end{{minipage}}
\\end{{table}}"""

    # Compile PDF (Landscape)
    tex_path = os.path.join(pdf_dir, f"{filename}.tex")
    with open(tex_path, 'w') as f:
        f.write(f"\\documentclass[12pt, landscape]{{article}}\n\\usepackage{{booktabs}}\n\\usepackage{{geometry}}\n\\usepackage{{caption}}\n\\usepackage{{graphicx}}\n\\geometry{{margin=1in}}\n\\begin{{document}}\n\\thispagestyle{{empty}}\n\\vspace*{{2cm}}\n{latex}\n\\end{{document}}")
    try:
        subprocess.run(['pdflatex', '-interaction=nonstopmode', f'-output-directory={pdf_dir}', tex_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for ext in ['.aux', '.log', '.tex']:
            if os.path.exists(os.path.join(pdf_dir, f"{filename}{ext}")): os.remove(os.path.join(pdf_dir, f"{filename}{ext}"))
    except: pass


# --- 2. PROCESS CSVs ---
csv_files = glob.glob(os.path.join(csv_dir, "*.csv"))

for file in csv_files:
    filename = os.path.basename(file).replace(".csv", "")
    df = pd.read_csv(file)
    df['prov_type'] = df['prov_type'].astype(str).replace(prov_map)
    prefix = "Inpatient" if "inpatient" in filename else "Outpatient ASC"
    
    # A. FULL SAMPLE LOGIC
    if "full" in filename:
        if "auth" in filename:
            df['np_authority'] = df['np_authority'].astype(str).replace(auth_map)
            pv = df.pivot_table(index='np_authority', columns='prov_type', values='provider_count', aggfunc='sum')
            valid_idx = [i for i in ["Restricted", "Reduced", "Full Practice"] if i in pv.index]
            row_name, title = "State NP Authority", "By Authority and Provider Type"
        elif "own" in filename:
            df['own_category'] = df['own_category'].astype(str).replace(own_map)
            pv = df.pivot_table(index='own_category', columns='prov_type', values='provider_count', aggfunc='sum')
            valid_idx = [i for i in ["Government", "Non-Profit", "For-Profit"] if i in pv.index]
            row_name, title = "Hospital Ownership", "By Ownership and Provider Type"
        elif "gender" in filename:
            pv = df.pivot_table(index='is_female', columns='prov_type', values='provider_count', aggfunc='sum')
            valid_idx = [i for i in ["Female", "Male"] if i in pv.index]
            row_name, title = "Provider Gender", "By Gender and Provider Type"

        valid_col = [c for c in ["MD/DO", "Nurse Practitioner", "Physician Assistant"] if c in pv.columns]
        pv = pv.reindex(index=valid_idx, columns=valid_col)
        generate_full_latex(pv, row_name, f"{prefix} {title}", filename)

    # B. YEARLY TIMELINE LOGIC
    elif "year" in filename:
        if "auth" in filename:
            df['np_authority'] = df['np_authority'].astype(str).replace(auth_map)
            pv = df.pivot_table(index=['prov_type', 'np_authority'], columns='year', values='provider_count', aggfunc='sum')
            valid_idx = ["Restricted", "Reduced", "Full Practice"]
            row_name, title = "State NP Authority", "By Authority and Provider Type"
        elif "own" in filename:
            df['own_category'] = df['own_category'].astype(str).replace(own_map)
            pv = df.pivot_table(index=['prov_type', 'own_category'], columns='year', values='provider_count', aggfunc='sum')
            valid_idx = ["Government", "Non-Profit", "For-Profit"]
            row_name, title = "Hospital Ownership", "By Ownership and Provider Type"
        elif "gender" in filename:
            pv = df.pivot_table(index=['prov_type', 'is_female'], columns='year', values='provider_count', aggfunc='sum')
            valid_idx = ["Female", "Male"]
            row_name, title = "Provider Gender", "By Gender and Provider Type"

        generate_yearly_latex(pv, row_name, valid_idx, f"{prefix} {title}", filename)

print("=== DEMOGRAPHIC PDFS GENERATED ===")