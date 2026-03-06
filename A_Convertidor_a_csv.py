import xml.etree.ElementTree as ET
import csv
import os

xml_file = r'c:\Users\ezequiel\Desktop\.eastudio\DATA\RoboForex-Pro_hub\reports\report_genetic__Apex_MeanReversion_v1.xml'
csv_file = r'c:\Users\ezequiel\Desktop\.eastudio\DATA\RoboForex-Pro_hub\reports\report_genetic__Apex_MeanReversion_v1.csv'

print(f"Abriendo {xml_file}...")

ns = {'ss': 'urn:schemas-microsoft-com:office:spreadsheet'}

try:
    tree = ET.parse(xml_file)
    root = tree.getroot()

    table = root.find('.//ss:Table', ns)
    rows = table.findall('ss:Row', ns)

    if rows:
        headers = [cell.find('ss:Data', ns).text for cell in rows[0].findall('ss:Cell', ns)]
        
        print(f"Extrayendo {len(rows)-1} filas...")
        
        with open(csv_file, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow(headers)
            
            for row in rows[1:]:
                data = []
                cells = row.findall('ss:Cell', ns)
                for cell in cells:
                    cell_data = cell.find('ss:Data', ns)
                    data.append(cell_data.text if cell_data is not None else "")
                writer.writerow(data)
        
        print(f"¡Éxito! Archivo guardado en: {csv_file}")
    else:
        print("No se encontraron filas en el archivo XML.")

except Exception as e:
    print(f"Error durante la conversión: {e}")
