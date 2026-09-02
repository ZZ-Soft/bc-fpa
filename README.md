# FatturaPA per Business Central online

Importa, valida e **visualizza** i file XML della fattura elettronica italiana e le ricevute
del Sistema di Interscambio, e genera l'XML di vendita dai documenti registrati —
direttamente dentro Business Central, senza assembly .NET (`target: Cloud`).

**Publisher:** ZZ Soft · **ID range:** 73000–73099 · **Licenza:** Apache 2.0

---

## Cosa fa

- **Acquisti e ricevute**: caricamento XML con selezione multipla e drag&drop, fatture e
  ricevute mescolate nello stesso batch.
- **Vendite**: l'XML viene costruito dall'estensione a partire dalla fattura registrata e
  archiviato in automatico, con il nome secondo la regola SdI.
- **Esplosione dei lotti**: ogni `FatturaElettronicaBody` diventa un documento a sé.
- **Aggancio automatico delle ricevute** alla fattura di riferimento, in qualunque ordine
  arrivino, con l'esito SdI ricalcolato di conseguenza.
- **Validazione** contro gli XSD ufficiali FatturaPA e dei messaggi SdI.
- **Visualizzazione** con il foglio di stile AssoSoftware per le fatture e con i fogli
  ufficiali per tutti e nove i tipi di ricevuta.

## Primi passi

1. Pubblicare l'estensione (AL Language per VS Code, *AL: Publish*). Non serve nessuno step
   preliminare: gli asset generati sono già nel repository.
2. **FatturaPA XSD Schemas** → *Load Schemas*, caricando **insieme** i due XSD ufficiali
   (`xmldsig-core-schema.xsd` e `Schema_del_file_xml_FatturaPA_v1.2.x.xsd`).
3. **FatturaPA XML Files** → *Import XML* per gli acquisti, oppure **FatturaPA Sales Export
   Setup** e poi *FatturaPA → Generate and File XML* su una fattura registrata per le vendite.

La procedura completa — schemi delle ricevute, ordine di caricamento, modalità del
progressivo — è in [`docs/DOCUMENTAZIONE.md`](docs/DOCUMENTAZIONE.md#setup).

## Documentazione

| | |
|---|---|
| [`docs/DOCUMENTAZIONE.md`](docs/DOCUMENTAZIONE.md) | Riferimento completo: modello dati, flusso SdI, export vendite, architettura del viewer, struttura del codice, setup, limiti noti |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Come contribuire, convenzioni, verifiche aperte |
| [`NOTICE`](NOTICE) | Componenti di terze parti ridistribuiti |
| [`docs/sample/`](docs/sample/) | Campioni ufficiali SdI e rese di riferimento del viewer |

## Licenza

**Apache License 2.0** — testo integrale in [`LICENSE`](LICENSE).

Il repository ridistribuisce componenti di terze parti che **non** sono coperti da quella
licenza: il runtime SaxonJS 2 di Saxonica, il foglio di stile AssoSoftware (qui anche
modificato) e i fogli di stile e schemi XSD del Sistema di Interscambio. Titolare, origine e
modifiche applicate a ciascuno sono in [`NOTICE`](NOTICE).

Due verifiche di licenza sono ancora aperte — Saxonica e AssoSoftware — e vanno chiuse prima
di rendere pubblico il repository: vedi [`CONTRIBUTING.md`](CONTRIBUTING.md).
