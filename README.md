# FatturaPA XML Viewer — Business Central online (SaaS)

**Publisher:** ZZ Soft · **ID range:** 73000–73099

Una sola tabella per tutti i file di fattura elettronica italiana:

- **acquisti e ricevute** caricati come XML (upload multiplo, drag&drop);
- **vendite** generate dall'export standard della localizzazione italiana e archiviate in
  automatico, con il nome secondo la regola SdI.

Ogni fattura viene esplosa in un documento per `FatturaElettronicaBody`, le ricevute si
collegano da sole alla fattura di riferimento, il tutto si valida contro gli XSD ufficiali e si
visualizza con il foglio di stile **AssoSoftware**. Nessun assembly .NET: `target: Cloud`.

---

## Modello dati

Un file FatturaPA contiene **un solo `FatturaElettronicaHeader`** e **N `FatturaElettronicaBody`**.
Da qui le due tabelle:

```
FE Xml File                    (73000)   la "cartella": 1 record per file fisico
  PK: File Name (Code[250])              nome file SdI = univoco per costruzione
  ├─ Xml (Blob)                          il file, memorizzato UNA volta sola
  ├─ File Type                           Invoice | Receipt | Unknown
  ├─ SdI Base Name  ◄──────────┐         IT..._HV1GH, senza estensione
  │                            │
  ├─ se FATTURA:               │  join fattura ⇄ ricevute
  │   DatiTrasmissione, Cedente, Cessionario   ← dall'unico header
  │   No. of Bodies, Has Signature, Versione
  │   SdI Status               │         esito derivato dalle ricevute
  │   No. of Receipts (FlowField su se stessa)
  │                            │
  └─ se RICEVUTA:              │
      Receipt Type (RC/NS/MC/MT/Other) + Receipt Type Code + Progressive
      Identificativo SdI, Message Id, Receipt Date/Time
      Error Count, Receipt Note
        │
        │ File Name
        ▼
FE Invoice Document            (73001)   1 record per FatturaElettronicaBody
  PK: File Name + Body No.               (solo per le fatture)
  ├─ TipoDocumento, Numero, Data, Divisa, ImportoTotaleDocumento, Causale
  ├─ Imponibile / Imposta      ← somma dei DatiRiepilogo di quel body
  ├─ No. of Lines, No. of VAT Rates, DataScadenzaPagamento, ModalitaPagamento
  └─ Cedente / Cessionario / Validation Status   ← FlowField lookup sul padre
```

### Fatture e ricevute nella stessa cartella

```
IT02155810225_HV1GH.xml            1 underscore  -> fattura
IT02155810225_HV1GH_RC_003.xml     di piu        -> ricevuta di quella fattura
              ^base^      ^^ ^^^
                          |  progressivo
                          tipo ricevuta
```

La regola del nome regge perché nessuna delle due parti del nome fattura può contenere un
underscore: è `IdPaese + IdCodice` + `_` + `ProgressivoInvio` (`[A-Za-z0-9]{1,5}`).

| Codice | Tipo | `MessaggiTypes_v1.1.xsd` | `SDIRicevute.xsd` |
|---|---|---|---|
| `RC` | Ricevuta di consegna | `RicevutaConsegna` | `RicevutaConsegna` |
| `NS` | Notifica di scarto | `NotificaScarto` | `RicevutaScarto` |
| `MC` | Notifica di mancata consegna | `NotificaMancataConsegna` | `RicevutaImpossibilitaRecapito` |
| `MT` | File dei metadati | `MetadatiInvioFile` | `FileMetadati` |
| `NE` | Notifica esito cedente/prestatore | `NotificaEsito` | — |
| `EC` | Notifica esito cessionario/committente | `NotificaEsitoCommittente` | — |
| `SE` | Notifica di scarto esito committente | `ScartoEsitoCommittente` | — |
| `DT` | Notifica decorrenza termini | `NotificaDecorrenzaTermini` | — |
| `AT` | Attestazione di trasmissione con impossibilità di recapito | `AttestazioneTrasmissioneFattura` | — |

