# TDDD80 Projekt

## Poäng:

### Från labbar:
1. Server-labbar inlämnade i tid. (1p)
2. Flutter-labbar inlämnade i tid. (1p)

### Projektet:
3. Gilla informationsobjekt (inklusive undo). (1p)
4. Kommentera informationsobjekt. (1p)
5. Följa andra användares aktivitet, t.ex. att man ser sina vänners inlägg. (1p)
6. Hantera vänner (etablering och terminering av en vänskapsrelation, samt visning av vänners status). (1p)
7. Navigering genom hela appen mha go_router biblioteket (notera att även navbars kan implementeras mha routes). (1 p)
8. Användning av provider fullt ut i hela appen för att hantera uppdatering av innehåll som visas i appen. (1 p)
9. Light vs. dark mode, som t.ex. anpassas efter systeminställningar. (1 p)
10. Tredjeparts-inloggning, t.ex. Google Sign-in (1 p)

### Utvärderingsrapport
11. Rapporten om användbarhetstestet utökas med en tabell som innehåller en uppdelning av de identifierade användbarhetsproblemen enligt allvarlighetsgrad. Tabellen ska ha fyra kolumner. En kolumn för allvarlighetsgraden (låg, medel, hög), en kolumn för beskrivningen av problemet, en kolumn som beskriver problemets påverkan på användbarupplevelsen, en kolumn som beskriver antalet användare som upplevt problemet. (1p)
12. Rapporten om användbarhetstestet utökas med 1 A4-sidas beskrivning och motivering av åtgärdsförslag för de allvarligaste användbarhetsproblemen som identifierats. OBS: kräver nivå 1 (dvs. att föregående punkt är genomförd). (1p)

Totalt 12 poäng.

## Setup

### Förutsättningar
- **Python 3.13**
- **Flutter SDK**
- **Android/IOS Emulator** (eventuellt egen mobil men kan kräva extra setup)

### Backend (Flask)
1. Skapa och aktivera virtuell miljö:
   ```bash
   python -m venv venv
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
      cp backend/.env.example .env # innehåller SECRET_KEY=dev + klient-IDs
      ```  
    - Med egen setup behöver man egna klient-ids

4. Starta backend:
      ```bash
      python server.py # eller: export FLASK_APP=server && flask run
      ```

### Klient (Flutter)
1. Hämta paket:
   ```bash
   flutter pub get
   ```

2. Starta appen
   ```bash
   flutter run
   ```