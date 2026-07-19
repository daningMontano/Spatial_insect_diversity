import os
import json

workspace_dir = r"c:\PROYECTOS\articulos\Spatial_patterns_insects\CODIGOS"
output_file = os.path.join(workspace_dir, "scratch", "notebook_texts.txt")

notebooks = [
    "0_Data_proccesing_cleaning.ipynb",
    "1_Sampling_coverage.ipynb",
    "2_Alpha_diversity.ipynb",
    "3_Beta_diversity.ipynb",
    "4_Endemism.ipynb",
    "5_Conservation_areas.ipynb",
    "6_Report.ipynb"
]

def extract():
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    with open(output_file, 'w', encoding='utf-8') as out:
        for nb_name in notebooks:
            nb_path = os.path.join(workspace_dir, nb_name)
            if not os.path.exists(nb_path):
                print(f"Warning: {nb_path} does not exist.")
                continue
            
            with open(nb_path, 'r', encoding='utf-8') as f:
                try:
                    data = json.load(f)
                except Exception as e:
                    print(f"Error reading {nb_name}: {e}")
                    continue
            
            out.write(f"<<<<<<<<<<<< FILE: {nb_name} >>>>>>>>>>>>\n")
            cells = data.get('cells', [])
            for idx, cell in enumerate(cells):
                cell_type = cell.get('cell_type', '')
                if cell_type not in ['markdown', 'code']:
                    continue
                
                source = cell.get('source', [])
                if isinstance(source, str):
                    source_str = source
                else:
                    source_str = "".join(source)
                
                out.write(f"<<<<<<<<<<<< CELL: {idx} TYPE: {cell_type} >>>>>>>>>>>>\n")
                out.write(source_str)
                if source_str and not source_str.endswith('\n'):
                    out.write('\n')

if __name__ == "__main__":
    extract()
    print("Extraction complete. Output written to scratch/notebook_texts.txt")
