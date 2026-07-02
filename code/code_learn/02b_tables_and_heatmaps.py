import os
import glob
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import subprocess

# --- 1. DEFINE PATHS ---
base_dir = r"C:\Users\omarf\Dropbox\personal_files_omar_farrag\Research\projects\NYS_npPolicy\output\summary_stats\in_patient\micro_stats"
csv_dir = os.path.join(base_dir, "tables_csv")
tex_dir = os.path.join(base_dir, "tables_tex")
pdf_dir = os.path.join(base_dir, "tables_pdf")
heat_dir = os.path.join(base_dir, "heatmaps")

os.makedirs(tex_dir, exist_ok=True)
os.makedirs(pdf_dir, exist_ok=True)
os.makedirs(heat_dir, exist_ok=True)

# --- 2. TITLE & DICTIONARY ENGINE ---
def get_clean_title(var_name):
    is_delta = var_name.startswith("d_")
    base_var = var_name[2:] if is_delta else var_name

    desc_dict = {
        "partd_generic_rate": ("Generic Prescribing Rate", "Rate: Proportion of total Part D prescriptions filled with generic drugs. Higher implies cost efficiency."),
        "partd_opioid_rate": ("Opioid Prescribing Rate", "Rate: Proportion of total Part D claims that are Schedule II/III opioids."),
        "partb_em_upcode_rate": ("Provider E&M Upcode Rate", "Rate: Proportion of total E&M visits billed at the highest intensity (Level 4/5)."),
        "mips_final_score": ("MIPS Final Score", "Score: 0-100 composite payment adjustment score. Higher reflects better overall clinical value."),
        "mips_quality_score": ("MIPS Quality Domain", "Score: 0-100 performance on evidence-based quality measures."),
        "mips_pi_score": ("MIPS Promoting Interoperability", "Score: 0-100 performance on EHR integration and patient data access."),
        "mips_ia_score": ("MIPS Improvement Activities", "Score: 0-100 performance on practice improvements like care coordination."),
        "mips_cost_score": ("MIPS Cost Domain", "Score: 0-100 performance on total cost of care / resource use."),
        "bene_avg_risk_scre": ("Average Patient Risk Score (HCC)", "Score: Hierarchical Condition Category (HCC) risk score. Higher implies a more complex/sicker panel."),
        "tot_benes": ("Total Beneficiaries Treated", "Count: Total number of unique Medicare beneficiaries treated by the provider."),
        "tot_sbmtd_chrg": ("Total Submitted Charges", "Financial: Total dollars billed to Medicare by the provider.")
    }

    if base_var in desc_dict:
        clean, desc = desc_dict[base_var]
    else:
        clean = base_var.replace("_", " ").title()
        desc = f"Variable: {base_var}"

    if is_delta:
        return f"Change in {clean}", True, f"Outcome represents year-over-year absolute change. Baseline Metric: {desc}"
    return clean, False, desc

# --- 3. CUSTOM JOURNAL-QUALITY LATEX GENERATORS ---

# A. Provider Type Generator
def generate_provtype_latex(df, clean_title, var_name, universal_val, desc):
    tex_title = clean_title.replace('&', r'\&').replace('%', r'\%')
    tex_desc = desc.replace('&', r'\&').replace('%', r'\%')
    
    def get_val(idx, col):
        if idx in df.index and col in df.columns:
            val = df.loc[idx, col]
            if pd.isna(val): return "-"
            return f"{val:.3f}"
        return "-"

    latex = f"""\\begin{{table}}[htbp]
    \\centering
    \\caption{{Summary of {tex_title} by Authority and Provider Type}}
    \\label{{tab:{var_name}_provtype}}
    \\vspace{{0.2cm}}
    \\begin{{tabular}}{{lccc}}
        \\toprule
        & \\multicolumn{{3}}{{c}}{{\\textbf{{Provider Type}}}} \\\\
        \\cmidrule(lr){{2-4}}
        \\textbf{{State NP Authority}} & \\textbf{{MD/DO}} & \\textbf{{Nurse Practitioner}} & \\textbf{{Physician Assistant}} \\\\
        \\midrule
        Restricted & {get_val("Restricted", "MD/DO")} & {get_val("Restricted", "Nurse Practitioner")} & {get_val("Restricted", "Physician Assistant")} \\\\
        Reduced & {get_val("Reduced", "MD/DO")} & {get_val("Reduced", "Nurse Practitioner")} & {get_val("Reduced", "Physician Assistant")} \\\\
        Full Practice & {get_val("Full Practice", "MD/DO")} & {get_val("Full Practice", "Nurse Practitioner")} & {get_val("Full Practice", "Physician Assistant")} \\\\
        \\midrule
        \\textbf{{National Average}} & \\multicolumn{{3}}{{c}}{{{universal_val}}} \\\\
        \\bottomrule
    \\end{{tabular}}
    \\vspace{{0.1cm}}
    \\begin{{minipage}}{{0.85\\textwidth}}
        \\footnotesize \\textit{{Notes:}} {tex_desc} NP Law categories represent Restricted (supervision), Reduced (collaborative), and Full (independent practice). Categorization reflects the regulatory environment as of 2023.
    \\end{{minipage}}
\\end{{table}}"""
    return latex