### Due famiglie di schemi, entrambe legittime

```
MessaggiTypes_v1.1.xsd   ns http://www.fatturapa.gov.it/sdi/messaggi/v1.0
                         tutti e nove i tipi

SDIRicevute.xsd          ns http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fattura/messaggi/v1.0
                         quattro tipi, tre con nomi radice DIVERSI
```

Solo `RicevutaConsegna` si chiama uguale in entrambe. **Le ricevute che ricevete davvero
appartengono alla seconda famiglia** — le vostre `_RC_003.xml` stanno nel namespace `ivaservizi`.
Sono mappate entrambe le grafie, e i fogli di stile sono patchati per matchare l'una o l'altra
(vedi sotto), quindi non importa da quale canale arrivi il file.

SdI ne definisce altri (`NE`, `EC`, `SE`, `DT`, `AT`…). Non sono nell'enum, ma **non vanno persi**:
il codice grezzo finisce sempre in `Receipt Type Code` e il tipo diventa `Other`. Per promuoverne
uno bastano un `value` in `enum "FE Receipt Type"` e una riga in `ReceiptTypeFromCode`.

**Il join è `SdI Base Name`, non il nome file.** È il prefisso *senza estensione*. Confermato sui
vostri file: dentro `IT02155810225_HV1GH_RC_003.xml` il `NomeFile` è
`IT02155810225_HV1GH.xml.p7m`, mentre la copia della fattura che avete su disco è
`IT02155810225_HV1GH.xml`. Un join sul nome completo — o sul `NomeFile` dichiarato dalla ricevuta —
fallirebbe proprio sulle fatture firmate. Il `NomeFile` viene comunque memorizzato in
`Referenced File Name`, perché documenta cosa è stato effettivamente trasmesso.

### Chi decide cosa

Il nome è la regola, ma da solo non basta: un file rinominato a mano con quattro underscore
verrebbe archiviato come ricevuta di una fattura inesistente, sotto un base name ritagliato dal
proprio nome. Quindi:

- **la radice XML decide fattura o ricevuta.** Radice `FatturaElettronica` ⇒ è una fattura,
  qualunque cosa dica il nome; in quel caso il base name diventa il nome intero.
- **il nome file decide quale ricevuta è** e il base name che la lega alla fattura. Un codice
  presente nel nome non viene **mai** sovrascritto dalla radice: `DT` resta `DT` (tipo `Other`),
  non viene silenziosamente riclassificato.

### Esito SdI

`SdI Status` sulla fattura è ricalcolato da zero a ogni import o cancellazione di un file con
quel base name — le ricevute arrivano spesso *prima* della fattura, e un aggiornamento
incrementale finirebbe per divergere.

Il flusso ha **tre stadi**, e uno stadio successivo prevale su quello precedente:

| Stadio | Ricevute | Esito |
|---|---|---|
| 1. accettazione del **file** | `NS` | Rejected by SdI |
| 2. **consegna** | `RC` `MC` `AT` | Delivered / Not Delivered / Transmission Attested |
| 3. esito dal **committente** (solo PA) | `EC` `DT` | Accepted / Refused / Terms Expired |

Uno scarto batte tutto: un file che SdI ha rifiutato non può poi risultare "consegnato" per via
di una ricevuta arrivata prima. `EC` e `NE` portano entrambe l'`Esito` del committente
(`EC01` accettata, `EC02` rifiutata) — `NE` è lo stesso esito riferito al cedente, quindi si
leggono allo stesso modo. `SE` è volutamente ignorata ai fini dello stato: dice che il messaggio
di esito del committente era malformato, quindi lascia la fattura dov'era.

### Visualizzazione di una ricevuta

Il foglio AssoSoftware fa match solo su `FatturaElettronica`. Ma SdI pubblica **un foglio di
stile per ogni tipo di messaggio**, e sono tutti e nove nel bundle: una ricevuta viene resa come
la rende SdI, non come sorgente XML. Il viewer sceglie il foglio per chiave —
`FATTURA` per una fattura, il codice a due lettere per una ricevuta — e ricade sul sorgente
indentato solo se per quel tipo non c'è un foglio.

