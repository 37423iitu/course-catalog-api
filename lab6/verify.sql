\set ON_ERROR_STOP on
DO $$
BEGIN
    IF (SELECT COUNT(*) FROM courses) <> 6 OR
       (SELECT COUNT(*) FROM students) <> 3 OR
       (SELECT COUNT(*) FROM enrollments) <> 4 THEN
        RAISE EXCEPTION 'Unexpected seed counts';
    END IF;
    IF (SELECT SUM(likes) FROM courses) <> 122 THEN RAISE EXCEPTION 'Wrong likes'; END IF;
    IF (SELECT COUNT(*) FROM courses WHERE is_elective) <> 2 THEN RAISE EXCEPTION 'Wrong electives'; END IF;
    IF EXISTS(SELECT 1 FROM courses WHERE id LIKE 'bench-%') THEN RAISE EXCEPTION 'Benchmark leaked'; END IF;
    IF EXISTS(SELECT 1 FROM students WHERE email LIKE 'tx-%' OR email='demo@example.com') THEN
        RAISE EXCEPTION 'Demo data leaked';
    END IF;
    IF (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE')<>3 THEN
        RAISE EXCEPTION 'Expected exactly 3 permanent tables';
    END IF;
END $$;
SELECT 'PASS: 3 tables; 6 courses; 3 students; 4 enrollments; 122 likes; no demo rows' AS verification;
