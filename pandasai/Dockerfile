FROM python:3.9-slim

WORKDIR /app

# Install git and build dependencies
RUN apt-get update && \
    apt-get install -y git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Clone PandasAI repository
RUN git clone https://github.com/sinaptik-ai/pandas-ai.git .

# Install dependencies
RUN pip install --no-cache-dir -r server/requirements.txt

# Copy environment file
COPY .env server/.env

WORKDIR /app/server

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
