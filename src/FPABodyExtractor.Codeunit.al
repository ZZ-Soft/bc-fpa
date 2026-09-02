namespace ZZSoft.FPA;

using System.Utilities;

codeunit 73002 "FPA Body Extractor"
{
    // Builds a reduced FatturaPA XML containing the file header plus ONE FatturaElettronicaBody.
    //
    // Why not just render the whole file: the AssoSoftware stylesheet renders every body it
    // finds, so a 12-document lotto would produce 12 invoices stacked in one page. Since the
    // application explodes bodies into separate records, the viewer has to show one at a time.
    //
    // The reduced document stays schema-valid: FatturaElettronicaBody has maxOccurs unbounded
    // and minOccurs 1, so keeping exactly one is always legal. Verified against the
    // AssoSoftware stylesheet on a 3-body file: each extraction renders that body only.
    //
    // Everything here uses the AL XmlDocument API - no .NET, so it runs on Business Central online.

    var
        BodyElementNameTxt: Label 'FatturaElettronicaBody', Locked = true;
        SignatureElementNameTxt: Label 'Signature', Locked = true;
        DsigNsTxt: Label 'http://www.w3.org/2000/09/xmldsig#', Locked = true;
        BodyNotFoundErr: Label 'Body no. %1 was not found in file %2, which contains %3 body element(s).', Comment = '%1 = requested body no., %2 = file name, %3 = actual count';
        NoRootErr: Label 'File %1 does not contain a readable XML root element.', Comment = '%1 = file name';

    /// <summary>
    /// Writes into Result the XML of the file limited to the requested body.
    /// </summary>
    procedure ExtractBody(var XmlFile: Record "FPA Xml File"; BodyNo: Integer; var Result: BigText)
    var
        XmlDoc: XmlDocument;
        Root: XmlElement;
        Bodies: XmlNodeList;
        BodyNode: XmlNode;
        TempBlob: Codeunit "Temp Blob";
        InStr: InStream;
        OutStr: OutStream;
        ResultInStr: InStream;
        Index: Integer;
    begin
        Clear(Result);

        // Single-document file: nothing to strip, hand back the original bytes untouched.
        // "No. of Bodies" is stored at import time, so this shortcut costs no parsing -
        // which matters, because it is the common case.
        if (BodyNo <= 1) and (XmlFile."No. of Bodies" <= 1) then begin
            XmlFile.GetXmlAsBigText(Result);
            exit;
        end;

        if not XmlFile.GetXmlInStream(InStr) then
            exit;
        if not XmlDocument.ReadFrom(InStr, XmlDoc) then
            Error(NoRootErr, XmlFile."File Name");
        if not XmlDoc.GetRoot(Root) then
            Error(NoRootErr, XmlFile."File Name");

        Bodies := Root.GetChildElements(BodyElementNameTxt);
        if (BodyNo < 1) or (BodyNo > Bodies.Count()) then
            Error(BodyNotFoundErr, BodyNo, XmlFile."File Name", Bodies.Count());

        // Iterate backwards: removing a node does not shift the references already held in
        // the XmlNodeList, but going in reverse keeps the intent obvious and is index-safe
        // regardless of how the list is materialised.
        for Index := Bodies.Count() downto 1 do
            if Index <> BodyNo then begin
                Bodies.Get(Index, BodyNode);
                BodyNode.AsXmlElement().Remove();
            end;

        RemoveSignature(Root);

        TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
        XmlDoc.WriteTo(OutStr);
        TempBlob.CreateInStream(ResultInStr, TextEncoding::UTF8);
        Result.Read(ResultInStr);
    end;

    /// <summary>
    /// Drops the enveloped ds:Signature from the reduced document.
    ///
    /// The signature covers the WHOLE original file; once bodies have been removed it can no
    /// longer verify, so leaving it in place would produce a document that looks signed and
    /// is not. The element is optional in the schema, so the reduced XML stays valid without it.
    /// This reduced XML is only ever fed to the viewer - the original file, signature intact,
    /// is what "Download XML" hands back.
    /// </summary>
    local procedure RemoveSignature(Root: XmlElement)
    var
        Signatures: XmlNodeList;
        SignatureNode: XmlNode;
        Index: Integer;
    begin
        Signatures := Root.GetChildElements(SignatureElementNameTxt, DsigNsTxt);
        for Index := Signatures.Count() downto 1 do begin
            Signatures.Get(Index, SignatureNode);
            SignatureNode.AsXmlElement().Remove();
        end;
    end;

    /// <summary>
    /// Number of FatturaElettronicaBody elements in the file.
    /// </summary>
    procedure CountBodies(var XmlFile: Record "FPA Xml File"): Integer
    var
        XmlDoc: XmlDocument;
        Root: XmlElement;
        InStr: InStream;
    begin
        if not XmlFile.GetXmlInStream(InStr) then
            exit(0);
        if not XmlDocument.ReadFrom(InStr, XmlDoc) then
            exit(0);
        if not XmlDoc.GetRoot(Root) then
            exit(0);
        exit(Root.GetChildElements(BodyElementNameTxt).Count());
    end;
}
