import pandas as pd
import os
import subprocess

# =====================================================
# PATHS
# =====================================================

out_root = r"C:\Users\omarf\Dropbox\personal_files_omar_farrag\Research\projects\NYS_npPolicy\output\summary_stats\in_patient\demographics"

csv_dir = os.path.join(out_root, "tables_csv")
tex_dir = os.path.join(out_root, "tables_pdf")

os.makedirs(tex_dir, exist_ok=True)

print("=== GENERATING JOURNAL-QUALITY LATEX TABLES ===")

# =====================================================
# LATEX COMPILATION FUNCTION
# =====================================================

def compile_to_pdf(filename_base, table_content, landscape=False):

    orientation = ""
    if landscape:
        orientation = r"\usepackage{pdflscape}"

    doc = rf"""
\documentclass{{article}}

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
        subprocess.run(
            [
                "pdflatex",
                "-interaction=nonstopmode",
                "-output-directory",
                tex_dir,
                tex_path
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )

        print(f" -> Successfully compiled: {filename_base}.pdf")

    except Exception as e:
        print(f" -> WARNING: Compilation failed for {filename_base}.tex")
        print(e)

# =====================================================
# SAFE RESIZE FUNCTION
# ONLY USE FOR VERY WIDE TABLES
# =====================================================

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
# TABLE 1
# TAXONOMY MAPPING
# =====================================================

taxonomy_tex = r"""
\begin{table}[htbp]
\centering
\caption{Taxonomy of Hospital Ownership Classifications}
\label{tab:ownership_mapping}

\renewcommand{\arraystretch}{1.15}

\begin{threeparttable}

\begin{tabular}{p{2.0in} p{4.2in}}
\toprule
\textbf{Grouped Category} &
\textbf{CMS Raw Ownership Classifications} \\
\midrule

\textbf{Government}
& Department of Defense \\
& Government -- Federal \\
& Government -- Hospital District or Authority \\
& Government -- Local \\
& Government -- State \\
& Tribal \\
& Veterans Health Administration \\
\midrule

\textbf{Non-Profit}
& Voluntary Non-Profit -- Church \\
& Voluntary Non-Profit -- Other \\
& Voluntary Non-Profit -- Private \\
\midrule

\textbf{For-Profit}
& Proprietary \\
& Physician \\
\bottomrule

\end{tabular}

\begin{tablenotes}[flushleft]
\footnotesize
\item Notes:
Raw ownership classifications reflect the Provider of Services
(POS) organizational ownership categories.
\end{tablenotes}

\end{threeparttable}
\end{table}
"""

with open(
    os.path.join(tex_dir, "tab1_ownership_taxonomy_fragment.tex"),
    "w",
    encoding="utf-8"
) as f:
    f.write(taxonomy_tex)

compile_to_pdf(
    "tab1_ownership_taxonomy",
    taxonomy_tex
)

# =====================================================
# TABLE 2A
# GROUPED OWNERSHIP COUNTS
# =====================================================

df_grp = pd.read_csv(
    os.path.join(
        csv_dir,
        "ownership_grouped_unique_full_sample.csv"
    )
)

# FIX: Stata exported the text labels, not numbers. 
# No numeric conversion needed. Just drop NaNs and keep the big three.
df_grp = df_grp.dropna(subset=["own_category"])
valid_cats = ["Government", "For-Profit", "Non-Profit"]
df_grp = df_grp[df_grp["own_category"].isin(valid_cats)]

df_grp = (
    df_grp[
        ["own_category", "fac_count"]
    ]
    .rename(
        columns={
            "own_category": "Grouped Classification",
            "fac_count": "Facility Count"
        }
    )
)

# Proper ordering
order = ["Government", "Non-Profit", "For-Profit"]

df_grp["Grouped Classification"] = pd.Categorical(
    df_grp["Grouped Classification"],
    categories=order,
    ordered=True
)

df_grp = df_grp.sort_values("Grouped Classification")

grouped_tex = r"""
\begin{table}[htbp]
\centering
\caption{Unique Facility Counts by Grouped Ownership Classification, 2007--2024}
\label{tab:grouped_counts}

\begin{threeparttable}
"""

grouped_tex += df_grp.to_latex(
    index=False,
    escape=False,
    column_format="lr"
)

grouped_tex += r"""

\begin{tablenotes}[flushleft]
\footnotesize
\item Notes:
Counts reflect unique facilities observed at any point
during the 2007--2024 sample period.
\end{tablenotes}

\end{threeparttable}
\end{table}
"""

compile_to_pdf(
    "tab2a_grouped_counts",
    grouped_tex
)



# =====================================================
# TABLE 2B
# CMS OWNERSHIP COUNTS
# =====================================================

df_fine = pd.read_csv(
    os.path.join(
        csv_dir,
        "ownership_fine_unique_full_sample.csv"
    )
)

df_fine = df_fine.dropna(subset=["own_str"])

df_fine["own_str"] = (
    df_fine["own_str"]
    .astype(str)
    .str.title()
)

df_fine = (
    df_fine[
        ["own_str", "fac_count"]
    ]
    .rename(
        columns={
            "own_str": "CMS Classification",
            "fac_count": "Facility Count"
        }
    )
    .sort_values("CMS Classification")
)

cms_tex = r"""
\begin{table}[htbp]
\centering
\caption{Unique Facility Counts by CMS Ownership Classification, 2007--2024}
\label{tab:cms_counts}

