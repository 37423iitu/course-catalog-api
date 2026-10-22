\set ON_ERROR_STOP on
-- Isolated benchmark: generated rows and the experimental index roll back.
-- Run on the lab database before creating the production index below.
BEGIN;
INSERT INTO courses(id,title,credits,is_elective,likes)
SELECT 'bench-'||g, 'Benchmark course '||g, 5, (g % 10 = 0), g % 1000
FROM generate_series(1,100000) g;
ANALYZE courses;
\echo BEFORE: no composite index
EXPLAIN (ANALYZE, BUFFERS)
SELECT id,title,description,credits,is_elective,likes FROM courses
WHERE is_elective=true ORDER BY likes DESC,id ASC LIMIT 20;
CREATE INDEX courses_elective_popular_idx ON courses(is_elective,likes DESC,id ASC);
ANALYZE courses;
\echo AFTER: composite index, same query and data
EXPLAIN (ANALYZE, BUFFERS)
SELECT id,title,description,credits,is_elective,likes FROM courses
WHERE is_elective=true ORDER BY likes DESC,id ASC LIMIT 20;
ROLLBACK;
-- Keep the useful index in the actual schema; benchmark rows have disappeared.
CREATE INDEX courses_elective_popular_idx ON courses(is_elective,likes DESC,id ASC);
CREATE INDEX enrollments_course_id_idx ON enrollments(course_id);
ANALYZE courses;
ANALYZE enrollments;
SELECT COUNT(*) AS remaining_courses FROM courses;
-- For repeated measurements see README: the existing index must be removed first.
