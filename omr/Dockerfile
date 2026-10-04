FROM python:3.12-slim
WORKDIR /omr
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
ENV PYTHONPATH=/omr
EXPOSE 8000
CMD ["uvicorn", "omr.server:app", "--host", "0.0.0.0", "--port", "8000"]