\small

\begin{threeparttable}
"""

cms_tex += df_fine.to_latex(
    index=False,
    escape=False,
    column_format="lr"
)

cms_tex += r"""

\begin{tablenotes}[flushleft]
\footnotesize
\item Notes:
Counts reflect unique facilities observed during the
2007--2024 sample period.
\end{tablenotes}

\end{threeparttable}
\end{table}
"""

compile_to_pdf(
    "tab2b_cms_counts",
    cms_tex
)


# =====================================================
# TABLE 3
# GROUPED OWNERSHIP BY YEAR
# =====================================================

df3 = pd.read_csv(
    os.path.join(
        csv_dir,
        "ownership_grouped_by_year.csv"
    )
)

# FIX: Just like Table 2A, filter directly by the text labels
df3 = df3.dropna(subset=["own_category"])
valid_cats = ["Government", "For-Profit", "Non-Profit"]
df3 = df3[df3["own_category"].isin(valid_cats)]

pivot3 = (
    df3.pivot_table(
        index="own_category",
        columns="year",
        values="fac_count",
        aggfunc="sum"
    )
    .fillna(0)
    .astype(int)
)

# Chronological ordering
pivot3 = pivot3[sorted(pivot3.columns)]
pivot3 = pivot3.reset_index()

# Rename for presentation
pivot3 = pivot3.rename(columns={"own_category": "Ownership"})

# Ordered rows
pivot3["Ownership"] = pd.Categorical(
    pivot3["Ownership"],
    categories=order,
    ordered=True
)

pivot3 = pivot3.sort_values("Ownership")

table3_tex = r"""
\begin{landscape}

\begin{table}[htbp]
\centering

\caption{
Active Facilities by Grouped Ownership Classification and Year, 2007--2024
}

\small
\setlength{\tabcolsep}{3pt}
"""

table3_tex += pivot3.to_latex(
    index=False,
    escape=False,
    column_format="l" + "r" * (len(pivot3.columns) - 1)
)

table3_tex += r"""

\end{table}

\end{landscape}
"""

compile_to_pdf(
    "tab3_grouped_by_year",
    table3_tex,
    landscape=True
)

# =====================================================
# TABLE 4
# CMS OWNERSHIP BY YEAR
# PANEL FORMAT
# =====================================================

df4 = pd.read_csv(
    os.path.join(
        csv_dir,
        "ownership_fine_by_year.csv"
    )
)

df4 = df4.dropna(subset=["own_str"])

df4["own_str"] = (
    df4["own_str"]
    .astype(str)
    .str.title()
)

pivot4 = (
    df4.pivot_table(
        index="own_str",
        columns="year",
        values="fac_count",
        aggfunc="sum"
    )
    .fillna(0)
    .astype(int)
)

pivot4 = pivot4[sorted(pivot4.columns)]

# =====================================================
# DEFINE PANELS
# =====================================================

government = [
    "Department Of Defense",
    "Government - Federal",
    "Government - Hospital District Or Authority",
    "Government - Local",
    "Government - State",
    "Tribal",
    "Veterans Health Administration"
]

nonprofit = [
    "Voluntary Non-Profit - Church",
    "Voluntary Non-Profit - Other",
    "Voluntary Non-Profit - Private"
]

forprofit = [
    "Physician",
    "Proprietary"
]

panel_map = {
    "Panel A: Government Ownership": government,
    "Panel B: Non-Profit Ownership": nonprofit,
    "Panel C: For-Profit Ownership": forprofit
}

# =====================================================
# BUILD TABLE 4
# =====================================================

table4_tex = r"""
\begin{landscape}

\begin{table}[htbp]
\centering

\caption{
Active Facilities by CMS Ownership Classification and Year, 2007--2024
}

\small
\setlength{\tabcolsep}{2.5pt}
"""

for panel_name, categories in panel_map.items():

    sub = pivot4.loc[
        pivot4.index.intersection(categories)
    ]

    sub = sub.reset_index()

    table4_tex += rf"""

\vspace{{0.75em}}

\textbf{{{panel_name}}}

\vspace{{0.25em}}
"""

    panel_tex = sub.to_latex(
        index=False,
        escape=False,
        column_format="p{3.0in}" + "r" * (len(sub.columns) - 1)
    )

    # ONLY TABLE 4 GETS RESIZED
    panel_tex = latex_resize(panel_tex)

    table4_tex += panel_tex

table4_tex += r"""

\end{table}

\end{landscape}
"""

compile_to_pdf(
    "tab4_cms_by_year",
    table4_tex,
    landscape=True
)

print("=== ALL TABLES COMPLETED ===")
