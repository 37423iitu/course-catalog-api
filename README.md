# course-catalog-api

Лабораторная 7 по Advanced Web Technologies. API каталога курсов на FastAPI,
SQLAlchemy 2.1, PostgreSQL и Alembic. Данные сохраняются в PostgreSQL, схема
создаётся цепочкой миграций `0001 → 0002`. Проверка выполнена 5 ноября 2026 года
на Python 3.12, PostgreSQL 17.4, SQLAlchemy 2.1.8 и Alembic 1.20.1.

## How to run

Требуются Python 3.11+ и PostgreSQL 16+. Все команды выполняются из этой папки.

### Быстрый запуск на Windows

```powershell
powershell -ExecutionPolicy Bypass -File .\run-lab7.ps1
```

Скрипт создаёт окружение при необходимости, устанавливает зависимости,
поднимает отдельный PostgreSQL на `127.0.0.1:55437`, применяет миграции и
заполняет только пустой каталог. При повторном запуске записи и лайки сохраняются.
База Lab 6 не изменяется. PostgreSQL по умолчанию находится в
`C:\Program Files\PostgreSQL\17\bin`; другой путь можно передать скрипту
`start-local.ps1` через `-PgBin`. Для проверки без запуска API:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-lab7.ps1 -CheckOnly
```

Swagger: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs).
Остановить API: Ctrl+C. Остановить отдельный PostgreSQL:

```powershell
powershell -ExecutionPolicy Bypass -File .\start-local.ps1 -Stop
```

### Ручной запуск с обычным PostgreSQL

Один раз от имени суперпользователя `postgres` создайте роль и базу:

```sql
CREATE ROLE catalog_app LOGIN PASSWORD 'change-me';
CREATE DATABASE course_catalog OWNER catalog_app;
```

Далее в PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env
# При необходимости измените адрес, порт и пароль в .env.
.\.venv\Scripts\python.exe -m alembic upgrade head
$env:PGPASSWORD = 'change-me'
& 'C:\Program Files\PostgreSQL\17\bin\psql.exe' -X -h localhost -U catalog_app -d course_catalog -v ON_ERROR_STOP=1 -f seed.sql
Remove-Item Env:PGPASSWORD
.\.venv\Scripts\python.exe check_db.py
.\.venv\Scripts\python.exe check_models.py
.\.venv\Scripts\python.exe -m alembic check
.\.venv\Scripts\python.exe -m uvicorn main:app --reload
```

`.env` исключён из Git; `.env.example` содержит только учебный адрес. Переменная
окружения `DATABASE_URL` имеет приоритет над `.env`. Для SQL-логов добавьте
`SQL_ECHO=true` в локальный `.env`; по умолчанию логирование параметров выключено.
Учебный пароль `change-me` предназначен для локальной лабораторной.

`seed.sql` очищает три таблицы и сбрасывает identity. Его повторный запуск
восстанавливает исходные 6 курсов, 3 студентов, 6 записей и исходные лайки.
Запускайте его только когда хотите сбросить учебные данные.

Если подключаете уже существующую базу Lab 6, сначала убедитесь, что её схема
соответствует `0001` и у таблиц есть нужные имена ограничений. Затем выполните
`python -m alembic stamp 0001` и `python -m alembic upgrade head`.
Используйте именно `0001`: `stamp head` в финальном проекте отметил бы `0002`,
но не создал бы колонку `level`. Для пустой базы нужен `upgrade`, а не `stamp`.

## What changed in the API

- Курсы, студенты, записи и лайки хранятся в базе и переживают перезапуск API.
- `POST /enrollments` принимает `{"courseId":"web-security","studentId":4}`.
  Студент создаётся заранее через `POST /students` с `name` и `email`.
- `GET /enrollments` использует JOIN и возвращает `courseTitle`, `studentName`
  и `enrolledAt` вместе с идентификаторами.
- `GET /stats/courses` использует LEFT JOIN и считает `Enrollment.id`, поэтому
  курсы без записей имеют 0. Исходные результаты: ai-integration — 3,
  modern-frontend — 2, backend-fastapi — 1, остальные — 0.
