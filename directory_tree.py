import os

def generate_tree(startpath, output_file):
    with open(output_file, 'w', encoding='utf-8') as f:
        for root, dirs, files in os.walk(startpath):
            level = root.replace(startpath, '').count(os.sep)
            indent = ' ' * 4 * (level)
            f.write(f"{indent}{os.path.basename(root)}/\n")
            subindent = ' ' * 4 * (level + 1)
            for file in files:
                f.write(f"{subindent}{file}\n")

# Dynamically get the directory where THIS script is saved
script_dir = os.path.dirname(os.path.abspath(__file__))

# Save the output file directly in that same folder
output_path = os.path.join(script_dir, 'directory_tree.txt')

generate_tree(script_dir, output_path)
print(f"Success! Directory tree saved to: {output_path}")