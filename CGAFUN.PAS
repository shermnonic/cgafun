program cga;

uses crt; (* for readkey *)

procedure int10mode(mode: byte);
  begin
    asm
    mov ah, 0
    mov al, mode
    int 10h
    end
  end;

procedure clear(evenRows: byte; oddRows: byte);
  var
    x, y : word;
    offset : word;
  begin
    offset := 0;
    for y := 0 to 99 do (* 200 rows / 2 "pages" = 100 rows per "page" *)
    begin
      for x := 0 to 79 do (* 320 pixel / 4 pixel/byte = 80 bytes *)
      begin
        mem[$B800:offset] := evenRows;
        mem[$B800:(offset+$2000)] := oddRows;
        inc(offset)
      end
    end
  end;

procedure freeSprite(var p: pointer);
  var
    W, H : byte;
  begin
    W := mem[seg(p^):ofs(p^)+0];
    H := mem[seg(p^):ofs(p^)+1];
    freemem(p, 2 + (W shr 2) * H);
  end;

procedure blitSprite(var p: pointer; x0: word; y0: word);
  var
    W, H, stride : byte;
    row, col : word;
    dstofs, srcofs, pageofs : word;
  begin
    W := mem[seg(p^):ofs(p^)+0];
    H := mem[seg(p^):ofs(p^)+1];

    stride := W shr 2;

    dstofs := (y0 shr 1) * 80 + (x0 shr 2);
    srcofs := ofs(p^) + 2;

    for row := 0 to (H-1) do
    begin
      if (row mod 2) = 1 then pageofs := $2000 else pageofs := 0;
      for col := 0 to (stride - 1) do
        (* TODO: Handle non 4-aligned x0 positions *)
        mem[$B800:dstofs+pageofs+col] := mem[seg(p^):srcofs+col];
      if (row mod 2) = 1 then dstofs := dstofs + 80;
      srcofs := srcofs + stride;
    end;
  end;

procedure createDiscSprite(var p: pointer; xofs: byte);
  const
    XBUF = 4;
    W = 16 + XBUF;
    H = 16;
  const
    color = 2; (* : byte;*) (* lowest 2 bit *)
  var
    row, col : byte;
    cx, cy : byte;
    xx, yy, rr : shortint;
    b : byte;
    offset : word;
  begin
    getmem(p, 2 + (W shr 2) * H);

    mem[seg(p^):ofs(p^)+0] := W;
    mem[seg(p^):ofs(p^)+1] := H;

    cx := (W - XBUF) shr 1 + xofs;
    cy := H shr 1 ;

    rr := cy * cy - cy;

    offset := ofs(p^) + 2;

    b := 0;

    for row := 0 to (H-1) do
    begin
      yy := row - cy;
      yy := yy * yy;
      for col := 0 to (W-1) do
      begin
        xx := col - cx;
        xx := xx * xx;
        if xx + yy <= rr then
          (* Color pixel inside disc *)
          b := b or (color shl ((3 - (col mod 4)) shl 1));

        (* every 4 pixels, write byte *)
        if (col mod 4) = 3 then
        begin
          mem[seg(p^):offset] := b;
          inc(offset);
          b := 0;
        end
      end
    end
  end;

var
  sprites : array [0..3] of pointer;
  i : word;

begin
  createDiscSprite(sprites[0], 0);
  createDiscSprite(sprites[1], 1);
  createDiscSprite(sprites[2], 2);
  createDiscSprite(sprites[3], 3);

  int10mode(4); (* mode 4 = 320x200 @ 4 colors *)
  port[$3D9] := 1 or 16 or 32; (* bright cool palette *)
  clear(1, 16);

  for i := 0 to 19 do
  begin
    blitSprite(sprites[i mod 4], i, i);
    delay(100);
  end;

  readkey;
  freeSprite(sprites[0]);
  freeSprite(sprites[1]);
  freeSprite(sprites[2]);
  freeSprite(sprites[3]);
  int10mode(3); (* return to text-mode *)
end.
