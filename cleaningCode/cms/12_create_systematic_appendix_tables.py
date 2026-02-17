import pandas as pd
import os
import subprocess

# --- 1. SETUP PATHS ---
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(script_dir, "..", ".."))
dict_dir = os.path.join(project_root, "dictionaries_and_crosswalks")
tex_dir = os.path.join(project_root, "outputs_while_cleaning", "tables")

if not os.path.exists(tex_dir): os.makedirs(tex_dir)

# ==============================================================================
# PART 1: EMPIRICAL COST THRESHOLD TABLE
# ==============================================================================
df_costs = pd.read_csv(os.path.join(dict_dir, "crosswalk_partd_empirical_costs.csv"))

# Calculate Summary Stats per Class
class_summary = df_costs.groupby('usan_class').agg(
    total_drugs=('generic_name', 'count'),
    threshold_75th=('avg_cost_per_claim', lambda x: x.quantile(0.75))
).reset_index()

# Format for LaTeX
class_summary['threshold_75th'] = class_summary['threshold_75th'].map('${:,.2f}'.format)
class_summary = class_summary.sort_values('usan_class')
class_summary.columns = ['Therapeutic Class (USAN)', 'Count of Generic Molecules', 'Top Quartile (High Cost) Threshold']

# ==============================================================================
# PART 2: RBCS SERVICE CLASSIFICATION TABLE
# ==============================================================================
df_rbcs = pd.read_csv(os.path.join(dict_dir, "crosswalk_rbcs_services.csv"))

# We summarize by Category and Subcategory to avoid a 10,000-row table
rbcs_summary = df_rbcs.groupby(['rbcs_cat', 'rbcs_subcat']).size().reset_index(name='code_count')

# Group 'Imaging' and 'E&M' to the top since they are our primary focus
priority = {'E&M': 1, 'Imaging': 2, 'Procedure': 3, 'Treatment': 4, 'Test': 5}
rbcs_summary['sort_key'] = rbcs_summary['rbcs_cat'].map(lambda x: priority.get(x, 99))
rbcs_summary = rbcs_summary.sort_values(['sort_key', 'rbcs_cat', 'code_count'], ascending=[True, True, False]).drop(columns='sort_key')

rbcs_summary.columns = ['CMS Category', 'Sub-Category', 'Number of CPT Codes']

# ==============================================================================
# PART 3: PDF GENERATION ENGINE
# ==============================================================================
def create_pdf(df, filename, caption, label, custom_col_spec=None):
    latex_code = df.to_latex(index=False, longtable=True, caption=caption, label=label, escape=True)
    
    # Inject custom column widths if provided
    if custom_col_spec:
        start_idx = latex_code.find("{longtable}") + 11
        end_idx = latex_code.find("}", start_idx) + 1
        current_spec = latex_code[start_idx:end_idx]
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
\\usepackage[margin=1in]{{geometry}}
\\usepackage{{booktabs}}
\\usepackage{{longtable}}
\\usepackage{{array}}
\\title{{Systematic Appendix Preview: {label}}}
\\date{{}}
\\begin{{document}}
\\maketitle
\\input{{{filename}}}
\\end{{document}}
    """
    with open(wrapper_path, 'w') as f:
        f.write(wrapper_content)

    try:
        subprocess.run(["pdflatex", "-interaction=nonstopmode", wrapper_name], cwd=tex_dir, stdout=subprocess.DEVNULL, check=True)
        print(f"SUCCESS! Created {wrapper_name.replace('.tex', '.pdf')}")
    except Exception:
        print(f"ERROR compiling {filename}")

# Generate Table D (Costs)
create_pdf(
    class_summary, 
    "appendix_empirical_cost_thresholds.tex", 
    "Empirical Cost Thresholds by Therapeutic Class", 
    "tab:empirical_costs",
    "{p{5cm}cc}"
)

# Generate Table E (RBCS)
create_pdf(
    rbcs_summary, 
    "appendix_rbcs_classification.tex", 
    "CMS Restructured BETOS Classification System (RBCS)", 
    "tab:rbcs",
    "{p{4cm}p{7cm}c}"
)