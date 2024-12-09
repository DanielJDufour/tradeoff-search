\timing

REFRESH MATERIALIZED VIEW CONCURRENTLY cells;
SELECT pg_sleep(60);
REFRESH MATERIALIZED VIEW CONCURRENTLY all_cells;
SELECT pg_sleep(60);
REFRESH MATERIALIZED VIEW CONCURRENTLY sketch_geometry_hashes;


SELECT * FROM get_similar_sketches(1);
SELECT * FROM get_similar_sketches(1234);
SELECT * FROM get_similar_sketches(5678);
SELECT * FROM get_similar_sketches(10000);
