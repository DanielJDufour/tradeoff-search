CREATE MATERIALIZED VIEW cells AS 
WITH cell_data AS(
  SELECT
    sketches.id AS sketch_id,
    poly_area,
    cells0,
    cells3,
    cells5,
    cells7
  FROM sketches
  LEFT JOIN LATERAL ST_Dump(geom) AS polys ON true
  LEFT JOIN LATERAL ST_Area(polys.geom) AS poly_area ON true
  LEFT JOIN LATERAL h3_polygon_to_cells(polys.geom, 7) AS cells7 ON true
  LEFT JOIN LATERAL h3_cell_to_parent(cells7, 5) AS cells5 ON true
  LEFT JOIN LATERAL h3_cell_to_parent(cells5, 3) AS cells3 ON true
  LEFT JOIN LATERAL h3_cell_to_parent(cells3, 0) AS cells0 ON true
)
(SELECT sketch_id, 0 AS res, cells0 AS cell_id, MAX(1 / poly_area) AS cell_weight FROM cell_data GROUP BY sketch_id, cells0 ORDER BY sketch_id)
UNION
(SELECT sketch_id, 3 AS res, cells3 AS cell_id, MAX(1 / poly_area) AS cell_weight FROM cell_data GROUP BY sketch_id, cells3 ORDER BY sketch_id)
UNION
(SELECT sketch_id, 5 AS res, cells5 AS cell_id, MAX(1 / poly_area) AS cell_weight FROM cell_data GROUP BY sketch_id, cells5 ORDER BY sketch_id)
UNION
(SELECT sketch_id, 7 AS res, cells7 AS cell_id, MAX(1 / poly_area) AS cell_weight FROM cell_data GROUP BY sketch_id, cells7 ORDER BY sketch_id);

CREATE UNIQUE INDEX idx_cells_sketch_id_and_cell_id ON cells (sketch_id, cell_id);

CREATE VIEW sketch_weights AS SELECT sketch_id, res, SUM(cell_weight) AS wt FROM cells GROUP BY sketch_id, res;

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

--- need to create unique index in order to enable refresh materialize view concurrently
CREATE UNIQUE INDEX idx_all_cells_sketch_id_and_cell_id ON all_cells (sketch_id, cell_id);


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
CREATE UNIQUE INDEX sketch_geometry_hashes_sketch_id_and_poly_hash ON sketch_geometry_hashes (sketch_id, poly_hash);

CREATE TYPE similar_sketch AS (sketch_id bigint, similarity double precision);

CREATE OR REPLACE FUNCTION get_similar_sketches(
  A_SKETCH_ID bigint,
  HASH_WEIGHT float default 0.25,
  RES_0_WEIGHT float default .05,
  RES_3_WEIGHT float default .1,
  RES_5_WEIGHT float default .2,
  RES_7_WEIGHT float default .4
) RETURNS SETOF similar_sketch AS
$func$
  SELECT
    a.sketch_id,
      HASH_WEIGHT * MAX(COALESCE(x.sim, 0))
    + RES_0_WEIGHT * (0.5 * SUM(CASE WHEN a.res = 0 THEN a.cell_weight ELSE 0 END) + 0.5 * SUM(CASE WHEN t.res = 0 THEN t.cell_weight ELSE 0 END))
    + RES_3_WEIGHT * (0.5 * SUM(CASE WHEN a.res = 3 THEN a.cell_weight ELSE 0 END) + 0.5 * SUM(CASE WHEN t.res = 3 THEN t.cell_weight ELSE 0 END))
    + RES_5_WEIGHT * (0.5 * SUM(CASE WHEN a.res = 5 THEN a.cell_weight ELSE 0 END) + 0.5 * SUM(CASE WHEN t.res = 5 THEN t.cell_weight ELSE 0 END))
    + RES_7_WEIGHT * (0.5 * SUM(CASE WHEN a.res = 7 THEN a.cell_weight ELSE 0 END) + 0.5 * SUM(CASE WHEN t.res = 7 THEN t.cell_weight ELSE 0 END)) AS similarity
  FROM all_cells a
  INNER JOIN (SELECT * FROM all_cells WHERE sketch_id = A_SKETCH_ID) t ON a.cell_id = t.cell_id
  LEFT JOIN (
    SELECT
    s.sketch_id,
    COUNT(*)::float / (any_value(s.num_geometries) + any_value(t2.num_geometries) - COUNT(*)) AS sim -- jaccard similarity of geom hashes
    FROM sketch_geometry_hashes s
    INNER JOIN (SELECT * FROM sketch_geometry_hashes WHERE sketch_id = A_SKETCH_ID) t2 ON s.poly_hash = t2.poly_hash
    GROUP BY s.sketch_id
  ) x ON a.sketch_id = x.sketch_id
  GROUP BY a.sketch_id
  ORDER BY similarity DESC
  LIMIT 10;
$func$
LANGUAGE sql IMMUTABLE;
