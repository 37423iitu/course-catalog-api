"""Run the lab on a new disposable PostgreSQL database, never on existing data.

Requires start-local.ps1 first. The generated database alone is dropped afterward.
All broken source files live in a temporary project copy.
"""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import tempfile
import uuid

import psycopg
from psycopg import sql

ROOT = Path(__file__).resolve().parent
RESULTS = ROOT / "results"


def main():
    settings = json.loads((ROOT / ".lab7-local/connection.json").read_text(encoding="utf-8-sig"))
    dbname = "lab7_verify_" + uuid.uuid4().hex[:12]
    admin = psycopg.connect(host="127.0.0.1", port=settings["port"], user="postgres",
                           password=settings["adminPassword"], dbname="postgres", autocommit=True)
    admin.execute(sql.SQL("CREATE DATABASE {} OWNER catalog_app").format(sql.Identifier(dbname)))
    env = os.environ.copy()
    env["DATABASE_URL"] = f"postgresql+psycopg://catalog_app:change-me@127.0.0.1:{settings['port']}/{dbname}"
    env["SQL_ECHO"] = "false"
    env["PYTHONIOENCODING"] = "utf-8"
    RESULTS.mkdir(exist_ok=True)
    transcript = []

    def log(message):
        print(message, flush=True)
        transcript.append(message)

    try:
        with tempfile.TemporaryDirectory(prefix="lab7-project-") as temp:
            work = Path(temp)
            for p in ROOT.iterdir():
                if p.is_file() and p.suffix in {".py", ".sql", ".ini"}:
                    shutil.copy2(p, work / p.name)
            shutil.copytree(ROOT / "alembic", work / "alembic", ignore=shutil.ignore_patterns("__pycache__"))
            conn = psycopg.connect(host="127.0.0.1", port=settings["port"], user="catalog_app",
                                   password="change-me", dbname=dbname, autocommit=True)

            def run(*args, ok=True):
                result = subprocess.run([sys.executable, *args], cwd=work, env=env,
                                        text=True, encoding="utf-8", capture_output=True, timeout=90)
                output = result.stdout + result.stderr
                log("$ python " + " ".join(args[:5]) + "\n" + output)
                assert (result.returncode == 0) == ok, (args, result.returncode, output)
                return output

            def alembic(*args, ok=True):
                return run("-m", "alembic", *args, ok=ok)

            def python(code, ok=True):
                return run("-c", code, ok=ok)

            model_path = work / "models.py"
            model_final = model_path.read_text(encoding="utf-8")
            model_base = model_final.replace("    level: Mapped[str]\n", "")
            migration2 = work / "alembic/versions/0002_add_course_level.py"
            migration2_final = migration2.read_text(encoding="utf-8")
            migration2.unlink()
            model_path.write_text(model_base, encoding="utf-8")

            # Generate and review 0001 on an empty database, as required by the lab.
            (work / "alembic/versions/0001_create_catalog_tables.py").unlink()
            alembic("revision", "--autogenerate", "-m", "create catalog tables", "--rev-id", "0001")
            generated = next((work / "alembic/versions").glob("0001_*.py"))
            generated_text = generated.read_text(encoding="utf-8")
            assert all(s in generated_text for s in ("always=True", "enrollments_student_id_idx", "op.f("))
            log("Generated 0001 contains identity columns, final constraint names and the index.")
            alembic("upgrade", "head")
            alembic("check")

            # Simulate adopting an existing Lab 6 schema without recreating its rows.
            conn.execute("DROP TABLE alembic_version")
            output = alembic("upgrade", "head", ok=False)
            assert "DuplicateTable" in output
            alembic("stamp", "0001")
            alembic("check")

            seed = (work / "seed.sql").read_text(encoding="utf-8")
            seed_body = "\n".join(line for line in seed.splitlines() if not line.startswith("\\"))
            base_seed = seed_body.replace(", likes, level)", ", likes)").replace(", 'beginner')", ")").replace(", 'intermediate')", ")")
            conn.execute(base_seed)
            counts = conn.execute("SELECT (SELECT count(*) FROM courses), (SELECT count(*) FROM students), (SELECT count(*) FROM enrollments)").fetchone()
            assert counts == (6, 3, 6), counts
            run("check_models.py")

            log("EXPERIMENT 1: change the unique naming convention")
            db_path = work / "db.py"
            db_original = db_path.read_text(encoding="utf-8")
            db_path.write_text(db_original.replace('%(table_name)s_%(column_0_N_name)s_key', '%(table_name)s_%(column_0_name)s_unique'), encoding="utf-8")
            output = run("check_models.py", ok=False)
            assert "students_email_unique" in output and "enrollments_course_id_unique" in output
            db_path.write_text(db_original, encoding="utf-8")
            run("check_models.py")

            # API experiments use the final schema so response serialization works.
            model_path.write_text(model_final, encoding="utf-8")
            migration2.write_text(migration2_final, encoding="utf-8")
            log("EXPERIMENT 5: add a required column directly on nonempty data")
            migration2.write_text('from alembic import op\nimport sqlalchemy as sa\nrevision="0002"\ndown_revision="0001"\ndef upgrade():\n    op.add_column("courses", sa.Column("level", sa.Text(), nullable=False))\ndef downgrade():\n    op.drop_column("courses", "level")\n', encoding="utf-8")
            output = alembic("upgrade", "head", ok=False)
            assert "NotNullViolation" in output
            assert conn.execute("SELECT version_num FROM alembic_version").fetchone()[0] == "0001"
            migration2.write_text(migration2_final, encoding="utf-8")
            static_sql = alembic("upgrade", "0001:0002", "--sql")
            assert all(x in static_sql for x in ("ADD COLUMN level TEXT", "UPDATE courses SET level", "SET NOT NULL"))
            (RESULTS / "migration-0002.sql").write_text(
                "\n".join(line for line in static_sql.splitlines() if not line.startswith("INFO")) + "\n",
                encoding="utf-8",
            )
            alembic("upgrade", "head")
            alembic("check")

            log("EXPERIMENT 2: remove Pydantic min_length")
            schemas_path = work / "schemas.py"
            schemas_original = schemas_path.read_text(encoding="utf-8")
            schemas_path.write_text(schemas_original.replace('name: str = Field(min_length=2)', 'name: str'), encoding="utf-8")
            python('from fastapi.testclient import TestClient\nfrom main import app\nwith TestClient(app, raise_server_exceptions=False) as c:\n r=c.post("/students",json={"name":"N","email":"n@example.com"}); print(r.status_code,r.text); assert r.status_code==500\n')
            python('from sqlalchemy.exc import IntegrityError\nfrom db import SessionLocal\nfrom models import Student\nwith SessionLocal() as s:\n s.add(Student(name="N",email="n@example.com"))\n try: s.commit()\n except IntegrityError as e: print(type(e.orig).__name__,e.orig.diag.constraint_name); s.rollback()\n')
            schemas_path.write_text(schemas_original, encoding="utf-8")

            log("EXPERIMENT 3: typo in the constraint response map")
            main_path = work / "main.py"
            main_original = main_path.read_text(encoding="utf-8")
            main_path.write_text(main_original.replace('"students_email_key":', '"students_email_uniq":'), encoding="utf-8")
            python('from fastapi.testclient import TestClient\nfrom main import app\nwith TestClient(app, raise_server_exceptions=False) as c:\n r=c.post("/students",json={"name":"Aigerim Two","email":"aigerim@example.com"}); print(r.status_code,r.text); assert r.status_code==500\n')
            main_path.write_text(main_original, encoding="utf-8")

            log("EXPERIMENT 4: nullable and type drift")
            conn.execute("ALTER TABLE courses ALTER COLUMN title DROP NOT NULL")
            assert "modify_nullable" in alembic("check", ok=False)
            conn.execute("ALTER TABLE courses ALTER COLUMN title SET NOT NULL")
            conn.execute("ALTER TABLE courses ALTER COLUMN title TYPE varchar(100)")
            assert "modify_type" in alembic("check", ok=False)
            conn.execute("ALTER TABLE courses ALTER COLUMN title TYPE text")
            alembic("check")

            log("EXPERIMENT 6: forget import models; review only, DO NOT APPLY")
            env_path = work / "alembic/env.py"
            env_original = env_path.read_text(encoding="utf-8")
            env_path.write_text(env_original.replace('import models  #', '# import models  #'), encoding="utf-8")
            alembic("revision", "--autogenerate", "-m", "oops", "--rev-id", "0003")
            oops = next((work / "alembic/versions").glob("0003_*.py"))
            oops_text = oops.read_text(encoding="utf-8")
            assert oops_text.count("op.drop_table(") == 3
            log(oops_text)
            oops.unlink()
            env_path.write_text(env_original, encoding="utf-8")

            log("EXPERIMENT 7: add phone without a migration")
            model_path.write_text(model_final.replace('    email: Mapped[str] = mapped_column(unique=True)', '    email: Mapped[str] = mapped_column(unique=True)\n    phone: Mapped[str | None]'), encoding="utf-8")
            assert "phone" in alembic("check", ok=False)
            model_path.write_text(model_final, encoding="utf-8")
            alembic("check")

            log("EXPERIMENT 8: two heads and a merge")
            alembic("revision", "-m", "add student phone", "--rev-id", "0003")
            alembic("revision", "-m", "add course language", "--rev-id", "0004", "--head", "0002", "--splice")
            output = alembic("heads")
            assert "0003 (head)" in output and "0004 (head)" in output
            assert "Multiple head" in alembic("upgrade", "head", ok=False)
            alembic("merge", "heads", "-m", "merge phone and language", "--rev-id", "0005")
            assert "0005 (head)" in alembic("heads")
            alembic("history")
            for p in (work / "alembic/versions").glob("*.py"):
                if p.name[:4] in {"0003", "0004", "0005"}:
                    p.unlink()
            assert "0002 (head)" in alembic("heads")

            log("VERIFY: upgrade / downgrade / upgrade with existing records")
            alembic("downgrade", "-1")
            assert not conn.execute("SELECT 1 FROM information_schema.columns WHERE table_name='courses' AND column_name='level'").fetchone()
            alembic("upgrade", "head")
            assert conn.execute("SELECT count(*) FROM courses WHERE level IS NULL").fetchone()[0] == 0
            alembic("check")

            log("VERIFY: clean start from an empty schema")
            alembic("downgrade", "base")
            alembic("upgrade", "head")
            conn.execute(seed_body)
            conn.execute(seed_body)  # Seed is repeatable, including identity reset.
            alembic("check")
            run("check_db.py")
            run("check_models.py")
            api_checks = '''
from concurrent.futures import ThreadPoolExecutor
from fastapi.testclient import TestClient
from main import app
from try_errors import CASES
with TestClient(app) as c:
    for title,path,body,status in CASES:
        r=c.post(path,json=body)
        print(title,r.status_code,r.text)
        assert r.status_code==status
    assert len(c.get('/courses').json())==6
    assert len(c.get('/courses?level=beginner').json())==2
    assert [x['likes'] for x in c.get('/courses?is_elective=false&page_size=3').json()]==[24,21,19]
    assert c.get('/courses?is_elective=false&page_size=3&page=2').json()[0]['id']=='databases-postgresql'
    assert c.get('/courses?sort=title').json()==sorted(c.get('/courses').json(),key=lambda x:x['title'])
    assert c.get('/courses?page=0').status_code==422
    assert c.get('/courses?page_size=101').status_code==422
    assert c.get('/courses/unknown').status_code==404
    assert c.post('/courses/unknown/like').status_code==404
    details=c.get('/enrollments').json()
    assert len(details)==6 and all('studentName' in e and 'courseTitle' in e for e in details)
    stats={x['courseId']:x['enrolled'] for x in c.get('/stats/courses').json()}
    assert stats=={'ai-integration':3,'modern-frontend':2,'backend-fastapi':1,'api-design':0,'databases-postgresql':0,'web-security':0}
    r=c.post('/students',json={'name':'Nurlan Abenov','email':'nurlan@example.com'})
    assert r.status_code==201,r.text
    student=r.json()['id']
    r=c.post('/enrollments',json={'courseId':'web-security','studentId':student})
    assert r.status_code==201 and r.json()['enrolledAt']
    assert c.post('/enrollments',json={'courseId':'web-security','studentName':'Old form'}).status_code==422
    with ThreadPoolExecutor(max_workers=6) as pool:
        statuses=list(pool.map(lambda _:c.post('/courses/api-design/like').status_code,range(12)))
    assert statuses==[200]*12,statuses
    assert c.get('/courses/api-design').json()['likes']==23
    cors=c.options('/courses',headers={'Origin':'http://localhost:3000','Access-Control-Request-Method':'GET'})
    assert cors.headers['access-control-allow-origin']=='http://localhost:3000'
with TestClient(app) as restarted:
    assert restarted.get('/courses/api-design').json()['likes']==23
print('PASS: error cases, filters, pagination, JOIN, zero statistics, create, concurrency, persistence, CORS')
'''
            python(api_checks)
            # A separate process proves data is independent of the API process.
            python("from db import SessionLocal\nfrom models import Course\nwith SessionLocal() as s:\n assert s.get(Course,'api-design').likes==23\nprint('PASS: likes persisted in a new Python process')")
            conn.close()
            log("PASS: all eight experiments and all verification checks completed.")
    finally:
        admin.execute(sql.SQL("DROP DATABASE {} WITH (FORCE)").format(sql.Identifier(dbname)))
        admin.close()
        # URLs and temporary paths are not needed in the submitted evidence.
        text = "\n".join(transcript).replace(dbname, "lab7_verify_temporary")
        (RESULTS / "lab7-verification.txt").write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
