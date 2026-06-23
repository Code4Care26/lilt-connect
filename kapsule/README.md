# Deploy di Hackatron LILT su Kubernetes Kapsule (Scaleway)

Piano di deploy dell'app **LILT** (monorepo a tre servizi) su **Scaleway
Kubernetes Kapsule**, con datastore **gestiti** (PostgreSQL + Redis) e tutto
pilotabile **da CLI `scw`** — nello spirito dell'esperimento `hello-kapsule`.

> ✅ **Stato:** pacchetto completo. Script `00..07`, manifest `k8s/` e Dockerfile
> ci sono. Il backend è già su PostgreSQL e gosse ha già il fan-out via Redis
> (vedi §8): il deploy non richiede altre modifiche al codice applicativo.

## Avvio rapido

```bash
cd kapsule
chmod +x *.sh

# 0) Account hackathon: basta crearne il profilo una volta. config.sh usa di
#    default SCW_PROFILE=hackathon, quindi non serve esportarlo a ogni shell.
scw -p hackathon init        # solo la prima volta

# 1) Imposta REGISTRY_NS in config.sh (è globalmente univoco) + i segreti:
export PG_PASSWORD='...'  REDIS_PASSWORD='...'  SSE_PUBLISH_SECRET='...'
# RAILS_MASTER_KEY è letto da backend/config/master.key se non lo esporti.

./00-crea-rete.sh        # Private Network (VPC)
./01-crea-cluster.sh     # cluster Kapsule agganciato alla PN + kubeconfig
./02-crea-db.sh          # PostgreSQL + Redis gestiti sulla stessa PN
./03-build-push.sh 0.0.1 # build & push delle 3 immagini :0.0.1 (TAG sempre esplicito)
./04-secrets.sh          # Secret k8s (endpoint DB letti da Scaleway)
./05-deploy.sh 0.0.1     # ingress-nginx + Job migrazione + app + Ingress (stesso tag)
# ...attendi l'EXTERNAL-IP, poi apri http://<ip>/

./06-test-scala.sh test  # smoke test
```

## Pubblicare una nuova release

Dopo il bootstrap (che NON si ripete), ogni nuova versione è **un comando**:

```bash
cd kapsule
./publish.sh v4         # tag git v4 → push → build+push immagini :v4 → deploy :v4
```

`publish.sh` forza `TAG=v4` (niente ambiguità se sul commit ci sono più tag),
crea/pusha il tag git, poi richiama `03-build-push.sh` e `05-deploy.sh`. Committa
prima le tue modifiche: il tag punta all'ultimo commit. In alternativa, i passi a
mano (TAG esplicito, identico nei due passi): `./03-build-push.sh v4 && ./05-deploy.sh v4`.

---

## 1.bis Usare un account Scaleway diverso (hackathon)

Se l'account dell'hackathon **non è il tuo personale**, non toccare la config
esistente: punta gli script all'altro account con uno di questi modi (le `SCW_*`
hanno priorità sul file di config).

- **Profilo dedicato (consigliato, già il default).** Aggiunge un profilo
  accanto ai tuoi; `config.sh` usa `SCW_PROFILE=hackathon` di default, quindi
  dopo l'`init` non devi esportare nulla:
  ```bash
  scw -p hackathon init        # chiede API key / org / project dell'account hackathon
  # (per un altro nome: SCW_PROFILE=altro ./00-crea-rete.sh, oppure cambia il default in config.sh)
  ```
- **Solo env (zero tracce su disco).** Buono per credenziali prestate:
  ```bash
  export SCW_ACCESS_KEY=... SCW_SECRET_KEY=... \
         SCW_DEFAULT_ORGANIZATION_ID=... SCW_DEFAULT_PROJECT_ID=...
  ```
- **File separato:** `export SCW_CONFIG_PATH=~/.config/scw/hackathon.yaml`.

**Salvagente integrato:** `00`, `02`, `03` stampano un banner con profilo/org su
cui stanno per agire, e avvisano se `SCW_PROFILE` non è impostato (staresti usando
il profilo *attivo*, che potrebbe essere il tuo). `06-test-scala.sh distruggi`
mostra il banner e chiede di digitare `DISTRUGGI` prima di cancellare.

