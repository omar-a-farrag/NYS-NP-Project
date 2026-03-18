
import pandas as pd
import os

def analyze_mips_variables():
    diagnostic_rows = []
    
    # 1. Establish absolute paths based on the script's new location
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Go up two levels (from 'mips' -> 'cleaningCode' -> 'general_cms_data')
    project_root = os.path.abspath(os.path.join(script_dir, '..', '..')) 
    
    # 2. Point to the correct data folder
    target_dir = os.path.join(project_root, 'cliniciansAndGroups', 'mipsClinician_overallPerformance')
    
    print(f"Scanning directory: {target_dir}\n")
    
    # Walk through the year subdirectories
    for root, dirs, files in os.walk(target_dir):
        for file in files:
            if file.endswith('.csv'):
                filepath = os.path.join(root, file)
                year = os.path.basename(root)
                
                print(f"Processing {year} data from {file}...")
                
                try:
                    df = pd.read_csv(filepath, low_memory=False) 
                    for col in df.columns:
                        diagnostic_rows.append({
                            'year': year,
                            'file_name': file,
                            'variable_name': col,
                            'data_type': str(df[col].dtype),
                            'null_count': df[col].isnull().sum(),
                            'percent_null': round(df[col].isnull().mean() * 100, 2),
                            'unique_values': df[col].nunique()
                        })
                except Exception as e:
                    print(f"Error reading {filepath}: {e}")

    diagnostic_df = pd.DataFrame(diagnostic_rows)
    
    if not diagnostic_df.empty:
        diagnostic_df.sort_values(by=['variable_name', 'year'], inplace=True)
        
        # 3. Route output directly to dictionaries_and_crosswalks
        output_dir = os.path.join(project_root, 'dictionaries_and_crosswalks')
        
        # Ensure the directory exists just to be safe
        os.makedirs(output_dir, exist_ok=True) 
        
        output_path = os.path.join(output_dir, 'mips_clinician_diagnostic.csv')
        diagnostic_df.to_csv(output_path, index=False)
        
        print(f"\nDiagnostic complete. Output saved to: {output_path}")
    else:
        print("\nNo CSV data found to process. Please check your file paths.")

if __name__ == "__main__":
    analyze_mips_variables()