```
window.FE_SEF = { FATTURA, RC, NS, MC, MT, NE, EC, SE, DT, AT }   // ~750 KB
```

Le letture usano `local-name()` invece di un namespace manager, ed è quello che le rende solide:
le ricevute reali stanno in

```
http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fattura/messaggi/v1.0
```

**non** in `http://www.fatturapa.gov.it/sdi/messaggi/v1.0`, che è l'URI sotto cui la documentazione
dei tipi di messaggio viene di solito archiviata. Cablare l'uno o l'altro sarebbe stato sbagliato.

I campi scalari sono presi come **figli diretti della radice** (`/*/…`), non con una ricerca
discendente: una ricevuta di consegna contiene un `Destinatario/Descrizione` che una
`//Descrizione` restituisce al posto di quello giusto.

Una `RicevutaConsegna` non ha né `Descrizione` né `Note` a livello di radice: l'unica prosa che
contiene sta sotto `Destinatario`, e vale la pena tenerla — *"Trasmesso su canale registrato dal
cessionario/committente"* dice una cosa ben diversa da una consegna via PEC. Il fallback è
esplicito su quel nodo, non una ricerca cieca.

**Anche le ricevute sono firmate**, da SdI con il proprio certificato — `ds:Signature` è
obbligatorio a schema in tutte e tre le ricevute per trasmittenti. `versione` e `Has Signature`
si leggono quindi sulla radice per entrambi i tipi di file, non nel ramo fattura.

### Errori di scarto: tabella figlia, non un campo

`SDIRicevute.xsd` ammette fino a **200 `Errore`** per `RicevutaScarto`, ognuno con `Codice`,
`Descrizione` (max 1000 char) e `Suggerimento` (max 2000, **obbligatorio**). Comprimere tutto in
un campo testo perderebbe quasi tutto — e il `Suggerimento` è proprio la parte che dice cosa
correggere. Da qui la tabella `FE Receipt Error` (73003), una riga per errore, con sottopagina
sulla card. `Receipt Note` resta il riassunto da lista: primo codice + descrizione.

### Campi allineati allo schema

| Campo | Prima | Da `SDIRicevute.xsd` |
|---|---|---|
| `Identificativo SdI` | `Code[20]` | `Code[36]` (`maxLength=36`) |
| `Message Id` | `Code[30]` | `Code[36]` |
| `File Hash` | assente | SHA-256 del file trasmesso |
| `Pec Message Id` | assente | opzionale in tutte le ricevute |
| `Data Messa A Disposizione` | assente | solo `MC`: da quando la fattura si considera ricevuta |
| `Tentativi Invio` | assente | solo `MT` |

`FileMetadati` porta `CodiceDestinatario` e `Formato`: finiscono nei campi `Codice Destinatario`
e `Formato Trasmissione` che già esistono e significano esattamente la stessa cosa.

Il dato di testata **non è duplicato**: sui documenti è esposto come FlowField `lookup` verso
`FE Xml File`. Anche l'XML resta uno solo, sul padre.

### `File Name` come chiave

Il nome SdI (`IdPaese + IdCodice + '_' + ProgressivoInvio + .xml`) è univoco per costruzione,
quindi è la PK. Essendo un campo `Code`, BC lo porta in maiuscolo: `Original File Name`
conserva la grafia originale per la visualizzazione e per il download.

> Nota: il `ProgressivoInvio` SdI è formalmente case-sensitive. La collation di BC è
> case-insensitive, quindi due file che differissero solo per maiuscole/minuscole
> collidono. In pratica non succede, ma se vi serve la garanzia teorica va aggiunto un
> `Entry No.` come PK e un indice unico su `File Name`.

### Visualizzazione di un singolo documento