# B. Timeline Generator
def generate_timeline_latex(df, uni_dict, clean_title, var_name, desc):
    tex_title = clean_title.replace('&', r'\&').replace('%', r'\%')
    tex_desc = desc.replace('&', r'\&').replace('%', r'\%')
    
    years = [str(col) for col in df.columns]
    num_years = len(years)
    col_format = "l" + "c" * num_years
    headers = " & ".join([f"\\textbf{{{y}}}" for y in years])
    
    rows = ""
    for idx in ["Restricted", "Reduced", "Full Practice"]:
        if idx in df.index:
            row_vals = []
            for col in df.columns:
                val = df.loc[idx, col]
                row_vals.append("-" if pd.isna(val) else f"{val:.3f}")
            rows += f"        {idx} & " + " & ".join(row_vals) + " \\\\\n"

    nat_vals = " & ".join([f"{uni_dict.get(int(y), '-'):.3f}" if uni_dict.get(int(y)) != '-' else "-" for y in years])

    latex = f"""\\begin{{table}}[htbp]
    \\centering
    \\caption{{Timeline of {tex_title} by Authority (Overall Providers)}}
    \\label{{tab:{var_name}_timeline}}
    \\vspace{{0.2cm}}
    \\resizebox{{\\textwidth}}{{!}}{{
    \\begin{{tabular}}{{{col_format}}}
        \\toprule
        \\textbf{{State NP Authority}} & {headers} \\\\
        \\midrule
{rows}        \\midrule
        \\textbf{{National Average}} & {nat_vals} \\\\
        \\bottomrule
    \\end{{tabular}}
    }}
    \\vspace{{0.1cm}}
    \\begin{{minipage}}{{\\textwidth}}
        \\footnotesize \\textit{{Notes:}} {tex_desc} Categorization reflects static 2023 status. Aggregated across all provider types.
    \\end{{minipage}}
\\end{{table}}"""
    return latex

# --- 4. MASTER LOOP ---
base_files = set([os.path.basename(f).replace("_by_auth_provtype.csv", "").replace("_by_auth_year.csv", "") for f in glob.glob(os.path.join(csv_dir, "*.csv")) if "by_auth" in f])
auth_map = {"1": "Restricted", "1.0": "Restricted", "2": "Reduced", "2.0": "Reduced", "3": "Full Practice", "3.0": "Full Practice"}
prov_map = {"1": "MD/DO", "1.0": "MD/DO", "2": "Nurse Practitioner", "2.0": "Nurse Practitioner", "3": "Physician Assistant", "3.0": "Physician Assistant"}

pdflatex_found = True 

