import os
import glob
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import subprocess

# --- 1. DEFINE PATHS ---
base_dir = r"C:\Users\omarf\Dropbox\personal_files_omar_farrag\Research\projects\NYS_npPolicy\output\summary_stats\in_patient\macro_stats"
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
        "hcahps_100_score": ("Overall HCAHPS Score", "Score: 0-100 linear mean score representing patient satisfaction. Higher is better."),
        "hcahps_grp1": ("HCAHPS: Staff Communication", "Score: 0-100 composite for Staff Communication (Nurses and Doctors). Higher is better."),
        "hcahps_grp2": ("HCAHPS: Patient Help", "Score: 0-100 composite for Providing Patient Help (Responsiveness & Meds). Higher is better."),
        "hcahps_grp3": ("HCAHPS: Environment", "Score: 0-100 composite for Facility Environment (Cleanliness & Quietness). Higher is better."),
        "hcahps_grp4": ("HCAHPS: Global Rating", "Score: 0-100 composite for Global Rating and Recommendation. Higher is better."),
        "h_hosp_rating_9_10": ("HCAHPS: Rating 9 or 10", "Rate: Percentage of patients rating the hospital a 9 or 10 overall. Higher is better."),
        "h_hosp_rating_0_6": ("HCAHPS: Rating 0 to 6", "Rate: Percentage of patients rating the hospital a 0 to 6 overall. Lower is better."),
        "hac_total_score": ("HAC Penalty Score", "Score: 1-10 Hospital-Acquired Condition index. Higher means worse safety (penalized > 6.75)."),
        "rrp_excess_ratio_ami": ("AMI Readmission Ratio", "Ratio: Observed divided by Expected (O/E) readmissions. >1.0 triggers penalties."),
        "rrp_excess_ratio_hf": ("HF Readmission Ratio", "Ratio: Observed divided by Expected (O/E) readmissions. >1.0 triggers penalties."),
        "rrp_excess_ratio_pn": ("Pneumonia Readmission Ratio", "Ratio: Observed divided by Expected (O/E) readmissions. >1.0 triggers penalties."),
        "mortality_rate_ami": ("30-Day AMI Mortality", "Rate: 30-Day risk-standardized mortality rate. Lower is better."),
        "mortality_rate_hf": ("30-Day HF Mortality", "Rate: 30-Day risk-standardized mortality rate. Lower is better."),
        "mortality_rate_pn": ("30-Day PN Mortality", "Rate: 30-Day risk-standardized mortality rate. Lower is better."),
        "mspb_score": ("Medicare Spending Per Beneficiary", "Ratio: Hospital spending divided by the national median (1.0 = Average). Lower is more efficient."),
        "hvbp_tps_score": ("Value-Based Purchasing Score", "Score: 0-100 Total Performance Score across efficiency and quality. Higher is better."),
        "partd_opioid_rate": ("Opioid Prescribing Rate", "Rate: Percentage of total Part D claims for opioids by affiliated staff."),
        "partb_em_upcode_rate": ("E&M Upcode Rate", "Rate: Percentage of E&M visits billed as high-intensity Level 4/5 by affiliated staff."),
        "partb_low_value_rate": ("Low-Value Care Rate", "Rate: Percentage of services categorized as 'Choosing Wisely' discouraged."),
        "partb_imaging_adv_rate": ("Advanced Imaging Rate", "Rate: Percentage of imaging claims representing CT/MRI/PET vs standard x-ray."),
        "mips_final_score": ("MIPS Final Score", "Score: 0-100 composite payment adjustment score for affiliated staff. Higher is better."),
        "pct_np": ("Workforce %: NPs", "Percentage: NPs divided by total billing MD/DO/PA/NPs at the facility."),
        "pct_md": ("Workforce %: MD/DOs", "Percentage: MD/DOs divided by total billing MD/DO/PA/NPs at the facility."),
        "pct_pa": ("Workforce %: PAs", "Percentage: PAs divided by total billing MD/DO/PA/NPs at the facility."),
        "hopd_op_8": ("HOPD Metric: OP-8", "Rate: MRI Lumbar Spine for Low Back Pain without prior conservative therapy."),
        "hopd_op_10": ("HOPD Metric: OP-10", "Rate: Abdomen CT with Contrast Material. Lower is better."),
        "hopd_op_13": ("HOPD Metric: OP-13", "Rate: Cardiac Imaging for Preoperative Risk Assessment. Lower is better."),
        "hopd_op_18b": ("HOPD Metric: OP-18b", "Time: Median time from ED arrival to ED departure (in minutes). Lower is better."),
        "hopd_op_22": ("HOPD Metric: OP-22", "Rate: Percentage of patients who left the ED without being seen. Lower is better."),
        "hopd_op_32": ("HOPD Metric: OP-32", "Rate: Unplanned hospital visits within 7 days of outpatient colonoscopy. Lower is better."),
        "hopd_op_36": ("HOPD Metric: OP-36", "Rate: Unplanned hospital visits within 7 days of outpatient surgery. Lower is better.")
    }

    if base_var in desc_dict:
        clean, desc = desc_dict[base_var]
    else:
        clean = base_var.replace("_", " ").title()
        desc = f"Variable: {base_var}"

    if is_delta:
        return f"Change in {clean}", True, f"Outcome represents year-over-year absolute change. Baseline Metric: {desc}"
    return clean, False, desc

