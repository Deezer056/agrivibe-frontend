# syntax=docker/dockerfile:1
# AgriVibe Gradio frontend. Same multi-stage pattern as the backend.
FROM ghcr.io/astral-sh/uv:0.13.7 AS uv

FROM python:3.12-slim-bookworm AS build
COPY --from=uv /uv /usr/local/bin/uv
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=never UV_PROJECT_ENVIRONMENT=/app/.venv
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv uv sync --locked --no-dev

FROM python:3.12-slim-bookworm
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin app
COPY --from=build /app/.venv /app/.venv
WORKDIR /app
COPY app.py settings.py ./
COPY api ./api
COPY contracts ./contracts
COPY handlers ./handlers
COPY theme ./theme
# GRADIO_SERVER_NAME: listen on every interface, so the load balancer (or your browser) can reach it.
# AGRIVIBE_API: the backend. On ECS both containers share the task's localhost.
ENV PATH=/app/.venv/bin:$PATH PYTHONUNBUFFERED=1 HOME=/tmp \
    GRADIO_SERVER_NAME=0.0.0.0 GRADIO_SERVER_PORT=7860 GRADIO_ANALYTICS_ENABLED=False \
    AGRIVIBE_API=http://127.0.0.1:8000
USER app
EXPOSE 7860
HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:7860/', timeout=2)"]
CMD ["python", "app.py"]