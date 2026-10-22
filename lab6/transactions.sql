\set ON_ERROR_STOP on
-- Successful request: insert student + enrollment, then verify and clean up in a transaction.
BEGIN;
INSERT INTO students(name,email) VALUES ('Transaction Success','tx-success@example.com') RETURNING id \gset success_
INSERT INTO enrollments(student_id,course_id) VALUES (:success_id,'api-design');
COMMIT;
SELECT s.email, e.course_id FROM students s JOIN enrollments e ON e.student_id=s.id
WHERE s.email='tx-success@example.com';
BEGIN;
DELETE FROM enrollments WHERE student_id=:success_id;
DELETE FROM students WHERE id=:success_id;
COMMIT;

-- Fail the second operation in an actual SQL transaction.
SELECT COUNT(*) AS count FROM students \gset before_students_
SELECT COUNT(*) AS count FROM enrollments \gset before_enrollments_
BEGIN;
INSERT INTO students(name,email) VALUES ('Transaction Failure','tx-failure@example.com') RETURNING id \gset failure_
-- Keep psql running only around the deliberate error; record the real SQLSTATE.
\set ON_ERROR_STOP off
INSERT INTO enrollments(student_id,course_id) VALUES (:failure_id,'missing-course');
\set failed_state :SQLSTATE
ROLLBACK;
\set ON_ERROR_STOP on
SELECT :'failed_state'='23503' AS expected_error,
       NOT EXISTS(SELECT 1 FROM students WHERE email='tx-failure@example.com') AS student_rolled_back,
       NOT EXISTS(SELECT 1 FROM enrollments WHERE student_id=:failure_id) AS enrollment_absent,
       (SELECT COUNT(*) FROM students)=:before_students_count AS student_count_unchanged,
       (SELECT COUNT(*) FROM enrollments)=:before_enrollments_count AS enrollment_count_unchanged
\gset tx_
\if :tx_expected_error
\else
    SELECT 1/0 AS unexpected_sqlstate;
\endif
\if :tx_student_rolled_back
\else
    SELECT 1/0 AS student_not_rolled_back;
\endif
\if :tx_enrollment_absent
\else
    SELECT 1/0 AS enrollment_not_rolled_back;
\endif
\if :tx_student_count_unchanged
\else
    SELECT 1/0 AS student_count_changed;
\endif
\if :tx_enrollment_count_unchanged
\else
    SELECT 1/0 AS enrollment_count_changed;
\endif
\echo PASS: SQLSTATE :failed_state; both inserts rolled back; row counts unchanged.
