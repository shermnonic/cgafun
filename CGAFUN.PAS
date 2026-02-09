program cgafun;

uses crt;

procedure int10mode(mode: byte); assembler;
  asm
    mov ah, 0
    mov al, mode
    int 10h
  end;

procedure waitretrace;
  begin
    (* bit 3 of status register indicates vertical retrace *)
    (* wait for bit 3 to switch from 0 to 1 *)
    repeat until (port[$3DA] and 8) = 0;
    repeat until (port[$3DA] and 8) > 0;
  end;


procedure clear(evenRows: byte; oddRows: byte);
  var
    x, y : word;
    offset : word;
  begin
    offset := 0;
    for y := 0 to 99 do (* 200 rows / 2 half-screen = 100 rows per half-screen *)
    begin
      for x := 0 to 79 do (* 320 pixel / 4 pixel/byte = 80 bytes *)
      begin
        mem[$B800:offset] := evenRows;
        mem[$B800:(offset+$2000)] := oddRows;
        inc(offset)
      end;
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

procedure xorBlitSprite(var p: pointer; x0: word; y0: word);
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
      if ((y0+row) mod 2) = 1 then pageofs := $2000 else pageofs := 0;
      for col := 0 to (stride - 1) do
        (* TODO: Handle non 4-aligned x0 positions *)
        {mem[$B800:dstofs+pageofs+col] := mem[seg(p^):srcofs+col];}
        mem[$B800:dstofs+pageofs+col] := mem[$B800:dstofs+pageofs+col] xor mem[seg(p^):srcofs+col];
      if ((y0+row) mod 2) = 1 then dstofs := dstofs + 80;
      srcofs := srcofs + stride;
    end;
  end;


function get4PixelColor(color: byte): byte;
  begin
    get4PixelColor := color or (color shl 2) or (color shl 4) or (color shl 6);
  end;


const
  SPRITE_SIZE = 24;

procedure createDiscSprite(var p: pointer; xofs: byte);
  const
    XBUF = 4;
    W = SPRITE_SIZE + XBUF;
    H = SPRITE_SIZE;
  const
    color = 1; (* : byte;*) (* lowest 2 bit *)
  var
    row, col : byte;
    cx, cy : byte;
    xx, yy, rr : integer;
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
      end;
    end
  end;

var
  sprites : array [0..3] of pointer;
  i : word;
  x, y, dx, dy : integer;

begin
  for i := 0 to 3 do createDiscSprite(sprites[i], i);

  int10mode(4); (* mode 4 = 320x200 @ 4 colors *)
  port[$3D9] := 1 or 16 or 32; (* bright cool palette *)

  clear(0, get4PixelColor(2));

  x := 160 - 16;
  y := 100 - 16;
  dx := 1;
  dy := 1;

  repeat
    xorBlitSprite(sprites[x mod 4], x, y);

    {delay(10);}

    if port[$60] = 28 then (* enter = key code 28 *)
    begin
      waitretrace;
      xorBlitSprite(sprites[x mod 4], x, y);
    end;

    x := x + dx;
    y := y + dy;

    if x > (320 - SPRITE_SIZE - 4) then begin dx := -dx; x := 320 - SPRITE_SIZE - 4; end;
    if x < 4 then begin dx := -dx; x := 4; end;
    if y > (200 - SPRITE_SIZE) then begin dy := -dy; y := 200 - SPRITE_SIZE; end;
    if y < 0 then begin dy := -dy; y := 0; end;

  until port[$60] = 1; (* wait on esc = key code 0 *)

  for i := 0 to 3 do freeSprite(sprites[i]);
  int10mode(3); (* return to text-mode *)
end.