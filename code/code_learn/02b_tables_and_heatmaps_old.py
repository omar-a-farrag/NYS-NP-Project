import os
import glob
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import subprocess

# --- 1. DEFINE PATHS (Updated for Micro Stats) ---
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
        "mips_final_score": ("MIPS Final Score", "Score: 0-100 composite payment adjustment score. Higher reflects better clinical quality/value."),
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

# --- 3. CUSTOM JOURNAL-QUALITY LATEX GENERATOR (Provider Type Headers) ---
def generate_latex_table(df, clean_title, var_name, universal_val, desc):
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
    \\label{{tab:{var_name}}}
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

# --- 4. MASTER LOOP ---
# Matching the micro_stats filename structure
csv_files = glob.glob(os.path.join(csv_dir, "*_by_auth_provtype.csv"))
print(f"Found {len(csv_files)} CSV files to process.")

pdflatex_found = True 

for file_path in csv_files:
    filename = os.path.basename(file_path)
    var_name = filename.replace("_by_auth_provtype.csv", "")
    clean_title, is_delta, desc = get_clean_title(var_name)
    
    df = pd.read_csv(file_path)
    df['np_authority'] = df['np_authority'].astype(str).str.strip()
    df['prov_type'] = df['prov_type'].astype(str).str.strip()
    
    auth_map = {"1": "Restricted", "1.0": "Restricted", "2": "Reduced", "2.0": "Reduced", "3": "Full Practice", "3.0": "Full Practice"}
    # Mapping to exact text expected by the LaTeX table and Heatmap columns
    prov_map = {"1": "MD/DO", "1.0": "MD/DO", "2": "Nurse Practitioner", "2.0": "Nurse Practitioner", "3": "Physician Assistant", "3.0": "Physician Assistant"}
    
    df['np_authority'] = df['np_authority'].replace(auth_map)
    df['prov_type'] = df['prov_type'].replace(prov_map)
    
    pivot_df = df.pivot_table(index='np_authority', columns='prov_type', values='mean_val', aggfunc='mean')
    
    valid_index = [idx for idx in ["Restricted", "Reduced", "Full Practice"] if idx in pivot_df.index]
    valid_cols = [col for col in ["MD/DO", "Nurse Practitioner", "Physician Assistant"] if col in pivot_df.columns]
    pivot_df = pivot_df.reindex(index=valid_index, columns=valid_cols)
    
    universal_file = os.path.join(csv_dir, f"{var_name}_universal.csv")
    uni_val = "-"
    if os.path.exists(universal_file):
        uni_df = pd.read_csv(universal_file)
        if not uni_df.empty:
            uni_val = f"{uni_df['mean_val'].iloc[0]:.3f}"

    # --------------------------------------------------
    # A. DRAW SEABORN HEATMAP
    # --------------------------------------------------
    fig = plt.figure(figsize=(8, 7.5)) 
    
    if is_delta:
        cmap = "RdBu"
        max_abs = pivot_df.abs().max().max()
        if pd.isna(max_abs): max_abs = 1 
        vmin, vmax = -max_abs, max_abs
    else:
        cmap = "Blues"
        vmin, vmax = pivot_df.min().min(), pivot_df.max().max()

    ax = sns.heatmap(pivot_df, annot=True, fmt=".3f", cmap=cmap, vmin=vmin, vmax=vmax, 
                cbar_kws={'label': 'Mean Value'}, annot_kws={"size": 12}, linewidths=.5, square=True)

    plt.title(clean_title, fontsize=14, fontweight='bold', pad=15)
    plt.ylabel("State NP Authority", fontsize=12, fontweight='bold')
    plt.xlabel("Provider Type", fontsize=12, fontweight='bold')
    
    footnote_text = f"Notes: {desc}\nNP Law: Restricted, Reduced, Full. Categorization reflects static 2023 status.\nProvider: MD/DO (Physician), Nurse Practitioner, Physician Assistant."
    plt.figtext(0.05, 0.02, footnote_text, wrap=True, horizontalalignment='left', fontsize=9, color='gray')
    plt.subplots_adjust(bottom=0.2) 

    plt.savefig(os.path.join(heat_dir, f"{var_name}_heatmap.png"), dpi=300, bbox_inches='tight')
    plt.close()

    # --------------------------------------------------
    # B. GENERATE & EXPORT LATEX
    # --------------------------------------------------
    latex_fragment = generate_latex_table(pivot_df, clean_title, var_name, uni_val, desc)
    tex_out = os.path.join(tex_dir, f"{var_name}_by_auth_provtype.tex")
    
    with open(tex_out, 'w') as f:
        f.write(latex_fragment)

    # --------------------------------------------------
    # C. COMPILE STANDALONE PDF
    # --------------------------------------------------
    if pdflatex_found:
        standalone_tex = f"""\\documentclass[12pt]{{article}}
\\usepackage{{booktabs}}
\\usepackage{{geometry}}
\\usepackage{{caption}}
\\geometry{{margin=1in}}
\\begin{{document}}
\\thispagestyle{{empty}}
\\vspace*{{2cm}}
{latex_fragment}
\\end{{document}}"""

        temp_tex_path = os.path.join(pdf_dir, f"{var_name}.tex")
        with open(temp_tex_path, 'w') as f:
            f.write(standalone_tex)

        try:
            subprocess.run(
                ['pdflatex', '-interaction=nonstopmode', f'-output-directory={pdf_dir}', temp_tex_path],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=True
            )
            for ext in ['.aux', '.log', '.tex']:
                clutter_file = os.path.join(pdf_dir, f"{var_name}{ext}")
                if os.path.exists(clutter_file):
                    os.remove(clutter_file)
        
        except subprocess.CalledProcessError:
            print(f"[WARNING] Compilation failed for {var_name}.")

print("=== PYTHON MICRO VISUALIZATION AND LATEX COMPILATION COMPLETE ===")