\timing

SELECT * FROM get_similar_sketches(1);
SELECT * FROM get_similar_sketches(1234);
SELECT * FROM get_similar_sketches(5678);
SELECT * FROM get_similar_sketches(10000);
SELECT * FROM get_similar_sketches(10001);

SELECT id, ST_AsGeoJSON(geom) FROM sketches WHERE id = 10002;
SELECT * FROM get_similar_sketches(10002);

\echo 'now faster'
SELECT * FROM get_similar_sketches_faster(1);
SELECT * FROM get_similar_sketches_faster(1234);
SELECT * FROM get_similar_sketches_faster(5678);
SELECT * FROM get_similar_sketches_faster(10000);
SELECT * FROM get_similar_sketches_faster(10001);

SELECT id, ST_AsGeoJSON(geom) FROM sketches WHERE id = 10002;
SELECT * FROM get_similar_sketches_faster(10002);

