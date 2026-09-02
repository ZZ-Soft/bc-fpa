namespace ZZSoft.SDIBase;

permissionset 73000 "FE Viewer"
{
    Assignable = true;
    Caption = 'FatturaPA Viewer';

    Permissions =
        table "FE Xml File" = X,
        tabledata "FE Xml File" = RIMD,
        table "FE Xml File Document" = X,
        tabledata "FE Xml File Document" = RIMD,
        table "FE Receipt Error" = X,
        tabledata "FE Receipt Error" = RIMD,
        table "FE Sales Export Setup" = X,
        tabledata "FE Sales Export Setup" = RIMD,
        table "FE Xsd Schema" = X,
        table "FE SDI Cue" = X,
        tabledata "FE SDI Cue" = RIMD,
        tabledata "FE Xsd Schema" = RIMD,
        codeunit "FE Xml Reader" = X,
        codeunit "FE Xsd Validator" = X,
        codeunit "FE Body Extractor" = X,
        codeunit "FE Chunk Helper" = X,
        codeunit "FE File Name Parser" = X,
        codeunit "FE SdI Status Mgt." = X,
        codeunit "FE Progressivo Mgt." = X,
        codeunit "FE Sales Export" = X,
        codeunit "FE Xml File Manager" = X,
        codeunit "FE Xml Test" = X,
        page "FE Xml Files" = X,
        page "FE Xml File Card" = X,
        page "FE Xml File Viewer" = X,
        page "FE Xml File Documents" = X,
        page "FE Xml File Doc Subform" = X,
        page "FE Receipt Subform" = X,
        page "FE Receipt Errors" = X,
        page "FE Xml File Doc Viewer" = X,
        page "FE Xsd Schemas" = X,
        page "FE Sales Export Setup" = X,
        page "FE SDI Role Center" = X,
        page "FE SDI Activities" = X;
}
