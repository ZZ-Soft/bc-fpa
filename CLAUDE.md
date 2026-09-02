# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Cos'e'

Estensione AL per Business Central online (`target: Cloud`, runtime 17.0, platform/application
28.0): importa, valida e **visualizza** XML FatturaPA e ricevute SdI, e genera l'XML di vendita
dai documenti registrati. Publisher `ZZ Soft`, prefisso oggetti `FPA`, namespace `ZZSoft.FPA`,
range ID **73000-73099**.

`docs/DOCUMENTAZIONE.md` e' la documentazione di progetto completa (modello dati, flusso SdI,
patch XSLT, setup, limiti noti). Leggila prima di toccare il viewer o il reader: contiene il
*perche'* di scelte che dal codice non si deducono.

## Build ed esecuzione

- **Compilazione**: AL Language per VS Code (`Ctrl+Shift+P` -> *AL: Publish*). Nessuno step
  preliminare: gli asset generati sono gia' nel repository, un clone pulito compila.
- **Sandbox**: `.vscode/launch.json` e' in `.gitignore`: non e' nel repository perche' porta il
  nome della sandbox di chi sviluppa. Va creato in locale (*AL: Go!* lo genera) con
  `environmentType: "Sandbox"` e il proprio `environmentName`.
- **Analyzer attivi**: CodeCop, UICop, AppSourceCop; `files.encoding: utf8bom`.
- **Rigenerare i fogli di stile** (solo dopo un aggiornamento AssoSoftware o SdI, serve Node):

  ```bash
  ./tools/build-sef.sh [percorso/al/nuovo.xsl] [cartella/sdi-xsl]
  ```

  Patcha e compila i 10 fogli in SEF e li impacchetta in `src/assets/js/fe-sef.js`
  (`window.FE_SEF`, ~750 KB). Le 4 patch sono documentate in commento dentro lo script.

**Non esiste una test suite automatica.** `FPA Xml Test` (73009) e' un *dry run* dell'export:
costruisce l'XML di un documento registrato e lo offre in download senza scrivere nulla e senza
consumare progressivi. La verifica del viewer e' manuale, sui campioni in `docs/sample/` — vedi
"Verificare una modifica al viewer".

## Architettura

### Il vincolo che spiega tutto

AL **non ha un motore XSLT**: `XmlDocument` e' solo `System.Xml.Linq`, e
`System.Xml.Xsl.XslCompiledTransform` non e' raggiungibile da un target Cloud. Quindi:

| Operazione | Dove |
|---|---|
| Leggere/interrogare XML | AL, `XmlDocument` + XPath |
| Validare contro XSD | AL, `Codeunit "Xml Validation"` (System Application) |
| Applicare un foglio XSLT | **client-side**, control add-in con SaxonJS 2 |

SaxonJS e non `XSLTProcessor` nativo perche' Chromium sta rimuovendo XSLT dal browser (fine 2026).
Il foglio arriva **pre-compilato in SEF**: a runtime non si parsa XSLT.

### Catena del viewer

```
Page --> FPA Body Extractor (XML del singolo body) --> FPA Chunk Helper (60.000 char)
     --> AppendXmlChunk x N --> RenderDocument(key) --> SaxonJS --> iframe
```

- `FPAStylesheetViewer.ControlAddIn.al` risolve `Scripts`/`StartupScript`/`StyleSheets`
  **relativi alla cartella del file .al**: gli asset stanno in `src/assets/`. Spostando il
  controladdin vanno riallineati i 5 path.
- La chiave del foglio e' `FATTURA` per una fattura, il codice a due lettere (`RC`, `NS`, `MC`,
  `MT`, `NE`, `EC`, `SE`, `DT`, `AT`) per una ricevuta. Chiave sconosciuta => fallback a sorgente
  XML indentato, mai pagina bianca.
- Ogni argomento di un metodo add-in e' un messaggio a se': un file da 1,2 MB sono 21 chunk.

### Modello dati

`FPA Xml File` (73000) e' la "cartella", **un record per file fisico**, PK = `File Name` (il nome
SdI e' univoco per costruzione). `FPA Xml File Document` (73001) e' **un record per
`FatturaElettronicaBody`**, PK = `File Name` + `Body No.`. L'XML esiste in un solo posto, sul
padre; i dati di testata sui documenti sono FlowField `lookup`, non copie.

Il **join fattura / ricevute e' `SdI Base Name`** (il prefisso senza estensione), non il nome
file e non il `NomeFile` dichiarato dalla ricevuta, che sulle fatture firmate vale `....xml.p7m`
e non corrisponderebbe.

Chi decide cosa: **la radice XML decide fattura o ricevuta** (radice `FatturaElettronica` =>
fattura, qualunque cosa dica il nome); **il nome file decide quale ricevuta e'** e il base name.
Un codice presente nel nome non viene mai sovrascritto dalla radice.

