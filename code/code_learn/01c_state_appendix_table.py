import os
import subprocess
import pandas as pd
from itertools import zip_longest

# --- 1. DEFINE PATHS ---
base_dir = r"C:\Users\omarf\Dropbox\personal_files_omar_farrag\Research\projects\NYS_npPolicy\output\summary_stats\in_patient\macro_stats"
tex_dir = os.path.join(base_dir, "tables_tex")
pdf_dir = os.path.join(base_dir, "tables_pdf", "appendix")

os.makedirs(tex_dir, exist_ok=True)
os.makedirs(pdf_dir, exist_ok=True)

# --- 2. THE STATE TAXONOMY ---
# Mapped exactly from your Stata DO-file logic to Full State Names
states_restricted = [
    "California", "Florida", "Georgia", "Michigan", "Missouri", 
    "North Carolina", "Oklahoma", "South Carolina", "Tennessee", 
    "Texas", "Virginia"
]

states_reduced = [
    "Alabama", "American Samoa", "Delaware", "Illinois", "Indiana", 
    "Kansas", "Kentucky", "Louisiana", "Mississippi", "New Jersey", 
    "Ohio", "Pennsylvania", "Utah", "Wisconsin"
]

states_full = [
    "Arizona", "Colorado", "Connecticut", "District of Columbia", 
    "Hawaii", "Idaho", "Iowa", "Maryland", "Massachusetts", 
    "Minnesota", "Montana", "Nebraska", "Nevada", "New Hampshire", 
    "New Mexico", "New York", "North Dakota", "Oregon", "Rhode Island", 
    "South Dakota", "Vermont", "Washington", "Wyoming"
]

# Alphabetize the lists for clean presentation
states_restricted.sort()
states_reduced.sort()
states_full.sort()

# --- 3. GENERATE LATEX FRAGMENT ---
# We use zip_longest to create rows out of unequal length columns
rows = zip_longest(states_restricted, states_reduced, states_full, fillvalue="")

latex_rows = ""
for r, red, f in rows:
    latex_rows += f"        {r} & {red} & {f} \\\\\n"

latex_fragment = f"""\\begin{{table}}[htbp]
    \\centering
    \\caption{{State Categorization by Nurse Practitioner Practice Authority}}
    \\label{{tab:np_authority_appendix}}
    \\vspace{{0.2cm}}
    \\begin{{tabular}}{{p{{4.5cm}} p{{4.5cm}} p{{4.5cm}}}}
        \\toprule
        \\textbf{{Restricted Practice}} & \\textbf{{Reduced Practice}} & \\textbf{{Full Practice}} \\\\
        \\midrule
{latex_rows}        \\bottomrule
    \\end{{tabular}}
    \\vspace{{0.1cm}}
    \\begin{{minipage}}{{0.9\\textwidth}}
        \\footnotesize \\textit{{Notes:}} Categorization reflects the primary regulatory environment for Nurse Practitioners. Restricted practice requires career-long physician supervision or delegation. Reduced practice requires a collaborative agreement. Full practice permits independent evaluation, diagnosis, and prescribing. 
    \\end{{minipage}}
\\end{{table}}"""

# Export Fragment
tex_out = os.path.join(tex_dir, "appendix_np_authority.tex")
with open(tex_out, 'w') as f:
    f.write(latex_fragment)

# --- 4. COMPILE STANDALONE PDF ---
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

temp_tex_path = os.path.join(pdf_dir, "appendix_np_authority.tex")
with open(temp_tex_path, 'w') as f:
    f.write(standalone_tex)

try:
    subprocess.run(
        ['pdflatex', '-interaction=nonstopmode', f'-output-directory={pdf_dir}', temp_tex_path],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=True
    )
    # Clean up clutter
    for ext in ['.aux', '.log', '.tex']:
        clutter_file = os.path.join(pdf_dir, f"appendix_np_authority{ext}")
        if os.path.exists(clutter_file):
            os.remove(clutter_file)
            
    print(f"Successfully generated Appendix Table PDF at: {pdf_dir}")

except subprocess.CalledProcessError:
    print("[WARNING] Compilation failed. Check LaTeX syntax.")