# --- 3. CUSTOM JOURNAL-QUALITY LATEX GENERATOR ---
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
    \\caption{{Summary of {tex_title} by Authority and Ownership}}
    \\label{{tab:{var_name}}}
    \\vspace{{0.2cm}}
    \\begin{{tabular}}{{lccc}}
        \\toprule
        & \\multicolumn{{3}}{{c}}{{\\textbf{{Hospital Ownership}}}} \\\\
        \\cmidrule(lr){{2-4}}
        \\textbf{{State NP Authority}} & \\textbf{{Government}} & \\textbf{{Non-Profit}} & \\textbf{{For-Profit}} \\\\
        \\midrule
        Restricted & {get_val("Restricted", "Government")} & {get_val("Restricted", "Non-Profit")} & {get_val("Restricted", "For-Profit")} \\\\
        Reduced & {get_val("Reduced", "Government")} & {get_val("Reduced", "Non-Profit")} & {get_val("Reduced", "For-Profit")} \\\\
        Full Practice & {get_val("Full Practice", "Government")} & {get_val("Full Practice", "Non-Profit")} & {get_val("Full Practice", "For-Profit")} \\\\
        \\midrule
        \\textbf{{National Average}} & \\multicolumn{{3}}{{c}}{{{universal_val}}} \\\\
        \\bottomrule
    \\end{{tabular}}
    \\vspace{{0.1cm}}
    \\begin{{minipage}}{{0.85\\textwidth}}
        \\footnotesize \\textit{{Notes:}} {tex_desc} NP Law categories represent Restricted (supervision), Reduced (collaborative), and Full (independent practice). Categorization reflects the regulatory environment as of 2023; note that several states transitioned categories during the 2013--2023 study period.
    \\end{{minipage}}
\\end{{table}}"""
    return latex

# --- 4. MASTER LOOP ---
csv_files = glob.glob(os.path.join(csv_dir, "*_by_auth_ownership.csv"))
print(f"Found {len(csv_files)} CSV files to process.")

pdflatex_found = True 

for file_path in csv_files:
    filename = os.path.basename(file_path)
    var_name = filename.replace("_by_auth_ownership.csv", "")
    clean_title, is_delta, desc = get_clean_title(var_name)
    
    df = pd.read_csv(file_path)
    df['np_authority'] = df['np_authority'].astype(str).str.strip()
    df['own_category'] = df['own_category'].astype(str).str.strip()
    
    auth_map = {"1": "Restricted", "1.0": "Restricted", "2": "Reduced", "2.0": "Reduced", "3": "Full Practice", "3.0": "Full Practice"}
    own_map = {"1": "Government", "1.0": "Government", "2": "For-Profit", "2.0": "For-Profit", "3": "Non-Profit", "3.0": "Non-Profit"}
    df['np_authority'] = df['np_authority'].replace(auth_map)
    df['own_category'] = df['own_category'].replace(own_map)
    
    pivot_df = df.pivot_table(index='np_authority', columns='own_category', values='mean_val', aggfunc='mean')
    
    valid_index = [idx for idx in ["Restricted", "Reduced", "Full Practice"] if idx in pivot_df.index]
    valid_cols = [col for col in ["Government", "Non-Profit", "For-Profit"] if col in pivot_df.columns]
    pivot_df = pivot_df.reindex(index=valid_index, columns=valid_cols)
    
    universal_file = os.path.join(csv_dir, f"{var_name}_universal.csv")
    uni_val = "-"
    if os.path.exists(universal_file):
        uni_df = pd.read_csv(universal_file)
        if not uni_df.empty:
            uni_val = f"{uni_df['mean_val'].iloc[0]:.3f}"

    # --------------------------------------------------
    # A. DRAW SEABORN HEATMAP (WITH FOOTNOTES)
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
    plt.xlabel("Hospital Ownership", fontsize=12, fontweight='bold')
    
    footnote_text = f"Notes: {desc}\nNP Law: Restricted, Reduced, Full. Categorization reflects static 2023 status (several states transitioned during study period).\nOwnership: Gov (Fed/State/Local), For-Profit (Proprietary), Non-Profit (Private)."
    plt.figtext(0.05, 0.02, footnote_text, wrap=True, horizontalalignment='left', fontsize=9, color='gray')
    plt.subplots_adjust(bottom=0.2) 

    plt.savefig(os.path.join(heat_dir, f"{var_name}_heatmap.png"), dpi=300, bbox_inches='tight')
    plt.close()

    # --------------------------------------------------
    # B. GENERATE & EXPORT LATEX
    # --------------------------------------------------
    latex_fragment = generate_latex_table(pivot_df, clean_title, var_name, uni_val, desc)
    tex_out = os.path.join(tex_dir, f"{var_name}_by_auth_ownership.tex")
    
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

print("=== PYTHON VISUALIZATION AND LATEX COMPILATION COMPLETE ===")
