CREATE TYPE sketch_cell AS (
  res int,
  cell_id h3index,
  cell_weight float
);

CREATE OR REPLACE FUNCTION get_sketch_cells(geom geometry) RETURNS SETOF sketch_cell AS
$func$
  WITH cell_data AS (
    SELECT
      poly_area,
      cells0,
      cells3,
      cells5,
      cells7
    FROM (
      SELECT
        polys.geom AS geom
      FROM ST_Dump(geom) polys
      WHERE polys.geom IS NOT NULL AND NOT ST_IsEmpty(polys.geom) AND ST_IsValid(polys.geom) AND GeometryType(polys.geom) = 'POLYGON' AND ST_Area(polys.geom) > 0
    ) valid_polys
    LEFT JOIN LATERAL ST_Area(valid_polys.geom) AS poly_area ON true
    LEFT JOIN LATERAL h3_polygon_to_cells(valid_polys.geom, 7) AS cells7 ON true
    LEFT JOIN LATERAL h3_cell_to_parent(cells7, 5) AS cells5 ON true
    LEFT JOIN LATERAL h3_cell_to_parent(cells5, 3) AS cells3 ON true
    LEFT JOIN LATERAL h3_cell_to_parent(cells3, 0) AS cells0 ON true
  )
  (SELECT 0 AS res, cells0 AS cell_id, MAX(1 / poly_area) AS cell_weight FROM cell_data GROUP BY cells0)
  UNION
  (SELECT 3 AS res, cells3 AS cell_id, MAX(1 / poly_area) AS cell_weight FROM cell_data GROUP BY cells3)
  UNION
  (SELECT 5 AS res, cells5 AS cell_id, MAX(1 / poly_area) AS cell_weight FROM cell_data GROUP BY cells5)
  UNION
  (SELECT 7 AS res, cells7 AS cell_id, MAX(1 / poly_area) AS cell_weight FROM cell_data GROUP BY cells7);
$func$
LANGUAGE sql IMMUTABLE;

ALTER FUNCTION get_sketch_cells(geom geometry) SET search_path = 'public';

\echo 'creating materialized view cells'
CREATE MATERIALIZED VIEW cells AS   
  SELECT
    id AS sketch_id,
    cells.res AS res,
    cells.cell_id as cell_id,
    cells.cell_weight as cell_weight
  FROM (SELECT id, geom FROM sketches WHERE geom IS NOT NULL AND NOT ST_IsEmpty(geom) AND ST_IsValid(geom))
  LEFT JOIN LATERAL get_sketch_cells(geom) cells ON true
  WHERE res IS NOT NULL AND cell_id IS NOT NULL;

CREATE UNIQUE INDEX idx_cells_sketch_id_and_cell_id ON cells (sketch_id, cell_id);

\echo 'creating view sketch_weights'
CREATE VIEW sketch_weights AS SELECT sketch_id, res, SUM(cell_weight) AS wt FROM cells GROUP BY sketch_id, res;

\echo 'creating materialized view all_cells'
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

\echo 'creating materialized view sketch_geometry_hashes'
CREATE MATERIALIZED VIEW sketch_geometry_hashes AS 
  SELECT
    id AS sketch_id,
    dumped.path AS poly_path,
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
CREATE UNIQUE INDEX sketch_geometry_hashes_unique ON sketch_geometry_hashes (sketch_id, poly_path, poly_hash);

CREATE TYPE similar_sketch AS (sketch_id bigint, similarity double precision);

\echo 'creating get_similar_sketches'
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
    COUNT(*)::float / NULLIF(MAX(s.num_geometries) + MAX(t2.num_geometries) - COUNT(*), 0) AS sim -- jaccard similarity of geom hashes
    FROM sketch_geometry_hashes s
    INNER JOIN (SELECT * FROM sketch_geometry_hashes WHERE sketch_id = A_SKETCH_ID) t2 ON s.poly_hash = t2.poly_hash
    GROUP BY s.sketch_id
  ) x ON a.sketch_id = x.sketch_id
  GROUP BY a.sketch_id
  ORDER BY similarity DESC
  LIMIT 10;
$func$
LANGUAGE sql IMMUTABLE;


CREATE OR REPLACE FUNCTION geometry_vector_similarity(
  a public.geometry,
  b public.geometry,
  a_area float,
  b_area float
)
  RETURNS float AS
$function$
DECLARE
    i float;
BEGIN
    i := ST_Area(ST_Intersection(a, b));
    IF i = 0 THEN RETURN 0; END IF;
    RETURN i / (a_area + b_area - i);
END;
$function$
LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION get_similar_sketches_faster(
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
    + RES_7_WEIGHT * MAX(COALESCE(v.sim, 0))
    AS similarity
  FROM all_cells a
  INNER JOIN (
    SELECT s.id AS sketch_id, geometry_vector_similarity(s.geom, c.geom, s.area, c.area) AS sim FROM sketches s, (SELECT geom, area FROM sketches WHERE id = A_SKETCH_ID LIMIT 1) c WHERE s.geom IS NOT NULL AND ST_IsValid(s.geom) AND ST_IsValid(c.geom) AND ST_Intersects(s.geom, c.geom) ORDER BY sim DESC LIMIT 10  
  ) v ON v.sketch_id = a.sketch_id
  INNER JOIN (SELECT * FROM all_cells WHERE sketch_id = A_SKETCH_ID) t ON a.cell_id = t.cell_id
  LEFT JOIN (
    SELECT
    s.sketch_id,
    COUNT(*)::float / NULLIF(MAX(s.num_geometries) + MAX(t2.num_geometries) - COUNT(*), 0) AS sim -- jaccard similarity of geom hashes
    FROM sketch_geometry_hashes s
    INNER JOIN (SELECT * FROM sketch_geometry_hashes WHERE sketch_id = A_SKETCH_ID) t2 ON s.poly_hash = t2.poly_hash
    GROUP BY s.sketch_id
  ) x ON a.sketch_id = x.sketch_id
  GROUP BY a.sketch_id
  ORDER BY similarity DESC
  LIMIT 10;
$func$
LANGUAGE sql IMMUTABLE;
