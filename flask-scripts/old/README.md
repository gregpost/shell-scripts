# FastAPI Terminal Relay

Минимальный FastAPI сервер для удалённого выполнения команд через туннель `localhost.run`.

---

## Содержимое

- `terminal-api-fastapi.py` — FastAPI сервер, принимает POST `/run` с токеном.  
- `stop-terminal-api.sh` — завершает сервер и SSH туннель.  
- `run-terminal-api.sh` — отправка команд на сервер и получение результата.

---

## Запуск сервера

```bash
python3 terminal-api-fastapi.py
