# src/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from .api.routes import router

app = FastAPI(
    title="AgroChain API",
    description="API para o sistema AgroChain de seguros agrícolas baseados em blockchain.",
    version="1.0.0",
    docs_url="/api/docs",  # Swagger UI
    redoc_url="/api/redoc"  # ReDoc
)

# ⚠️ Ajuste isso para a origem que você deseja permitir
origins = [
    "http://localhost:4200",
    "http://localhost:3000",  # seu frontend Angular
]

# Configurar CORS para Angular
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,  # ou ['*'] para tudo (em desenvolvimento)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Redireciona "/" para "/api/docs"
@app.get("/")
def root():
    return RedirectResponse(url="/api/docs")

app.include_router(router, prefix="/api")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.1", port=8000, reload=True)
