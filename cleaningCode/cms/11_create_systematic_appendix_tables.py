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
class_summary.columns = ['Therapeutic Class (USAN)', 'Unique Molecules ($N$)', '75th Percentile Cost Threshold']

# ==============================================================================
# PART 2: RBCS SERVICE CLASSIFICATION TABLE (Sample)
# ==============================================================================
df_rbcs = pd.read_csv(os.path.join(dict_dir, "crosswalk_rbcs_services.csv"))

# Get the top 20 most populated RBCS subcategories just for a summary appendix
rbcs_summary = df_rbcs['rbcs_subcat'].value_counts().reset_index().head(20)
rbcs_summary.columns = ['RBCS Subcategory', 'Number of Associated HCPCS Codes']

# ==============================================================================
# PART 3: LATEX EXPORT PIPELINE
# ==============================================================================
def create_pdf(df, filename, caption, label, custom_col_spec=None):
    tex_path = os.path.join(tex_dir, filename)
    
    col_spec = custom_col_spec if custom_col_spec else ("l" * len(df.columns))
    
    latex_str = df.to_latex(
        index=False,
        caption=caption,
        label=label,
        escape=True,
        column_format=col_spec,
        position="htbp"
    )
    latex_str = latex_str.replace("\\toprule", "\\toprule\n\\rowcolor{gray!10}")
    
    with open(tex_path, 'w') as f:
        f.write(latex_str)

    wrapper_name = filename.replace(".tex", "_preview.tex")
    wrapper_path = os.path.join(tex_dir, wrapper_name)
    wrapper_content = f"""\\documentclass[11pt]{{article}}
\\usepackage[margin=1in]{{geometry}}
\\usepackage{{booktabs}}
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

    print(f"Compiling {filename}...")
    try:
        subprocess.run(['pdflatex', '-interaction=nonstopmode', wrapper_name], 
                       cwd=tex_dir, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    except subprocess.CalledProcessError:
        print(f"ERROR compiling {filename}")

# --- UPDATED DYNAMIC CAPTIONS ---
caption_costs = (
    "Empirical High-Cost Thresholds (75th Percentile) by USAN Therapeutic Class. "
    "Calculated using the 100\\% sample of Medicare Part D claims spanning 2013--2023. "
    "$N$ represents the number of unique generic molecules dispensed >100 times during the study period."
)

caption_rbcs = (
    "Top 20 Most Frequent RBCS Service Categories in Medicare Part B. "
    "Calculated using the 100\\% sample of CMS physician billing data spanning 2013--2023."
)

create_pdf(class_summary, "appendix_empirical_cost_thresholds.tex", caption_costs, "tab:empirical_costs", custom_col_spec="llc")
create_pdf(rbcs_summary, "appendix_rbcs_classification.tex", caption_rbcs, "tab:rbcs", custom_col_spec="lc")

print("\nSUCCESS: Systematic Tables generated and PDFs compiled!")