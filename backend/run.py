import uvicorn

if __name__ == "__main__":
    # Start the backend server on 0.0.0.0:8000
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