> Gli script passano sempre `region=fr-par`/`zone=fr-par-1` in modo **esplicito**,
> quindi il `default-region` del profilo (anche `it-mil`) non li devia.
>
> Nota su `docker`: `scw registry login` salva le credenziali docker per l'host
> `rg.fr-par.scw.cloud`, condiviso fra account → se cambi account, rifai
> `./03-build-push.sh` (rilancia il login) prima di pushare.

---

## 1. Nota sulla region "Italia"

Scaleway **non** ha una region in Italia utilizzabile per Kapsule, il Container
Registry e i database gestiti. Le region complete sono `fr-par` (Parigi),
`nl-ams` (Amsterdam) e `pl-waw` (Varsavia). Esiste una AZ a Milano (`MIL1`) ma
con prodotti limitati.

Questo pacchetto usa **`fr-par` (Parigi)**, la region GA più vicina all'Italia.
La region è una variabile in cima a ogni script: per cambiarla basta modificarla
in un punto.

---

## 2. L'app: tre servizi, di cui due con stato

A differenza dell'echo server di `hello-kapsule` (un solo binario stateless),
qui abbiamo un **monorepo a tre processi** (vedi `run.sh` / `Procfile.dev`):

| Servizio   | Cosa è                                   | Porta container | Stato                         |
|------------|------------------------------------------|-----------------|-------------------------------|
| `backend`  | Rails 8 API-only, Puma + Thruster        | 80              | stato → **PostgreSQL gestito** |
| `gosse`    | SSE fan-out in Go                        | 3002            | realtime → **Redis gestito**   |
| `frontend` | Vue 3 + Vite + PWA → build statica       | 80 (nginx)      | stateless                      |

Il "contratto di rete" da replicare su Kubernetes nasce da `run.sh`:

- il frontend chiama URL **relativi** (`/api` → Rails, `/sse` → gosse); in dev
  è **Vite** a fare da proxy same-origin (niente CORS). Su Kubernetes Vite
  sparisce → il same-origin lo rimette un **Ingress**.
- Rails → gosse è una chiamata **server-to-server** (`SSE_PUBLISH_URL=.../publish`)
  autenticata con `SSE_PUBLISH_SECRET` condiviso.

---

## 3. Decisioni di architettura (e perché)

### 3.1 PostgreSQL gestito al posto di SQLite → Rails diventa stateless
Spostando lo stato fuori dal pod, il backend perde il vincolo di replica
singola: `replicas: N` + HPA, come l'echo. Costo: una sola insidia vera, le
**migration con più repliche** (vedi §6.4).

### 3.2 Redis gestito per gosse → anche il realtime si replica (opzione A)
L'hub di gosse è in-memory: oggi **una sola istanza** (lo dice il suo README).
Con Redis pub/sub diventa replicabile. Schema scelto (**opzione A**):

```
Rails --POST /publish--> gosse (una qualsiasi istanza)
                           |
                           +--PUBLISH--> Redis (canale invalidazioni)
                                            |
            SUBSCRIBE <-----+---------------+---------------+
                            |               |               |
                         gosse #1        gosse #2        gosse #3
                            |               |               |
                        fan-out SSE ai propri EventSource (browser)
```

Rails **non cambia il suo contratto** (continua a fare un solo POST HTTP, con il
secret invariato); l'unica modifica vive dentro gosse. Il pub/sub è
**fire-and-forget**: messaggi effimeri (`{"type":"events.changed"}`), nessuna
persistenza Redis necessaria; se Redis riparte si perde qualche invalidazione e
i client si risincronizzano alla riconnessione SSE. Tollerabile by design.

### 3.3 Ingress same-origin (non tre LoadBalancer)
Il frontend usa path relativi → un solo IP pubblico con routing per path:

- `/`     → Service `frontend`
- `/api`  → Service `backend`
- `/sse`  → Service `gosse`

Stesso origin ⇒ **zero CORS** ⇒ la PWA è felice. gosse setta già
`X-Accel-Buffering: no`, quindi l'SSE attraversa l'ingress senza buffering.
Con gosse replicabile via Redis **non servono sticky session**: qualsiasi
istanza serve qualsiasi client (tutte ricevono tutto dal canale).

### 3.4 Private Network (VPC), non endpoint pubblico + ACL
Come raggiungono i pod i DB gestiti? Due strade:

