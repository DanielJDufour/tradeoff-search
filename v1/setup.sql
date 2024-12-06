CREATE EXTENSION postgis SCHEMA public;
CREATE EXTENSION postgis_raster SCHEMA public;
CREATE EXTENSION h3 CASCADE;
CREATE EXTENSION h3_postgis CASCADE;

--- debug
SELECT * FROM pg_namespace;

-- SELECT format('%I.%I(%s)', ns.nspname, p.proname, oidvectortypes(p.proargtypes)) 
-- FROM pg_proc p INNER JOIN pg_namespace ns ON (p.pronamespace = ns.oid)
-- WHERE ns.nspname = 'public';

SELECT current_user;

SELECT * FROM pg_authid;

SHOW search_path;

CREATE MATERIALIZED VIEW cell_data AS 
  SELECT
    sketches.id AS sketch_id,
    poly_area,
    cells0,
    cells3,
    cells5,
    cells7,
    cells9
  FROM sketches
  LEFT JOIN LATERAL ST_Dump(geom) AS polys ON true
  LEFT JOIN LATERAL ST_Area(polys.geom) AS poly_area ON true
  LEFT JOIN LATERAL h3_polygon_to_cells(polys.geom, 9) AS cells9 ON true
  LEFT JOIN LATERAL h3_cell_to_parent(cells9, 7) AS cells7 ON true
  LEFT JOIN LATERAL h3_cell_to_parent(cells7, 5) AS cells5 ON true
  LEFT JOIN LATERAL h3_cell_to_parent(cells5, 3) AS cells3 ON true
  LEFT JOIN LATERAL h3_cell_to_parent(cells3, 0) AS cells0 ON true;

CREATE MATERIALIZED VIEW cells AS 
(SELECT sketch_id, 0 AS res, cells0 AS cell_id, MAX(1 / poly_area) AS cell_weight FROM cell_data GROUP BY sketch_id, cells0 ORDER BY sketch_id)
UNION
(SELECT sketch_id, 3 AS res, cells3 AS cell_id, MAX(1 / poly_area) AS cell_weight FROM cell_data GROUP BY sketch_id, cells3 ORDER BY sketch_id)
UNION
(SELECT sketch_id, 5 AS res, cells5 AS cell_id, MAX(1 / poly_area) AS cell_weight FROM cell_data GROUP BY sketch_id, cells5 ORDER BY sketch_id)
UNION
(SELECT sketch_id, 7 AS res, cells7 AS cell_id, MAX(1 / poly_area) AS cell_weight FROM cell_data GROUP BY sketch_id, cells7 ORDER BY sketch_id);
UNION
(SELECT sketch_id, 9 AS res, cells9 AS cell_id, MAX(1 / poly_area) AS cell_weight FROM cell_data GROUP BY sketch_id, cells9 ORDER BY sketch_id);

SELECT * FROM cells LIMIT 5;

CREATE VIEW sketch_weights AS SELECT sketch_id, res, SUM(cell_weight) AS wt FROM cells GROUP BY sketch_id, res;

SELECT * FROM sketch_weights LIMIT 5;

CREATE MATERIALIZED VIEW all_cells AS 
SELECT
  c.sketch_id,
  c.res,
  c.cell_id,
  c.cell_weight / sketch_weights.wt AS cell_weight
FROM cells c
LEFT JOIN sketch_weights ON c.res = sketch_weights.res AND c.sketch_id = sketch_weights.sketch_id;

CREATE INDEX idx_all_cells_sketch_id ON all_cells (sketch_id);
CREATE INDEX idx_all_cells_sketch_res ON all_cells (res);
CREATE INDEX idx_all_cells_cell_id ON all_cells (cell_id);
CREATE INDEX idx_all_cells_cell_weight ON all_cells (cell_weight);

SELECT * FROM all_cells LIMIT 5;

CREATE MATERIALIZED VIEW sketch_geometry_hashes AS 
  SELECT
    id AS sketch_id,
    poly_hash,
    num_geometries,
    1 / num_geometries::float AS wt
  FROM sketches
  LEFT JOIN LATERAL ST_NumGeometries(geom) AS num_geometries ON true
  LEFT JOIN LATERAL ST_Dump(geom) AS dumped ON true
  LEFT JOIN LATERAL hashtextextended(encode(ST_AsBinary(dumped.geom), 'hex')::text, 0) AS poly_hash ON true;

CREATE INDEX idx_sketch_geometry_hashes_sketch_id ON sketch_geometry_hashes (sketch_id);
CREATE INDEX idx_sketch_geometry_hashes_num_geometries ON sketch_geometry_hashes (num_geometries);
CREATE INDEX idx_sketch_geometry_hashes_poly_hash ON sketch_geometry_hashes (poly_hash);
CREATE INDEX idx_sketch_geometry_hashes_wt ON sketch_geometry_hashes (wt);

SELECT * FROM sketch_geometry_hashes LIMIT 5;