for var_name in base_files:
    clean_title, is_delta, desc = get_clean_title(var_name)
    
    # Universal Dictionaries
    uni_val = "-"
    uni_file = os.path.join(csv_dir, f"{var_name}_universal.csv")
    if os.path.exists(uni_file):
        u_df = pd.read_csv(uni_file)
        if not u_df.empty: uni_val = f"{u_df['mean_val'].iloc[0]:.3f}"
            
    uni_year_dict = {}
    uni_yr_file = os.path.join(csv_dir, f"{var_name}_universal_by_year.csv")
    if os.path.exists(uni_yr_file):
        uy_df = pd.read_csv(uni_yr_file)
        uni_year_dict = dict(zip(uy_df['year'], uy_df['mean_val']))

    # --------------------------------------------------
    # A. PROCESS PROVIDER TYPE DATA (Full Sample)
    # --------------------------------------------------
    prov_file = os.path.join(csv_dir, f"{var_name}_by_auth_provtype.csv")
    if os.path.exists(prov_file):
        df_prov = pd.read_csv(prov_file)
        df_prov['np_authority'] = df_prov['np_authority'].astype(str).str.strip().replace(auth_map)
        df_prov['prov_type'] = df_prov['prov_type'].astype(str).str.strip().replace(prov_map)
        
        pivot_prov = df_prov.pivot_table(index='np_authority', columns='prov_type', values='mean_val', aggfunc='mean')
        valid_idx = [i for i in ["Restricted", "Reduced", "Full Practice"] if i in pivot_prov.index]
        valid_col = [c for c in ["MD/DO", "Nurse Practitioner", "Physician Assistant"] if c in pivot_prov.columns]
        pivot_prov = pivot_prov.reindex(index=valid_idx, columns=valid_col)
        
        # Heatmap
        fig = plt.figure(figsize=(8, 7.5)) 
        cmap, vmin, vmax = ("RdBu", -pivot_prov.abs().max().max(), pivot_prov.abs().max().max()) if is_delta else ("Blues", pivot_prov.min().min(), pivot_prov.max().max())
        if pd.isna(vmax): vmax = 1; vmin = -1
        sns.heatmap(pivot_prov, annot=True, fmt=".3f", cmap=cmap, vmin=vmin, vmax=vmax, cbar_kws={'label': 'Mean Value'}, annot_kws={"size": 12}, linewidths=.5, square=True)
        plt.title(clean_title, fontsize=14, fontweight='bold', pad=15)
        plt.ylabel("State NP Authority", fontsize=12, fontweight='bold')
        plt.xlabel("Provider Type", fontsize=12, fontweight='bold')
        plt.figtext(0.05, 0.02, f"Notes: {desc}\nNP Law: Restricted, Reduced, Full.", wrap=True, fontsize=9, color='gray')
        plt.subplots_adjust(bottom=0.2) 
        plt.savefig(os.path.join(heat_dir, f"{var_name}_provtype_heatmap.png"), dpi=300, bbox_inches='tight')
        plt.close()

        # LaTeX & PDF
        tex_prov = generate_provtype_latex(pivot_prov, clean_title, var_name, uni_val, desc)
        with open(os.path.join(tex_dir, f"{var_name}_provtype.tex"), 'w') as f: f.write(tex_prov)
        
        if pdflatex_found:
            standalone_prov = f"\\documentclass[12pt]{{article}}\n\\usepackage{{booktabs}}\n\\usepackage{{geometry}}\n\\usepackage{{caption}}\n\\geometry{{margin=1in}}\n\\begin{{document}}\n\\thispagestyle{{empty}}\n\\vspace*{{2cm}}\n{tex_prov}\n\\end{{document}}"
            temp_path = os.path.join(pdf_dir, f"{var_name}_provtype.tex")
            with open(temp_path, 'w') as f: f.write(standalone_prov)
            try:
                subprocess.run(['pdflatex', '-interaction=nonstopmode', f'-output-directory={pdf_dir}', temp_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                for ext in ['.aux', '.log', '.tex']:
                    if os.path.exists(os.path.join(pdf_dir, f"{var_name}_provtype{ext}")): os.remove(os.path.join(pdf_dir, f"{var_name}_provtype{ext}"))
            except subprocess.CalledProcessError: pass

    # --------------------------------------------------
    # B. PROCESS TIMELINE DATA (Aggregated Providers)
    # --------------------------------------------------
    time_file = os.path.join(csv_dir, f"{var_name}_by_auth_year.csv")
    if os.path.exists(time_file):
        df_time = pd.read_csv(time_file)
        df_time['np_authority'] = df_time['np_authority'].astype(str).str.strip().replace(auth_map)
        pivot_time = df_time.pivot_table(index='np_authority', columns='year', values='mean_val', aggfunc='mean')
        valid_idx = [i for i in ["Restricted", "Reduced", "Full Practice"] if i in pivot_time.index]
        pivot_time = pivot_time.reindex(index=valid_idx)
        
        # Heatmap
        fig = plt.figure(figsize=(10, 6.5)) 
        cmap, vmin, vmax = ("RdBu", -pivot_time.abs().max().max(), pivot_time.abs().max().max()) if is_delta else ("Oranges", pivot_time.min().min(), pivot_time.max().max())
        if pd.isna(vmax): vmax = 1; vmin = -1
        sns.heatmap(pivot_time, annot=True, fmt=".3f", cmap=cmap, vmin=vmin, vmax=vmax, cbar_kws={'label': 'Mean Value'}, annot_kws={"size": 10}, linewidths=.5)
        plt.title(clean_title, fontsize=14, fontweight='bold', pad=15)
        plt.ylabel("State NP Authority", fontsize=12, fontweight='bold')
        plt.xlabel("Year", fontsize=12, fontweight='bold')
        plt.figtext(0.05, 0.02, f"Notes: {desc}\nNP Law: Restricted, Reduced, Full.", wrap=True, fontsize=9, color='gray')
        plt.subplots_adjust(bottom=0.2) 
        plt.savefig(os.path.join(heat_dir, f"{var_name}_timeline_heatmap.png"), dpi=300, bbox_inches='tight')
        plt.close()

        # LaTeX & PDF
        tex_time = generate_timeline_latex(pivot_time, uni_year_dict, clean_title, var_name, desc)
        with open(os.path.join(tex_dir, f"{var_name}_timeline.tex"), 'w') as f: f.write(tex_time)
        
        if pdflatex_found:
            standalone_time = f"\\documentclass[12pt, landscape]{{article}}\n\\usepackage{{booktabs}}\n\\usepackage{{geometry}}\n\\usepackage{{caption}}\n\\usepackage{{graphicx}}\n\\geometry{{margin=1in}}\n\\begin{{document}}\n\\thispagestyle{{empty}}\n\\vspace*{{2cm}}\n{tex_time}\n\\end{{document}}"
            temp_path = os.path.join(pdf_dir, f"{var_name}_timeline.tex")
            with open(temp_path, 'w') as f: f.write(standalone_time)
            try:
                subprocess.run(['pdflatex', '-interaction=nonstopmode', f'-output-directory={pdf_dir}', temp_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                for ext in ['.aux', '.log', '.tex']:
                    if os.path.exists(os.path.join(pdf_dir, f"{var_name}_timeline{ext}")): os.remove(os.path.join(pdf_dir, f"{var_name}_timeline{ext}"))
            except subprocess.CalledProcessError: pass

print("=== PYTHON DUAL-PIPELINE (PROV TYPE & TIMELINE) COMPLETE ===")
