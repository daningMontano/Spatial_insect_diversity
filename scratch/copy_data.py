import os
import shutil

# Configuración de directorios de trabajo
# Ajuste BASE_DIR si ejecuta el script desde otra ubicación externa
BASE_DIR = "."
DEST_DIR = os.path.join(BASE_DIR, "Apps", "data")

# Crear el directorio de destino si no existe
os.makedirs(DEST_DIR, exist_ok=True)

# 1. Definición de archivos individuales y tabulares
archivos_directos = [
    "Data/Records/insects_records_clean.csv",
    "Data/Records/insects_ecuador_preprocessed.rds"
]

# 2. Definición de capas base de Shapefiles (requieren copiar todos sus componentes)
shapefiles = [
    "Data/Shp/ecuador_limits",
    "Data/Shp/ron_2011_no_UTM",
    "Data/Shp/snap",
    "Results/shp/grid_10km_sampling"
]
extensiones_shp = [".shp", ".shx", ".dbf", ".prj", ".sbn", ".sbx", ".cpg"]

# 3. Lista de Rasters estructurados en el proyecto original
rasters = [
    "Results/raster/alpha_diversity/alpha_conservation_all_clusters_likert5.tif",
    "Results/raster/alpha_endemism_records/alpha_endemism_records_all_clusters_likert5.tif",
    "Results/raster/endemism/endemism_conservation_all_clusters_likert5.tif",
    "Results/raster/GAM_prediction_alpha.tif",
    "Results/raster/cluster_raster_result.tiff",
    "Results/raster/nmds_result.tiff",
    "Results/raster/records_kernel_density.tiff"
]

def copiar_archivo(ruta_origen, carpeta_destino):
    """Copia un archivo manteniendo solo su nombre base en el destino."""
    src = os.path.join(BASE_DIR, ruta_origen)
    if os.path.exists(src):
        dst = os.path.join(carpeta_destino, os.path.basename(ruta_origen))
        shutil.copy2(src, dst)
        print(f"Copiado: {ruta_origen} -> {dst}")
    else:
        print(f"Advertencia: No se encontró el archivo {ruta_origen}")

# Ejecución del proceso de copiado
print("Iniciando migración de datos hacia Apps/data/...")

# Procesar archivos directos
for archivo in archivos_directos:
    copiar_archivo(archivo, DEST_DIR)

# Procesar componentes de shapefiles
for shp_base in shapefiles:
    for ext in extensiones_shp:
        ruta_componente = f"{shp_base}{ext}"
        copiar_archivo(ruta_componente, DEST_DIR)

# Procesar y aplanar capas raster
for raster in rasters:
    copiar_archivo(raster, DEST_DIR)

print("Proceso finalizado.")
