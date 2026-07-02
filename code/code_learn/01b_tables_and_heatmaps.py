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
        "mips_final_score": ("Facility Avg: MIPS Final Score", "Score: 0-100 weighted facility average of affiliated providers' MIPS composite score."),
        "mips_quality_score": ("Facility Avg: MIPS Quality", "Score: 0-100 weighted facility average of affiliated providers' MIPS Quality domain."),
        "mips_pi_score": ("Facility Avg: MIPS PI", "Score: 0-100 weighted facility avg of MIPS Promoting Interoperability (EHR) domain."),
        "mips_ia_score": ("Facility Avg: MIPS Improvement", "Score: 0-100 weighted facility average of affiliated providers' MIPS Improvement Activities domain."),
        "mips_cost_score": ("Facility Avg: MIPS Cost", "Score: 0-100 weighted facility average of affiliated providers' MIPS Cost domain."),
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

# --- 3. CUSTOM JOURNAL-QUALITY LATEX GENERATORS ---

# A. Ownership Generator
def generate_own_latex(df, clean_title, var_name, universal_val, desc):
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
    \\label{{tab:{var_name}_own}}
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
        \\footnotesize \\textit{{Notes:}} {tex_desc} Categorization reflects the regulatory environment as of 2023.
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

# --- 4. MASTER LOOP ---
base_files = set([os.path.basename(f).replace("_by_auth_ownership.csv", "").replace("_by_auth_year.csv", "") for f in glob.glob(os.path.join(csv_dir, "*.csv")) if "by_auth" in f])
auth_map = {"1": "Restricted", "1.0": "Restricted", "2": "Reduced", "2.0": "Reduced", "3": "Full Practice", "3.0": "Full Practice"}
own_map = {"1": "Government", "1.0": "Government", "2": "For-Profit", "2.0": "For-Profit", "3": "Non-Profit", "3.0": "Non-Profit"}

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
    # A. PROCESS OWNERSHIP DATA (Full Sample)
    # --------------------------------------------------
    own_file = os.path.join(csv_dir, f"{var_name}_by_auth_ownership.csv")
    if os.path.exists(own_file):
        df_own = pd.read_csv(own_file)
        df_own['np_authority'] = df_own['np_authority'].astype(str).str.strip().replace(auth_map)
        df_own['own_category'] = df_own['own_category'].astype(str).str.strip().replace(own_map)
        
        pivot_own = df_own.pivot_table(index='np_authority', columns='own_category', values='mean_val', aggfunc='mean')
        valid_idx = [i for i in ["Restricted", "Reduced", "Full Practice"] if i in pivot_own.index]
        valid_col = [c for c in ["Government", "Non-Profit", "For-Profit"] if c in pivot_own.columns]
        pivot_own = pivot_own.reindex(index=valid_idx, columns=valid_col)
        
        # Heatmap
        fig = plt.figure(figsize=(8, 7.5)) 
        cmap, vmin, vmax = ("RdBu", -pivot_own.abs().max().max(), pivot_own.abs().max().max()) if is_delta else ("Blues", pivot_own.min().min(), pivot_own.max().max())
        if pd.isna(vmax): vmax = 1; vmin = -1
        sns.heatmap(pivot_own, annot=True, fmt=".3f", cmap=cmap, vmin=vmin, vmax=vmax, cbar_kws={'label': 'Mean Value'}, annot_kws={"size": 12}, linewidths=.5, square=True)
        plt.title(clean_title, fontsize=14, fontweight='bold', pad=15)
        plt.ylabel("State NP Authority", fontsize=12, fontweight='bold')
        plt.xlabel("Hospital Ownership", fontsize=12, fontweight='bold')
        plt.figtext(0.05, 0.02, f"Notes: {desc}\nNP Law: Restricted, Reduced, Full.", wrap=True, fontsize=9, color='gray')
        plt.subplots_adjust(bottom=0.2) 
        plt.savefig(os.path.join(heat_dir, f"{var_name}_ownership_heatmap.png"), dpi=300, bbox_inches='tight')
        plt.close()

        # LaTeX & PDF
        tex_own = generate_own_latex(pivot_own, clean_title, var_name, uni_val, desc)
        with open(os.path.join(tex_dir, f"{var_name}_ownership.tex"), 'w') as f: f.write(tex_own)
        
        if pdflatex_found:
            standalone_own = f"\\documentclass[12pt]{{article}}\n\\usepackage{{booktabs}}\n\\usepackage{{geometry}}\n\\usepackage{{caption}}\n\\geometry{{margin=1in}}\n\\begin{{document}}\n\\thispagestyle{{empty}}\n\\vspace*{{2cm}}\n{tex_own}\n\\end{{document}}"
            temp_path = os.path.join(pdf_dir, f"{var_name}_ownership.tex")
            with open(temp_path, 'w') as f: f.write(standalone_own)
            try:
                subprocess.run(['pdflatex', '-interaction=nonstopmode', f'-output-directory={pdf_dir}', temp_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                for ext in ['.aux', '.log', '.tex']:
                    if os.path.exists(os.path.join(pdf_dir, f"{var_name}_ownership{ext}")): os.remove(os.path.join(pdf_dir, f"{var_name}_ownership{ext}"))
            except subprocess.CalledProcessError: pass

    # --------------------------------------------------
    # B. PROCESS TIMELINE DATA (Aggregated Facilities)
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
        cmap, vmin, vmax = ("RdBu", -pivot_time.abs().max().max(), pivot_time.abs().max().max()) if is_delta else ("Purples", pivot_time.min().min(), pivot_time.max().max())
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

print("=== PYTHON DUAL-PIPELINE (OWNERSHIP & TIMELINE) COMPLETE ===")