Il foglio AssoSoftware rende **tutti** i body che trova: su un lotto da 3 fatture produce
3 fatture impilate in una pagina. Dato che l'app le esplode in record separati, il viewer
non può passargli il file intero.

`FE Body Extractor.ExtractBody` costruisce al volo un XML ridotto — header + **solo quel body** —
e lo manda all'add-in. Il documento ridotto resta schema-valido: `FatturaElettronicaBody` ha
`maxOccurs="unbounded"`, tenerne uno è sempre legale.

**La firma viene rimossa dall'XML ridotto.** La `ds:Signature` copre l'intero file originale:
tolti dei body non può più verificare, e lasciarla darebbe un documento che *sembra* firmato
e non lo è. È opzionale a schema, quindi il ridotto resta valido senza. L'originale con firma
intatta è quello che restituisce *Download XML*.

Se il file ha un solo body l'estrazione viene saltata del tutto (`No. of Bodies <= 1`),
quindi il caso comune non paga né parsing né serializzazione.

**Verificato sul vostro `IT03237470236_ZZZZZ.xml`** (1,2 MB, 1 header, 3 body, firmato):

| Body | Numero | Data | Imponibile | Imposta | Totale | Righe |
|---:|---|---|---:|---:|---:|---:|
| 1 | 82600460040 | 2026-01-22 | 48,43 | 10,65 | **59,08** | 6 |
| 2 | 82600764942 | 2026-02-18 | 52,50 | 11,55 | **64,05** | 6 |
| 3 | 82601569120 | 2026-03-19 | 48,66 | 10,71 | **59,37** | 6 |

Il file intero rende 72 importi; ogni estrazione ne rende 24, con il solo numero documento
corretto. `sample/anteprima-3-documenti.html` mostra le tre rese affiancate.

---

## Fatture di vendita

L'XML **non viene costruito qui**. Lo produce l'export standard della localizzazione italiana,
chiamato attraverso `Record "Electronic Document Format".SendElectronically` — lo stesso percorso
dell'azione *Send*. Passare da lì invece che dagli oggetti della localizzazione rende
l'estensione indipendente dai loro ID e da quale versione di FatturaPA è installata: qualunque
formato sia registrato per il documento è quello che viene generato.

Questa estensione decide due cose soltanto: **come si chiama il file e dove finisce**.

```
Posted Sales Invoice ──► SendElectronically ──► TempBlob ──► FE Xml File
   azione "Generate and File XML"   (localizzazione IT)      + esplosione documenti
```

### Il nome del file

```
IT02155810225_00001.xml
└─┬─┘└────┬────┘ └─┬─┘
  │       │        └── progressivo, 5 caratteri
  │       └─────────── VAT Registration No.  ┐ Company Information
  └─────────────────── IdPaese               ┘
```

`IdPaese` è il **codice ISO** della Country/Region, non il codice BC: sono campi diversi e il
secondo è libero. Se la partita IVA è già inserita con il prefisso (`IT02155810225`) il prefisso
non viene raddoppiato.

### Il progressivo

| Modalità | Come |
|---|---|
| **Sequential** (default) | contatore in base 36 via `NumberSequence` |
| **Random** | 5 caratteri estratti, con verifica di collisione |
| **From Document** | il `ProgressivoInvio` che l'export ha scritto nell'XML |

Avete chiesto 5 caratteri casuali e l'opzione c'è, ma il default è il contatore, per due motivi.

**Non può collidere.** Il casuale ha bisogno di un ciclo di verifica-e-riprova che in teoria può
non concludersi; il contatore è univoco per costruzione. `NumberSequence` distribuisce i valori
fuori transazione e non li restituisce in caso di rollback — esattamente quello che serve: un
progressivo consumato da un export poi fallito non deve essere riassegnato.

**È quello che fate già.** Nei vostri file `HV1GH` e `HV1GI` sono, in base 36, 30001697 e
30001698: differiscono di uno. Anche il vostro attuale trasmittente usa un contatore, non
caratteri casuali.

