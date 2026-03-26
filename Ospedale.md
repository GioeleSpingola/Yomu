# Documentazione del Sistema Informativo: Ospedale San Leonardo

> **Documentazione Tecnica** > **Versione:** 1.0.0  
> **Stato:** Bozza  
> **Ultimo aggiornamento:** 2026-03-26  
> **Autore/i:** Gioele Spingola  

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

Il sistema informativo "Ospedale San Leonardo" è una piattaforma gestionale sanitaria integrata progettata per digitalizzare e ottimizzare i flussi ospedalieri. Il sistema gestisce l'intero ciclo di cura del paziente: dalla prenotazione delle visite (online o tramite centralino), alla gestione in tempo reale delle cartelle cliniche elettroniche, fino al monitoraggio dei posti letto e all'integrazione dei pagamenti.

---

# 2. Introduzione

Il progetto nasce dall'esigenza della Direzione Sanitaria di modernizzare l'infrastruttura dell'Ospedale San Leonardo, garantendo un'operatività H24 per supportare i turni di 20 medici e gestire inizialmente 150 posti letto su 4 reparti. 

Data la stringente tempistica di 6 mesi per l'apertura e un budget fissato a 80.000 €, il progetto segue un approccio di sviluppo per fasi (incrementale). La **Fase 1** si concentra sul "core" del sistema: aggiornamento delle cartelle cliniche in tempo reale, portale unificato per l'ottimizzazione delle agende (prevenendo accavallamenti) e gestione sicura dei pagamenti. Sviluppi più complessi, come l'integrazione di un Chatbot basato su Intelligenza Artificiale per il triage iniziale, sono pianificati per le fasi successive per garantire la messa in sicurezza e l'operatività immediata della struttura.

---

# 3. Panoramica del Sistema

## 3.1 Architettura Generale

Il sistema è basato su un'architettura Client-Server sicura e interoperabile, essenziale per il trattamento di dati medici sensibili.
- **Interfacce Profilate (Frontend):** Un'unica Web-App responsiva (Omnichannel) che si adatta dinamicamente al ruolo dell'utente: i pazienti accedono al portale prenotazioni/referti, gli operatori CUP hanno una dashboard gestionale rapida, e i medici dispongono di un'interfaccia clinica sicura.
- **Backend & Sicurezza:** Il server centrale gestisce la logica di business e le code di prenotazione. L'accesso remoto dei medici (es. da casa) è garantito da elevati standard di crittografia. È implementata una logica temporale rigida: i dati dei pazienti sono visibili ai medici solo per 24 ore.
- **Interoperabilità:** Il sistema prevede moduli API dedicati per comunicare costantemente con enti esterni (Apparato Regionale, INPS, Agenzia delle Entrate) per la sincronizzazione di ricette, esenzioni e fatturazione.

---

## 3.2 Stack Tecnologico

| Livello | Tecnologia |
|----------|-----------|
| **Frontend** | React / Vue.js (Web-App Responsiva) |
| **Backend** | Node.js o Java Spring Boot |
| **Database** | PostgreSQL (Relazionale) protetto da crittografia TDE |
| **Autenticazione** | OAuth 2.0 / JWT con Autenticazione a Due Fattori (2FA) |
| **Infrastruttura** | Server Cloud privati e certificati (compliance sanitaria/GDPR) |
| **Integrazioni** | REST API per Gateway di pagamento e servizi Regionali/INPS |

---

# 4. Data Flow Diagram (DFD)

Questo diagramma illustra i processi principali e come i dati si muovono tra gli attori (Pazienti, Medici, Operatori), il sistema informativo e gli archivi di database.
<img width="6556" height="2517" alt="image" src="https://github.com/user-attachments/assets/1bcefbd7-404a-4620-a48e-faf2ad23990c" />

Elencare i processi principali:

