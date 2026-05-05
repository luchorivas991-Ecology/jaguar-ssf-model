"""
Model exported as python.
Name : model_points
Group : 
With QGIS : 34010
"""

from qgis.core import QgsProcessing
from qgis.core import QgsProcessingAlgorithm
from qgis.core import QgsProcessingMultiStepFeedback
from qgis.core import QgsProcessingParameterVectorLayer
from qgis.core import QgsProcessingParameterRasterLayer
from qgis.core import QgsProcessingParameterFeatureSink
from qgis.core import QgsCoordinateReferenceSystem
import processing


class Model_points(QgsProcessingAlgorithm):

    def initAlgorithm(self, config=None):
        self.addParameter(QgsProcessingParameterVectorLayer('jaguar_points', 'Jaguar points', types=[QgsProcessing.TypeVectorPoint], defaultValue=None))
        self.addParameter(QgsProcessingParameterRasterLayer('ndvi', 'NDVI', defaultValue=None))
        self.addParameter(QgsProcessingParameterRasterLayer('temperature', 'Temperature', defaultValue=None))
        self.addParameter(QgsProcessingParameterFeatureSink('Points_env_model', 'points_env_model', type=QgsProcessing.TypeVectorPoint, createByDefault=True, defaultValue='TEMPORARY_OUTPUT'))

    def processAlgorithm(self, parameters, context, model_feedback):
        # Use a multi-step feedback, so that individual child algorithm progress reports are adjusted for the
        # overall progress through the model
        feedback = QgsProcessingMultiStepFeedback(7, model_feedback)
        results = {}
        outputs = {}

        # Reproject layer
        alg_params = {
            'CONVERT_CURVED_GEOMETRIES': False,
            'INPUT': parameters['jaguar_points'],
            'OPERATION': None,
            'TARGET_CRS': QgsCoordinateReferenceSystem('EPSG:4326'),
            'OUTPUT': QgsProcessing.TEMPORARY_OUTPUT
        }
        outputs['ReprojectLayer'] = processing.run('native:reprojectlayer', alg_params, context=context, feedback=feedback, is_child_algorithm=True)

        feedback.setCurrentStep(1)
        if feedback.isCanceled():
            return {}

        # Minimum bounding geometry
        alg_params = {
            'FIELD': None,
            'INPUT': outputs['ReprojectLayer']['OUTPUT'],
            'TYPE': 3,  # Convex Hull
            'OUTPUT': QgsProcessing.TEMPORARY_OUTPUT
        }
        outputs['MinimumBoundingGeometry'] = processing.run('qgis:minimumboundinggeometry', alg_params, context=context, feedback=feedback, is_child_algorithm=True)

        feedback.setCurrentStep(2)
        if feedback.isCanceled():
            return {}

        # Buffer
        alg_params = {
            'DISSOLVE': True,
            'DISTANCE': 0.02,
            'END_CAP_STYLE': 0,  # Round
            'INPUT': outputs['MinimumBoundingGeometry']['OUTPUT'],
            'JOIN_STYLE': 0,  # Round
            'MITER_LIMIT': 2,
            'SEGMENTS': 5,
            'SEPARATE_DISJOINT': False,
            'OUTPUT': QgsProcessing.TEMPORARY_OUTPUT
        }
        outputs['Buffer'] = processing.run('native:buffer', alg_params, context=context, feedback=feedback, is_child_algorithm=True)

        feedback.setCurrentStep(3)
        if feedback.isCanceled():
            return {}

        # Temperature clipped
        alg_params = {
            'ALPHA_BAND': False,
            'CROP_TO_CUTLINE': True,
            'DATA_TYPE': 0,  # Use Input Layer Data Type
            'EXTRA': None,
            'INPUT': parameters['temperature'],
            'KEEP_RESOLUTION': True,
            'MASK': outputs['Buffer']['OUTPUT'],
            'MULTITHREADING': False,
            'NODATA': None,
            'OPTIONS': None,
            'SET_RESOLUTION': False,
            'SOURCE_CRS': QgsCoordinateReferenceSystem('EPSG:4326'),
            'TARGET_CRS': None,
            'TARGET_EXTENT': None,
            'X_RESOLUTION': None,
            'Y_RESOLUTION': None,
            'OUTPUT': QgsProcessing.TEMPORARY_OUTPUT
        }
        outputs['TemperatureClipped'] = processing.run('gdal:cliprasterbymasklayer', alg_params, context=context, feedback=feedback, is_child_algorithm=True)

        feedback.setCurrentStep(4)
        if feedback.isCanceled():
            return {}

        # NDVI clipped
        alg_params = {
            'ALPHA_BAND': False,
            'CROP_TO_CUTLINE': True,
            'DATA_TYPE': 0,  # Use Input Layer Data Type
            'EXTRA': None,
            'INPUT': parameters['ndvi'],
            'KEEP_RESOLUTION': True,
            'MASK': outputs['Buffer']['OUTPUT'],
            'MULTITHREADING': False,
            'NODATA': None,
            'OPTIONS': None,
            'SET_RESOLUTION': False,
            'SOURCE_CRS': QgsCoordinateReferenceSystem('EPSG:4326'),
            'TARGET_CRS': None,
            'TARGET_EXTENT': None,
            'X_RESOLUTION': None,
            'Y_RESOLUTION': None,
            'OUTPUT': QgsProcessing.TEMPORARY_OUTPUT
        }
        outputs['NdviClipped'] = processing.run('gdal:cliprasterbymasklayer', alg_params, context=context, feedback=feedback, is_child_algorithm=True)

        feedback.setCurrentStep(5)
        if feedback.isCanceled():
            return {}

        # Sample raster values NDVI
        alg_params = {
            'COLUMN_PREFIX': 'NDVI',
            'INPUT': outputs['ReprojectLayer']['OUTPUT'],
            'RASTERCOPY': outputs['NdviClipped']['OUTPUT'],
            'OUTPUT': QgsProcessing.TEMPORARY_OUTPUT
        }
        outputs['SampleRasterValuesNdvi'] = processing.run('native:rastersampling', alg_params, context=context, feedback=feedback, is_child_algorithm=True)

        feedback.setCurrentStep(6)
        if feedback.isCanceled():
            return {}

        # Sample raster values temp
        alg_params = {
            'COLUMN_PREFIX': 'temp',
            'INPUT': outputs['SampleRasterValuesNdvi']['OUTPUT'],
            'RASTERCOPY': outputs['TemperatureClipped']['OUTPUT'],
            'OUTPUT': parameters['Points_env_model']
        }
        outputs['SampleRasterValuesTemp'] = processing.run('native:rastersampling', alg_params, context=context, feedback=feedback, is_child_algorithm=True)
        results['Points_env_model'] = outputs['SampleRasterValuesTemp']['OUTPUT']
        return results

    def name(self):
        return 'model_points'

    def displayName(self):
        return 'model_points'

    def group(self):
        return ''

    def groupId(self):
        return ''

    def createInstance(self):
        return Model_points()
