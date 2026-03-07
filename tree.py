import os
import sys

def print_tree(start_path='.', prefix='', f=None):
    # Directorios a ignorar completamente (basado en peticiones previas y lógica de sistema)
    ignore_dirs = {'.venv', '.git', '__pycache__', '.pytest_cache'}
    
    try:
        # Usamos una lista filtrada de entrada
        entries = sorted([e for e in os.listdir(start_path) if e not in ignore_dirs])
    except PermissionError:
        return

    for i, entry in enumerate(entries):
        path = os.path.join(start_path, entry)
        is_dir = os.path.isdir(path)
        
        # Lógica de "Corte": Filtrado inteligente de archivos
        if not is_dir:
            # Carpetas donde SI queremos ver los archivos (root y herramientas)
            allowed_parents = {"instalacion", "00_setup", "bin", "Instancias"}
            parent_name = os.path.basename(os.path.dirname(path))
            
            # Si estamos en zona MQL5 (sistema), ocultamos archivos para no saturar.
            if "MQL5" in path:
                continue
            
            # En zona de sistema (instalacion o 00_setup), solo mostramos si es un padre permitido.
            if "instalacion" in path or "00_setup" in path:
                if parent_name not in allowed_parents:
                    continue

        connector = '└── ' if i == len(entries)-1 else '├── '
        line = prefix + connector + entry
        
        if f:
            f.write(line + '\n')
        else:
            print(line)

        if is_dir:
            # Carpetas que queremos MOSTRAR pero NO EXPANDIR dentro de MQL5/Instalación
            # para no saturar con miles de indicadores, archivos temporales o bases de datos.
            stop_recursion_dirs = {
                'Profiles', 'Include', 'Indicators', 'Scripts', 
                'UnitTest', 'UnitTests', 'Default', 'Custom', 'Files',
                'bases', 'temp', 'Tester', 'Deriv', 'Demo', 'Examples', 'Expert',
                'history', 'ticks', 'Deriv-Demo', 'includes-ejemplo'
            }
            
            if entry in stop_recursion_dirs:
                continue

            extension = '    ' if i == len(entries)-1 else '│   '
            print_tree(path, prefix + extension, f)

if __name__ == "__main__":
    output_file = "tree.txt"
    with open(output_file, "w", encoding="utf-8") as f:
        print_tree('.', f=f)
    print(f"Árbol de directorios (solo carpetas en instalación) guardado en {output_file}")