# jaguar-ssf-model
What the model does 
How to run it 
What data is needed

This project models jaguar habitat use using a Step Selection Function (SSF).
It combines GPS tracking data with environmental variables (NDVI and temperature).

# Jaguar Habitat Use Modeling with QGIS and R

This project explores jaguar (*Panthera onca*) habitat use in the Brazilian Pantanal using GPS tracking data, environmental covariates, and Step Selection Functions (SSF).

The workflow combines:

- QGIS for spatial preprocessing and environmental covariate extraction
- R for movement data processing, SSF modeling, and spatial prediction
- Remote sensing layers such as NDVI and temperature

## Workflow

1. Clean and filter GPS tracking data
2. Generate observed and random movement steps
3. Extract environmental covariates using QGIS Model Designer
4. Fit a Step Selection Function in R
5. Generate a predicted relative habitat use surface
6. Visualize results in 2D and 3D

## Model

The SSF compares observed movement steps with randomly generated available steps using conditional logistic regression.

Main predictors:

- NDVI
- Temperature
- Step length
- Turning angle

## Key outputs

- Predicted relative habitat use map
- 3D habitat suitability visualization
- Reproducible QGIS + R workflow

## Tools

- QGIS
- R
- `amt`
- `survival`
- `terra`
- `sf`
- `dplyr`

## Data

GPS tracking data should be downloaded from Movebank according to dataset permissions. Environmental rasters were obtained from remote sensing products such as MODIS NDVI and TerraClimate.
