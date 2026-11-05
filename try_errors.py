import argparse
import httpx

CASES = [
    ("email already taken", "/students", {"name": "Aigerim Two", "email": "aigerim@example.com"}, 409),
    ("already enrolled", "/enrollments", {"courseId": "ai-integration", "studentId": 3}, 409),
    ("unknown course", "/enrollments", {"courseId": "nope", "studentId": 3}, 404),
    ("unknown student", "/enrollments", {"courseId": "web-security", "studentId": 999}, 404),
    ("name too short", "/students", {"name": "N", "email": "n@example.com"}, 422),
]

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://127.0.0.1:8000")
    args = parser.parse_args()
    failed = 0
    with httpx.Client(base_url=args.base, timeout=10) as client:
        for title, path, body, expected in CASES:
            response = client.post(path, json=body)
            ok = response.status_code == expected
            failed += not ok
            print(f"{'ok' if ok else 'FAIL':4} {title:<20} {response.status_code} {response.text[:80]}")
    print(f"{len(CASES) - failed} of {len(CASES)} as expected")
    raise SystemExit(bool(failed))