| ID Processo | Nome Processo | Descrizione |
|------------|--------------|------------|
| P1 | Gestione Prenotazioni | Gestisce gli input di pazienti e operatori telefonici, ottimizzando gli slot nel DB Agende per evitare accavallamenti. |
| P2 | Gestione Visite e Referti | Permette al medico di visionare/scrivere il referto e salva i dati clinici nel DB Pazienti (visibilità limitata a 24h). |
| P3 | Gestione Pagamenti | Elabora i pagamenti, registra i flussi nel DB Amministrativo e si interfaccia con gli Agenti Esterni (Agenzia Entrate/INPS). |
| P4 | Gestione Reparti | Monitora e organizza l'assegnazione dei 150 posti letto all'interno dei 4 reparti nel DB dedicato. |

---

# 5. Requisiti di Sistema

## 5.1 Requisiti Funzionali

I requisiti funzionali descrivono ciò che il sistema deve fare per l'operatività ospedaliera.

| ID | Descrizione del Requisito | Priorità |
|----|--------------------------|----------|
| RF-01 |	Gestione Cartella Clinica Elettronica: Aggiornamento real-time. Dati e referti visibili ai medici per max 24 ore. Supporto per 20 medici in turno. |	Alta
| RF-02 |	Sistema Prenotazione (CUP): Piattaforma per prenotazioni online (paziente) e interfaccia gestionale per il centralino telefonico. |	Alta
| RF-03 |	Ottimizzazione Agende Mediche: Prevenzione doppioni, calcolo tempi variabili, gestione priorità e buchi in agenda (1 medico per visita). |	Alta
| RF-04 |	Portale Web/Mobile Pazienti: Interfaccia per inserire ricette mediche e completare prenotazioni in autonomia. |	Alta
| RF-05 |	Gestione Pagamenti e Burocrazia: Pagamento online sincronizzato con Agenzia Entrate/INPS, gestione rimborsi ed esenzioni. |	Alta
| RF-06 |	Gestione Reparti e Degenti: Modulo per organizzare e assegnare 150 posti letto divisi in 4 reparti operativi.	| Media
| RF-07 |	Integrazione Chatbot (IA): Assistente per il primo contatto e indirizzamento verso reparti/procedure (pianificato per Fase 2).	| Bassa

---

## 5.2 Requisiti Non Funzionali

I requisiti non funzionali definiscono gli attributi di qualità e i vincoli operativi.

### Prestazioni e Affidabilità
- Operatività H24: Affidabilità totale 24/7 per supportare i turni medici ospedalieri senza interruzioni.
- Interoperabilità: Capacità di comunicare in sicurezza con database esterni regionali e nazionali.

### Sicurezza
- Accesso Remoto Protetto: Crittografia e riservatezza per l'accesso ai dati sensibili dall'esterno (es. casa del medico).
- Logica Temporale: Revoca automatica dei permessi di visualizzazione referti dopo 24 ore.

### Usabilità
- Accessibilità Omnichannel: Esperienza fluida su Web/Mobile per i pazienti e strumento ergonomico per i centralinisti.
- Interfacce Profilate: Adattamento intuitivo della UI alla tipologia di account (Medico, Paziente, Amministratore).

---

## 5.3 Requisiti Hardware

| Componente | Requisito Minimo |
|------------|-----------------|
| Server | Cluster in High Availability (HA) per garantire l'uptime H24 |
| Storage | SAN (Storage Area Network) crittografato con dischi SSD per i Database |
| Rete | Connessione in fibra ottica ridondata con firewall hardware dedicato |

---

## 5.4 Requisiti Software

| Componente | Versione |
|------------|---------|
| Sistema Operativo | Windows  |
| Database | PostgreSQL (con moduli per la sicurezza avanzata) |
| Integrazioni | Supporto nativo per protocolli HL7/FHIR (Standard informatici sanitari) |
| Browser Client | Compatibilità con le versioni moderne (Chrome, Edge, Firefox, Safari) |

---

# 6. Schema Entità-Relazione (E/R)

*(Da completare nelle versioni future in classe)*

## 6.1 Entità

| Entità | Descrizione |
|--------|------------|
| | |

## 6.2 Relazioni

| Relazione | Entità Coinvolte | Cardinalità |
|-----------|-----------------|-------------|
| | | |

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
