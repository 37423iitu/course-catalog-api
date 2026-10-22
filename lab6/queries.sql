\set ON_ERROR_STOP on
-- PREPARE uses PostgreSQL $1 parameters, not string interpolation.
-- GET /courses?is_elective=true&sort=popular&page=1&page_size=2
PREPARE list_courses(boolean, text, integer, integer) AS
SELECT id, title, description, credits, is_elective, likes FROM courses
WHERE ($1 IS NULL OR is_elective = $1)
ORDER BY CASE WHEN $2 = 'title' THEN title END ASC,
         CASE WHEN $2 = 'popular' THEN likes END DESC, id ASC
LIMIT $3 OFFSET $4;
EXECUTE list_courses(true, 'popular', 2, 0);
-- API validates sort in {popular,title}, page>=1, page_size in [1,100].
-- $3 = page_size; $4 = (page-1)*page_size. Stable tie-breaker: id.
EXECUTE list_courses(NULL, 'title', 2, 2);

-- GET /courses/{course_id}; no row => HTTP 404.
PREPARE one_course(text) AS
SELECT id, title, description, credits, is_elective, likes FROM courses WHERE id = $1;
EXECUTE one_course('databases-postgresql');

-- POST /courses/{course_id}/like; atomic update; no row => HTTP 404.
PREPARE like_course(text) AS
UPDATE courses SET likes = likes + 1 WHERE id = $1
RETURNING id, title, description, credits, is_elective, likes;
-- Demonstration leaves the original like count unchanged.
BEGIN;
EXECUTE like_course('databases-postgresql');
ROLLBACK;

-- POST /enrollments: name retained for Lab 5 JSON compatibility.
-- The API must supply studentEmail (new identity) in addition to studentName.
-- One API request = one transaction; upsert and enrollment are atomic.
PREPARE enroll_student(text, text, text) AS
WITH student AS (
    INSERT INTO students (name, email) VALUES ($1, lower(btrim($2)))
    ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name
    RETURNING id
)
INSERT INTO enrollments (student_id, course_id)
SELECT id, $3 FROM student
RETURNING id, student_id, course_id, enrolled_at;
BEGIN;
EXECUTE enroll_student('Demo Student', 'demo@example.com', 'api-design');
ROLLBACK;

-- GET /enrollments (JOIN all three tables; API aliases snake_case to camelCase).
PREPARE enrollment_list AS
SELECT e.id, e.course_id, s.name AS student_name, s.email AS student_email,
       c.title AS course_title, e.enrolled_at
FROM enrollments e JOIN students s ON s.id = e.student_id
JOIN courses c ON c.id = e.course_id ORDER BY e.id;
EXECUTE enrollment_list;

-- GET /statistics: LEFT JOIN includes courses with no enrollments.
PREPARE statistics AS
SELECT c.id, c.title, c.likes, COUNT(e.id) AS enrollment_count
FROM courses c LEFT JOIN enrollments e ON e.course_id = c.id
GROUP BY c.id ORDER BY enrollment_count DESC, c.id;
EXECUTE statistics;
SELECT COUNT(*) AS course_count, SUM(likes) AS total_likes,
       ROUND(AVG(credits), 2) AS average_credits FROM courses;
DEALLOCATE ALL;
