namespace ZZSoft.FPA;

table 73001 "FPA Xml File Document"
{
    // One record per <FatturaElettronicaBody> inside an "FPA Xml File".
    //
    // The XML itself is NOT duplicated here: it stays once on the parent file record.
    // When a single document has to be rendered, codeunit "FPA Body Extractor" builds a
    // reduced XML on the fly (header + only this body) and streams that to the viewer.

    Caption = 'FatturaPA Document';
    DataClassification = CustomerContent;
    LookupPageId = "FPA Xml File Documents";
    DrillDownPageId = "FPA Xml File Documents";

    fields
    {
        field(1; "File Name"; Code[250])
        {
            Caption = 'File Name';
            NotBlank = true;
            TableRelation = "FPA Xml File"."File Name";
            ValidateTableRelation = false;
        }
        field(2; "Body No."; Integer)
        {
            Caption = 'Body No.';
            MinValue = 1;
            ToolTip = 'Position of the FatturaElettronicaBody element inside the file, starting at 1.';
        }

        field(10; "Tipo Documento"; Code[10])
        {
            Caption = 'Document Type';
            Editable = false;
        }
        field(11; Numero; Text[50])
        {
            Caption = 'Document No.';
            Editable = false;
        }
        field(12; Data; Date)
        {
            Caption = 'Document Date';
            Editable = false;
        }
        field(13; Divisa; Code[10])
        {
            Caption = 'Currency';
            Editable = false;
        }
        field(14; "Importo Totale Documento"; Decimal)
        {
            Caption = 'Total Amount';
            Editable = false;
            AutoFormatType = 1;
            AutoFormatExpression = Rec.Divisa;
        }
        field(15; Causale; Text[250])
        {
            Caption = 'Description';
            Editable = false;
            ToolTip = 'First Causale element of the document. FatturaPA allows several; only the first is stored here.';
        }

        field(20; "Imponibile Importo"; Decimal)
        {
            Caption = 'Taxable Amount';
            Editable = false;
            AutoFormatType = 1;
            AutoFormatExpression = Rec.Divisa;
            ToolTip = 'Sum of ImponibileImporto over all DatiRiepilogo blocks of this document.';
        }
        field(21; Imposta; Decimal)
        {
            Caption = 'VAT Amount';
            Editable = false;
            AutoFormatType = 1;
            AutoFormatExpression = Rec.Divisa;
            ToolTip = 'Sum of Imposta over all DatiRiepilogo blocks of this document.';
        }
        field(22; "No. of Lines"; Integer)
        {
            Caption = 'No. of Lines';
            Editable = false;
            BlankZero = true;
        }
        field(23; "No. of VAT Rates"; Integer)
        {
            Caption = 'No. of VAT Rates';
            Editable = false;
            BlankZero = true;
        }

        field(30; "Data Scadenza Pagamento"; Date)
        {
            Caption = 'Due Date';
            Editable = false;
            ToolTip = 'Earliest DataScadenzaPagamento found in DatiPagamento.';
        }
        field(31; "Modalita Pagamento"; Code[10])
        {
            Caption = 'Payment Method';
            Editable = false;
        }

        // ---- Header data, read through the parent file. Never duplicated. ----
        field(40; "Cedente Denominazione"; Text[100])
        {
            Caption = 'Supplier Name';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup("FPA Xml File"."Cedente Denominazione" where("File Name" = field("File Name")));
        }
        field(41; "Cedente P.IVA"; Code[30])
        {
            Caption = 'Supplier VAT No.';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup("FPA Xml File"."Cedente P.IVA" where("File Name" = field("File Name")));
        }
        field(42; "Cessionario Denominazione"; Text[100])
        {
            Caption = 'Customer Name';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup("FPA Xml File"."Cessionario Denominazione" where("File Name" = field("File Name")));
        }
        field(43; "Cessionario P.IVA"; Code[30])
        {
            Caption = 'Customer VAT No.';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup("FPA Xml File"."Cessionario P.IVA" where("File Name" = field("File Name")));
        }
        field(44; "Validation Status"; Enum "FPA Validation Status")
        {
            Caption = 'Validation Status';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup("FPA Xml File"."Validation Status" where("File Name" = field("File Name")));
            ToolTip = 'XSD validation applies to the whole file, so this is read from the parent file record.';
        }
        field(45; "Formato Trasmissione"; Code[10])
        {
            Caption = 'Transmission Format';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup("FPA Xml File"."Formato Trasmissione" where("File Name" = field("File Name")));
        }
        field(46; "Imported At"; DateTime)
        {
            Caption = 'Imported At';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup("FPA Xml File"."Imported At" where("File Name" = field("File Name")));
        }
    }

    keys
    {
        key(PK; "File Name", "Body No.")
        {
            Clustered = true;
        }
        key(DocumentNo; Numero, Data)
        {
        }
        key(DocumentDate; Data)
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Numero, Data, "Importo Totale Documento")
        {
        }
        fieldgroup(Brick; Numero, Data, "Cedente Denominazione", "Importo Totale Documento")
        {
        }
    }

    /// <summary>
    /// Retrieves the parent file record.
    /// </summary>
    procedure GetXmlFile(var XmlFile: Record "FPA Xml File"): Boolean
    begin
        exit(XmlFile.Get(Rec."File Name"));
    end;

    /// <summary>
    /// Returns the XML of THIS document only: the file header plus this single body.
    /// </summary>
    procedure GetSingleDocumentXml(var Result: BigText)
    var
        XmlFile: Record "FPA Xml File";
        BodyExtractor: Codeunit "FPA Body Extractor";
    begin
        Clear(Result);
        if not GetXmlFile(XmlFile) then
            exit;
        BodyExtractor.ExtractBody(XmlFile, Rec."Body No.", Result);
    end;

}
