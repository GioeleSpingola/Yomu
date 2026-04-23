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

<img width="1208" height="568" alt="DFD_Yomu" src="https://github.com/user-attachments/assets/40e122fc-0e5a-4231-afc8-d754c54fa829" />


| ID Processo | Nome Processo | Descrizione |
|------------|--------------|------------|
| **P1** | Autenticazione | Gestisce login/registrazione e verifica le credenziali. Gestisce il passaggio da Utente Non Loggato a Utente Loggato. |
| **P2** | Esplorazione e Ricerca | Interroga l'API esterna di MangaDex per popolare il catalogo, eseguire ricerche e filtrare i risultati. Accessibile a tutti. |
| **P3** | Lettura Capitoli | Gestisce la visualizzazione delle immagini dei manga interrogando l'API esterna. Accessibile a tutti. |
| **P4** | Gestione Libreria | Permette all'utente loggato di aggiungere/rimuovere opere e aggiornare il loro stato (es. "In lettura", "Completato"). |
| **P5** | Gestione Progressi | Traccia e salva automaticamente i capitoli e le pagine lette dall'utente loggato, recuperando la cronologia al rientro. |
| **P6** | Personalizzazione Impostazioni | Gestisce le preferenze utente (es. direzione di lettura, tema cromatico, sfondo) salvandole nella memoria locale del dispositivo. |
| **P7** | Chatbot Raccomandazioni | *(Opzionale)* Interroga un'API di Intelligenza Artificiale per suggerire letture basate sulla libreria e i progressi dell'utente. |

### Flusso tra Processi e Archivi Dati

L'architettura del sistema prevede flussi differenziati in base ai permessi dell'utente. 

L'Utente Non Loggato può interagire con il sistema interrogando P2 per esplorare il catalogo o P3 per leggere capitoli, processi che fungono da ponte diretto e bidirezionale con l'API Esterna. Per sbloccare le funzionalità complete, l'utente interagisce con P1, che legge e scrive i dati nel database degli utenti (DB1), validando la sessione e abilitando i permessi di Utente Loggato.

Una volta loggato, i flussi di lettura si ramificano: le azioni dell'utente passano per P4 e P5, i quali comunicano in modo bidirezionale con i rispettivi archivi (Libreria, DB2 e Progressi, DB3) per salvare lo stato delle opere e aggiornare in tempo reale la cronologia. 
Parallelamente, qualsiasi utente può interagire con P6 per modificare le preferenze di interfaccia, i cui dati vengono scritti e letti direttamente dalla memoria cache del dispositivo (DB4: Local Storage), garantendo un'esperienza fluida senza gravare sul database principale. 
Infine, le richieste di consigli di lettura vengono elaborate da P7, che funge da intermediario verso un'API di AI Esterna.

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
| LIBRERIA |	Entità ponte che traccia quali manga l'utente ha salvato tra i preferiti o sta leggendo. |
| PROGRESSO |	Traccia l'esatta posizione di lettura (Ultimo capitolo e pagina letta) per un determinato manga. |

## 6.2 Relazioni

| Relazione | Entità Coinvolte | Cardinalità |
|-----------|-----------------|-------------|
| Salva in	| UTENTE - LIBRERIA |	1 : N |	Un utente può avere molti manga nella sua libreria. |
| Genera	| UTENTE - PROGRESSO |	1 : N	| L'utente genera diversi record di progresso (uno per manga). |

Inserire il diagramma E/R qui.
<img width="630" height="531" alt="Schema_E_R_Yomu" src="https://github.com/user-attachments/assets/c857659b-24a4-4d47-9259-b17a61f45148" />


---

# 7. Struttura dell’Interfaccia (Markup)

*(Da completare nelle versioni future)*

## 7.1 Struttura delle Pagine

| Pagina | Descrizione | Livello di Accesso |
|--------|------------|-------------------|
| **Splash Screen** | Schermata di avvio con logo e smistamento automatico basato sulla sessione utente attiva. | Tutti |
| **Auth Screen** | Interfaccia di Login e Registrazione con validazione dei campi in tempo reale. | Utente Non Loggato |
| **Main Screen** | Contenitore principale ("Scaffold") che ospita la barra di navigazione inferiore e mantiene lo stato. | Tutti |
| **Home Screen (Esplora)** | Catalogo interattivo collegato all'API esterna con barra di ricerca e filtri avanzati (BottomSheet). | Tutti |
| **Library Screen** | Dashboard personale che mostra i manga salvati divisi per stato di lettura (chip dinamici). | Utente Loggato |
| **History Screen** | Cronologia dinamica che mostra l'esatto capitolo e pagina dell'ultima sessione di lettura. | Utente Loggato |
| **Manga Detail Screen**| Pagina di dettaglio dell'opera con trama, gestione salvataggi e lista completa dei capitoli. | Tutti |
| **Reader Screen** | Visualizzatore immersivo a schermo intero con zoom, cambio pagina al tocco e slider direzionale. | Tutti |
| **Settings Screen** | Pannello per la personalizzazione dell'app (colore tema, verso di lettura, svuotamento cache). | Tutti |
## 7.2 Componenti Principali

Per costruire l'interfaccia sono stati utilizzati i seguenti componenti nativi e personalizzati:

- **Navigazione**: `BottomNavigationBar` customizzata per il passaggio rapido tra le sezioni principali, supportata da un `IndexedStack` per evitare ricaricamenti inutili dei dati. `SliverAppBar` a scomparsa per massimizzare lo spazio di lettura.
- **Form**: Campi `TextFormField` con validazione in tempo reale e decorazioni di stato (errore, focus) per i moduli di autenticazione. Barra di ricerca interattiva integrata nella testata.
- **Tabelle dati**: Motore di rendering basato su `CustomScrollView` combinato con `SliverGrid` (per le griglie delle copertine) e `SliverList` (per i capitoli e la cronologia), garantendo prestazioni elevate.
- **Dashboard**: Utilizzo di `ModalBottomSheet` per mostrare menu contestuali non invasivi (es. selezione stato lettura, filtri di esplorazione) e interfacce a schede scorrevoli.
- **Notifiche**: Sistema di alert `SnackBar` fluttuanti e arrotondate per fornire feedback visivo immediato (es. "Manga aggiunto alla libreria", errori di connessione o login).

1) Libreria
<img width="562" height="864" alt="image" src="https://github.com/user-attachments/assets/938e2a16-3a8b-40fd-bd4e-42969a4d547c" />



2)Esplora
<img width="556" height="865" alt="image" src="https://github.com/user-attachments/assets/4d97af2b-a0f6-43bb-a24b-39f36bc4075c" />



3)Cronologia
<img width="549" height="865" alt="image" src="https://github.com/user-attachments/assets/59b7e3f5-602a-4a73-b38d-0d9ae563b637" />



4)Impostazioni
<img width="546" height="916" alt="image" src="https://github.com/user-attachments/assets/fcc1d38b-a3ff-4541-8a5f-c7aecd5d93c1" />



5)Dettagli Opera
<img width="555" height="913" alt="image" src="https://github.com/user-attachments/assets/4db17b96-e1d0-487b-8b9a-04f1d3ce4ef9" />



6)Chatbot per raccomandazioni
<img width="554" height="913" alt="image" src="https://github.com/user-attachments/assets/9a1d2f8e-a317-460f-b155-08d88f3da15d" />



7)Lettura effettiva
<img width="555" height="905" alt="image" src="https://github.com/user-attachments/assets/fffee34c-3c14-471d-ab66-e9ed8554b325" />

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