- **Endpoint pubblico + ACL sugli IP dei nodi** — inadatto: il pool ha
  autoscaling 2→10 nodi, ogni nodo nuovo è un IP nuovo, l'ACL diventa un
  bersaglio mobile.
- **Private Network (VPC)** ✅ — cluster Kapsule **e** i due DB sulla *stessa*
  private network. Endpoint interni, nessuna esposizione pubblica, l'autoscaling
  dei nodi non tocca nulla.

Con un cluster ad autoscaling, la Private Network è l'unica scelta sensata.

---

## 4. Topologia finale

```
                         Internet
                            │
                   ┌────────▼─────────┐   (LB Scaleway, 1 IP pubblico)
                   │  Ingress nginx   │
                   └───┬────┬─────┬───┘
              /        │    │/api │/sse
        ┌──────────────▼┐ ┌─▼────────┐ ┌▼───────────────┐
        │ frontend (N)  │ │ backend  │ │ gosse (N)      │
        │ nginx + dist  │ │ Rails N  │ │ SSE + Redis sub│
        └───────────────┘ └────┬─────┘ └───────┬────────┘
                               │ DATABASE_URL   │ REDIS_URL (PUBLISH/SUBSCRIBE)
        ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌  Private Network (VPC)
                        ┌──────▼──────┐  ┌──────▼──────┐
                        │ PostgreSQL  │  │   Redis     │
                        │  gestito    │  │  gestito    │
                        └─────────────┘  └─────────────┘
```

---

## 5. Prerequisiti

- CLI `scw` installata e configurata: `scw init`
- `docker`, `kubectl`
- `python3` (gli script leggono gli ID dai JSON, come in `hello-kapsule`)
- `RAILS_MASTER_KEY` di produzione (da `backend/config/master.key`)

---

## 6. Procedura prevista (tutto via `scw` / `kubectl`)

Layout di pacchetto previsto (analogo a `hello-kapsule`, ma per 3 servizi):

```
kapsule/
  README.md            ← questo documento
  00-crea-rete.sh      crea/individua la VPC Private Network
  01-crea-cluster.sh   crea il cluster Kapsule (agganciato alla PN) + kubeconfig
  02-crea-db.sh        crea Postgres + Redis gestiti sulla stessa PN
  03-build-push.sh     crea il registry, build & push delle 3 immagini
  04-secrets.sh        crea i Secret k8s (DATABASE_URL, REDIS_URL, secret, master key)
  05-deploy.sh         Job migration + apply manifest + Ingress; attende l'IP
  06-test-scala.sh     test, scaling pod/nodi, status, pulizia
  07-aggiorna.sh       rolling update di un singolo servizio (tag nuovo)
  k8s/
    backend.yaml       Deployment + Service (ClusterIP) + HPA
    gosse.yaml         Deployment + Service (ClusterIP) + HPA
    frontend.yaml      Deployment + Service (ClusterIP)
    migrate-job.yaml   Job: bin/rails db:prepare (una volta, prima del rollout)
    ingress.yaml       Ingress: / → frontend, /api → backend, /sse → gosse
```

### 6.1 Private Network + cluster
La VPC Private Network si crea una volta; il cluster Kapsule ci si aggancia
(`private-network-id=...`) e si abilita l'autoscaling del pool, come nell'echo.

### 6.2 Database gestiti (sulla stessa Private Network)
```bash
# PostgreSQL  (verifica engine/node-type: scw rdb engine list / node-types)
scw rdb instance create \
  region=fr-par name=lilt-pg \
  engine=PostgreSQL-16 node-type=db-dev-s \
  user-name=lilt password='********' \
  init-endpoints.0.private-network.private-network-id=$PN_ID \
  --wait

# Redis  (NB: il verbo è "cluster create"; verifica le versioni: scw redis version list)
scw redis cluster create \
  zone=fr-par-1 name=lilt-redis \
  version=7.0.5 node-type=RED1-MICRO cluster-size=1 \
  user-name=lilt password='********' \
  endpoints.0.private-network.id=$PN_ID
```
`cluster-size=1` su Redis = standalone (no cluster-mode): ci serve solo il
pub/sub, go-redis parla con un endpoint singolo senza grane di cluster-mode.

Gli **endpoint privati** si ricavano poi con `scw rdb instance get` /
`scw redis cluster get` e finiscono nei Secret (§7).

