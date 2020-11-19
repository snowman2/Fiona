"""Extension module supporting crs.py.

Calls methods from GDAL's OSR module.
"""

from __future__ import absolute_import

import logging
import warnings

from six import string_types

from fiona cimport _cpl
from fiona._err cimport exc_wrap_pointer
from fiona._err import CPLE_BaseError
from fiona._shim cimport osr_get_name, osr_set_traditional_axis_mapping_strategy
from fiona.compat import DICT_TYPES
from fiona.errors import CRSError


logger = logging.getLogger(__name__)

cdef int OAMS_TRADITIONAL_GIS_ORDER = 0


cdef _osr_to_wkt(OGRSpatialReferenceH cogr_srs, crs, wkt_version):
    cdef char *wkt_c = NULL
    wkt = None
    IF (CTE_GDAL_MAJOR_VERSION, CTE_GDAL_MINOR_VERSION) >= (3, 0):
        cdef const char* options_wkt[2]
        wkt_format = "FORMAT={}".format(wkt_version or "WKT1_GDAL").encode("utf-8")
        options_wkt[0] = wkt_format
        options_wkt[1] = NULL
        OSRExportToWktEx(cogr_srs, &wkt_c, options_wkt)
        if wkt_c != NULL:
            wkt_b = wkt_c
            wkt = wkt_b.decode('utf-8')
        if not wkt and wkt_version is None:
            # attempt to morph to ESRI before export
            wkt_format = "FORMAT={}".format("WKT1_ESRI").encode("utf-8")
            options_wkt[0] = wkt_format
            OSRExportToWktEx(cogr_srs, &wkt_c, options_wkt)

    ELSE:
        if wkt_version is not None:
            warnings.warn("'wkt_version' is only supported with GDAL 3+")

        OSRExportToWkt(cogr_srs, &wkt_c)
        if wkt_c != NULL:
            wkt_b = wkt_c
            wkt = wkt_b.decode('utf-8')
        if not wkt:
            # attempt to morph to ESRI before export
            OSRMorphToESRI(cogr_srs)
            OSRExportToWkt(cogr_srs, &wkt_c)

    if wkt_c != NULL:
        wkt_b = wkt_c
        wkt = wkt_b.decode('utf-8')

    _cpl.CPLFree(wkt_c)

    if not wkt:
        raise CRSError("Invalid input to create CRS: {}".format(crs))
    return wkt

# Export a WKT string from input crs.
def crs_to_wkt(crs, wkt_version=None):
    """Convert a Fiona CRS object to WKT format"""
    cdef OGRSpatialReferenceH cogr_srs = NULL
    cdef char *proj_c = NULL

    try:
        cogr_srs = exc_wrap_pointer(OSRNewSpatialReference(NULL))
    except CPLE_BaseError as exc:
        raise CRSError(u"{}".format(exc))

    # check for other CRS classes
    if hasattr(crs, "to_wkt") and callable(crs.to_wkt):
        crs = crs.to_wkt()

    # First, check for CRS strings like "EPSG:3857".
    if isinstance(crs, string_types):
        proj_b = crs.encode('utf-8')
        proj_c = proj_b
        OSRSetFromUserInput(cogr_srs, proj_c)

    elif isinstance(crs, DICT_TYPES):
        # EPSG is a special case.
        init = crs.get('init')
        if init:
            logger.debug("Init: %s", init)
            auth, val = init.split(':')
            if auth.upper() == 'EPSG':
                logger.debug("Setting EPSG: %s", val)
                OSRImportFromEPSG(cogr_srs, int(val))
        else:
            params = []
            crs['wktext'] = True
            for k, v in crs.items():
                if v is True or (k in ('no_defs', 'wktext') and v):
                    params.append("+%s" % k)
                else:
                    params.append("+%s=%s" % (k, v))
            proj = " ".join(params)
            logger.debug("PROJ.4 to be imported: %r", proj)
            proj_b = proj.encode('utf-8')
            proj_c = proj_b
            OSRImportFromProj4(cogr_srs, proj_c)
    else:
        raise CRSError("Invalid input to create CRS: {}".format(crs))

    osr_set_traditional_axis_mapping_strategy(cogr_srs)
    return _osr_to_wkt(cogr_srs, crs, wkt_version)
