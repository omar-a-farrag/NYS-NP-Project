import os
import glob
import pandas as pd
import subprocess

# =====================================================
# PATHS
# =====================================================
out_root = r"C:\Users\omarf\Dropbox\personal_files_omar_farrag\Research\projects\NYS_npPolicy\output\summary_stats\demographics_nys"
csv_dir = os.path.join(out_root, "tables_csv")
tex_dir = os.path.join(out_root, "tables_pdf")
os.makedirs(tex_dir, exist_ok=True)

print("=== GENERATING NYS JOURNAL-QUALITY LATEX TABLES ===")

# Maps for clean provider labeling (Handles Stata numeric exports gracefully)
auth_map = {"1": "Restricted", "1.0": "Restricted", "2": "Reduced", "2.0": "Reduced", "3": "Full Practice", "3.0": "Full Practice"}
own_map = {"1": "Government", "1.0": "Government", "2": "For-Profit", "2.0": "For-Profit", "3": "Non-Profit", "3.0": "Non-Profit"}
prov_map = {"1": "MD/DO", "1.0": "MD/DO", "2": "Nurse Practitioner", "2.0": "Nurse Practitioner", "3": "Physician Assistant", "3.0": "Physician Assistant"}

# =====================================================
# CORE FUNCTIONS
# =====================================================
def compile_to_pdf(filename_base, table_content, landscape=False):
    orientation = r"\usepackage{pdflscape}" if landscape else ""
    doc = rf"""\documentclass{{article}}
\usepackage[margin=0.6in]{{geometry}}
\usepackage{{booktabs}}
\usepackage{{threeparttable}}
\usepackage{{longtable}}
\usepackage{{array}}
\usepackage{{graphicx}}
\usepackage{{multirow}}
{orientation}

\begin{{document}}
{table_content}
\end{{document}}
"""
    tex_path = os.path.join(tex_dir, f"{filename_base}.tex")
    with open(tex_path, "w", encoding="utf-8") as f:
        f.write(doc)
    try:
        subprocess.run(["pdflatex", "-interaction=nonstopmode", "-output-directory", tex_dir, tex_path],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f" -> Successfully compiled: {filename_base}.pdf")
    except Exception as e:
        print(f" -> WARNING: Compilation failed for {filename_base}.tex")

def latex_resize(tex):
    lines = tex.splitlines()
    out = []
    for line in lines:
        if line.startswith(r"\begin{tabular}"):
            out.append(r"\resizebox{\textwidth}{!}{%")
            out.append(line)
        elif line.startswith(r"\end{tabular}"):
            out.append(line)
            out.append(r"}")
        else:
            out.append(line)
    return "\n".join(out)

# =====================================================
# SECTION A: PROVIDER TABLES LOGIC
# =====================================================
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
\\caption{{Full Sample Unique NYS Provider Count: {title_desc}}}
\\label{{tab:{filename}}}
\\begin{{threeparttable}}
\\begin{{tabular}}{{l{"c" * len(df.columns)}}}
\\toprule
\\textbf{{{row_var_name}}} & {headers} \\\\
\\midrule
{rows}\\bottomrule
\\end{{tabular}}
\\begin{{tablenotes}}[flushleft]
\\footnotesize
\\item Notes: Counts represent unique billing providers in New York across the panel.
\\end{{tablenotes}}
\\end{{threeparttable}}
\\end{{table}}"""
    compile_to_pdf(filename, latex)

def generate_yearly_latex(df, row_var_name, valid_row_idx, title_desc, filename):
    years = [str(y) for y in df.columns]
    headers = " & ".join([f"\\textbf{{{y}}}" for y in years])
    
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

    latex = f"""\\begin{{landscape}}