### 6.3 Immagini
Le tre immagini sul Container Registry Scaleway (`rg.fr-par.scw.cloud/<ns>/...`).
`backend/Dockerfile` esiste già; servono `gosse/Dockerfile` (multi-stage →
distroless) e `frontend/Dockerfile` (stage build Vite → stage nginx su `dist/`).

### 6.4 Migration (il punto delicato di Postgres)
Con N repliche Rails che bootano insieme, N processi corrono `db:prepare` sullo
stesso schema → race. Fix: un **Job k8s** (o initContainer con leader) che gira
le migration **una volta**, prima del rollout; i pod app **non** le rifanno.

Inoltre attenzione al **pool di connessioni**: `puma_threads × repliche` deve
stare sotto il `max_connections` del Postgres gestito (limiti bassi sui nodi
piccoli) — eventualmente PgBouncer davanti.

---

## 7. Variabili d'ambiente e Secret

| Servizio | Var                   | Origine / valore                                            |
|----------|-----------------------|-------------------------------------------------------------|
| backend  | `RAILS_ENV`           | `production`                                                |
| backend  | `RAILS_MASTER_KEY`    | Secret (da `config/master.key`)                             |
| backend  | `DATABASE_URL`        | Secret → `postgres://lilt:***@<pg-priv-endpoint>:5432/rdb`  |
| backend  | `SSE_PUBLISH_URL`     | `http://gosse/publish` (DNS interno del Service)            |
| backend  | `SSE_PUBLISH_SECRET`  | Secret (condiviso con gosse)                                |
| gosse    | `HOST`                | **`0.0.0.0`** (default è `127.0.0.1` → irraggiungibile!)    |
| gosse    | `PORT`                | `3002`                                                      |
| gosse    | `SSE_PUBLISH_SECRET`  | Secret (condiviso con backend)                              |
| gosse    | `REDIS_URL`           | Secret → `rediss://:***@<redis-priv-endpoint>:6379` (TLS)   |

---

## 8. Stato del codice applicativo

Quasi tutto era già a posto nel repo; il deploy ha richiesto solo i Dockerfile
mancanti e un guard:

- **`gosse`** — broadcaster Redis (opzione A) **già implementato** (`broadcast.go`,
  cablato in `main.go`): `REDIS_URL` attiva il `PUBLISH`/`SUBSCRIBE` sul canale;
  senza `REDIS_URL` resta la modalità single-instance (hub in-memory). L'hub
  locale è il fan-out per i client di quell'istanza.
- **`backend`** — **già su PostgreSQL** (gem `pg`, adapter `postgresql` in
  `config/database.yml` via `DATABASE_*`, `postgresql-client` nel `Dockerfile`).
  Unica aggiunta: `bin/docker-entrypoint` salta `db:prepare` se `SKIP_DB_PREPARE=1`,
  così i pod app non corrono le migration in parallelo (le fa il Job, §6.4).
- **`gosse/Dockerfile`** e **`frontend/Dockerfile`** (+ `nginx.conf`): nuovi,
  erano gli unici artefatti di build mancanti.

---

## 9. Scaling

- **Pod**: HPA su `backend` e `gosse` (CPU). I `resources.requests` nei manifest
  sono **essenziali**, altrimenti il Cluster Autoscaler dei nodi non sa
  calcolare se serve un nodo in più.
- **Nodi**: Cluster Autoscaler attivo sul pool (es. 2→10), come in `hello-kapsule`.
- `frontend` resta a poche repliche fisse (statico).

---

## 10. Pulizia

- `06-test-scala.sh pulisci` → rimuove app + Ingress, tiene cluster e DB.
- `06-test-scala.sh distruggi` → cancella cluster, **Postgres e Redis gestiti**
  (irreversibile) e la Private Network.

---

## 11. Valori da verificare sul tuo ambiente

- Versioni K8s: `scw k8s version list region=fr-par`
- Versioni/engine Postgres: `scw rdb engine list region=fr-par`
- Node-type RDB: `scw rdb node-type list region=fr-par`
- Versioni Redis: `scw redis version list zone=fr-par-1`
- Node-type Redis e prezzi: cambiano nel tempo, controlla la console.
- Default economici di partenza: `db-dev-s` (PG), `RED1-MICRO` (Redis),
  `DEV1-M` (nodi K8s).