Cinque caratteri base 36 danno 60.466.176 file prima di riavvolgersi; il nome viene comunque
verificato contro la tabella prima dell'uso.

### ProgressivoInvio e nome file possono divergere

La specifica SdI chiede solo che il progressivo nel **nome** sia univoco per trasmittente: non
deve coincidere con `DatiTrasmissione/ProgressivoInvio` dentro l'XML. Con *Sequential* o *Random*
i due valori saranno diversi — visibile sulla card, dove il campo `Progressivo Invio` mostra
quello letto dall'XML. Se preferite che coincidano, *From Document* fa esattamente quello.
Nessuna delle due opzioni riscrive il contenuto generato da Business Central.

---

## Il vincolo che determina l'architettura

AL **non ha un motore XSLT**. `XmlDocument` è un wrapper su `System.Xml.Linq`;
`System.Xml.Xsl.XslCompiledTransform` non è raggiungibile da un'estensione `target: Cloud`.

| Operazione | Come |
|---|---|
| Leggere/interrogare l'XML | `XmlDocument` + `XmlNamespaceManager` + XPath |
| **Validare contro XSD** | `Codeunit "Xml Validation"` (System Application, `System.Xml`) |
| Applicare un foglio XSLT | ❌ niente in AL → control add-in JavaScript |

### Perché SaxonJS e non `XSLTProcessor` del browser

Chromium ha annunciato la **rimozione di XSLT dal browser**, target fine 2026; Firefox è
sulla stessa strada. Un viewer basato su `XSLTProcessor` smetterebbe di funzionare da solo.
L'estensione impacchetta **SaxonJS 2** e il foglio di stile **pre-compilato in SEF**:
a runtime non c'è nessun parsing di XSLT.

---

## Due patch obbligatorie al foglio di stile

Il foglio AssoSoftware funziona con libxslt e con l'`XSLTProcessor` nativo, ma **non** con un
processore rigoroso. Entrambe verificate sui file reali:

**1. `<xsl:call-template select=".">` — 10 occorrenze.**
`@select` non è ammesso su `xsl:call-template`. Saxon rifiuta di compilare (`XTSE0090`).
Rimuoverlo è un no-op: `call-template` non cambia comunque il context node.

**2. `format-number(NodeRef, …)` — 26 occorrenze.**
La più insidiosa, perché **non dà errore**. In XSLT 3.0 il nodo atomizza a `xs:untypedAtomic`,
il cast implicito a `xs:double` produce `NaN`, e gli `xsl:if test="number(...)"` a monte del
foglio rendono il risultato **una cella vuota**. Esito: la fattura si vede, ma *tutti gli
importi e le aliquote sono in bianco*. Va incapsulato in `number()`.

> Stessa trappola su `xslt-processor` (npm, XSLT 1.0 puro): 27 importi vuoti, nessun errore.
> Se valutate un motore JS alternativo, **controllate gli importi**, non che la pagina si disegni.

### E due sui fogli di stile SdI

**3. `<xsl:output version="4.0">`.** SaxonJS serializza solo HTML 5 e solleva `SESU0013` su
qualunque altra versione. Diventa `5.0`.

**4. La radice è vincolata a un namespace.** I fogli SdI matchano `a:RicevutaConsegna`, con `a`
legato a `fatturapa.gov.it`. Le vostre ricevute stanno nell'altro namespace, quindi il foglio
ufficiale produceva **una pagina bianca**. Riscrivendo quell'*unico* selettore su `local-name()`,
con la grafia alternativa dove le due famiglie divergono, ogni foglio funziona per entrambe. È
l'unica espressione con un prefisso in quei fogli: tutto il resto seleziona già figli non
qualificati, quindi la patch è una riga per foglio.

Tutte e quattro applicate automaticamente da `tools/build-sef.sh`. Sulla fattura, dopo le patch,
l'output è **identico carattere per carattere** a `xsltproc`, cioè a ciò che il browser mostra oggi.

---

## Struttura

