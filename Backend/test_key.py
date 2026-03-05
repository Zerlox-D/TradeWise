import os
from dotenv import load_dotenv
from google import genai

# 1. Force Python to read the .env file
load_dotenv()

# 2. Grab the key
my_key = os.environ.get("GEMINI_API_KEY")
print(f"My key starts with: {my_key[:10]}...") 

# 3. Test the connection
try:
    client = genai.Client()
    response = client.models.generate_content(
        model='gemini-2.5-flash',
        contents='Reply with the word "SUCCESS" if you can hear me.'
    )
    print("AI Says:", response.text)
except Exception as e:
    print("Error:", e)