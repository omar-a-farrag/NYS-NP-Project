import os

# --- SETUP: Point this to the root of your hospital data ---

# (Adjust this path if your HCAHPS/HAI data is stored elsewhere)

script_dir = os.path.dirname(os.path.abspath(__file__))

project_root = os.path.abspath(os.path.join(script_dir, "..",".."))

# The folders you want to scan
target_folders = ["hcahps"] # Add others if needed, like "asc"

output_file = os.path.join(script_dir,"..","..","dictionaries_and_crosswalks", "raw_directory_scan.txt")

with open(output_file, 'w', encoding='utf-8') as f:
    f.write("=== FULL RAW DATA DIRECTORY SCAN (Excluding .dta) ===\n\n")
    
    for folder_name in target_folders:
        folder_path = os.path.join(project_root, folder_name)
        if not os.path.exists(folder_path):
            f.write(f"[!] Directory not found: {folder_path}\n\n")
            continue
            
        f.write(f"--- FOLDER: {folder_name.upper()} ---\n")
        
        for root, dirs, files in os.walk(folder_path):
            level = root.replace(folder_path, '').count(os.sep)
            indent = ' ' * 4 * (level)
            
            # Filter out the old cleaned Stata files
            raw_files = [file for file in files if not file.endswith('.dta')]
            
            # Only print the folder if it contains raw files
            if raw_files:
                f.write(f"{indent}{os.path.basename(root)}/\n")
                subindent = ' ' * 4 * (level + 1)
                for file in raw_files:
                    f.write(f"{subindent}{file}\n")
        f.write("\n")

print(f"Full scan complete! Please open '{output_file}' and paste the contents.")
