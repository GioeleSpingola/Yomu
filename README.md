# Documentazione del Sistema Informativo: Yomu

> **Documentazione Tecnica** > **Versione:** 1.0.0  
> **Stato:** Bozza  
> **Ultimo aggiornamento:** 2026-03-26  
> **Autore/i:** Spingola Gioele  

---

# Indice

1. [Abstract](#1-abstract)
2. [Introduzione](#2-introduzione)
3. [Panoramica del Sistema](#3-panoramica-del-sistema)
4. [Data Flow Diagram (DFD)](#4-data-flow-diagram-dfd)
5. [Requisiti di Sistema](#5-requisiti-di-sistema)
6. [Schema Entità-Relazione (E/R)](#6-schema-entità-relazione-er)
7. [Struttura dell’Interfaccia (Markup)](#7-struttura-dellinterfaccia-markup)
8. [Strategia di Test](#8-strategia-di-test)
9. [Evoluzioni Future](#9-evoluzioni-future)
10. [Glossario](#10-glossario)

---

# 1. Abstract

Yomu è un'applicazione mobile-first (con potenziale estensione web) che funge da reader online per manga in lingua inglese. Il sistema risolve il problema della frammentazione della lettura, offrendo una libreria centralizzata per l'utente, recuperando dinamicamente i contenuti tramite API da una sorgente esterna e salvando automaticamente i progressi di lettura nel database.

---

# 2. Introduzione

L'idea di Yomu nasce dall'esigenza di fornire agli appassionati un'esperienza di lettura fluida, rapida e organizzata. Prendendo ispirazione da reader consolidati nel panorama mobile come Mihon, il sistema si concentra sull'eliminare la necessità di scaricare file o navigare su siti pieni di pubblicità, aggregando il contenuto in un'interfaccia pulita. 

Il cuore del progetto è la gestione della "Libreria Utente", che permette a chi si registra di tenere traccia di ciò che sta leggendo, riprendendo esattamente dall'ultima pagina visualizzata. Per il futuro e come elemento distintivo, il sistema mira a integrare un Chatbot in grado di raccomandare nuove letture basandosi sui generi preferiti o sulle abitudini dell'utente.

---

# 3. Panoramica del Sistema

## 3.1 Architettura Generale

Il sistema Yomu è basato su un'architettura Client-Server fortemente orientata all'integrazione di servizi di terze parti (API esterne).
- **Frontend:** Sviluppato con un approccio "Mobile First" tramite un framework cross-platform (es. React Native o Flutter), garantendo un'interfaccia touch-friendly essenziale per la lettura (swipe, zoom).
- **Backend:** Un server leggero (es. Node.js) che funge da intermediario tra il client, il database proprietario e l'API del sito sorgente dei manga. Questo previene problemi di CORS e permette di formattare i dati prima di inviarli all'app.
- **Accesso ai Dati:** Le immagini dei capitoli e l'elenco dei manga vengono consumati "on the fly" da una singola sorgente esterna. Il database proprietario (relazionale) si occupa esclusivamente di memorizzare le credenziali degli utenti, le loro librerie personali e le coordinate esatte dei salvataggi (ID Manga, Capitolo, Pagina).

---

## 3.2 Stack Tecnologico

| Livello | Tecnologia |
|----------|-----------|
| **Frontend** | React Native / Expo (App Mobile) / React.js (Sito Web futuro) |
| **Backend** | Node.js con Express |
| **Database** | PostgreSQL o MySQL (Relazionale) |
| **Autenticazione** | JWT (JSON Web Token) / Gestione nativa delle sessioni |
| **Infrastruttura** | Hosting Cloud per Backend (es. Render/Railway) e DB Cloud |
| **Sorgente Dati** | API REST esterna (Sito provider manga) |

---

# 4. Data Flow Diagram (DFD)

## 4.1 Diagramma di Contesto (Livello 0)

**Descrizione:**
- **Entità esterne:** Utente (Lettore), API Sorgente Manga.
- **Processo principale del sistema:** Sistema di Lettura Yomu.
- **Flussi di dati primari:** Input di ricerca e comandi di lettura dall'utente; Flusso di immagini e metadati dall'API; Output visuale e raccomandazioni verso l'utente.

Inserire il diagramma qui:

<img width="2180" height="2250" alt="image" src="https://github.com/user-attachments/assets/b11072ed-7e1a-4b2e-9675-c9ff3d18fd19" />

---

## 4.2 DFD Livello 1

<img width="4995" height="4234" alt="image" src="https://github.com/user-attachments/assets/0da40481-aeca-4947-85c9-1bbdf9d7dda5" />

Elencare i processi principali:

| ID Processo | Nome Processo | Descrizione |
|------------|--------------|------------|
| P1 | Autenticazione | Gestisce login/registrazione e verifica i token utente. |
| P2 | Fetching Contenuti | Interroga l'API esterna per popolare catalogo e immagini. |
| P3 | Gestione Libreria & Progressi | Salva e recupera lo stato di lettura (capitolo/pagina) nel DB. |
| P4 | Motore Raccomandazioni (Chatbot) | Elabora i dati dell'utente per fornire suggerimenti testuali. |

Flusso tra Processi e Archivi Dati:
L'Utente si interfaccia inizialmente con P1 per l'accesso, leggendo e scrivendo i dati nel database degli utenti (D1). Una volta dentro, le sue richieste di ricerca e lettura passano attraverso P2, che fa da ponte diretto con l'API Esterna per recuperare i capitoli senza salvarli localmente. Durante la lettura, P3 intercetta i movimenti dell'utente (cambio pagina) e aggiorna costantemente l'archivio della Libreria (D2). Infine, quando l'utente richiede un consiglio, P4 elabora la cronologia di lettura presente in D2 per generare raccomandazioni personalizzate.

---

# 5. Requisiti di Sistema

## 5.1 Requisiti Funzionali

I requisiti funzionali descrivono ciò che il sistema deve fare.

| ID | Descrizione del Requisito | Priorità |
|----|--------------------------|----------|
| RF-01 |	Lettura Capitoli: Il sistema deve permettere la visualizzazione fluida delle pagine del manga tradotte in inglese. |	Alta |
| RF-02 |	Integrazione API: Il sistema deve recuperare catalogo, info e immagini da un singolo provider esterno. |	Alta |
| RF-03 |	Libreria Utente: Il sistema deve mostrare all'utente autenticato i manga salvati/in corso nella Home. |	Alta |
| RF-04 |	Salvataggio Progressi: Il sistema deve salvare in automatico nel DB l'esatto punto di lettura (Capitolo e Pagina). |	Alta |
| RF-05 |	Ricerca e Filtri: Il sistema deve permettere di cercare manga per titolo e filtrare la propria libreria. |	Media |
| RF-06 |	Chatbot Raccomandazioni: Il sistema deve includere un modulo chat per consigliare titoli.	| Bassa |

---

## 5.2 Requisiti Non Funzionali

I requisiti non funzionali definiscono attributi di qualità.

### Prestazioni
- Tempo di caricamento pagine: Pre-fetching delle immagini limitato per garantire una lettura fluida senza attese tra una pagina e l'altra.
- Latenza DB: Risposta rapida per il caricamento della libreria al login.

### Sicurezza
- Metodo di autenticazione: JWT per mantenere la sessione attiva in modo sicuro sull'app mobile. 
- Crittografia dei dati: Password hashate (es. bcrypt) nel database.

### Usabilità
- Mobile First: UI progettata esplicitamente per schermi touch, con controlli intuitivi per il reader (tap ai lati per scorrere, pinch to zoom).
- Responsive design: Adattabilità nel caso in cui venga sviluppata l'interfaccia Web.  

---

## 5.3 Requisiti Hardware

| Componente | Requisito Minimo (Client) | Requisito Minimo (Server) |
|------------|-----------------|
| CPU | Processore base (ARM) | 1 vCPU |
| RAM | 2 GB | 512 MB |
| Storage | 100 MB (cache immagini) | 1 GB (solo Logica e Dati, le immagini non sono hostate) |

---

## 5.4 Requisiti Software

| Componente | Versione |
|------------|---------|
| Sistema Operativo | Android 8.0+ |
| Database | PostgreSQL 13+ |
| Runtime | Node.js 18+ |

---

# 6. Schema Entità-Relazione (E/R)

Il database di Yomu è progettato per essere snello, poiché gran parte dei dati volumetrici (le immagini e le trame dei manga) risiedono sul provider esterno. Memorizziamo solo ciò che serve per tracciare gli utenti e i loro salvataggi.

## 6.1 Entità

| Entità | Descrizione |
|--------|------------|
| UTENTE |	Contiene i dati di autenticazione e anagrafica base. |
| MANGA_CACHE |	Entità di supporto. Salva gli ID dell'API esterna, il titolo e l'URL della cover per caricare velocemente la libreria senza chiamare l'API per ogni singolo fumetto. |
| LIBRERIA |	Entità ponte che traccia quali manga l'utente ha salvato tra i preferiti o sta leggendo. |
| PROGRESSO |	Traccia l'esatta posizione di lettura (Ultimo capitolo e pagina letta) per un determinato manga. |

## 6.2 Relazioni

| Relazione | Entità Coinvolte | Cardinalità |
|-----------|-----------------|-------------|
| Salva in	| UTENTE - LIBRERIA |	1 : N |	Un utente può avere molti manga nella sua libreria. |
| Riferisce a |	LIBRERIA - MANGA_CACHE |	N : 1 |	Più utenti possono avere lo stesso manga salvato. |
| Genera	| UTENTE - PROGRESSO |	1 : N	| L'utente genera diversi record di progresso (uno per manga). |
| Traccia | PROGRESSO - MANGA_CACHE | N : 1 | Il progresso è associato a uno specifico manga. |

Inserire il diagramma E/R qui.
<img width="8192" height="2956" alt="image" src="https://github.com/user-attachments/assets/96b41373-a116-463e-a0f0-2ee5d32ef266" />

---

# 7. Struttura dell’Interfaccia (Markup)

*(Da completare nelle versioni future)*

## 7.1 Struttura delle Pagine

| Pagina | Descrizione | Livello di Accesso |
|--------|------------|-------------------|
| | | |

## 7.2 Componenti Principali

- Navigazione  
- Form  
- Tabelle dati  
- Dashboard  
- Notifiche  

---

# 8. Strategia di Test

## 8.1 Approccio ai Test

- Test Unitari  
- Test di Integrazione  
- Test di Sistema  
- Test di Accettazione Utente (UAT)  

---

## 8.2 Casi di Test

| ID Test | Descrizione | Input | Output Atteso | Stato |
|---------|------------|-------|--------------|--------|
| TC-01 | | | | |

---

## 8.3 Tracciamento Difetti

| ID Issue | Descrizione | Gravità | Stato |
|----------|------------|----------|--------|
| | | | |

---

# 9. Evoluzioni Future

- Miglioramenti pianificati  
- Refactoring architetturale  
- Ottimizzazione delle performance  
- Estensione funzionalità  

---

# 10. Glossario

| Termine | Definizione |
|----------|------------|
| | |

---
