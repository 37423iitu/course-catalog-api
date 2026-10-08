# Course Catalog API

Standalone FastAPI backend for Lab 4 with a six-course catalog, Pydantic validation, filtering, sorting, and pagination through Depends.

## How to run on Windows

Python 3.10 or newer is required. Open PowerShell in this project folder:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
fastapi dev main.py
```

If PowerShell blocks activation, use the environment directly without changing execution policy:

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\fastapi.exe dev main.py
```

Open http://127.0.0.1:8000/docs and use **Try it out**, then **Execute**. Alternative documentation is at `/redoc`, and the OpenAPI schema is at `/openapi.json`. Stop the server with Ctrl+C. If port 8000 is occupied, add `--port 8001`.

## Project structure

- `main.py`: three GET routes and the pagination dependency.
- `models.py`: the Pydantic Course model.
- `data.py`: six courses and lookup helpers.
- `requirements.txt`: FastAPI with its standard dependencies.
- `.gitignore`: excludes the virtual environment and Python cache files.

## What was verified

The following requests were checked locally; the same requests can be repeated in Swagger UI.

| Request | Result |
| --- | --- |
| `GET /` | 200; `{"message":"Course Catalog API is running"}` |
| `GET /courses` | 200; ai-integration, modern-frontend, web-security, backend-fastapi, databases-postgresql, api-design |
| `GET /courses/web-security` | 200; the Web Security Essentials course |
| `GET /courses/nope` | 404; `{"detail":"Course not found"}` |
| `GET /courses?is_elective=true` | 200; ai-integration, api-design |
| `GET /courses?is_elective=false` | 200; modern-frontend, web-security, backend-fastapi, databases-postgresql |
| `GET /courses?sort=title` | 200; ai-integration, api-design, backend-fastapi, modern-frontend, databases-postgresql, web-security |
| `GET /courses?page=1&page_size=2` | 200; ai-integration, modern-frontend |
| `GET /courses?page=2&page_size=2` | 200; web-security, backend-fastapi |
| `GET /courses?page=3&page_size=2` | 200; databases-postgresql, api-design |
| `GET /courses?page=4&page_size=2` | 200; `[]` |
| `GET /courses?is_elective=false&sort=title&page=2&page_size=2` | 200; databases-postgresql, web-security |
| `GET /courses?is_elective=true&page=2&page_size=1` | 200; api-design |
| `GET /courses?page=0` | 422; page must be at least 1 |
| `GET /courses?page_size=0` | 422; page_size must be at least 1 |
| `GET /courses?page_size=1000` | 422; page_size must be at most 100 |
| `GET /courses?page=abc` | 422; invalid integer |
| `GET /courses?is_elective=banana` | 422; invalid boolean |
| `GET /docs` | 200; Swagger UI |
| `GET /redoc` | 200; ReDoc |
| `GET /openapi.json` | 200; exactly three GET routes and the Course schema |

All course responses include `id`, `title`, `description`, `credits`, `is_elective`, and `likes`. The model defaults are `is_elective=False` and `likes=0`. Pydantic rejects `credits="five"` and converts `credits="5"` to integer 5.

Filtering runs before sorting, and pagination runs last. Default sorting is by likes descending; `sort=title` sorts by title. Other sort values use popular sorting, as in the core assignment. The pagination bounds implement the optional Query validation task.

The data matches the Lab 4 handout, including 24 likes for Modern Frontend. The older frontend copy had 9 likes for that course.

## Submission

The local Git repository contains separate commits for the environment, root route, model and data, course routes, filtering and sorting, pagination, and documentation. `.venv/` is ignored and is not committed.

Create a GitHub repository named `course-catalog-api`, then replace `YOUR_USERNAME` below with your actual username:

```powershell
git remote add origin https://github.com/YOUR_USERNAME/course-catalog-api.git
git push -u origin main
```

Submit the GitHub repository link as required by your instructor.

For an environment that blocks the Windows reload subprocess, disable automatic reload:

```powershell
.\.venv\Scripts\fastapi.exe dev main.py --no-reload
```

The running server was also checked over HTTP for the root response, page 2, Swagger UI, and the three-route OpenAPI schema. The server startup check used `--no-reload`; the default reload subprocess was blocked in the execution environment.