```
app.json                             publisher: ZZ Soft, idRanges 73000-73099
src/
  FEXmlFile.Table.al             73000   la cartella: 1 record per file
  FEInvoiceDocument.Table.al     73001   1 record per FatturaElettronicaBody
  FEXsdSchema.Table.al           73002   XSD caricati
  FEValidationStatus.Enum.al     73000
  FEFileType.Enum.al             73001   Invoice / Receipt / Unknown
  FEReceiptType.Enum.al          73002   RC / NS / MC / MT / Other
  FESdiStatus.Enum.al            73003   esito della fattura a SdI
  FEXmlReader.Codeunit.al        73000   import multiplo + classificazione + esplosione
  FEXsdValidator.Codeunit.al     73001   validazione via Codeunit "Xml Validation"
  FEBodyExtractor.Codeunit.al    73002   XML ridotto a un singolo body
  FEChunkHelper.Codeunit.al      73003   spezzettamento per il control add-in
  FEFileNameParser.Codeunit.al   73004   nome file -> tipo, base name, codice ricevuta
  FESdiStatusMgt.Codeunit.al     73005   ricevute -> esito sulla fattura
  FEProgressivoMgt.Codeunit.al   73006   nome file SdI per le vendite
  FESalesExport.Codeunit.al      73007   export standard IT -> FE Xml File
  FESalesExportSetup.Table.al    73004   formato elettronico + modalita progressivo
  FEFileOrigin.Enum.al           73004   Upload / Sales Export
  FEProgressivoSource.Enum.al    73005   Sequential / Random / From Document
  FESourceDocType.Enum.al        73006   Sales Invoice / Sales Credit Memo
  FEStylesheetViewer.ControlAddIn.al
  FEXmlFiles.Page.al             73000   lista file  (fileuploadaction)
  FEXmlFileCard.Page.al          73001   card file + sottopagina documenti
  FEXmlFileViewer.Page.al        73002   anteprima del file intero
  FEInvoiceDocuments.Page.al     73003   lista documenti (fileuploadaction)
  FEInvoiceDocSubform.Page.al    73004   sottopagina documenti
  FEInvoiceViewer.Page.al        73005   anteprima di UN documento
  FEXsdSchemas.Page.al           73006   XSD (fileuploadaction)
  FEReceiptSubform.Page.al       73007   ricevute di una fattura
  FEReceiptErrors.Page.al        73008   errori di uno scarto
  FESalesExportSetup.Page.al     73009   setup export vendite
  FEPostedSalesInvoice.PageExt.al   73010
  FEPostedSalesInvoices.PageExt.al  73011  export multiplo dalla lista
  FEPostedSalesCrMemo.PageExt.al    73012
  FEViewerPermissions.PermissionSet.al  73000
  assets/
    js/
      SaxonJS2.rt.js                 ⚠️ da scaricare (vedi sotto)
      fe-sef.js                      generato — foglio di stile compilato
      fe-viewer.js, fe-startup.js
    css/
      fe-viewer.css
tools/
  build-sef.sh
  FoglioStileAssoSoftware-BCpatched.xsl   già patchato, pronto
schemas/
  SDIRicevute.xsd                    schema ricevute (canale ivaservizi), come fornito
  SDIRicevute-BC.xsd                 stesso schema, caricabile (vedi sotto)
  MessaggiTypes_v1.1.xsd             schema messaggi (canale fatturapa), come fornito
  MessaggiTypes_v1.1-BC.xsd          stesso schema, senza schemaLocation
sample/
  rendered-invoice.html              fattura singola
  anteprima-3-documenti.html         le 3 fatture del lotto, una per scheda
  anteprima-fatture-e-ricevute.html  2 fatture ZZ Soft + le loro ricevute di consegna
  esempio-RicevutaScarto.xml         scarto con 2 errori, valido a schema
  anteprima-ricevute-sdi.html        tutti e 9 i tipi resi + una ricevuta reale
  IT01234567890_11111_*.xml          i campioni ufficiali SdI, uno per tipo
tools/sdi-xsl/                       i 9 fogli di stile ufficiali SdI
```