\\begin{{table}}[htbp]
\\centering
\\caption{{Yearly Active NYS Provider Count: {title_desc}}}
\\label{{tab:{filename}}}
\\begin{{threeparttable}}
\\resizebox{{\\textwidth}}{{!}}{{
\\begin{{tabular}}{{l{"c" * len(years)}}}
\\toprule
\\textbf{{{row_var_name}}} & {headers} \\\\
\\midrule
{rows}\\bottomrule
\\end{{tabular}}
}}
\\begin{{tablenotes}}[flushleft]
\\footnotesize
\\item Notes: Yearly counts represent active billing providers per year in New York.
\\end{{tablenotes}}
\\end{{threeparttable}}
\\end{{table}}
\\end{{landscape}}"""
    compile_to_pdf(filename, latex, landscape=True)

# =====================================================
# SECTION B: SCAN AND ROUTE FILES
# =====================================================
csv_files = glob.glob(os.path.join(csv_dir, "*.csv"))

for file in csv_files:
    filename = os.path.basename(file).replace(".csv", "")
    prefix = "Inpatient" if "inpatient" in filename else "Outpatient ASC"
    
    # --- ROUTE 1: FACILITY OWNERSHIP LOGIC ---
    if filename.startswith("ownership"):
        df = pd.read_csv(file)
        
        # 1. Unique Grouped
        if "grouped_unique" in filename:
            df = df.dropna(subset=["own_category"])
            df = df[df["own_category"].isin(["Government", "For-Profit", "Non-Profit"])]
            df = df[["own_category", "fac_count"]].rename(columns={"own_category": "Grouped Classification", "fac_count": "Facility Count"})
            df["Grouped Classification"] = pd.Categorical(df["Grouped Classification"], categories=["Government", "Non-Profit", "For-Profit"], ordered=True)
            df = df.sort_values("Grouped Classification")
            
            tex = r"\begin{table}[htbp]\centering\caption{Unique NYS Facilities by Grouped Ownership, 2007--2024}\begin{threeparttable}" + "\n"
            tex += df.to_latex(index=False, escape=False, column_format="lr")
            tex += r"\begin{tablenotes}[flushleft]\footnotesize\item Notes: Counts reflect unique NYS facilities during the 2007--2024 sample period.\end{tablenotes}\end{threeparttable}\end{table}"
            compile_to_pdf(filename, tex)
            
        # 2. Unique Fine
        elif "fine_unique" in filename:
            df = df.dropna(subset=["own_str"])
            df["own_str"] = df["own_str"].astype(str).str.title().str.replace("_", " ")
            df = df[["own_str", "fac_count"]].rename(columns={"own_str": "CMS Classification", "fac_count": "Facility Count"}).sort_values("CMS Classification")
            
            tex = r"\begin{table}[htbp]\centering\caption{Unique NYS Facilities by CMS Ownership, 2007--2024}\small\begin{threeparttable}" + "\n"
            tex += df.to_latex(index=False, escape=False, column_format="lr")
            tex += r"\begin{tablenotes}[flushleft]\footnotesize\item Notes: Counts reflect unique NYS facilities during the 2007--2024 sample period.\end{tablenotes}\end{threeparttable}\end{table}"
            compile_to_pdf(filename, tex)
            
        # 3. Yearly Grouped
        elif "grouped_by_year" in filename:
            df = df.dropna(subset=["own_category"])
            df = df[df["own_category"].isin(["Government", "For-Profit", "Non-Profit"])]
            pv = df.pivot_table(index="own_category", columns="year", values="fac_count", aggfunc="sum").fillna(0).astype(int)
            pv = pv[sorted(pv.columns)].reset_index().rename(columns={"own_category": "Ownership"})
            pv["Ownership"] = pd.Categorical(pv["Ownership"], categories=["Government", "Non-Profit", "For-Profit"], ordered=True)
            pv = pv.sort_values("Ownership")
            
            tex = r"\begin{landscape}\begin{table}[htbp]\centering\caption{Active NYS Facilities by Grouped Ownership, 2007--2024}\small" + "\n"
            tex += pv.to_latex(index=False, escape=False, column_format="l" + "r" * (len(pv.columns) - 1))
            tex += r"\end{table}\end{landscape}"
            compile_to_pdf(filename, tex, landscape=True)
            
        # 4. Yearly Fine
        elif "fine_by_year" in filename:
            df = df.dropna(subset=["own_str"])
            df["own_str"] = df["own_str"].astype(str).str.title().str.replace("_", " ")
            pv = df.pivot_table(index="own_str", columns="year", values="fac_count", aggfunc="sum").fillna(0).astype(int)
            pv = pv[sorted(pv.columns)].reset_index()
            
            tex = r"\begin{landscape}\begin{table}[htbp]\centering\caption{Active NYS Facilities by CMS Ownership, 2007--2024}\small" + "\n"
            inner = pv.to_latex(index=False, escape=False, column_format="p{2.5in}" + "r" * (len(pv.columns) - 1))
            tex += latex_resize(inner) + r"\end{table}\end{landscape}"
            compile_to_pdf(filename, tex, landscape=True)

    # --- ROUTE 2: PROVIDER DEMOGRAPHICS LOGIC ---
    elif filename.startswith("inpatient") or filename.startswith("outpatient"):
        df = pd.read_csv(file)
        df['prov_type'] = df['prov_type'].astype(str).replace(prov_map)
        
        # A. FULL SAMPLE
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

        # B. YEARLY TIMELINE
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

print("=== ALL NYS TABLES COMPLETED ===")