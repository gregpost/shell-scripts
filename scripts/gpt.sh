#!/bin/bash

# Check if python and openai are installed
if ! command -v python3 &> /dev/null; then
    echo "python3 not found, please install Python 3."
    exit 1
fi

if ! python3 -c "import openai" &> /dev/null; then
    echo "openai python package not found, installing..."
    pip install openai
fi

# Temporary Python script to handle conversation
read -r -d '' PYTHON_SCRIPT << EOF
import openai
import sys
from openai import OpenAI

client = OpenAI(api_key="$OPENAI_API_KEY")

print("ChatGPT CLI session (openai>=1.0). Type 'exit' or Ctrl+C to quit.")

while True:
    try:
        prompt = input("You: ")
        if prompt.strip().lower() == "exit":
            break

        response = client.chat.completions.create(
            model="gpt-4o",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=150
        )

        print("ChatGPT:", response.choices[0].message.content.strip())
    except KeyboardInterrupt:
        print("\nExiting...")
        sys.exit(0)
    except Exception as e:
        print("Error:", e)
EOF

python3 -c "$PYTHON_SCRIPT"
