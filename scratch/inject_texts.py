import os
import json

workspace_dir = r"c:\PROYECTOS\articulos\Spatial_patterns_insects\CODIGOS"
input_file = os.path.join(workspace_dir, "scratch", "notebook_texts.txt")

def to_jupyter_lines(source_str):
    if not source_str:
        return []
    return source_str.splitlines(keepends=True)

def inject():
    if not os.path.exists(input_file):
        print(f"Error: {input_file} does not exist.")
        return

    cell_updates = {}
    current_file = None
    current_cell_idx = None
    current_source = []

    with open(input_file, 'r', encoding='utf-8') as f:
        for line in f:
            if line.startswith("<<<<<<<<<<<< FILE: ") and line.strip().endswith(" >>>>>>>>>>>>"):
                # Save previous cell
                if current_file is not None and current_cell_idx is not None:
                    cell_updates.setdefault(current_file, {})[current_cell_idx] = "".join(current_source)
                current_file = line.replace("<<<<<<<<<<<< FILE: ", "").replace(" >>>>>>>>>>>>", "").strip()
                current_cell_idx = None
                current_source = []
            elif line.startswith("<<<<<<<<<<<< CELL: ") and line.strip().endswith(" >>>>>>>>>>>>"):
                # Save previous cell
                if current_file is not None and current_cell_idx is not None:
                    cell_updates.setdefault(current_file, {})[current_cell_idx] = "".join(current_source)
                parts = line.strip().split()
                current_cell_idx = int(parts[2])
                current_source = []
            else:
                if current_file is not None and current_cell_idx is not None:
                    current_source.append(line)

        # Save last cell
        if current_file is not None and current_cell_idx is not None:
            cell_updates.setdefault(current_file, {})[current_cell_idx] = "".join(current_source)

    for nb_name, updates in cell_updates.items():
        nb_path = os.path.join(workspace_dir, nb_name)
        if not os.path.exists(nb_path):
            print(f"Warning: Notebook {nb_path} not found. Skipping updates for it.")
            continue

        with open(nb_path, 'r', encoding='utf-8') as f:
            try:
                data = json.load(f)
            except Exception as e:
                print(f"Error reading {nb_name}: {e}")
                continue

        cells = data.get('cells', [])
        updated_count = 0
        for idx, new_source in updates.items():
            if idx < 0 or idx >= len(cells):
                print(f"Warning: Cell index {idx} out of range for {nb_name}. Skipping cell.")
                continue
            cells[idx]['source'] = to_jupyter_lines(new_source)
            updated_count += 1

        with open(nb_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=1, ensure_ascii=False)
            f.write('\n')  # Trailing newline at EOF

        print(f"Successfully updated {updated_count} cells in {nb_name}.")

if __name__ == "__main__":
    inject()