- У курса появилось обязательное поле `level`. Два элективных курса получают
  `beginner`, остальные — `intermediate`. `advanced` предусмотрен как уровень;
  отдельного CHECK для списка уровней в обязательной части задания нет.
- `GET /courses` поддерживает `is_elective`, `level`, `sort=title`, `page`,
  `page_size`. По умолчанию сортирует по лайкам убыванию и затем по id.
  Пагинация проверяет `page >= 1`, `1 <= page_size <= 100`.
- `POST /courses/{course_id}/like` увеличивает лайки одним UPDATE RETURNING.
- Занятый email и повторная запись дают 409, отсутствующий курс или студент —
  404. Короткое имя и неверный email отклоняются Pydantic с 422.
- JSON использует camelCase; схемы также принимают имена полей в snake_case.

Фронтенд Lab 5 сохранён. Его форма отправляет `studentName`, поэтому по новому
контракту получает 422. Для Lab 7 запросы проверяются в Swagger.

## Migrations

В активированном окружении можно использовать `alembic`; без активации —
`.\.venv\Scripts\python.exe -m alembic`.

| Команда | Действие |
|---|---|
| `alembic upgrade head` | Применяет недостающие миграции |
| `alembic downgrade -1` | Откатывает последнюю миграцию |
| `alembic current` | Показывает версию базы |
| `alembic heads` | Показывает конечные ревизии; итоговая одна — 0002 |
| `alembic history` | Показывает историю 0001 → 0002 |
| `alembic revision --autogenerate -m "text"` | Создаёт черновик разницы моделей и базы |
| `alembic check` | Завершается ошибкой при расхождении схемы и моделей |
| `alembic upgrade 0001:0002 --sql` | Печатает SQL без выполнения |
| `alembic stamp head` | Только записывает конечную версию, не меняя схему |
| `alembic stamp 0001` | Отмечает существующую схему Lab 6 перед применением 0002 |

`0001` создаёт три таблицы, CHECK, UNIQUE, внешние ключи, identity и индекс
`enrollments_student_id_idx`. `0002` добавляет nullable `level`, заполняет CASE
по `is_elective`, затем устанавливает NOT NULL. Дефолта у `level` нет.
Имена ограничений в миграциях обёрнуты в `op.f`, чтобы naming_convention
повторно не добавила префикс и суффикс. Миграции не импортируют текущие ORM-модели.

## Experiment log

Все восемь экспериментов воспроизведены скриптом `verify_lab7.py` в отдельной
временной базе и копии исходников. Ни одна поломка не оставлена в рабочем коде.
Полная фактическая запись: [results/lab7-verification.txt](results/lab7-verification.txt).
SQL миграции: [results/migration-0002.sql](results/migration-0002.sql).

| № | Что изменено | Что наблюдалось | Причина | Исправление |
|---|---|---|---|---|
| 1 | uq заменён на `%(table_name)s_%(column_0_name)s_unique` | Только в моделях: `students_email_unique`, `enrollments_course_id_unique`; в базе остались имена с `_key` | Имена не совпадают, а составной ключ потерял вторую колонку в имени | Восстановлен `%(table_name)s_%(column_0_N_name)s_key`; обе разницы — none |
| 2 | Убран min_length; отправлено имя N | HTTP 500; прямой INSERT подтвердил `CheckViolation students_name_check` | Pydantic пропустил запрос, CHECK отказал, неизвестное ограничение не преобразуется в HTTP | Восстановлен `Field(min_length=2)`; снова 422 |
| 3 | Ключ словаря изменён на students_email_uniq | Занятый email дал 500 вместо 409 | Драйвер сообщает students_email_key, которого нет в испорченном словаре | Восстановлен точный ключ; снова 409 |
| 4 | У title убран NOT NULL, затем тип изменён на varchar(100) | `alembic check` сообщил `modify_nullable`, затем `modify_type` | Модель ожидает обязательный Text | Возвращены NOT NULL и text; check чистый |
| 5 | 0002 добавляет сразу `level TEXT NOT NULL` | `NotNullViolation`; текущая ревизия осталась 0001 | Для существующих шести строк нет значения нового поля; транзакционный DDL откатил изменение | Nullable → UPDATE CASE → NOT NULL; upgrade успешен |
| 6 | Убран import models из env.py | Autogenerate предложил три `op.drop_table` и удаление индекса | Base.metadata пустая, таблицы выглядят лишними | Опасный черновик НЕ применялся; удалён, импорт восстановлен |
| 7 | Student.phone добавлен без миграции | check завершился ошибкой, обнаружил `add_column students.phone` | Модель опережает схему | Экспериментальное поле удалено; check чистый |
| 8 | От 0002 созданы 0003 и 0004 | Два head; `upgrade head` отказал с Multiple head revisions | Две ветки без единой конечной ревизии | Merge 0005 дал один head; затем три экспериментальных файла удалены, итоговый head — 0002 |

