import os
import glob
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import subprocess

# --- 1. DEFINE PATHS ---
base_dir = r"C:\Users\omarf\Dropbox\personal_files_omar_farrag\Research\projects\NYS_npPolicy\output\summary_stats\out_patient\macro_stats"
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
        "asc_rate_1": ("ASC-1: Patient Burns Rate", "Rate: Percentage of patients experiencing a burn prior to discharge. Lower is better."),
        "asc_rate_2": ("ASC-2: Patient Falls Rate", "Rate: Percentage of patients experiencing a fall within the ASC. Lower is better."),
        "asc_rate_8": ("ASC-8: Influenza Vaccination Coverage", "Rate: Percentage of healthcare personnel vaccinated for influenza. Higher is better."),
        "oas_100_score": ("Overall OAS CAHPS Score", "Score: 0-100 linear mean score representing patient satisfaction at the ASC. Higher is better."),
        "oas_grp1": ("OAS CAHPS: Communication", "Score: 0-100 composite for Patient Communication."),
        "oas_grp2": ("OAS CAHPS: Care & Cleanliness", "Score: 0-100 composite for Professional Care and Facility Cleanliness."),
        "oas_grp3": ("OAS CAHPS: Prep & Discharge", "Score: 0-100 composite for Preparation and Discharge."),
        "oas_rating_9_10": ("OAS CAHPS: Rating 9 or 10", "Rate: Percentage of patients rating the ASC a 9 or 10 overall. Higher is better."),
        "oas_rating_0_6": ("OAS CAHPS: Rating 0 to 6", "Rate: Percentage of patients rating the ASC a 0 to 6 overall. Lower is better."),
        "fac_mips_final_score": ("Facility Avg: MIPS Final Score", "Score: 0-100 weighted facility average of affiliated providers' MIPS composite score."),
        "fac_mips_quality_score": ("Facility Avg: MIPS Quality", "Score: 0-100 weighted facility average of affiliated providers' MIPS Quality domain."),
        "fac_mips_ia_score": ("Facility Avg: MIPS Improvement", "Score: 0-100 weighted facility average of affiliated providers' MIPS Improvement Activities domain."),
        "fac_mips_pi_score": ("Facility Avg: MIPS PI", "Score: 0-100 weighted facility avg of MIPS Promoting Interoperability (EHR) domain."),
        "fac_mips_cost_score": ("Facility Avg: MIPS Cost", "Score: 0-100 weighted facility average of affiliated providers' MIPS Cost domain.")
    }

    if base_var in desc_dict:
        clean, desc = desc_dict[base_var]
    else:
        clean = base_var.replace("_", " ").title()
        desc = f"Variable: {base_var}"

    if is_delta:
        return f"Change in {clean}", True, f"Outcome represents year-over-year absolute change. Baseline Metric: {desc}"
    return clean, False, desc

# --- 3. LATEX GENERATORS ---

# A. The Timeline Generator (Dynamic National Average row)
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
    \\caption{{Timeline of {tex_title} by Authority}}
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
        \\footnotesize \\textit{{Notes:}} {tex_desc} Categorization reflects static 2023 status.
    \\end{{minipage}}
\\end{{table}}"""
    return latex

# B. The Full Sample Generator
def generate_fullsample_latex(df, uni_val, clean_title, var_name, desc):
    tex_title = clean_title.replace('&', r'\&').replace('%', r'\%')
    tex_desc = desc.replace('&', r'\&').replace('%', r'\%')
    
    def get_val(idx):
        if idx in df['np_authority'].values:
            val = df.loc[df['np_authority'] == idx, 'mean_val'].iloc[0]
            if pd.isna(val): return "-"
            return f"{val:.3f}"
        return "-"

    latex = f"""\\begin{{table}}[htbp]
    \\centering
    \\caption{{Overall {tex_title} by Authority (2015--2024)}}
    \\label{{tab:{var_name}_full}}
    \\vspace{{0.2cm}}
    \\begin{{tabular}}{{lc}}
        \\toprule
        \\textbf{{State NP Authority}} & \\textbf{{Whole Sample Mean}} \\\\
        \\midrule
        Restricted & {get_val("Restricted")} \\\\
        Reduced & {get_val("Reduced")} \\\\
        Full Practice & {get_val("Full Practice")} \\\\
        \\midrule
        \\textbf{{National Average}} & {uni_val} \\\\
        \\bottomrule
    \\end{{tabular}}
    \\vspace{{0.1cm}}
    \\begin{{minipage}}{{0.6\\textwidth}}
        \\footnotesize \\textit{{Notes:}} {tex_desc} Full sample aggregate.
    \\end{{minipage}}
