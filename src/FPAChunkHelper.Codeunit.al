namespace ZZSoft.FPA;

codeunit 73003 "FPA Chunk Helper"
{
    // Business Central sends each control add-in method argument as a single message, so a
    // 500 KB invoice cannot be passed in one call. This splits a BigText into chunks the
    // pages then push to the add-in one at a time.
    //
    // 60.000 characters keeps every message comfortably small while limiting round trips:
    // the 468 KB sample invoice becomes 8 calls.

    procedure DefaultChunkSize(): Integer
    begin
        exit(60000);
    end;

    procedure SplitIntoChunks(var Source: BigText; var Chunks: List of [Text])
    begin
        SplitIntoChunks(Source, Chunks, DefaultChunkSize());
    end;

    procedure SplitIntoChunks(var Source: BigText; var Chunks: List of [Text]; ChunkSize: Integer)
    var
        Chunk: Text;
        Position: Integer;
        ChunkLen: Integer;
    begin
        Clear(Chunks);
        if ChunkSize <= 0 then
            ChunkSize := DefaultChunkSize();

        Position := 1;
        while Position <= Source.Length() do begin
            ChunkLen := ChunkSize;
            if Position + ChunkLen - 1 > Source.Length() then
                ChunkLen := Source.Length() - Position + 1;
            Clear(Chunk);
            Source.GetSubText(Chunk, Position, ChunkLen);
            Chunks.Add(Chunk);
            Position += ChunkLen;
        end;
    end;
}
