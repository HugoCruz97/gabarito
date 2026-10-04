FROM python:3.12-slim
WORKDIR /omr
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
ENV PYTHONPATH=/omr
