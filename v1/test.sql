\timing

WITH t AS (SELECT * FROM all_cells WHERE sketch_id = 1234),
t2 AS (SELECT * FROM sketch_geometry_hashes WHERE sketch_id = 1234)
SELECT
  a.sketch_id,
    .25 * MAX(COALESCE(x.sim, 0))
  + .05 * (0.5 * SUM(CASE WHEN a.res = 0 THEN a.cell_weight ELSE 0 END) + 0.5 * SUM(CASE WHEN t.res = 0 THEN t.cell_weight ELSE 0 END))
  + .1 * (0.5 * SUM(CASE WHEN a.res = 3 THEN a.cell_weight ELSE 0 END) + 0.5 * SUM(CASE WHEN t.res = 3 THEN t.cell_weight ELSE 0 END))
  + .2 * (0.5 * SUM(CASE WHEN a.res = 5 THEN a.cell_weight ELSE 0 END) + 0.5 * SUM(CASE WHEN t.res = 5 THEN t.cell_weight ELSE 0 END))
  + .4 * (0.5 * SUM(CASE WHEN a.res = 7 THEN a.cell_weight ELSE 0 END) + 0.5 * SUM(CASE WHEN t.res = 7 THEN t.cell_weight ELSE 0 END)) AS sim
FROM all_cells a
INNER JOIN t ON a.cell_id = t.cell_id
LEFT JOIN (
  SELECT
  s.sketch_id,
  COUNT(*)::float / (any_value(s.num_geometries) + any_value(t2.num_geometries) - COUNT(*)) AS sim -- jaccard similarity of geom hashes
  FROM sketch_geometry_hashes s
  INNER JOIN t2 ON s.poly_hash = t2.poly_hash
  GROUP BY s.sketch_id
) x ON a.sketch_id = x.sketch_id
GROUP BY a.sketch_id
ORDER BY sim DESC
LIMIT 10;
