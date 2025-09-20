Poetry-based local development

This project supports Poetry for managing the Python environment in `functions/`.

Quick start (macOS / zsh):

1. Install Poetry if you don't have it:

```bash
curl -sSL https://install.python-poetry.org | python3 -
```

2. Create the virtual environment and install deps:

```bash
cd functions
poetry install
poetry shell
```

3. Run tests and type check:

```bash
pytest -q
mypy .
```

4. Run Azure Functions locally (inside poetry shell):

```bash
export SIGNING_SECRET="test-secret"
func start
```

Note: `requirements.txt` is kept for environments that prefer pip. `pyproject.toml` is the recommended workflow for development.
