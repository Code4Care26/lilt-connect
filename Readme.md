# Hackatron — Gestione volontari LILT

> Piattaforma unica per pianificare le attività degli ambulatori e degli eventi LILT,
> coinvolgere i volontari, e **tracciare automaticamente le ore donate** trasformandole
> in dati utili per gestione, rendicontazione e racconto dell'impatto sociale.

---

## 1. Contesto

**LILT** (Lega Italiana per la Lotta contro i Tumori) coordina circa **200 volontari**
che operano negli ambulatori e durante eventi sul territorio. Oggi la pianificazione
avviene su fogli (Excel/cartacei) compilati a mano dallo staff — vedi gli esempi in
[`docs/`](docs/):

- **`turni_maggio.jpeg`** — griglia settimanale Mattina/Pomeriggio × Mansione/Volontario
  (es. mansione *Telefono* → volontari *Barbara Car + Laura C*).
- **`Calendario 22_26 giugno.jpeg`** — "Presenze Volontari Spazio Arcella": per ogni
  giorno e fascia, medici e volontari con orario d'ingresso (es. *Lina dalle 8.45*).

Questi fogli sono il **punto di partenza da digitalizzare**.

## 2. La domanda di progetto

> Come possiamo permettere a 200 volontari di:
> - vedere la pianificazione settimanale degli ambulatori,
> - candidarsi autonomamente agli eventi e alle attività,
> - registrare automaticamente la loro partecipazione,
> - e trasformare il tempo donato in dati utili per gestione, rendicontazione e impatto sociale?

**Tema:** gestione turni ambulatori · logistica · eventi + consuntivo ore di volontariato
per aree tematiche.

## 3. Attori coinvolti

