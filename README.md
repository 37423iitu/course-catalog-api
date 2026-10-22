# Lab 6 — PostgreSQL catalog database

Готовая лабораторная №6: [SQL, ER-диаграмма, запуск и результаты проверок](lab6/README.md).

Быстрый запуск отдельной учебной базы: `powershell -ExecutionPolicy Bypass -File .\lab6\start-local.ps1`.

---

# Course Catalog API — Lab 5

FastAPI backend for a six-course Next.js catalog, with filtering, sorting, pagination, likes and in-memory enrollment.

## Run on Windows

Requires Python 3.10+ and Pydantic 2.11+:

```powershell
cd "C:\Users\user\Desktop\новый\course-catalog-api"
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\fastapi.exe dev main.py --port 8000
```

Activation is optional when using these direct executable paths. Open http://localhost:8000/docs, then start the frontend at **http://localhost:3000** in a second terminal. If the reload subprocess is blocked, use `fastapi dev main.py --no-reload --port 8000`. Use port 8000 to match the frontend environment; changing the port also requires updating both frontend API variables.

## What changed

`CORSMiddleware` permits the exact browser origin `http://localhost:3000`, with all methods and headers. Browser requests from the Next.js frontend need this permission because port 3000 and port 8000 are different origins. Server Component requests come from the Next.js server and are not subject to browser CORS. Foreign origins get no Access-Control-Allow-Origin response header; a simple request can still execute even if the browser cannot read its result.

`CamelModel` uses `alias_generator=to_camel`, `validate_by_name=True` and `validate_by_alias=True`. Python fields stay snake_case, JSON fields become camelCase, and either name is accepted when creating a model. `Course`, `EnrollmentIn` and `Enrollment` inherit this configuration. `validate_by_name` is necessary because `data.py` constructs electives with `is_elective=True`. Query parameters are independent: use `?is_elective=true`, not `?isElective=true`.

Three routes were added:

| Route | Successful result |
| --- | --- |
| POST /courses/web-security/like | 200; `{"id":"web-security","title":"Web Security Essentials","description":"JWT/OAuth2, XSS, CSRF, and SQL injection defense.","credits":4,"isElective":false,"likes":22}` after the first like since restart |
| POST /enrollments | 201; `{"courseId":"web-security","studentName":"Aigerim","id":1}` for the first enrollment |
| GET /enrollments | 200; `[{"courseId":"web-security","studentName":"Aigerim","id":1}]` after the preceding POST |

Enrollment request body:

```json
{"courseId":"web-security","studentName":"Aigerim"}
```

The request must have `Content-Type: application/json`. A one-character `studentName` returns 422 with `detail[0].msg` equal to `String should have at least 2 characters`. Unknown course IDs return 404 with `{"detail":"Course not found"}` for both POST routes. The enrollment form deliberately displays backend validation instead of blocking short names in the browser.

Likes and enrollments are held in process memory: refreshing a page preserves them, but restarting FastAPI resets them. No database is required for this lab.

## All six routes

| Method | Path | Purpose |
| --- | --- | --- |
| GET | / | Running status |
| GET | /courses | List, filter, sort, paginate |
| GET | /courses/{course_id} | One course or 404 |
| POST | /courses/{course_id}/like | Increment and return course |
| POST | /enrollments | Validate and create enrollment |
| GET | /enrollments | List current enrollments |

`GET /courses` returns six courses, with ai-integration first. `?is_elective=true` returns ai-integration and api-design. `?isElective=true` is ignored and returns six. `?sort=title` sorts by title; default sorting is by likes descending. `?page=2&page_size=2` returns the second pair. Filtering precedes sorting, followed by pagination. Page must be >=1 and page_size must be between 1 and 100; invalid values return 422.

## CORS checks

```powershell
curl.exe -i -H "Origin: http://localhost:3000" http://localhost:8000/
curl.exe -i -H "Origin: http://evil.example" http://localhost:8000/
curl.exe -i -X OPTIONS http://localhost:8000/enrollments -H "Origin: http://localhost:3000" -H "Access-Control-Request-Method: POST" -H "Access-Control-Request-Headers: content-type"
```

The first response includes `Access-Control-Allow-Origin: http://localhost:3000`; the second has no such header. The OPTIONS response is 200 OK and allows POST and content-type. A like has no body or special headers and therefore has no preflight; enrollment JSON triggers one. The browser may cache successful preflight permission for 600 seconds; disable cache when reproducing it.

## Verification and submission

Verified on 15 October 2026: all six OpenAPI operations; camelCase; electives; sorting and pagination; allowed/foreign origin headers; preflight 200; two likes (22, 23); valid enrollment 201 and list; short name 422; unknown courses 404. Chrome browser checks also cover both frontend request paths, the filter, persisted likes, validation messages, loading, not-found and recovery with retry. The frontend README contains five reproduced breakages and actual browser console messages.

Local Lab 5 commits separately cover CORS, camelCase models, POST routes and documentation. The configured remote is https://github.com/37423iitu/course-catalog-api. Push the local commits using your GitHub access before submitting; local changes have not been published automatically.
