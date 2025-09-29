# File: chatgpt_bridge.py
# Purpose: Получать промпт через Flask API, отправлять его в браузер на chatgpt.com
#          и возвращать результат пользователю. Использует Selenium для Chrome.
#
# Требования:
#   pip install flask selenium pyperclip
#   Установленный Chrome и chromedriver в PATH

import time, pyperclip
from flask import Flask, request, jsonify
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys

app = Flask(__name__)

driver = None

def init_browser():
    global driver
    if driver is None:
        options = webdriver.ChromeOptions()
        options.add_argument("--user-data-dir=/tmp/chrome-profile")  # сохранить сессию
        options.add_argument("--start-maximized")
        driver = webdriver.Chrome(options=options)
        driver.get("https://chat.openai.com/")
        print(">>> Войдите в аккаунт вручную один раз, потом сервер будет использовать эту сессию.")

@app.route("/ai", methods=["POST"])
def send_ai_prompt():
    init_browser()
    data = request.get_json(force=True)
    prompt = data.get("prompt")
    if not prompt:
        return jsonify({"error":"No prompt"}), 400

    try:
        textarea = driver.find_element(By.TAG_NAME, "textarea")
        textarea.clear()
        textarea.send_keys(prompt)
        textarea.send_keys(Keys.ENTER)
    except Exception as e:
        return jsonify({"error": f"Cannot send prompt: {e}"}), 500

    result = ""
    for _ in range(120):  # ждём до 120 сек
        try:
            copy_btns = driver.find_elements(By.XPATH, "//button[contains(., 'Copy')]")
            if copy_btns:
                copy_btns[0].click()
                time.sleep(1)
                text = pyperclip.paste()
                if "<<<END>>>" in text:
                    result = text
                    break
        except Exception:
            pass
        time.sleep(1)

    if not result:
        return jsonify({"error":"Timeout waiting for AI response"}), 504

    return jsonify({"response": result})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=4000)
