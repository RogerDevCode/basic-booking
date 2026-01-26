import os
import requests
import re

def get_env_variable(var_name):
    try:
        with open('.env', 'r') as f:
            for line in f:
                if line.strip().startswith(f"{var_name}="):
                    return line.strip().split('=', 1)[1]
    except FileNotFoundError:
        pass
    return os.environ.get(var_name)

token = get_env_variable('TELEGRAM_BOT_TOKEN')

if not token or token == '123456789:ABCDefGHIjklMNOpqrsTUVwxyz':
    print("Error: TELEGRAM_BOT_TOKEN not found or is default placeholder in .env")
    print("Please set your real Telegram Bot Token in .env")
else:
    try:
        response = requests.get(f"https://api.telegram.org/bot{token}/getMe")
        if response.status_code == 200:
            data = response.json()
            if data.get('ok'):
                bot_username = data['result']['username']
                print(f"Bot Username: {bot_username}")
                print(f"Bot Name: {data['result']['first_name']}")
                print(f"Link: https://t.me/{bot_username}")
            else:
                print(f"Telegram API Error: {data.get('description')}")
        else:
            print(f"HTTP Error: {response.status_code}")
    except Exception as e:
        print(f"Connection Error: {e}")
