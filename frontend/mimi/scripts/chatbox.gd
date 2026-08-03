extends Control

@onready var chat_display = $VBoxContainer/ChatDisplay
@onready var input_field = $VBoxContainer/InputField
@onready var send_button = $VBoxContainer/SendButton
@onready var mode_toggle = $VBoxContainer/ModeToggle  # Assume ModeToggle is a CheckBox in the UI

var backend_url = "http://127.0.0.1:8000/"
var is_lesson_mode = false  # Default mode is conversational
var session_id = ""  # Define a session ID variable


func _ready():
	# Connect button and toggle actions
	send_button.pressed.connect(self._on_send_pressed)
	mode_toggle.toggled.connect(self._on_mode_toggled)
	session_id = generate_session_id()

func generate_session_id() -> String:
	# Combine a random number with a unique prefix
	return "session_" + str(randi())

# Handle toggle mode changes
func _on_mode_toggled(checked):
	is_lesson_mode = checked
	var mode = "Lesson Mode" if is_lesson_mode else "Conversational Mode"
	chat_display.text += "\n[Switched to " + mode + "]"

# Trigger action on pressing the send button
func _on_send_pressed():
	var user_text = input_field.text.strip_edges()
	if user_text == "":
		return

	chat_display.text += "\nYou: " + user_text
	input_field.text = ""  # Clear input field

	# Choose appropriate request based on current mode
	if is_lesson_mode:
		_send_lesson_request(user_text)
	else:
		_send_chat_request(user_text)

func _send_chat_request(prompt):
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._on_chat_request_completed)

	var url = "http://127.0.0.1:8000/chat/?prompt=" + url_encode(prompt) + "&session_id=" + session_id
	print("Chat URL: ", url)
	http_request.request(url)

func _send_lesson_request(prompt):
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._on_chat_request_completed)

	var url = "http://127.0.0.1:8000/chat/?prompt=" + url_encode(prompt) + "&session_id=" + session_id
	print("lesson URL: ", url)
	http_request.request(url)


# doesnt work with question marks yet
func url_encode(input: String) -> String:
	var encoded = ""
	for i in range(input.length()):
		var char = input[i]
		# Check if the character is alphanumeric or one of the safe characters
		if (char >= "A" and char <= "Z") or (char >= "a" and char <= "z") or (char >= "0" and char <= "9") or char in "-_.~":
			encoded += char  # Safe characters are added as-is
		elif char == " ":  # Explicitly handle spaces
			encoded += "%20"  # Replace spaces with %20
		else:
			# Convert the character to its hexadecimal representation
			var hex_value = str(char.to_utf8()[0], 16).pad_zeros(2).to_upper()  # Convert to hex
			encoded += "%" + hex_value
	return encoded



func _on_chat_request_completed(result, response_code, headers, body):
	if response_code == 200:  # Successful response
		var response = JSON.parse_string(body.get_string_from_utf8())
		if typeof(response) == TYPE_DICTIONARY and response.has("response"):
			chat_display.text += "\nMimi: " + response["response"]
		else:
			chat_display.text += "\nMimi: [Error: Invalid response from server]"
	else:
		chat_display.text += "\nMimi: [Error: Failed to connect to server. Response code: %s]" % response_code


# Handle translation response
func _on_lesson_request_completed(result, response_code, headers, body):
	if response_code == 200:  # Successful response
		var response = JSON.parse_string(body.get_string_from_utf8())
		if typeof(response) == TYPE_DICTIONARY and response.has("response"):
			chat_display.text += "\nMimi: " + response["response"]
		else:
			chat_display.text += "\nMimi: [Error: Invalid response from server]"
	else:
		chat_display.text += "\nMimi: [Error: Failed to connect to server. Response code: %s]" % response_code