\\end{{table}}"""
    return latex


# --- 4. MASTER LOOP ---
csv_files = glob.glob(os.path.join(csv_dir, "*_by_auth_year.csv"))
print(f"Found {len(csv_files)} Timeline CSV files to process.")

auth_map = {"1": "Restricted", "1.0": "Restricted", "2": "Reduced", "2.0": "Reduced", "3": "Full Practice", "3.0": "Full Practice"}
pdflatex_found = True 

for file_path in csv_files:
    filename = os.path.basename(file_path)
    var_name = filename.replace("_by_auth_year.csv", "")
    clean_title, is_delta, desc = get_clean_title(var_name)
    
    # --------------------------------------------------
    # A. PROCESS TIMELINE DATA & HEATMAP
    # --------------------------------------------------
    df_time = pd.read_csv(file_path)
    df_time['np_authority'] = df_time['np_authority'].astype(str).str.strip().replace(auth_map)
    pivot_df = df_time.pivot_table(index='np_authority', columns='year', values='mean_val', aggfunc='mean')
    valid_index = [idx for idx in ["Restricted", "Reduced", "Full Practice"] if idx in pivot_df.index]
    pivot_df = pivot_df.reindex(index=valid_index)
    
    # Heatmap
    fig = plt.figure(figsize=(10, 6.5)) 
    if is_delta:
        cmap, vmin, vmax = "RdBu", -pivot_df.abs().max().max(), pivot_df.abs().max().max()
        if pd.isna(vmax): vmax = 1; vmin = -1
    else:
        cmap, vmin, vmax = "Greens", pivot_df.min().min(), pivot_df.max().max()

    ax = sns.heatmap(pivot_df, annot=True, fmt=".3f", cmap=cmap, vmin=vmin, vmax=vmax, 
                cbar_kws={'label': 'Mean Value'}, annot_kws={"size": 10}, linewidths=.5)
    plt.title(clean_title, fontsize=14, fontweight='bold', pad=15)
    plt.ylabel("State NP Authority", fontsize=12, fontweight='bold')
    plt.xlabel("Year", fontsize=12, fontweight='bold')
    plt.figtext(0.05, 0.02, f"Notes: {desc}\nNP Law: Restricted, Reduced, Full.", wrap=True, fontsize=9, color='gray')
    plt.subplots_adjust(bottom=0.2) 
    plt.savefig(os.path.join(heat_dir, f"{var_name}_heatmap.png"), dpi=300, bbox_inches='tight')
    plt.close()

    # Dynamic National Average Dictionary
    uni_year_dict = {}
    uni_yr_file = os.path.join(csv_dir, f"{var_name}_universal_by_year.csv")
    if os.path.exists(uni_yr_file):
        uy_df = pd.read_csv(uni_yr_file)
        uni_year_dict = dict(zip(uy_df['year'], uy_df['mean_val']))

    tex_time = generate_timeline_latex(pivot_df, uni_year_dict, clean_title, var_name, desc)
    with open(os.path.join(tex_dir, f"{var_name}_timeline.tex"), 'w') as f:
        f.write(tex_time)

    # --------------------------------------------------
    # B. PROCESS FULL SAMPLE DATA
    # --------------------------------------------------
    full_file = os.path.join(csv_dir, f"{var_name}_by_authority.csv")
    tex_full = ""
    if os.path.exists(full_file):
        df_full = pd.read_csv(full_file)
        df_full['np_authority'] = df_full['np_authority'].astype(str).str.strip().replace(auth_map)
        
        uni_val = "-"
        uni_file = os.path.join(csv_dir, f"{var_name}_universal.csv")
        if os.path.exists(uni_file):
            u_df = pd.read_csv(uni_file)
            if not u_df.empty: uni_val = f"{u_df['mean_val'].iloc[0]:.3f}"
            
        tex_full = generate_fullsample_latex(df_full, uni_val, clean_title, var_name, desc)
        with open(os.path.join(tex_dir, f"{var_name}_full_sample.tex"), 'w') as f:
            f.write(tex_full)

    # --------------------------------------------------
    # C. COMPILE STANDALONE PDFS
    # --------------------------------------------------
    if pdflatex_found:
        
        # 1. Compile Timeline PDF (Landscape)
        standalone_time_tex = f"""\\documentclass[12pt, landscape]{{article}}
\\usepackage{{booktabs}}
\\usepackage{{geometry}}
\\usepackage{{caption}}
\\usepackage{{graphicx}}
\\geometry{{margin=1in}}
\\begin{{document}}
\\thispagestyle{{empty}}
\\vspace*{{2cm}}
{tex_time}
\\end{{document}}"""

        time_tex_path = os.path.join(pdf_dir, f"{var_name}_timeline.tex")
        with open(time_tex_path, 'w') as f:
            f.write(standalone_time_tex)

        try:
            subprocess.run(['pdflatex', '-interaction=nonstopmode', f'-output-directory={pdf_dir}', time_tex_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            for ext in ['.aux', '.log', '.tex']:
                clutter_file = os.path.join(pdf_dir, f"{var_name}_timeline{ext}")
                if os.path.exists(clutter_file): os.remove(clutter_file)
        except subprocess.CalledProcessError: pass

        # 2. Compile Full Sample PDF (Portrait)
        if tex_full != "":
            standalone_full_tex = f"""\\documentclass[12pt]{{article}}
\\usepackage{{booktabs}}
\\usepackage{{geometry}}
\\usepackage{{caption}}
\\geometry{{margin=1in}}
\\begin{{document}}
\\thispagestyle{{empty}}
\\vspace*{{2cm}}
{tex_full}
\\end{{document}}"""

            full_tex_path = os.path.join(pdf_dir, f"{var_name}_full_sample.tex")
            with open(full_tex_path, 'w') as f:
                f.write(standalone_full_tex)

            try:
                subprocess.run(['pdflatex', '-interaction=nonstopmode', f'-output-directory={pdf_dir}', full_tex_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                for ext in ['.aux', '.log', '.tex']:
                    clutter_file = os.path.join(pdf_dir, f"{var_name}_full_sample{ext}")
                    if os.path.exists(clutter_file): os.remove(clutter_file)
            except subprocess.CalledProcessError: pass

print("=== PYTHON VISUALIZATION AND DUAL-LATEX COMPILATION COMPLETE ===")
