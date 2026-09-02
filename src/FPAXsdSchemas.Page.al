namespace ZZSoft.FPA;

page 73006 "FPA Xsd Schemas"
{
    Caption = 'FatturaPA XSD Schemas';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "FPA Xsd Schema";
    SourceTableView = sorting("Load Order");

    layout
    {
        area(Content)
        {
            repeater(Schemas)
            {
                field("Load Order"; Rec."Load Order")
                {
                    ApplicationArea = All;
                    ToolTip = 'Order in which the schemas are handed to the validator. xmldsig-core-schema.xsd (10) must come before the FatturaPA schema (20), because the latter imports the former.';
                }
                field("Code"; Rec.Code) { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
                field("Target Namespace"; Rec."Target Namespace")
                {
                    ApplicationArea = All;
                    ToolTip = 'Read from the targetNamespace attribute of the uploaded .xsd file.';
                }
                field("File Name"; Rec."File Name") { ApplicationArea = All; }
                field(Loaded; Rec.Loaded)
                {
                    ApplicationArea = All;
                    StyleExpr = LoadedStyle;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            fileuploadaction(LoadSchemas)
            {
                ApplicationArea = All;
                Caption = 'Load Schemas';
                Image = Import;
                AllowMultipleFiles = true;
                AllowedFileExtensions = '.xsd';
                ToolTip = 'Uploads one or more .xsd files. FatturaPA needs two of them, so select both at once: each file is matched to its row by targetNamespace, and a row is created if none exists.';

                trigger OnAction(Files: List of [FileUpload])
                var
                    XsdSchema: Record "FPA Xsd Schema";
                    CurrentFile: FileUpload;
                    InStr: InStream;
                    LoadedCount: Integer;
                    DoneTxt: Label '%1 schema(s) loaded.', Comment = '%1 = number of schemas';
                begin
                    foreach CurrentFile in Files do begin
                        CurrentFile.CreateInStream(InStr, TextEncoding::UTF8);
                        if XsdSchema.LoadFromStream(InStr, CurrentFile.FileName()) then
                            LoadedCount += 1;
                    end;
                    CurrPage.Update(false);
                    Message(DoneTxt, LoadedCount);
                end;
            }
            action(LoadIntoRow)
            {
                ApplicationArea = All;
                Caption = 'Load Into Selected Row';
                Image = ImportCodes;
                ToolTip = 'Uploads a single .xsd file into the row you have selected, keeping its code and load order.';

                trigger OnAction()
                begin
                    Rec.TestField(Code);
                    Rec.UploadSchema();
                    CurrPage.Update(false);
                end;
            }
            action(CreateDefaults)
            {
                ApplicationArea = All;
                Caption = 'Create Default Rows';
                Image = Setup;
                ToolTip = 'Creates the two empty rows expected by FatturaPA v1.2, in the right load order. Not needed if you use Load Schemas, which creates them itself.';

                trigger OnAction()
                var
                    XsdSchema: Record "FPA Xsd Schema";
                begin
                    XsdSchema.EnsureDefaultRows();
                    CurrPage.Update(false);
                end;
            }
        }

        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(LoadSchemas_Promoted; LoadSchemas) { }
                actionref(LoadIntoRow_Promoted; LoadIntoRow) { }
                actionref(CreateDefaults_Promoted; CreateDefaults) { }
            }
        }
    }

    var
        LoadedStyle: Text;

    trigger OnAfterGetRecord()
    begin
        if Rec.Loaded then
            LoadedStyle := 'Favorable'
        else
            LoadedStyle := 'Unfavorable';
    end;
}
