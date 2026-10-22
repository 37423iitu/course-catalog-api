\set ON_ERROR_STOP on
BEGIN;
CREATE TEMP TABLE constraint_results (
    test text, sqlstate text, constraint_or_column text, proposed_http integer, passed boolean
);
CREATE FUNCTION pg_temp.expect_error(label text, statement text, expected_state text,
                                    expected_target text, http integer)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE actual_state text; actual_constraint text; actual_column text;
BEGIN
    BEGIN
        EXECUTE statement;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS actual_state = RETURNED_SQLSTATE,
            actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_state <> expected_state OR
           (CASE WHEN expected_state = '23502' THEN actual_column
                ELSE actual_constraint END) IS DISTINCT FROM expected_target THEN
            RAISE EXCEPTION 'FAIL %: expected % / %, got % / % / %',
                label, expected_state, expected_target, actual_state, actual_constraint, actual_column;
        END IF;
        INSERT INTO constraint_results VALUES
            (label, actual_state, expected_target, http, true);
        RETURN;
    END;
    RAISE EXCEPTION 'FAIL %: statement unexpectedly succeeded', label;
END;
$$;
SELECT pg_temp.expect_error('courses primary key', 'INSERT INTO courses(id,title,credits) VALUES (''api-design'',''Duplicate'',4)', '23505', 'courses_pkey', 409);
SELECT pg_temp.expect_error('students primary key', 'INSERT INTO students(id,name,email) SELECT id,''Duplicate'',''duplicate@example.com'' FROM students WHERE email=''gani@example.com''', '23505', 'students_pkey', 409);
SELECT pg_temp.expect_error('enrollments primary key', 'INSERT INTO enrollments(id,student_id,course_id) SELECT id,student_id,course_id FROM enrollments LIMIT 1', '23505', 'enrollments_pkey', 409);
SELECT pg_temp.expect_error('unique email', 'INSERT INTO students(name,email) VALUES (''Another Gani'',''gani@example.com'')', '23505', 'students_email_key', 409);
SELECT pg_temp.expect_error('unique enrollment', 'INSERT INTO enrollments(student_id,course_id) SELECT student_id,course_id FROM enrollments LIMIT 1', '23505', 'enrollments_student_course_key', 409);
SELECT pg_temp.expect_error('slug', 'INSERT INTO courses(id,title,credits) VALUES (''Bad Slug'',''Title'',5)', '23514', 'courses_id_check', 422);
SELECT pg_temp.expect_error('title blank', 'INSERT INTO courses(id,title,credits) VALUES (''bad-title'',''  '',5)', '23514', 'courses_title_check', 422);
SELECT pg_temp.expect_error('credits low', 'INSERT INTO courses(id,title,credits) VALUES (''bad-credits'',''Title'',0)', '23514', 'courses_credits_check', 422);
SELECT pg_temp.expect_error('credits high', 'INSERT INTO courses(id,title,credits) VALUES (''bad-credits'',''Title'',11)', '23514', 'courses_credits_check', 422);
SELECT pg_temp.expect_error('negative likes', 'INSERT INTO courses(id,title,credits,likes) VALUES (''bad-likes'',''Title'',5,-1)', '23514', 'courses_likes_check', 422);
SELECT pg_temp.expect_error('short name', 'INSERT INTO students(name,email) VALUES (''A'',''valid@example.com'')', '23514', 'students_name_check', 422);
SELECT pg_temp.expect_error('invalid email', 'INSERT INTO students(name,email) VALUES (''Valid Name'',''invalid'')', '23514', 'students_email_check', 422);
SELECT pg_temp.expect_error('email uppercase', 'INSERT INTO students(name,email) VALUES (''Valid Name'',''UPPER@example.com'')', '23514', 'students_email_check', 422);
SELECT pg_temp.expect_error('student foreign key', 'INSERT INTO enrollments(student_id,course_id) VALUES (-1,''api-design'')', '23503', 'enrollments_student_id_fkey', 404);
SELECT pg_temp.expect_error('course foreign key', 'INSERT INTO enrollments(student_id,course_id) SELECT id,''missing-course'' FROM students LIMIT 1', '23503', 'enrollments_course_id_fkey', 404);
SELECT pg_temp.expect_error('restrict student deletion', 'DELETE FROM students WHERE email=''gani@example.com''', '23503', 'enrollments_student_id_fkey', 409);
SELECT pg_temp.expect_error('restrict course deletion', 'DELETE FROM courses WHERE id=''databases-postgresql''', '23503', 'enrollments_course_id_fkey', 409);
SELECT pg_temp.expect_error('courses.id NOT NULL', 'INSERT INTO courses (id,title,description,credits,is_elective,likes,created_at) VALUES (NULL,''Valid Title'',''Description'',5,false,0,CURRENT_TIMESTAMP)', '23502', 'id', 422);
SELECT pg_temp.expect_error('courses.title NOT NULL', 'INSERT INTO courses (id,title,description,credits,is_elective,likes,created_at) VALUES (''null-test'',NULL,''Description'',5,false,0,CURRENT_TIMESTAMP)', '23502', 'title', 422);
SELECT pg_temp.expect_error('courses.description NOT NULL', 'INSERT INTO courses (id,title,description,credits,is_elective,likes,created_at) VALUES (''null-test'',''Valid Title'',NULL,5,false,0,CURRENT_TIMESTAMP)', '23502', 'description', 422);
SELECT pg_temp.expect_error('courses.credits NOT NULL', 'INSERT INTO courses (id,title,description,credits,is_elective,likes,created_at) VALUES (''null-test'',''Valid Title'',''Description'',NULL,false,0,CURRENT_TIMESTAMP)', '23502', 'credits', 422);
SELECT pg_temp.expect_error('courses.is_elective NOT NULL', 'INSERT INTO courses (id,title,description,credits,is_elective,likes,created_at) VALUES (''null-test'',''Valid Title'',''Description'',5,NULL,0,CURRENT_TIMESTAMP)', '23502', 'is_elective', 422);
SELECT pg_temp.expect_error('courses.likes NOT NULL', 'INSERT INTO courses (id,title,description,credits,is_elective,likes,created_at) VALUES (''null-test'',''Valid Title'',''Description'',5,false,NULL,CURRENT_TIMESTAMP)', '23502', 'likes', 422);
SELECT pg_temp.expect_error('courses.created_at NOT NULL', 'INSERT INTO courses (id,title,description,credits,is_elective,likes,created_at) VALUES (''null-test'',''Valid Title'',''Description'',5,false,0,NULL)', '23502', 'created_at', 422);
SELECT pg_temp.expect_error('students.id NOT NULL', 'INSERT INTO students (id,name,email,created_at) VALUES (NULL,''Valid Name'',''null-test@example.com'',CURRENT_TIMESTAMP)', '23502', 'id', 422);
SELECT pg_temp.expect_error('students.name NOT NULL', 'INSERT INTO students (id,name,email,created_at) VALUES (-100,NULL,''null-test@example.com'',CURRENT_TIMESTAMP)', '23502', 'name', 422);
SELECT pg_temp.expect_error('students.email NOT NULL', 'INSERT INTO students (id,name,email,created_at) VALUES (-100,''Valid Name'',NULL,CURRENT_TIMESTAMP)', '23502', 'email', 422);
SELECT pg_temp.expect_error('students.created_at NOT NULL', 'INSERT INTO students (id,name,email,created_at) VALUES (-100,''Valid Name'',''null-test@example.com'',NULL)', '23502', 'created_at', 422);
SELECT pg_temp.expect_error('enrollments.id NOT NULL', 'INSERT INTO enrollments (id,student_id,course_id,enrolled_at) VALUES (NULL,(SELECT id FROM students WHERE email=''gani@example.com''),''api-design'',CURRENT_TIMESTAMP)', '23502', 'id', 422);
SELECT pg_temp.expect_error('enrollments.student_id NOT NULL', 'INSERT INTO enrollments (id,student_id,course_id,enrolled_at) VALUES (-100,NULL,''api-design'',CURRENT_TIMESTAMP)', '23502', 'student_id', 422);
SELECT pg_temp.expect_error('enrollments.course_id NOT NULL', 'INSERT INTO enrollments (id,student_id,course_id,enrolled_at) VALUES (-100,(SELECT id FROM students WHERE email=''gani@example.com''),NULL,CURRENT_TIMESTAMP)', '23502', 'course_id', 422);
SELECT pg_temp.expect_error('enrollments.enrolled_at NOT NULL', 'INSERT INTO enrollments (id,student_id,course_id,enrolled_at) VALUES (-100,(SELECT id FROM students WHERE email=''gani@example.com''),''api-design'',NULL)', '23502', 'enrolled_at', 422);
SELECT * FROM constraint_results ORDER BY test;
SELECT COUNT(*) AS passed_constraint_tests FROM constraint_results WHERE passed;
-- Inventory: compare named constraints and all NOT NULL columns with the tests.
SELECT conrelid::regclass AS table_name, conname, contype
FROM pg_constraint WHERE connamespace = 'public'::regnamespace ORDER BY 1,2;
SELECT table_name, column_name FROM information_schema.columns
WHERE table_schema='public' AND is_nullable='NO' ORDER BY table_name, ordinal_position;
ROLLBACK;
