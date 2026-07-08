import uvicorn

if __name__ == "__main__":
    # FastAPI uygulamasını 127.0.0.1:8000 adresinde ayağa kaldırıyoruz.
    # reload=True sayesinde kod değişiklikleri anında yansır.
    uvicorn.run("app.main:app", host="127.0.0.1", port=8000, reload=True)
