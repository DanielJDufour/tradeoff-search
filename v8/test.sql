\timing

\echo 'starting test.sql'

SELECT * FROM get_similar_sketches(1);
SELECT * FROM get_similar_sketches(100);
SELECT * FROM get_similar_sketches(1234);
SELECT * FROM get_similar_sketches(5000);
SELECT * FROM get_similar_sketches(5001);
SELECT * FROM get_similar_sketches(5002);
SELECT * FROM get_similar_sketches(5678);
SELECT * FROM get_similar_sketches(10000);
SELECT * FROM get_similar_sketches(10001);
SELECT * FROM get_similar_sketches(10002);
