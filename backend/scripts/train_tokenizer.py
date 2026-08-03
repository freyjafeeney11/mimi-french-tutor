from transformers import GPT2Tokenizer
from tokenizers import Tokenizer, models, trainers, pre_tokenizers

def train_tokenizer(corpus_files=["corpus.txt"], vocab_size=5000, min_frequency=2):
    # Initialize tokenizer model with BPE (Byte Pair Encoding)
    tokenizer = Tokenizer(models.BPE())

    # Set pre-tokenizer to split on whitespace
    tokenizer.pre_tokenizer = pre_tokenizers.Whitespace()

    # Initialize trainer
    trainer = trainers.BpeTrainer(vocab_size=vocab_size, min_frequency=min_frequency)

    # Train the tokenizer on your corpus files
    tokenizer.train(corpus_files, trainer=trainer)

    # Save the trained tokenizer
    tokenizer.save("my_tokenizer.json")
    print("Tokenizer saved as my_tokenizer.json")

def load_pretrained_tokenizer():
    # You can also use the pre-trained GPT-2 tokenizer
    tokenizer = GPT2Tokenizer.from_pretrained("gpt2")
    tokenizer.save_pretrained("my_tokenizer.json")
    print("Pre-trained tokenizer saved as my_tokenizer.json")

if __name__ == "__main__":
    # Option 1: Train a tokenizer from your data
    train_tokenizer()

    # Option 2: Use a pre-trained tokenizer and save it
    # load_pretrained_tokenizer()
