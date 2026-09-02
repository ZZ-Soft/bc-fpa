namespace ZZSoft.FPA;

permissionset 73000 "FPA Viewer"
{
    Assignable = true;
    Caption = 'FatturaPA Viewer';

    Permissions =
        table "FPA Xml File" = X,
        tabledata "FPA Xml File" = RIMD,
        table "FPA Xml File Document" = X,
        tabledata "FPA Xml File Document" = RIMD,
        table "FPA Receipt Error" = X,
        tabledata "FPA Receipt Error" = RIMD,
        table "FPA Sales Export Setup" = X,
        tabledata "FPA Sales Export Setup" = RIMD,
        table "FPA Xsd Schema" = X,
        table "FPA SDI Cue" = X,
        tabledata "FPA SDI Cue" = RIMD,
        tabledata "FPA Xsd Schema" = RIMD,
        codeunit "FPA Xml Reader" = X,
        codeunit "FPA Xsd Validator" = X,
        codeunit "FPA Body Extractor" = X,
        codeunit "FPA Chunk Helper" = X,
        codeunit "FPA File Name Parser" = X,
        codeunit "FPA SdI Status Mgt." = X,
        codeunit "FPA Progressivo Mgt." = X,
        codeunit "FPA Sales Export" = X,
        codeunit "FPA Xml File Manager" = X,
        codeunit "FPA Xml Test" = X,
        page "FPA Xml Files" = X,
        page "FPA Xml File Card" = X,
        page "FPA Xml File Viewer" = X,
        page "FPA Xml File Documents" = X,
        page "FPA Xml File Doc Subform" = X,
        page "FPA Receipt Subform" = X,
        page "FPA Receipt Errors" = X,
        page "FPA Xml File Doc Viewer" = X,
        page "FPA Xsd Schemas" = X,
        page "FPA Sales Export Setup" = X,
        page "FPA SDI Role Center" = X,
        page "FPA SDI Activities" = X;
}