Tre categorie di persone gravitano attorno alla piattaforma. Si distinguono per
**relazione con LILT**, **cosa fanno nel sistema** e **cosa possono vedere** — quest'ultimo
punto è critico dato il [vincolo di privacy](#71-sostituire-whatsapp--privacy-by-design-).

### 3.1 Staff LILT
**Chi:** coordinatori/dipendenti che organizzano l'attività. Pochi, uso frequente e intensivo.

- **Fa:** crea turni ricorrenti, pubblica il calendario eventi, **assegna** i volontari,
  **sceglie** gli assegnatari tra le candidature, gestisce assenze/sostituzioni, invia
  comunicazioni mirate, genera la **rendicontazione ore**.
- **Vede:** visibilità ampia sui dati di coordinamento (anagrafica volontari, disponibilità,
  presenze) — limitata a ciò che serve a coordinare.
- **Device:** prevalentemente desktop.

### 3.2 Volontari
**Chi:** i ~200 iscritti **formali**, eterogenei per età e dimestichezza digitale.
Si articolano in tre profili operativi — vedi [§4](#4-le-tre-tipologie-di-volontario).

- **Fa:** consulta i propri turni, **si candida** agli eventi, **segnala assenze**,
  **conferma la presenza**; riceve solo le comunicazioni che lo riguardano.
- **Vede:** **solo i propri dati** e ciò che gli è assegnato — mai i contatti o i dati
  degli altri volontari.
- **Device:** mobile-first.
- **Rendicontazione:** sono il soggetto del **consuntivo ore donate**.

### 3.3 Simpatizzanti
**Chi:** il bacino **esterno** vicino a LILT — potenziali volontari, sostenitori,
partecipanti occasionali. **Non** sono volontari formali.

- **Fa:** consulta gli **eventi pubblici** (raccolta fondi, Pigiama Run, point di
  sensibilizzazione), può **manifestare interesse / candidarsi** a iniziative aperte,
  riceve comunicazioni su attività pubbliche.
- **Vede:** **solo contenuti pubblici** — nessun accesso ai turni degli ambulatori
  né ai dati interni.
- **Ruolo strategico:** sono un **imbuto di ingaggio** → un simpatizzante che partecipa
  con continuità può **diventare volontario**. Il sistema dovrebbe supportare questa
  transizione (`simpatizzante → volontario`) e, dove sensato, contabilizzarne le ore
  donate agli eventi.

> 💡 **Implicazione di design:** i tre attori non sono solo "permessi diversi" ma definiscono
> un **modello di autorizzazione a livelli** — pubblico (simpatizzante) ⊂ riservato
> (volontario, solo i propri dati) ⊂ coordinamento (staff). E un **ciclo di vita** della
> persona, da simpatizzante a volontario, che attraversa questi livelli.

## 4. Le tre tipologie di volontario

LILT gestisce tre profili di volontario con flussi operativi diversi.

### 4.1 Volontario **ambulatori**
Attività: **Accettazione utenti** · **CUP** (prenotazioni).

Turni **programmati e ricorrenti**, assegnati dallo staff LILT, che specificano:
orari · date · tipologia di incarico/ambulatorio.

Problemi da risolvere:
- comunicazione a tutti i volontari;
- gestione di **assenze, sostituzioni e presenze**.

### 4.2 Volontario **eventi e iniziative**
Attività: **Tour della Prevenzione** · **eventi di raccolta fondi** · **altro**
(Pigiama Run, Festa del volontariato, point di sensibilizzazione…).

Ricevono un **calendario eventi** (tipologia · luogo · data · orario) a cui si possono
**candidare liberamente**; lo staff LILT decide poi gli assegnatari e comunica le scelte.

Problemi da risolvere:
- raccogliere le adesioni;
- tenere traccia anche di **chi si è candidato ma non è stato scelto**;
- comunicare a tutti gli eventi assegnati;
- inviare comunicazioni operative **solo a chi è assegnato** a quel singolo evento.

### 4.3 Volontario **logistica**
Attività unica: **logistica**.

Turni **programmati e ricorrenti** assegnati dallo staff (orari · date).

Problemi da risolvere:
- comunicazione a tutti i volontari;
- gestione di **assenze, sostituzioni e presenze**.

## 5. Obiettivi generali

1. **Strumento unico** per pianificare le attività, coinvolgere i volontari in modo
   semplice e tracciare automaticamente partecipazione e ore svolte.
2. **Valorizzare l'impatto** del volontariato.
3. Poter raccontare che *"i volontari nel 2026 hanno donato **xxx** ore di servizio alla comunità"*.

## 6. Sintesi: due modelli operativi

I tre profili si riducono a **due pattern di pianificazione** che il sistema deve unificare:

| Pattern | Profili | Chi decide il turno | Stato del volontario sul turno |
|---------|---------|---------------------|--------------------------------|
| **Assegnazione (push)** | Ambulatori, Logistica | lo staff assegna | assegnato → presente / assente / sostituito |
| **Candidatura (pull)** | Eventi e iniziative | il volontario si candida, lo staff sceglie | candidato → assegnato / non assegnato → presente / assente |

> ⚠️ **Requisito non banale:** lo stato di un'adesione a un evento **non è booleano**.
> Va conservato lo storico anche dei **non scelti** — utile per equità nelle assegnazioni
> future e per il consuntivo complessivo della disponibilità offerta.

## 7. Capacità chiave attese

- 📅 **Pianificazione** turni ricorrenti (ambulatori/logistica) e calendario eventi.
- 🙋 **Candidature** agli eventi con tracciamento di assegnati e non assegnati.
- 🔁 **Assenze / sostituzioni** con flusso di richiesta e copertura.
- ✅ **Registrazione presenze** → calcolo automatico delle **ore donate**.
- 📣 **Comunicazioni** mirate: a tutti, oppure solo agli assegnati di un evento.
- 📊 **Reportistica**: ore di volontariato per area tematica, per periodo, per persona.

## 8. Vincoli e requisiti non funzionali

### 8.1 Sostituire WhatsApp — privacy by design 🔒
Oggi le comunicazioni tra staff e volontari avvengono su **WhatsApp**. Questo strumento
deve **sostituire WhatsApp** come canale operativo, con un approccio **più rispettoso
della privacy**. Implicazioni:

- I **dati personali** dei volontari (nome, contatti, disponibilità, presenze) non devono
  transitare né restare su servizi di messaggistica di terze parti.
- I numeri di telefono **non devono essere esposti** agli altri volontari (su WA un gruppo
  rende visibile la rubrica di tutti): le comunicazioni passano per l'identità interna,
  non per il numero.
- **Minimizzazione**: raccogliere e mostrare solo i dati necessari a ciascun ruolo
  (un volontario non vede i dati altrui; lo staff vede ciò che serve a coordinare).
- **Comunicazioni mirate** per design: a tutti, a un gruppo, oppure **solo agli assegnati**
  di un evento — senza creare gruppi che espongono i contatti di tutti.
- **Conformità GDPR**: base giuridica per il trattamento, possibilità di cancellazione/export
  dei propri dati, log degli accessi proporzionato.
- **Tracciabilità delle notifiche**: sapere cosa è stato comunicato e a chi, senza dipendere
  dallo storico di una chat esterna.

### 8.2 Altri vincoli
- **Scala**: ~200 volontari, eterogenei per età e dimestichezza digitale → interfaccia
  **semplice e accessibile**, idealmente mobile-first (sostituisce un'app che già usavano
  dal telefono).
- **Doppio ruolo**: due esperienze distinte — **staff** (pianifica, assegna, comunica,
  rendiconta) e **volontario** (consulta, si candida, segnala assenze, conferma presenza).
- **Continuità con l'esistente**: deve coprire ciò che oggi fanno i fogli in `docs/`
  (turni ricorrenti + calendario presenze) senza perdita di informazione.

## 9. Entità del dominio (in evoluzione)

### Person
Entità base. Ha **una** tipologia tra:

- **Supporter** (simpatizzante)
- **Volunteer** (volontario)
- **Staff** (membro dello staff)

### Event
Singolo o ricorrente. Rappresenta un range temporale **from/to**.

- `title`
- `description`
- `place` (luogo)
- `start_time`, `end_time`: datetime
- `kind`: single | recurring
- se ricorrente → `recurrence`: daily | weekly | monthly

## 10. Stack tecnologico

**Monorepo** — `frontend/` + `backend/` nello stesso git.

### Frontend (`frontend/`)
- **Vue 3** (`<script setup>`) + **Pinia** (state)
- **Vite** (build/dev)
- **Tailwind CSS**
- **Lucide** icons
- **PWA** (installabile)

### Backend (`backend/`)
- **Ruby on Rails** in modalità **API-only** (JSON)
- **PostgreSQL** (in dev via Docker: `docker compose up -d db`)

### Note
- **Auth**: mock per l'hackathon (utente/ruolo simulato, niente login reale).

## 11. Stato del repository

Progetto in fase iniziale. Contenuti attuali:

```
.
├── Readme.md     ← questo documento (analisi del problema)
└── docs/         ← materiale di partenza
    ├── lilt_doc.docx                 (brief ufficiale)
    ├── turni_maggio.jpeg             (esempio griglia turni ambulatori)
    └── Calendario 22_26 giugno.jpeg  (esempio calendario presenze)
```

**Prossimi passi suggeriti:** modello dati · scelta dello stack · prototipo dei due
flussi (assegnazione e candidatura) · meccanismo di consuntivo ore.
