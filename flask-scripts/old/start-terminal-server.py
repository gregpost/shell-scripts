#!/usr/bin/env python3
"""
File: start-terminal-server.py

FastAPI Terminal Relay

- Receives commands via POST /run
- Executes commands safely:
    - обычные команды от пользователя
    - sudo команды только из белого списка
"""


import os
import subprocess
from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
import secrets

# ---------------- CONFIG ----------------
API_TOKEN = "ef43818d21a0fc2f3c5d834e29adae27"
ALLOWED_SUDO = [
    "systemctl restart some-service",
    "apt update"
]
APP_PORT = 3000

# ---------------- FastAPI ----------------
app = FastAPI()

class CommandRequest(BaseModel):
    cmd: str

def run_command(cmd: str):
    """Execute command safely."""
    use_sudo = cmd.startswith("sudo ")
    if use_sudo:
        # проверка, разрешена ли sudo команда
        cmd_check = cmd[len("sudo "):].strip()
        if cmd_check not in ALLOWED_SUDO:
            raise HTTPException(status_code=403, detail="Sudo command not allowed")
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, executable="/bin/bash"
        )
        return {"output": result.stdout + result.stderr}
    except Exception as e:
        return {"output": str(e)}

@app.post("/run")
async def run(request: Request, data: CommandRequest):
    # Проверка токена
    auth = request.headers.get("Authorization", "")
    if auth != f"Bearer {API_TOKEN}":
        raise HTTPException(status_code=401, detail="Unauthorized")

    return run_command(data.cmd)

# ---------------- Run server ----------------
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=APP_PORT)
