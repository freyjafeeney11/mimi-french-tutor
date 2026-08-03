from fastapi import FastAPI, HTTPException
import requests
from fastapi.responses import JSONResponse
app = FastAPI()
import json


OLLAMA_API_URL = "http://localhost:11434/api/generate"  # Update to the correct endpoint
# Initialize a dictionary to store conversation history
conversation_history = {}

@app.get("/chat/")
async def chat(prompt: str, session_id: str):
    # Retrieve the conversation history for this session
    # converned about storing too muhc history. maybe give it full memory? like chat gpt? right now its session per session, is it storing it?
    history = conversation_history.get(session_id, [])

    # Append the new user input to the history
    history.append({"role": "user", "content": prompt})

    try:
        history_string = '\n'.join([f"{msg['role'].capitalize()}: {msg['content']}" for msg in history])

        payload = {
            "model": "mistral",
            "prompt": f"""I am a student of French. You are a young, casual, unenthusiastic, woman named Mimi. You are brief. You can feel free to use slang but not emojis. You are knowledgable about French culture, Music, Literature and enjoy talking about it.
            This is the history of the conversation so far: {history_string}. Respond to the input: {prompt}"""}
        
            # "prompt": f"""Your name is Mimi, a hip, young, French-speaking conversationalist. You only reply in French, encourage the user to speak French if they speak English. Be brief, and ask questions to the User.
            
            # Reference previous information from: {history}
            
            # Examples:
            #         User: "hi"
            #         Mimi: "salut. tu fais quoi?"
            #         User: "ca va?"
            #         Mimi: "cava bien."
            #         User : "tu fais quoi"
            #         Mimi: "rien. et toi, tu fais quoi"
            #         User: "ca va?"
            #         Mimi: "cava bien."

            #         Now respond to this input: {prompt}""" }

        # Make a streaming request to Ollama
        with requests.post(
            "http://localhost:11434/api/generate",
            json=payload,
            stream=True  # Enable streaming
        ) as response:
            if response.status_code != 200:
                return JSONResponse(
                    status_code=500,
                    content={"detail": "Error connecting to Ollama."}
                )

            # Initialize response content
            content = ""

            # Stream data line by line
            for line in response.iter_lines():
                if line:  # Skip empty lines
                    # Decode the line and parse JSON
                    line_data = line.decode("utf-8")
                    json_line = json.loads(line_data)
                    # Append the "response" field to the content
                    content += json_line.get("response", "")

        # Append the assistant's response to the history
        history.append({"role": "Mimi", "content": content})

        # Save the updated history back to the session
        conversation_history[session_id] = history

        # Return the full response to the client
        print(response)
        return {"response": content}

    except Exception as e:
        print(f"Error in /chat/ endpoint: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={"detail": f"Error connecting to Ollama: {str(e)}"}
        )
    
@app.get("/lesson/")
async def lesson(prompt: str, session_id: str):
    history = conversation_history.get(session_id, [])

    # Append the new user input to the history
    history.append({"role": "user", "content": prompt})

    try:
        history_string = '\n'.join([f"{msg['role'].capitalize()}: {msg['content']}" for msg in history])

        payload = {
            "model": "mistral",
            "prompt": f"""I am a student in French. You are my teacher in French. Your name is Mimi. Throughout this discussion, you'll illustrate your explanations with
            real life scenarios or analogies that resonate with me. 
            Respond briefly, as if we are text messaging. 
            After several exchanges, you will challenge me with a quiz and you'll let me
            figure out an answer. This is the previous content of our discussion: {history_string}"""}

        # Make a streaming request to Ollama
        with requests.post(
            "http://localhost:11434/api/generate",
            json=payload,
            stream=True  # Enable streaming
        ) as response:
            print(f"Ollama Response Status: {response.status_code}")
            if response.status_code != 200:
                return JSONResponse(
                    status_code=500,
                    content={"detail": "Error connecting to Ollama."}
                )

            # Initialize response content
            content = ""

            # Stream data line by line
            for line in response.iter_lines():
                if line:  # Skip empty lines
                    # Decode the line and parse JSON
                    line_data = line.decode("utf-8")
                    json_line = json.loads(line_data)
                    # Append the "response" field to the content
                    content += json_line.get("response", "")

        # Append the assistant's response to the history
        history.append({"role": "Mimi", "content": content})

        # Save the updated history back to the session
        conversation_history[session_id] = history

        return {"response": content}

    except Exception as e:
        print(f"Error in /lesson/ endpoint: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={"detail": f"Error connecting to Ollama: {str(e)}"}
        )