### Percorsi degli asset

Il `controladdin` risolve `Scripts` / `StartupScript` / `StyleSheets` **a partire dalla cartella
che contiene il file .al**. `FEStylesheetViewer.ControlAddIn.al` sta in `src/`, quindi gli asset
stanno in `src/assets/` e i riferimenti sono `assets/js/...` e `assets/css/...`.
Spostando il controladdin altrove vanno riallineati anche quei cinque path.


## Setup

1. **SaxonJS runtime** — già incluso: `src/assets/js/saxon-js2/SaxonJS2.rt.js`
   (runtime browser, 499 KB). Non serve scaricare nulla, il progetto compila da un
   clone pulito. Per aggiornarlo, sostituire il file con una release più recente da
   <https://www.saxonica.com/download/javascript.xml>.

   Il runtime è software proprietario di Saxonica, ridistribuito qui invariato e
   attribuito in `NOTICE`. Le condizioni esatte di ridistribuzione sono ancora da
   confermare con Saxonica: vedi `CONTRIBUTING.md`.

2. **`fe-sef.js`** — già generato. Per rigenerarlo dopo un aggiornamento AssoSoftware:
   `./tools/build-sef.sh percorso/al/nuovo.xsl` (serve Node).

3. **Pubblicare**, poi **FatturaPA XSD Schemas** → *Load Schemas* → selezionare **entrambi**
   gli XSD ufficiali in una volta sola:
   - `xmldsig-core-schema.xsd`
   - `Schema_del_file_xml_FatturaPA_v1.2.x.xsd`

   Ogni file viene instradato alla riga giusta leggendone il `targetNamespace`, e la riga
   viene creata se non c'è: `Create Default Rows` non serve più, resta solo per preparare
   le righe a mano.

   Per validare anche le **ricevute** aggiungere `schemas/SDIRicevute-BC.xsd` (ordine 30) e
   `schemas/MessaggiTypes_v1.1-BC.xsd` (ordine 40): coprono le due famiglie.

   L'ordine di caricamento conta (DSig = 10, FatturaPA = 20, SdIRicevute = 30): entrambi gli
   schemi fanno `xs:import` di quello XML-DSig per `<ds:Signature>`. Caricato da solo, la
   validazione fallisce su ogni file firmato — e le vostre fatture e ricevute lo sono.

   **Perché una copia `-BC` dello schema.** `SDIRicevute.xsd` così com'è **non è caricabile da
   nessun validatore**: alle righe 54, 112 e 170 ci sono i numeri di pagina `185`, `186`, `187`
   rimasti incollati dal PDF delle specifiche. Sono nodi di testo dentro un `xsd:sequence`, che
   non li ammette, e l'errore che ne esce (`Element 'sequence': The content is not valid`) non
   fa capire da dove arrivi. `SDIRicevute-BC.xsd` li toglie e rimuove lo `schemaLocation`
   dall'`xs:import`, così il DSig viene risolto dallo schema già in tabella invece che con una
   chiamata HTTP a w3.org che in SaaS non partirebbe. Nessuna altra modifica.

   Con quella copia, le vostre due ricevute di consegna reali validano.

4. **FatturaPA XML Files** → *Import XML*: si possono selezionare o trascinare **più file
   insieme**, fatture e ricevute mescolate. A fine batch compare un riepilogo che le distingue;
   la card si apre solo se il file era uno.

5. Per le **vendite**: **FatturaPA Sales Export Setup** → scegliere l'*Electronic Format*
   registrato dalla localizzazione per FatturaPA. La pagina mostra il trasmittente ricavato da
   Company Information e un esempio del nome file, così si vede subito se qualcosa non torna.
   Poi, su una fattura registrata, **FatturaPA → Generate and File XML**. Dalla lista si può
   selezionare più documenti insieme.

   Le ricevute possono essere importate **prima** delle rispettive fatture: restano lì, e
   l'esito si aggancia da solo quando la fattura arriva.

