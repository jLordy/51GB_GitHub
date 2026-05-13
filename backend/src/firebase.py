import os
import json
import firebase_admin
from dotenv import load_dotenv
from firebase_admin import credentials, firestore

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '.env'))

def get_firebase_app() -> firebase_admin.App:
    try:
        # Check if already initialized
        return firebase_admin.get_app()
    except ValueError:
        pass

    raw_creds = os.getenv("FIREBASE_CREDENTIALS")
    if not raw_creds:
        raise EnvironmentError("FIREBASE_CREDENTIALS missing in .env")

    # If the string starts with '{', it's raw JSON; otherwise, it's a file path
    if raw_creds.strip().startswith('{'):
        cred_dict = json.loads(raw_creds)
    else:
        with open(raw_creds, 'r') as f:
            cred_dict = json.load(f)

    cred = credentials.Certificate(cred_dict)
    return firebase_admin.initialize_app(cred)

def get_firestore_client():
    """This is the function your router is looking for"""
    app = get_firebase_app()
    return firestore.client(app=app)