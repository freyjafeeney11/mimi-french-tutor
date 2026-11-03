from transformers import GPT2Tokenizer
from tokenizers import Tokenizer, models, trainers, pre_tokenizers


def train_tokenizer(corpus_files=["corpus.txt"], vocab_size=5000, min_frequency=2):
    tokenizer = Tokenizer(models.BPE())
    tokenizer.pre_tokenizer = pre_tokenizers.Whitespace()

    trainer = trainers.BpeTrainer(vocab_size=vocab_size, min_frequency=min_frequency)
    tokenizer.train(corpus_files, trainer=trainer)

    tokenizer.save("my_tokenizer.json")
    print("Tokenizer saved as my_tokenizer.json")


def load_pretrained_tokenizer():
    tokenizer = GPT2Tokenizer.from_pretrained("gpt2")
    tokenizer.save_pretrained("my_tokenizer.json")
    print("Pre-trained tokenizer saved as my_tokenizer.json")


if __name__ == "__main__":
    train_tokenizer()
    # load_pretrained_tokenizer()
