namespace ZZSoft.FPA;

page 73009 "FPA Sales Export Setup"
{
    Caption = 'FatturaPA Sales Export Setup';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "FPA Sales Export Setup";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(Export)
            {
                Caption = 'Export';

                field("Electronic Format"; Rec."Electronic Format")
                {
                    ApplicationArea = All;
                    ToolTip = 'The Electronic Document Format the Italian localization registers for FatturaPA. The XML is built by the standard export through that format; this extension only names and files the result.';
                }
                field("Open Card After Export"; Rec."Open Card After Export") { ApplicationArea = All; }
            }
            group(FileName)
            {
                Caption = 'File Name';

                field(TransmitterId; TransmitterId)
                {
                    ApplicationArea = All;
                    Caption = 'Transmitter';
                    Editable = false;
                    ToolTip = 'IdPaese + IdCodice taken from Company Information, exactly as it will appear in the file name. Fix Company Information if this looks wrong.';
                }
                field(SampleFileName; SampleFileName)
                {
                    ApplicationArea = All;
                    Caption = 'Example';
                    Editable = false;
                    ToolTip = 'What the next file would be called.';
                }
                field("Progressivo Source"; Rec."Progressivo Source")
                {
                    ApplicationArea = All;

                    trigger OnValidate()
                    begin
                        CurrPage.Update(true);
                    end;
                }
                field("Progressivo Start No."; Rec."Progressivo Start No.")
                {
                    ApplicationArea = All;
                    Enabled = Rec."Progressivo Source" = Rec."Progressivo Source"::Sequential;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ViewWholeFile)
            {
                ApplicationArea = All;
                Caption = 'Update FPA Base Data';
                Image = View;
                ToolTip = 'Updates the FPA Base data with the latest information.';
                RunObject = codeunit "FPA Base";
                RunPageOnRec = false;
            }
        }
    }
    var
        TransmitterId: Text;
        SampleFileName: Text;

    trigger OnOpenPage()
    begin
        Rec.GetSetup();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        RefreshPreview();
    end;

    local procedure RefreshPreview()
    var
        ProgressivoMgt: Codeunit "FPA Progressivo Mgt.";
        SampleTok: Label '%1_%2.xml', Locked = true;
        Placeholder: Text;
    begin
        // Never call NextFileName here: it would burn a progressive just to draw the page.
        if not TryGetTransmitterId(ProgressivoMgt, TransmitterId) then begin
            TransmitterId := '';
            SampleFileName := '';
            exit;
        end;

        case Rec."Progressivo Source" of
            Rec."Progressivo Source"::Sequential:
                Placeholder := '00001';
            Rec."Progressivo Source"::Random:
                Placeholder := 'A7K2Q';
            Rec."Progressivo Source"::"From Document":
                Placeholder := 'HV1GH';
        end;
        SampleFileName := UpperCase(StrSubstNo(SampleTok, TransmitterId, Placeholder));
    end;

    [TryFunction]
    local procedure TryGetTransmitterId(var ProgressivoMgt: Codeunit "FPA Progressivo Mgt."; var Result: Text)
    begin
        Result := ProgressivoMgt.GetTransmitterId();
    end;
}
