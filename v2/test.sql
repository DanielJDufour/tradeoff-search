\timing

REFRESH MATERIALIZED VIEW CONCURRENTLY cells;
VACUUM cells;

REFRESH MATERIALIZED VIEW CONCURRENTLY all_cells;
VACUUM all_cells;

REFRESH MATERIALIZED VIEW CONCURRENTLY sketch_geometry_hashes;
VACUUM sketch_geometry_hashes;

SELECT * FROM get_similar_sketches(1);
SELECT * FROM get_similar_sketches(1234);
SELECT * FROM get_similar_sketches(5678);
SELECT * FROM get_similar_sketches(10000);
