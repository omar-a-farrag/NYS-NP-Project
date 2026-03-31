import pandas as pd
import numpy as np
import os

# --- 1. SETUP PATHS ---
script_dir = os.path.dirname(os.path.abspath(__file__))
# Input: Cleaning logs
input_path = os.path.abspath(os.path.join(script_dir, "..", "logs", "mips", "facility_specialty_growth_tracker.csv"))
# Output: Tables folder
output_dir = os.path.abspath(os.path.join(script_dir, "..", "..", "outputs_while_cleaning", "tables"))

if not os.path.exists(output_dir):
    os.makedirs(output_dir)

output_csv = os.path.join(output_dir, "specialty_presence_formatted.csv")
output_tex = os.path.join(output_dir, "specialty_presence_formatted.tex")

print(f"Reading: {input_path}")
print(f"Writing: {output_dir}")

def format_years(row):
    years = []
    for col in row.index:
        if col.startswith('exists') and row[col] == 1:
            try:
                year = int(col.replace('exists', ''))
                years.append(year)
            except ValueError:
                continue
    if not years: return ""
    years.sort()
    ranges = []
    start = years[0]
    end = years[0]
    for i in range(1, len(years)):
        if years[i] == end + 1:
            end = years[i]
        else:
            ranges.append(f"{start}-{end}" if start != end else f"{start}")
            start = years[i]
            end = years[i]
    ranges.append(f"{start}-{end}" if start != end else f"{start}")
    return ", ".join(ranges)

# --- 2. LOAD AND PROCESS ---
try:
    df = pd.read_csv(input_path)
except FileNotFoundError:
    print(f"CRITICAL ERROR: File not found at {input_path}")
    exit()

df['Years'] = df.apply(format_years, axis=1)
final_table = df[['specialty', 'Years']].rename(columns={'specialty': 'Specialty'})

# --- 3. EXPORT ---
final_table.to_csv(output_csv, index=False)

latex_code = final_table.to_latex(
    index=False, 
    longtable=True, 
    caption="Specialty Presence in Facility Data (2014-2025)", 
    label="tab:specialty_presence",
    column_format="ll" # Simple 2-column layout
)

# Optional: Keep \small to make it look tighter, or remove it for normal text size.
# I will keep it for now as it usually looks better for data tables.
latex_code = "{\\small\n" + latex_code + "\n}"

with open(output_tex, 'w') as f:
    f.write(latex_code)

print("SUCCESS! Generated standard 2-column table.")