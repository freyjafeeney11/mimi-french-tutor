from transformers import AutoTokenizer, AutoModelForCausalLM

model_name = "mistralai/mistral-7b" 

tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForCausalLM.from_pretrained(
    model_name, 
    device_map="auto",  # Automatically uses GPU if available
    torch_dtype=torch.float16  # Uses half-precision for faster GPU performance
)

# Generate a response
prompt = "Hello, how are you?"
inputs = tokenizer(prompt, return_tensors="pt").to("cuda")
outputs = model.generate(inputs["input_ids"], max_length=50)
print(tokenizer.decode(outputs[0], skip_special_tokens=True))