`SdI Status` sulla fattura e' **ricalcolato da zero** (`FPA SdI Status Mgt`) a ogni import o
cancellazione con quel base name: le ricevute arrivano spesso prima della fattura, un
aggiornamento incrementale divergerebbe. `Draft` e `Sent` non vengono dalle ricevute e non sono
toccati dal ricalcolo.

### Export vendite

L'XML e' costruito **qui**, da `FPA Xml File Manager` (73008) con `XmlDocument`, non da
`SendElectronically`: quella strada restituisce un blob vuoto senza motivazione, e i suoi
controlli (`Fattura Doc. Helper`) sono `[Scope('OnPrem')]`, irraggiungibili in Cloud.
`FPA Sales Export` (73007) decide solo nome file e archiviazione.

## Trappole da non ripetere

- **Namespace FatturaPA**: solo la **radice** e' qualificata, tutti i discendenti no. La radice
  va serializzata con un **prefisso** (`p:FatturaElettronica`), mai come `xmlns` di default,
  altrimenti i figli vengono trascinati nel namespace e SdI scarta il file.
- **XPath sulle ricevute**: usare sempre `local-name()`, mai un namespace manager con un URI
  cablato. Le ricevute reali stanno in `ivaservizi.agenziaentrate.gov.it`, non in
  `fatturapa.gov.it`, ed entrambe le famiglie sono legittime.
- **Campi scalari delle ricevute**: prenderli come figli **diretti** della radice (`/*/...`).
  Una ricerca discendente pesca il `Destinatario/Descrizione` sbagliato.
- **`format-number(NodeRef, ...)` fallisce in silenzio** sotto XSLT 3.0: la pagina si disegna e
  **tutti gli importi sono celle vuote**. Se valuti un motore XSLT alternativo, controlla gli
  importi, non che la pagina appaia.
- **`FPA Body Extractor` rimuove la firma** dall'XML ridotto: la `ds:Signature` copre il file
  intero e non verificherebbe piu'. L'originale firmato e' quello di *Download XML*.
- **`FPA VAT Summary Buffer` (73005) e' `TableType = Temporary`**: FatturaPA vuole un solo
  `DatiRiepilogo` per combinazione aliquota/natura/esigibilita', quindi le righe si accumulano
  e si scrivono dopo.
- **`NumberSequence` non restituisce i valori**: un progressivo consumato e poi rollbackato
  lascia un buco. Per questo il dry run usa `TEST0` fisso.

## Verificare una modifica al viewer

Il foglio AssoSoftware fallisce in silenzio se il patching e' incompleto. Non basta che la
fattura appaia: su `docs/sample/` controlla che

- gli **importi siano valorizzati**, non vuoti;
- `anteprima-3-documenti.html` renda i 3 body del lotto separatamente, ognuno con il proprio
  numero documento;
- tutti e **9 i tipi di ricevuta** rendano i campioni ufficiali (`IT01234567890_11111_*.xml`).

## Convenzioni

- Nomi file: `<Oggetto>.<Tipo>.al` (es. `FPAXmlFile.Table.al`), prefisso oggetto `FPA`,
  `namespace ZZSoft.FPA;` in testa a ogni file.
- L'affisso `FPA` e' dichiarato in `AppSourceCop.json` (`mandatoryAffixes`): AppSourceCop lo
  pretende come **errore** AS0011, non come warning, su oggetti, campi e controlli/azioni
  aggiunti a oggetti standard. Un oggetto nuovo senza `FPA` non compila.
- Lingua: **commenti e Label in inglese**, documentazione e messaggi di commit in italiano.
  I commenti nei file spiegano il *perche'*, non il *cosa*: mantieni quel registro.
- ID liberi nel range: pagine da 73013 (oltre a 73020/73021 gia' usate), codeunit da 73010
  (73048/73049/73088/73099 usate), pageextension da 73013 (73097 usata). Verifica prima di
  aggiungere.
- Terze parti: qualsiasi componente non originale va elencato in `NOTICE` con titolare, origine
  e modifiche. Due verifiche di licenza sono ancora aperte (Saxonica, AssoSoftware), vedi
  `CONTRIBUTING.md`.

## Debiti noti gia' tracciati

Non riscoprirli, sono in `docs/DOCUMENTAZIONE.md`/`CONTRIBUTING.md`: `Electronic Format` su
`FPA Sales Export Setup` e' un campo morto da rimuovere; `docs/SDI/` duplica byte per byte
`docs/sample/`, `tools/sdi-xsl/` e `schemas/`; i `.p7m` non sono gestiti; accanto al
`.gitignore` c'e' un `.gitingore` (refuso).
