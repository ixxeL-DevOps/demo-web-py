import uvicorn
from fastapi import FastAPI

# Créer une instance de l'application FastAPI
app = FastAPI()

# Définir une route pour gérer les requêtes GET sur '/'
@app.get("/")
async def read_root():
    return {"message": "Bienvenue sur le serveur web new methode git write back SUCCESS 2!"}

if __name__ == "__main__":
    config = uvicorn.Config(app, port=8080, log_level="info")
    server = uvicorn.Server(config)
    server.run()

