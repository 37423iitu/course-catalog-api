\set ON_ERROR_STOP on
BEGIN;
-- Preserve later likes and edits when the seed is run again.
INSERT INTO courses (id, title, description, credits, is_elective, likes) VALUES
('modern-frontend', 'Modern Frontend: React & Next.js', 'React 19, Server Components, and the App Router.', 5, false, 24),
('backend-fastapi', 'Backend Foundations: FastAPI', 'Async REST APIs in Python with FastAPI and Pydantic.', 5, false, 19),
('databases-postgresql', 'Relational Databases: PostgreSQL', 'Schemas, SQLAlchemy, and migrations with Alembic.', 5, false, 15),
('api-design', 'API Design: REST vs GraphQL', 'Comparing REST and GraphQL in one hands-on project.', 4, true, 11),
('web-security', 'Web Security Essentials', 'JWT/OAuth2, XSS, CSRF, and SQL injection defense.', 4, false, 21),
('ai-integration', 'AI/LLM Integration', 'LLM features in an app via the OpenAI API.', 5, true, 32)
ON CONFLICT (id) DO NOTHING;
INSERT INTO students (name, email) VALUES
('Gani Karimov', 'gani@example.com'),
('Aigerim', 'aigerim@example.com'),
('Nurserik', 'nurserik@example.com')
ON CONFLICT (email) DO NOTHING;
INSERT INTO enrollments (student_id, course_id)
SELECT s.id, v.course_id FROM (VALUES
    ('gani@example.com', 'databases-postgresql'),
    ('gani@example.com', 'backend-fastapi'),
    ('aigerim@example.com', 'ai-integration'),
    ('nurserik@example.com', 'modern-frontend')
) AS v(email, course_id) JOIN students s ON s.email = v.email
ON CONFLICT (student_id, course_id) DO NOTHING;
COMMIT;
SELECT id, title, credits, is_elective, likes FROM courses ORDER BY id;
SELECT s.name, s.email, c.title FROM enrollments e
JOIN students s ON s.id = e.student_id JOIN courses c ON c.id = e.course_id
ORDER BY s.email, c.id;
