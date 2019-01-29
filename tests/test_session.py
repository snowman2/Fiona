"""Tests of the ogrext.Session class"""
import pytest

import fiona

from .conftest import requires_gdal2


def test_get(path_coutwildrnp_shp):
    with fiona.open(path_coutwildrnp_shp) as col:
        feat3 = col.get(2)
        assert feat3['properties']['NAME'] == 'Mount Zirkel Wilderness'


@pytest.mark.parametrize("layer, namespace, tags", [
    (None, None, {"test_tag1": "test_value1", "test_tag2": "test_value2"}),
    (None, "test", {"test_tag1": "test_value1", "test_tag2": "test_value2"}),
    (None, None, {}),
    (None, "test", {}),  
    ("layer", None, {"test_tag1": "test_value1", "test_tag2": "test_value2"}),
    ("layer", "test", {"test_tag1": "test_value1", "test_tag2": "test_value2"}),
    ("layer", None, {}),
    ("layer", "test", {}),  
])
@requires_gdal2
def test_set_tags(layer, namespace, tags, tmpdir):
    test_geopackage = str(tmpdir.join("test.gpkg"))
    schema = {'properties': {'CDATA1': 'str:254'}, 'geometry': 'Polygon'}
    with fiona.open(test_geopackage, "w", driver="GPKG", schema=schema, layer=layer) as gpkg:
        assert gpkg.tags() == {}
        gpkg.set_tags(tags, ns=namespace)

    with fiona.open(test_geopackage, layer=layer) as gpkg:
        assert gpkg.tags(ns=namespace) == tags
        if namespace is not None:
            assert gpkg.tags() == {}
        with pytest.raises(RuntimeError):
            gpkg.set_tags({}, ns=namespace)


@pytest.mark.parametrize("layer, namespace", [
    (None, None),
    (None, "test"),
    ("test", None),
    ("test", "test"),
])
@requires_gdal2
def test_set_tag_item(layer, namespace, tmpdir):
    test_geopackage = str(tmpdir.join("test.gpkg"))
    schema = {'properties': {'CDATA1': 'str:254'}, 'geometry': 'Polygon'}
    with fiona.open(test_geopackage, "w", driver="GPKG", schema=schema, layer=layer) as gpkg:
        assert gpkg.get_tag_item("test_tag1", ns=namespace) is None
        gpkg.set_tag_item("test_tag1", "test_value1", ns=namespace)

    with fiona.open(test_geopackage, layer=layer) as gpkg:
        if namespace is not None:
            assert gpkg.get_tag_item("test_tag1") is None
        assert gpkg.get_tag_item("test_tag1", ns=namespace) == "test_value1"
        with pytest.raises(RuntimeError):
            gpkg.set_tag_item("test_tag1", "test_value1", ns=namespace)
