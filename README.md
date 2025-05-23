# Projekt: Social Mobilapp - Setup

## Förutsättningar
- **Python 3.13**
- **venv** för virtuell miljö
- **Flutter SDK**
- **Android/IOS Emulator** (eventuellt egen mobil men kan kräva extra setup)

## Backend (Flask)
1. Skapa och aktivera virtuell miljö:
   ```bash
   python3.13 -m venv venv
   source venv/bin/activate   # macOS/Linux
   venv\Scripts\activate    # Windows
   ```  
2. Installera alla python libraries:
   ```bash
   pip install -r requirements.txt
   ```  
3. Hantera miljövariabler:
    - För demo:
      ```bash
      cp .env.test .env
      ```  
    - Med egen setup behöver man egna klient-ids

4. Starta backend:
    - Alternativt:
      ```bash
      flask run
      ```

## Klient (Flutter)
1. Hämta paket:
   ```bash
   flutter pub get
   ```
3. Förbered enhet som ska köra appen med simulatorer eller egen mobil.

2. Starta appen i demo-läge/mock-login
   ```bash
   flutter run --dart-define=MOCK_LOGIN=true
   ```