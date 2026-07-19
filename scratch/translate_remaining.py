"""
Translate remaining Spanish comments/text to English in all notebooks.
This script directly modifies the .ipynb JSON files.
"""
import json
import os
import re

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if not os.path.basename(BASE) == "CODIGOS":
    BASE = os.path.dirname(os.path.abspath(__file__)).replace("scratch", "")

# Mapping: (old_text, new_text) — applied as simple string replacements in source lines.
# Each tuple is (spanish_substring, english_replacement).
REPLACEMENTS = {
    # ===== 0_Data_proccesing_cleaning.ipynb =====
    "0_Data_proccesing_cleaning.ipynb": [
        ("# Incertidumbre (\"cf.\", \"aff.\", \"?\", \"nr.\", \"indet.\", \"undet\")", "# Uncertainty terms (\"cf.\", \"aff.\", \"?\", \"nr.\", \"indet.\", \"undet\")"),
        ("# Género sin especie (\"sp.\", \"spp.\")", "# Genus without species (\"sp.\", \"spp.\")"),
        ("\"capitals\",     # cerca de capitales", "\"capitals\",     # Close to capital cities"),
        ("\"centroids\",    # cerca de centroides adm. (país/provincia)", "\"centroids\",    # Close to administrative centroids (country/province)"),
        ("\"institutions\", # cerca de instituciones (museos, herbarios, zoos)", "\"institutions\", # Close to biodiversity institutions (museums, herbaria, zoos)"),
        ("\"outliers\"    # outliers geográficos por especie", "\"outliers\"    # Geographic outliers per species"),
        ("centroids_detail  = \"both\",   # país y provincia", "centroids_detail  = \"both\",   # country and province"),
    ],

    # ===== 1_Sampling_coverage.ipynb =====
    "1_Sampling_coverage.ipynb": [
        ("title = \"Relación entre registros y especies\"", "title = \"Relationship between records and species\""),
        ("x = \"Total de registros\",", "x = \"Total records\","),
        ("y = \"Total de especies\",", "y = \"Total species\","),
        ("# columna SC = sample coverage; T = # unidades de muestreo", "# SC column = sample coverage; T = # sampling units"),
        ("Samplig_coverage = numeric(),  # SC observado (abundancia)", "Samplig_coverage = numeric(),  # Observed SC (abundance)"),
        ("n_records = numeric(),         # n total de registros", "n_records = numeric(),         # Total number of records (n)"),
        ("sc_ext = numeric(),            # SC al extremo de la curva", "sc_ext = numeric(),            # SC at the asymptotic end of the curve"),
        ("n_records_ext = numeric(),     # n (size) al extremo", "n_records_ext = numeric(),     # Sample size (n) at the asymptotic end"),
        ("sp_ext = numeric(),         # qD al extremo", "sp_ext = numeric(),         # Estimated richness (qD) at the asymptotic end"),
        ("# 1) Filtrar todo dentro del 10-km (SIN usar id_2km)", "# 1) Filter records within the current 10 km cell"),
        ("# 2) Abundance vector (number of records per species)", "# 2) Count records per species to build the abundance vector"),
        ("#    - quitar NAs en genus", "#    - Filter out empty scientific names"),
        ("#    - keep species with n > 0", "#    - Keep species with abundance > 0"),
        ("# 2) Vector de abundancias por género (n° de registros por género)", "# 2) Count records per species to build the abundance vector"),
        ("#    - quedarnos con géneros con n > 0", "#    - Keep species with abundance > 0"),
        ("# 3) Casos sin información suficiente", "# 3) Handle cases with insufficient data"),
        ("# 4) iNEXT con abundancias (curva en función de # de registros)", "# 4) Run iNEXT using abundance data (species accumulation based on records)"),
        ("#      coverage_based: SC y qD al extremo (última fila)", "#      Extract asymptotic sample coverage and estimated richness"),
        ("#      size_based: n (m) al extremo (última fila)", "#      Extract sample size at the asymptotic end"),
    ],

    # ===== 2_Alpha_diversity.ipynb =====
    "2_Alpha_diversity.ipynb": [
        ("# 1. Efecto parcial de elev_mean", "# 1. Partial effect of elev_mean"),
        ('ggtitle("Efecto parcial de elev_mean")', 'ggtitle("Partial effect of elev_mean")'),
        ("# 2. Efecto parcial de centroid_x", "# 2. Partial effect of centroid_x"),
        ('ggtitle("Efecto parcial de centroid_x")', 'ggtitle("Partial effect of centroid_x")'),
        ("# 3. Efecto parcial de centroid_y", "# 3. Partial effect of centroid_y"),
        ('ggtitle("Efecto parcial de centroid_y")', 'ggtitle("Partial effect of centroid_y")'),
        ('labs(x = "Elevación", y = "Richness (predicted)")', 'labs(x = "Elevation", y = "Richness (predicted)")'),
        ('labs(x = "Coordenada X", y = "Richness (predicted)")', 'labs(x = "X Coordinate", y = "Richness (predicted)")'),
        ('labs(x = "Coordenada Y", y = "Richness (predicted)")', 'labs(x = "Y Coordinate", y = "Richness (predicted)")'),
        ("# 4. Figura final combinada", "# 4. Combined final figure"),
        # Prediction section
        ("# 1. Cargar límite de Ecuador y DEM en WGS84", "# 1. Load Ecuador limits and DEM in WGS84"),
        ("# 2. Crear raster vacío de 10 km cubriendo todo Ecuador", "# 2. Create a blank 10 km raster covering all of Ecuador"),
        ("# resolución equivalente a 10 km en grados", "# Resolution equivalent to 10 km in degrees"),
        ("# 3. Extraer coordenadas de cada celda", "# 3. Extract coordinates of each cell"),
        ("# 4. Extraer elevación desde DEM", "# 4. Extract elevation from DEM"),
        ("# eliminar NA", "# Remove NA values"),
        ("# 5. Predecir GAM riqueza en TODA LA ZONA", "# 5. Predict GAM richness across the entire study area"),
        ("# identidad → predicción = η", "# Identity link -> prediction = linear predictor"),
        ("# 6. Insertar predicciones en raster", "# 6. Insert predictions into the raster"),
        ("# 7. Máscara para limitar SOLO Ecuador", "# 7. Mask: Restrict predictions to Ecuador limits"),
        # GAM model comments
        ("# efecto no lineal de elevación", "# Non-linear elevation effect"),
        ("# suavizador espacial 2D", "# 2D spatial smoother"),
        ('labs(x = "Elevación", y = "Richness (predicho)")', 'labs(x = "Elevation", y = "Richness (predicted)")'),
        ('labs(x = "Coordenada X", y = "Richness (predicho)")', 'labs(x = "X Coordinate", y = "Richness (predicted)")'),
        ('labs(x = "Coordenada Y", y = "Richness (predicho)")', 'labs(x = "Y Coordinate", y = "Richness (predicted)")'),
        ("El modelo GAM con distribución Negativa Binomial detecta una relación significativa entre la riqueza de especies y los predictores evaluados. La elevación muestra un efecto no lineal moderado pero estadísticamente significativo (edf ≈ 3.0, p = 0.00031), mientras que el efecto espacial representado por las coordenadas del centróide presenta una contribución más compleja y altamente significativa (edf ≈ 14.6, p < 2e-16), indicando variación espacial estructurada en la riqueza. El intercepto es alto, coherente con un promedio elevado de especies por celda. El modelo explica un 36.8% de la desviancia y presenta un R² ajustado modesto (0.165), lo que sugiere que, aunque capta patrones importantes, aún existe variabilidad no explicada que podría estar asociada a otros factores ambientales o de muestreo.",
         "The GAM model with Negative Binomial distribution detects a significant relationship between species richness and the evaluated predictors. Elevation shows a moderate but statistically significant non-linear effect (edf ≈ 3.0, p = 0.00031), while the spatial effect represented by the centroid coordinates presents a more complex and highly significant contribution (edf ≈ 14.6, p < 2e-16), indicating structured spatial variation in richness. The intercept is high, consistent with a high average number of species per cell. The model explains 36.8% of the deviance and has a modest adjusted R² (0.165), suggesting that although it captures important patterns, there is still unexplained variability that could be associated with other environmental or sampling factors."),
        ("La concurvidad evalúa cuánta dependencia existe entre los efectos suaves del modelo. Valores altos indican que un término puede ser parcialmente explicado por otro, reduciendo la capacidad del modelo para estimar efectos independientes. En tus resultados, el término espacial s(centroid_x, centroid_y) muestra una concurvidad observada baja (≈ 0.247) y una concurvidad estimada aún menor (≈ 0.149), lo que indica independencia razonable respecto del resto del modelo. El suave de elevación presenta una concurvidad observada moderada (≈ 0.499), lejos de niveles problemáticos. En conjunto, no hay señales de solapamiento severo entre los predictores, y los efectos se estiman de manera estable.",
         "Concurvity assesses how much dependency exists between the smooth effects in the model. High values indicate that a term can be partially explained by another, reducing the model's ability to estimate independent effects. In your results, the spatial term s(centroid_x, centroid_y) shows low observed concurvity (≈ 0.247) and even lower estimated concurvity (≈ 0.149), indicating reasonable independence from the rest of the model. The elevation smoother presents moderate observed concurvity (≈ 0.499), far from problematic levels. Overall, there are no signs of severe overlap between the predictors, and the effects are stably estimated."),
        ("El efecto de la elevación muestra una relación unimodal, con mayor riqueza en elevaciones intermedias y disminución hacia los extremos. La coordenada X presenta un gradiente espacial marcado, con un pico localizado que sugiere variación geográfica fuerte en sentido longitudinal. La coordenada Y evidencia también un patrón no lineal, indicando zonas específicas con mayor riqueza en el eje latitudinal. En conjunto, los efectos espaciales capturan heterogeneidad geográfica sustancial más allá del efecto de la elevación.",
         "The effect of elevation shows a unimodal relationship, with greater richness at intermediate elevations and a decrease towards the extremes. The X coordinate presents a marked spatial gradient, with a localized peak suggesting strong longitudinal geographic variation. The Y coordinate also shows a non-linear pattern, indicating specific areas with greater richness on the latitudinal axis. Overall, spatial effects capture substantial geographic heterogeneity beyond the effect of elevation."),
        ("# 7. Máscara: limitar SOLO a Ecuador", "# 7. Mask: Restrict predictions to Ecuador limits"),
        ("### datos", "### Data"),
        ("# Calcular concurvidad", "# Calculate concurvity"),
        ("El test de Moran I aplicado a los residuos indica ausencia de autocorrelación espacial. El valor observado de Moran I es muy cercano a cero (–0.0269), su desviación tipificada es baja (–0.57) y el p-value alto (0.716) confirma que la estructura espacial de los residuos no difiere de lo esperado bajo aleatoriedad. La expectativa teórica del índice (–0.0046) es prácticamente igual al valor observado, lo que refuerza que el modelo no deja patrones espaciales sistemáticos sin capturar.",
         "Moran's I test applied to the residuals indicates an absence of spatial autocorrelation. The observed Moran's I value is very close to zero (-0.0269), its standard deviate is low (-0.57), and the high p-value (0.716) confirms that the spatial structure of the residuals does not differ from what is expected under randomness. The theoretical expectation of the index (-0.0046) is virtually identical to the observed value, reinforcing that the model does not leave systematic spatial patterns uncaptured."),
    ],

    # ===== 3_Beta_diversity.ipynb =====
    "3_Beta_diversity.ipynb": [
        # Library comments
        ("# Para clustering y cálculo del índice de silhouette", "# For clustering and silhouette index calculation"),
        ("# Para el método del codo y silhouette", "# For elbow method and silhouette"),
        # Data extraction
        ("# Asegurar CRS igual", "# Ensure matching CRS"),
        ("# Extraer valores por celda del grid", "# Extract elevation values per grid cell"),
        ("# Calcular estadísticos por id", "# Calculate statistics per grid ID"),
        ("# Extraer coordenadas como columnas X y Y", "# Extract coordinates as X and Y columns"),
        # Spatial join
        ("# Solo puntos dentro", "# Keep only points within cells"),
        ("# Extraer coordenadas a columnas X, Y", "# Extract coordinates to X, Y columns"),
        ("# Remover geometría si se quiere tabla pura", "# Drop spatial geometry for tabular format"),
        ("# Resultado final", "# Final result"),
        # Beta diversity
        ("### TABLA PARA ANALISIS BETA -D", "### Table for Beta Diversity analysis"),
        ("##### calculo de la beta diversidad", "##### Beta diversity calculation"),
        ("## realiza los analisis de beta diversidad", "## Perform beta diversity analysis"),
        ("## con el indice de jaccard ( presencia/ausencia), con particiones", "## using Jaccard index (presence/absence) with partitioning"),
        ("# se explicar un R = 91 total con dos ejes", "# An R^2 of 91% is explained using two axes"),
        # GAM comments for NMDS1
        ("# efecto no lineal de elevación", "# Non-linear elevation effect"),
        ("# suavizador espacial 2D", "# 2D spatial smoother"),
        # Partial effects - NMDS1 and NMDS2
        ("# 1. Efecto parcial de elev_mean", "# 1. Partial effect of elev_mean"),
        ('ggtitle("Efecto parcial de elev_mean")', 'ggtitle("Partial effect of elev_mean")'),
        ("# 2. Efecto parcial de centroid_x", "# 2. Partial effect of centroid_x"),
        ('ggtitle("Efecto parcial de centroid_x")', 'ggtitle("Partial effect of centroid_x")'),
        ("# 3. Efecto parcial de centroid_y", "# 3. Partial effect of centroid_y"),
        ('ggtitle("Efecto parcial de centroid_y")', 'ggtitle("Partial effect of centroid_y")'),
        ("# 4. Figura final combinada", "# 4. Combined final figure"),
        # Axis labels
        ('labs(x = "Elevación", y = "NMDS1 (predicho)")', 'labs(x = "Elevation", y = "NMDS1 (predicted)")'),
        ('labs(x = "Coordenada X", y = "NMDS1 (predicho)")', 'labs(x = "X Coordinate", y = "NMDS1 (predicted)")'),
        ('labs(x = "Coordenada Y", y = "NMDS1 (predicho)")', 'labs(x = "Y Coordinate", y = "NMDS1 (predicted)")'),
        ('labs(x = "Elevación", y = "NMDS2 (predicho)")', 'labs(x = "Elevation", y = "NMDS2 (predicted)")'),
        ('labs(x = "Coordenada X", y = "NMDS2 (predicho)")', 'labs(x = "X Coordinate", y = "NMDS2 (predicted)")'),
        ('labs(x = "Coordenada Y", y = "NMDS2 (predicho)")', 'labs(x = "Y Coordinate", y = "NMDS2 (predicted)")'),
        # Prediction sections
        ("# 1. Cargar límite de Ecuador y DEM en WGS84", "# 1. Load Ecuador limits and DEM in WGS84"),
        ("# 2. Crear raster vacío de 10 km cubriendo todo Ecuador", "# 2. Create a blank 10 km raster covering all of Ecuador"),
        ("# resolución equivalente a 10 km en grados", "# Resolution equivalent to 10 km in degrees"),
        ("# 3. Extraer coordenadas de cada celda", "# 3. Extract coordinates of each cell"),
        ("# 4. Extraer elevación desde DEM", "# 4. Extract elevation from DEM"),
        ("# eliminar NA", "# Remove NA values"),
        ("# 5. Predecir GAM NMDS1 en TODA LA ZONA", "# 5. Predict GAM NMDS1 across the entire study area"),
        ("# 5. Predecir GAM NMDS2 en TODA LA ZONA", "# 5. Predict GAM NMDS2 across the entire study area"),
        ("# identidad → predicción = η", "# Identity link -> prediction = linear predictor"),
        ("# 6. Insertar predicciones en raster", "# 6. Insert predictions into the raster"),
        ("# 7. Máscara para limitar SOLO Ecuador", "# 7. Mask: Restrict predictions to Ecuador limits"),
        # Markdown text
        ("El modelo GAM ajustado para NMDS1 mostró un ajuste sólido y estadísticamente consistente, con un R² ajustado de 0.74 y una deviance explicada cercana al 77%, indicando que la elevación y la estructura espacial explican gran parte del gradiente ecológico representado por este eje. Ambos suavizadores fueron altamente significativos y sin señales de colinealidad, y los chequeos de bases confirmaron que la complejidad elegida fue suficiente sin sobreajuste. Los diagnósticos mostraron residuos aproximadamente normales, sin heterocedasticidad y sin patrones no capturados, mientras que el test de Moran evidenció ausencia de autocorrelación espacial residual. En conjunto, los supuestos del modelo se cumplen y los efectos estimados pueden interpretarse de manera confiable.",
         "The GAM model fitted for NMDS1 showed a robust and statistically consistent fit, with an adjusted R² of 0.74 and explained deviance near 77%, indicating that elevation and spatial structure explain a large portion of the ecological gradient represented by this axis. Both smoothers were highly significant with no signs of collinearity, and basis dimension checks confirmed that the chosen complexity was sufficient without overfitting. Diagnostics showed approximately normal residuals with no heteroscedasticity or uncaptured patterns, while Moran's I test indicated an absence of residual spatial autocorrelation. Overall, the model assumptions are met, and the estimated effects can be reliably interpreted."),
        ("El modelo GAM ajustado para NMDS2 mostró un rendimiento modesto, con un R² ajustado de 0.45 y una deviance explicada del 51.7%, indicando que la elevación y la estructura espacial capturan aproximadamente la mitad de la variabilidad del segundo eje de composición. Los suavizadores fueron significativos, pero los diagnósticos revelaron residuos con desviaciones menores de la normalidad y cierta asimetría, lo que sugiere que parte de la variación no fue capturada por las variables incluidas. La autocorrelación espacial residual fue baja, aunque no completamente ausente. En conjunto, el modelo NMDS2 ofrece una aproximación razonable pero menos confiable que el de NMDS1, y sus efectos estimados deben interpretarse con mayor cautela.",
         "The GAM model fitted for NMDS2 showed a modest performance, with an adjusted R² of 0.45 and explained deviance of 51.7%, indicating that elevation and spatial structure capture approximately half of the variability of the second composition axis. The smoothers were significant, but diagnostics revealed residuals with minor deviations from normality and some asymmetry, suggesting that part of the variation was not captured by the included variables. Residual spatial autocorrelation was low, though not completely absent. Overall, the NMDS2 model provides a reasonable but less reliable approximation than the NMDS1 model, and its estimated effects should be interpreted with greater caution."),
        ("With NMDS we caught the 0.917 variance of the disimilarities",
         "With NMDS, we captured 91.7% of the variance in the dissimilarity matrix."),
        ("Recorcos inside high sampling coverage grids",
         "Records inside high-sampling-coverage grid cells"),
        (" Generate table", "Generate presence/absence table."),
    ],

    # ===== 4_Endemism.ipynb =====
    "4_Endemism.ipynb": [
        ("# Kernel Gaussiano truncado (dist en m)", "# Truncated Gaussian kernel (dist in meters)"),
        ("# sigma como fracción de Rc (suavidad)", "# sigma as a fraction of Rc (smoothness)"),
        ("# 2) Cargar datos y raster", "# 2) Load data and raster"),
        ("# Ajusta nombres si difieren", "# Adjust column names if they differ"),
        ("# 3) Definir CRS métrico (UTM) y reproyectar raster plantilla", "# 3) Define metric CRS (UTM) and reproject template raster"),
        ("# Centro del raster en lon/lat (si el raster no tiene lon/lat, usamos su centro igualmente)", "# Center of the raster in lon/lat (if raster is not in lon/lat, we use its center anyway)"),
        ("# Si raster está en lon/lat, lon0/lat0 están en grados y esto funciona bien.", "# If raster is in lon/lat, lon0/lat0 are in degrees and this works fine."),
        ("# Si no, aún así solo se usa para estimar UTM; en ese caso es mejor definir EPSG manual.", "# Otherwise, it is only used to estimate UTM; in that case, it is better to define EPSG manually."),
        ("# Reproyectar raster a UTM si está en lon/lat; si no, igual forzamos plantilla en UTM para coherencia", "# Reproject raster to UTM if in lon/lat; otherwise, force template to UTM for consistency"),
        ("# Define resolución objetivo en metros (ajusta a tu escala)", "# Define target resolution in meters (adjust to your scale)"),
        ("# 4) Pasar ocurrencias a UTM (SpatVector)", "# 4) Convert occurrences to UTM (SpatVector)"),
        ("# 5) Filtrar especies con mínimo 3 registros", "# 5) Filter species with a minimum of 3 records"),
        ("# 6) Centroide y di por especie", "# 6) Centroid and di per species"),
        ("# di_m (máxima distancia al centroide), en metros", "# di_m (maximum distance to centroid), in meters"),
        ("# 7) Categorías de rango (como el paper; ajustable)", "# 7) Range categories (as in the paper; adjustable)"),
        ("# Rc por categoría = max(di) de la categoría (m)", "# Rc per category = max(di) of the category (m)"),
        ("# Guardar tabla de control", "# Save control table"),
        ("# 8) Kernel por categoría + consenso", "# 8) Kernel per category + consensus"),
        ("# Centroides a vector", "# Centroids to vector"),
        ('message("Procesando categoría: ", ct)', 'message("Processing category: ", ct)'),
        ("# radios por categoría", "# Radii per category"),
        ("# centroides de la categoría", "# Centroids of the category"),
        ("# Suma de kernels por centroide", "# Sum of kernels per centroid"),
        ('stop("No se generó ningún k por categoría. Revisa filtros y CRS.")', 'stop("No k generated for any category. Check filters and CRS.")'),
        ("# Consenso: estandariza 0–1 por categoría y suma (paper)", "# Consensus: standardize 0-1 per category and sum (as in paper)"),
        ("# 9) Volver a la geometría EXACTA del raster de referencia (misma res/ext/origen/CRS)", "# 9) Return to the EXACT geometry of the reference raster (same res/ext/origin/CRS)"),
        ("# Opción recomendada: project usando plantilla (y) => copia geometría de raster_ref_ll", "# Recommended option: project using template (y) => copies geometry from raster_ref_ll"),
        ("# Asegurar que quede exactamente alineado (por si hubiera micro-diferencias)", "# Ensure exact alignment (in case of micro-differences)"),
        ("# Forzar extensión exacta (seguro adicional)", "# Force exact extent (additional safety measure)"),
        ("# Normalización min-max a [0, 1] (ignorando NA)", "# Min-max normalization to [0, 1] (ignoring NAs)"),
        ("# (opcional) asegurar límites numéricos por redondeos", "# (optional) ensure numerical limits against rounding errors"),
    ],

    # ===== 5_Conservation_areas.ipynb =====
    "5_Conservation_areas.ipynb": [
        ("# 1) Cargar rasters (template = primer raster)", "# 1) Load rasters (template = first raster)"),
        ("# 2) Igualar CRS / resolución / extensión al template", "# 2) Match CRS / resolution / extent to the template"),
        ("# (a) Ajustar a CRS del template (si hace falta)", "# (a) Match template CRS (if needed)"),
        ("# (b) Ajustar extensión y resolución: resample al grid del template", "# (b) Adjust extent and resolution: resample to template grid"),
        ("# (opcional) recortar/maskar al extent exacto del template", "# (optional) crop/mask to the exact extent of the template"),
        ("# 3) Leer puntos y construir \"mapa de calor\" (densidad por celda)", "# 3) Read points and build heat map (density per cell)"),
        ("# Densidad Kernel con bandwidth óptimo para CRS 4326", "# Kernel Density with optimal bandwidth for CRS 4326"),
        ("# Método: Diggle (Likelihood Cross-Validation)", "# Method: Diggle (Likelihood Cross-Validation)"),
        ("# Crear ventana desde la extensión del raster", "# Create window from raster extent"),
        ("Número de puntos:", "Number of points:"),
        ("Extensión X:", "X range:"),
        ("Extensión Y:", "Y range:"),
        ("# Aplicar máscara de Ecuador", "# Apply Ecuador mask"),
        ("# Visualización", "# Visualization"),
        ("✓ Análisis completado exitosamente", "✓ Analysis completed successfully"),
        ("Características del análisis:", "Analysis characteristics:"),
        ("Cada clúster analizado independientemente (escala 0-1 interna)", "Each cluster analyzed independently (internal 0-1 scale)"),
        ("Clasificación Likert 1-5 aplicada", "Likert 1-5 classification applied"),
        ("# 0) Configuración de salida", "# 0) Output configuration"),
        ("# 2) Bucle por clúster: recorte, escalado, exportación", "# 2) Loop per cluster: cropping, scaling, export"),
        ("# 2.1) Máscara del clúster i (1 dentro; NA fuera)", "# 2.1) Mask of cluster i (1 inside; NA outside)"),
        ("# 2.2) Alpha (riqueza) recortada y escalada 0–1 dentro del clúster", "# 2.2) Alpha (richness) cropped and scaled 0-1 within the cluster"),
        ("# Obtener rango del clúster para invertir correctamente", "# Get cluster range to invert correctly"),
        ("# AHORA sí escalar 0-1 el raster invertido", "# NOW scale the inverted raster 0-1"),
        ("# 2.4) Promedio final por clúster (ambos ya en escala 0-1)", "# 2.4) Final average per cluster (both already in 0-1 scale)"),
        ("# 3) Unir promedios de clústeres en un solo raster", "# 3) Merge cluster averages into a single raster"),
        ("# Cada clúster ya está en 0–1, aplicar Likert directamente", "# Each cluster is already in 0-1, apply Likert directly"),
        ("✓ Análisis de endemismo completado exitosamente", "✓ Endemism analysis completed successfully"),
        ("# 0) Configuración de salida (ENDEMISMO)", "# 0) Output configuration (ENDEMISM)"),
        ("# 2) Bucle por clúster: recorte (endemismo), escalado, exportación", "# 2) Loop per cluster: cropping (endemism), scaling, export"),
        ("# 2.2) Endemismo recortado y escalado 0–1 dentro del clúster", "# 2.2) Endemism cropped and scaled 0-1 within the cluster"),
        ("# 2.4) Promedio final por clúster (endemismo + densidad invertida)", "# 2.4) Final average per cluster (endemism + inverted density)"),
        ("✓ Análisis combinado completado exitosamente", "✓ Combined analysis completed successfully"),
        ("# 0) Configuración de salida (COMBINADO)", "# 0) Output configuration (COMBINED)"),
        ("# 2) Bucle por clúster: recorte (combinado), escalado, exportación", "# 2) Loop per cluster: cropping (combined), scaling, export"),
        ("# 2.2) Alpha recortado y escalado 0–1 dentro del clúster", "# 2.2) Alpha cropped and scaled 0-1 within the cluster"),
        ("# 2.3) Endemismo recortado y escalado 0–1 dentro del clúster", "# 2.3) Endemism cropped and scaled 0-1 within the cluster"),
        ("# 2.5) Promedio final por clúster (ambos ya en escala 0-1 + densidad invertida)", "# 2.5) Final average per cluster (both in 0-1 scale + inverted density)"),
    ],

    # ===== 6_Report.ipynb =====
    "6_Report.ipynb": [
        ("# 3) Asegurar CRS = 4326 y geometrías válidas", "# 3) Ensure CRS = 4326 and valid geometries"),
        ("#    - Polígonos: recortar a Ecuador", "# - Polygons: crop to Ecuador"),
        ("# Etiqueta final: retenido y disminución acumulada vs inicial", "# Final label: retained and cumulative decrease vs initial"),
        ("# Especies únicas: top 8 + Otro", "# Unique species: top 8 + Other"),
        ("# Estilo (idéntico a los gráficos anteriores)", "# Style (identical to previous plots)"),
        ("# Especies únicas por base de datos", "# Unique species per database"),
        ("# Barra: n_species = especies únicas dentro del grupo (igual que antes)", "# Bar: n_species = unique species within the group (same as before)"),
        ("# d) Especies únicas por database_name", "# d) Unique species by database_name"),
        ("#    Barra: n_species (especies únicas dentro del grupo)", "# Bar: n_species (unique species within the group)"),
        ("# b) Top 5 instituciones por especies únicas", "# b) Top 5 institutions by unique species"),
        ("# Join por intersección (dentro)", "# Join by intersection (within)"),
        ("# Identificar columnas \"de región\" (todas las de natural_regions excepto geometry)", "# Identify \"region\" columns (all from natural_regions except geometry)"),
        ("# Para los que quedaron sin región (NA en la primera col de región), asignar el más cercano", "# For those left without region (NA in the first region column), assign the nearest"),
        ("# Extraer atributos del polígono más cercano", "# Extract attributes of the nearest polygon"),
        ("# Distancia al polígono más cercano (en metros aprox con S2 apagado; es una aproximación en 4326)", "# Distance to nearest polygon (in meters approx with S2 off; approximation in 4326)"),
        ("# Si necesitas distancia geodésica exacta, deja sf_use_s2(TRUE) y recalcula.", "# If you need exact geodesic distance, leave sf_use_s2(TRUE) and recalculate."),
        ("# 1) REGISTROS por tipo de vegetación", "# 1) RECORDS by vegetation type"),
        ("# 2) ESPECIES por tipo de vegetación", "# 2) SPECIES by vegetation type"),
        ("#    Barra: n_species = especies únicas dentro de cada veget", "# Bar: n_species = unique species within each vegetation type"),
        ("# a) Registros por vegetación", "# a) Records by vegetation"),
        ("# b) Especies únicas por vegetación", "# b) Unique species by vegetation"),
        ("# 1) REGISTROS por condición SNAP", "# 1) RECORDS by SNAP condition"),
        ("# 2) ESPECIES por condición SNAP", "# 2) SPECIES by SNAP condition"),
        ("#    Barra: n_species = especies únicas dentro de cada grupo", "# Bar: n_species = unique species within each group"),
        ("# b) Especies únicas dentro / fuera de SNAP", "# b) Unique species inside / outside SNAP"),
        ("# 1) Preparación de datos", "# 1) Data preparation"),
        ("#    (mismo FIX de título + leyenda interna)", "# (same FIX for title + internal legend)"),
        ("legend.key.size = unit(0.3, \"cm\"),        # Reduce el tamaño de las keys", "legend.key.size = unit(0.3, \"cm\"),        # Reduce key size"),
        ("legend.title = element_text(size = 7),     # Tamaño del título", "legend.title = element_text(size = 7),     # Title size"),
        ("legend.text = element_text(size = 6),      # Tamaño del texto", "legend.text = element_text(size = 6),      # Text size"),
        ("legend.margin = margin(t = 0, r = 0, b = 0, l = 0),  # Reduce márgenes", "legend.margin = margin(t = 0, r = 0, b = 0, l = 0),  # Reduce margins"),
        ("# Convertir los valores de \"valor\" a numéricos para poder usar un gradiente continuo", "# Convert value column to numeric to use a continuous gradient"),
        ("# Añadir la capa de datos clasificada con gradiente continuo", "# Add the classified data layer with a continuous gradient"),
        ("# Likert discreto (1–5) con orden explícito", "# Discrete Likert (1-5) with explicit ordering"),
        ("# SOLUCIÓN: Guardar los límites originales ANTES de agregar dummies", "# SOLUTION: Save original limits BEFORE adding dummies"),
        ("coord_sf(xlim = lon_limits, ylim = lat_limits, expand = FALSE) +  # Forzar límites originales", "coord_sf(xlim = lon_limits, ylim = lat_limits, expand = FALSE) +  # Force original limits"),
        ("# Convertir los valores de \"valor\" a numéricos", "# Convert values in \"valor\" to numeric"),
        ("# Luego la capa de polígonos (sin aes)", "# Then the polygon layer (without aes)"),
        ("# Anotación (a)", "# Annotation (a)"),
    ],
}

def process_notebook(filename, replacements):
    filepath = os.path.join(BASE, filename)
    if not os.path.exists(filepath):
        print(f"  WARNING: {filepath} not found, skipping.")
        return

    with open(filepath, "r", encoding="utf-8") as f:
        nb = json.load(f)

    count = 0
    for cell in nb.get("cells", []):
        source = cell.get("source", [])
        new_source = []
        for line in source:
            for old, new in replacements:
                if old in line:
                    line = line.replace(old, new)
                    count += 1
            new_source.append(line)
        cell["source"] = new_source

    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(nb, f, indent=1, ensure_ascii=False)
        f.write("\n")

    print(f"  {filename}: {count} replacements made.")

def main():
    print("Translating remaining Spanish text to English in notebooks...")
    for filename, replacements in REPLACEMENTS.items():
        print(f"\nProcessing {filename}...")
        process_notebook(filename, replacements)
    print("\nDone!")

if __name__ == "__main__":
    main()