## Navigazione

- **FatturaPA XML Files** → un record per file, con `No. of Documents` e `Total Amount` calcolati.
  *Import XML* è una `fileuploadaction` con `AllowMultipleFiles = true`: selezione multipla e
  drag&drop. I file già presenti fanno scattare **una sola** domanda per tutto il batch, e un
  file illeggibile non lo interrompe — `Explode` gira dentro una `[TryFunction]`, il motivo
  finisce sul `Validation Message` di quel file e il ciclo prosegue.
- **card del file** → per una fattura: testata, documenti esplosi, **ricevute SdI** e `SdI Status`;
  per una ricevuta: i campi del messaggio e *Open Invoice* per risalire alla fattura.
  *View Whole File* rende tutto insieme (sorgente indentato se è una ricevuta).
- **FatturaPA Documents** → lista piatta di tutti i documenti di tutti i file; il click apre la resa del singolo documento.
- *Re-read XML* rilegge il blob e ricostruisce testata e righe: da usare dopo un aggiornamento dell'estensione, senza reimportare i file.

## Note sui namespace

In FatturaPA **solo la radice è qualificata** (`p:FatturaElettronica`, URI
`…/docs/xsd/fatture/v1.2`); tutti i discendenti sono senza namespace. Per questo gli XPath in
`FEXmlReader` portano il prefisso `a:` solo sulla radice, e la navigazione dentro il body usa
`GetChildElements` per nome semplice. `DetectRootPath` copre anche v1.1, v1.0 e i file senza namespace.

## Limiti noti

- **File `.p7m`** (CAdES): non gestiti. Scartare una busta PKCS#7 in AL puro non è praticabile;
  la via in SaaS è togliere la busta a monte (middleware / Azure Function) e passare a BC l'XML nudo.
- **Causale**: FatturaPA ne ammette N per documento, viene memorizzata solo la prima.
  Nella resa del viewer ci sono tutte — il campo è solo un'etichetta di lista.
- **Validazione XSD delle ricevute**: il validatore usa gli schemi caricati in tabella, che sono
  quelli FatturaPA. Per validare anche le ricevute vanno caricati gli XSD dei messaggi SdI
  (`MessaggiTypes_v1.0.xsd` e affini) — il caricamento multiplo li instrada da solo per
  `targetNamespace`.
- **`SendElectronically` non è verificato in compilazione**: senza i simboli della localizzazione
  italiana non ho potuto controllare la firma esatta né quale codice formato usiate. È l'unico
  punto dell'estensione che potrebbe richiedere un aggiustamento al primo build.
- **Tipi di ricevuta verificati**: tutti e nove rendono correttamente i campioni ufficiali SdI;
  `RC` è verificato anche su file reali vostri. Di uno scarto vero non ho ancora visto un
  esemplare: il percorso `ListaErrori` è provato sul campione ufficiale e su
  `sample/esempio-RicevutaScarto.xml`, costruito e valido a schema.
- **Dimensione**: l'XML viaggia al client a blocchi di 60.000 caratteri (`FE Chunk Helper`).
  Il lotto da 1,2 MB sono 21 blocchi per il file intero, 7-8 per singolo documento.
- La stampa usa il dialogo del browser sull'`iframe`, non un report RDLC.

---

## Licenza

**Apache License 2.0** — testo integrale in [`LICENSE`](LICENSE).

Il repository ridistribuisce componenti di terze parti che **non** sono coperti da quella
licenza: il runtime SaxonJS 2 di Saxonica, il foglio di stile AssoSoftware (qui anche
modificato) e i fogli di stile e schemi XSD del Sistema di Interscambio. Titolare, origine e
modifiche applicate a ciascuno sono in [`NOTICE`](NOTICE).

Due verifiche di licenza sono ancora aperte — Saxonica e AssoSoftware — e vanno chiuse prima
di rendere pubblico il repository: vedi [`CONTRIBUTING.md`](CONTRIBUTING.md).