Дополнительно проверены отказ DuplicateTable при upgrade существующей схемы
и принятие её через stamp 0001; автогенерация 0001 на пустой базе; повторный seed;
upgrade → downgrade → upgrade; полное создание схемы с base; JOIN; фильтры;
пагинация; CORS; создание студента и записи; все пять ошибок из задания.
Двенадцать одновременных лайков увеличили api-design с 11 до 23. Значение 23
подтверждено новым Python-процессом после завершения HTTP-проверок.

Повторить эксперименты после запуска локального PostgreSQL:

```powershell
.\.venv\Scripts\python.exe verify_lab7.py
```

Скрипт создаёт базу с уникальным именем `lab7_verify_...`, меняет только её
и удаляет именно её в конце. Основная база course_catalog не очищается.
Для пяти HTTP-проверок при запущенном API:

```powershell
.\.venv\Scripts\python.exe try_errors.py
# Ожидается: 5 of 5 as expected. Нужны исходные seed-данные.
```

## Decisions

1. **Имена ограничений и commit.** SQLSTATE 23505 одинаков для разных UNIQUE:
   по нему нельзя выбрать сообщение о занятом email или повторной записи.
   `exc.orig.diag.constraint_name` однозначно определяет правило. Предварительный
   SELECT не гарантирует уникальность: другой запрос может вставить строку
   между проверкой и INSERT. Поэтому сохраняем и обрабатываем IntegrityError
   после commit; сессия явно откатывается. Неизвестная ошибка повторно поднимается.
2. **Атомарный лайк.** При чтении числа в программу два запроса могут прочитать
   11 и оба записать 12. `UPDATE ... SET likes = likes + 1` выполняет сложение
   в PostgreSQL; блокировка строки последовательно применяет оба обновления.
   RETURNING возвращает изменённый курс. Commit делает результат постоянным.
3. **Три шага в 0002.** У старых строк нет level, поэтому добавить сразу NOT NULL
   нельзя. Сначала разрешаем NULL, заполняем старые строки, затем запрещаем NULL.
   Весь переход транзакционный. Downgrade удаляет поле и его значения; повторный
   upgrade вычисляет уровни по исходному правилу, но не восстановит ручные правки.

## Migration 0002 self-check

| Критерий | Результат |
|---|---|
| Goal and steps | Да. Только level: ADD nullable, UPDATE CASE, SET NOT NULL |
| Data | Да. Все 6 существующих курсов сохранены; NULL отсутствуют |
| Renames and drops | Да. В upgrade нет переименований и удалений; downgrade удаляет level |
| Rollback | Да. Откат испытан. Нет, без резервной копии нельзя считать его безопасным для ручных уровней: они теряются |
| Verification | Да. SQL прочитан; upgrade/downgrade/upgrade и создание с base прошли; alembic check чистый |
| History | Да. Одна конечная ревизия 0002; модель, схема ответа, фильтр, seed и миграция в одном коммите |
| Application | Да. CourseOut возвращает level, фильтр работает, seed обновлён; студент и запись используют новый контракт |

Источники по библиотекам: [SQLAlchemy 2.1](https://docs.sqlalchemy.org/en/21/intro.html)
и [Alembic autogenerate](https://alembic.sqlalchemy.org/en/latest/autogenerate.html).

Результат сдаётся как репозиторий course-catalog-api. Новая работа находится
в ветке `codex/lab7-sqlalchemy`; публикация на GitHub выполняется отдельно.
Материалы Lab 6 сохранены в `lab6/`.
