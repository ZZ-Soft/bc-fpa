# Contribuire a FPA

FPA e' un progetto opensource per la gestione della fattura elettronica italiana
in Microsoft Dynamics 365 Business Central. Contributi benvenuti.

## Licenza dei contributi

Il progetto e' distribuito sotto **Apache License 2.0** (vedi `LICENSE`).
Aprendo una pull request accetti che il tuo contributo sia distribuito con la
stessa licenza, secondo la sezione 5 della licenza stessa.

Non aggiungere codice di terze parti senza segnalarlo: ogni componente non
originale va elencato in `NOTICE`, con titolare, origine ed eventuali modifiche.

## Questioni di licenza ancora aperte

Prima di rendere pubblico il repository vanno chiuse due verifiche. Sono
segnalate anche in `NOTICE`.

1. **SaxonJS 2** (`src/assets/js/saxon-js2/SaxonJS2.rt.js`) e' software
   proprietario di Saxonica. Va confermato con Saxonica che la ridistribuzione
   del runtime dentro un'estensione opensource sia ammessa, e con quali
   obblighi di attribuzione.

2. **Foglio di stile AssoSoftware**: qui non viene solo ridistribuito, viene
   anche **modificato** (due patch, senza le quali gli importi risultano vuoti).
   Le condizioni per un'opera derivata vanno verificate con AssoSoftware.

Se una delle due dovesse risultare incompatibile, l'alternativa e' non
impacchettare l'asset e chiedere all'utente di procurarselo in fase di setup.

## Ambiente

- Business Central **28.0** o superiore (`runtime 17.0`), estensione
  `target: Cloud`
- AL Language per VS Code
- Node.js, solo per rigenerare `fe-sef.js`

Il range di ID e' **73000-73099**. E' gia' quasi pieno: verifica gli ID liberi
prima di aggiungere oggetti.

## Build

L'estensione si compila con AL Language senza passaggi preliminari: gli asset
generati sono gia' nel repository.

Per rigenerare il bundle dei fogli di stile dopo un aggiornamento AssoSoftware:

```bash
./tools/build-sef.sh percorso/al/nuovo.xsl
```

Lo script applica le quattro patch necessarie a SaxonJS, compila i dieci fogli
in SEF e li impacchetta in `src/assets/js/fe-sef.js`. Le patch sono documentate
in commento dentro lo script: leggile prima di modificarlo.

## Cosa verificare in una modifica al viewer

Il foglio AssoSoftware fallisce **in silenzio** se il patching e' incompleto:
la pagina si disegna, ma tutti gli importi sono celle vuote. Non basta quindi
controllare che la fattura appaia.

Dopo ogni modifica alla catena XSLT, verifica su `docs/sample/`:

- gli importi sono valorizzati, non vuoti
- `anteprima-3-documenti.html` rende i 3 body del lotto separatamente, ognuno
  con il proprio numero documento
- tutti e 9 i tipi di ricevuta rendono i campioni ufficiali SdI
  (`docs/sample/IT01234567890_11111_*.xml`)

## Convenzioni

- Prefisso oggetti: `FPA`, dichiarato in `AppSourceCop.json` (`mandatoryAffixes`):
  AppSourceCop lo pretende come errore AS0011, non come warning
- Namespace AL: `ZZSoft.FPA`
- Nomi file: `<Oggetto>.<Tipo>.al`, es. `FPAXmlFile.Table.al`
- Gli XPath usano `local-name()` invece di un namespace manager: le ricevute
  reali stanno nel namespace `ivaservizi.agenziaentrate.gov.it`, non in
  `fatturapa.gov.it`, e cablare l'uno o l'altro sarebbe sbagliato
