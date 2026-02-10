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
    offset : word;
  begin
    (* 200 rows / 2 half-screen = 100 rows per half-screen *)
    (* 320 pixel / 4 pixel/byte = 80 bytes *)
    for offset := 0 to 100*80-1 do mem[$B800:offset] := evenRows;
    for offset := 0 to 100*80-1 do mem[$B800:(offset+$2000)] := oddRows;
  end;

function colorByte(color: byte): byte;
  begin
    colorByte := color or (color shl 2) or (color shl 4) or (color shl 6);
  end;


procedure freeSprite(var p: pointer);
  var
    W, H : byte;
  begin
    W := mem[seg(p^):ofs(p^)+0];
    H := mem[seg(p^):ofs(p^)+1];
    freemem(p, 2 + (W shr 2) * H);
  end;

procedure xorBlitSprite(var p: pointer; x0, y0: word);
  var
    W, H, src1line, src2lines : byte;
    row, col : word;
    dstofs, srcofs, pageofs : word;
    part : byte;
  begin
    W := mem[seg(p^):ofs(p^)+0];
    H := mem[seg(p^):ofs(p^)+1];

    src2lines := W shr 1;
    src1line := src2lines shr 1; (* = W shr 2 *)

    pageofs := $2000 * (y0 mod 2);

    for part := 0 to 1 do
    begin
      srcofs := (ofs(p^) + 2) + part * src1line;
      dstofs := (y0 shr 1) * 80 + (x0 shr 2) + part * (y0 mod 2) * 80;

      for row := 1 to (H shr 1) do
      begin
        for col := 0 to src1line - 1 do
          mem[$B800:dstofs+pageofs+col] := mem[$B800:dstofs+pageofs+col] xor mem[seg(p^):srcofs+col];
        dstofs := dstofs + 80;
        srcofs := srcofs + src2lines;
      end;

      pageofs := pageofs xor $2000;
    end;
  end;

(* assume size is multiple of 4 *)
procedure createDiscSprite(var p: pointer; size, color, xshift: byte);
  const
    XPAD = 4;
  var
    W, H : byte;
    row, col : byte;
    cx, cy : byte;
    xx, yy, rr : integer;
    b : byte;
    offset : word;
  begin
    W := size + XPAD;
    H := size;

    getmem(p, 2 + (W shr 2) * H);

    mem[seg(p^):ofs(p^)+0] := W;
    mem[seg(p^):ofs(p^)+1] := H;

    cx := (W - XPAD) shr 1 + xshift;
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


type
  Ball = record
    x, y, dx, dy : integer;
    sprites : array [0..3] of pointer;
    size : byte;
  end;

procedure createBall(var b: Ball; sprites: array of pointer; size: byte; x,y,dx,dy: integer);
  var
    i : byte;
  begin
    b.x := x;  b.y := y;  b.dx := dx;  b.dy := dy;
    for i := 0 to 3 do b.sprites[i] := sprites[i];
    b.size := size;
  end;

procedure moveBall(var b: Ball);
  begin
    with b do
    begin
      x := x + dx;
      y := y + dy;

      if x > (320 - size - 4) then begin dx := -dx; x := 320 - size - 4; end;
      if x < 4 then begin dx := -dx; x := 4; end;
      if y > (200 - size) then begin dy := -dy; y := 200 - size; end;
      if y < 0 then begin dy := -dy; y := 0; end;
    end
  end;

procedure drawBall(b: Ball);
  begin
    xorBlitSprite(b.sprites[b.x mod 4], b.x, b.y);
  end;


const
  NUM_BALLS = 4;
  SPRITE_SIZE = 32;

var
  balls : array [1..NUM_BALLS] of Ball;
  sprites : array [0..3] of pointer;
  i : word;
  dx, dy : integer;

begin
  for i := 0 to 3 do createDiscSprite(sprites[i], SPRITE_SIZE, 1, i);

  Randomize;
  createBall(balls[1], sprites, SPRITE_SIZE, 160 - SPRITE_SIZE shr 1, 100 - SPRITE_SIZE shr 1, 1, 1);
  if true then
  begin
    createBall(balls[2], sprites, SPRITE_SIZE, 160 - SPRITE_SIZE shr 1, 100 - SPRITE_SIZE shr 1, -1, 1);
    createBall(balls[3], sprites, SPRITE_SIZE, 160 - SPRITE_SIZE shr 1, 100 - SPRITE_SIZE shr 1, -1, -1);
    createBall(balls[4], sprites, SPRITE_SIZE, 160 - SPRITE_SIZE shr 1, 100 - SPRITE_SIZE shr 1, 1, -1);
  end
  else
  begin
    for i := 2 to NUM_BALLS do
    begin
      if random(2) = 0 then dx := -1 else dx := +1;
      if random(2) = 0 then dy := -1 else dy := +1;
      createBall(balls[i], sprites, SPRITE_SIZE,
        random(320 - SPRITE_SIZE), random(200 - SPRITE_SIZE), dx, dy)
    end;
  end;

  int10mode(4); (* mode 4 = 320x200 @ 4 colors *)
  {port[$3D9] := 1 or 16 or 32; (* bright cool palette *)}
  clear(0, colorByte(2));

  repeat
    for i := 1 to NUM_BALLS do
      drawBall(balls[i]);

    {delay(10);}

    if port[$60] = 28 then (* enter = key code 28 *)
    begin
      waitretrace;
      for i := 1 to NUM_BALLS do
        drawBall(balls[i]);
    end;

    for i := 1 to NUM_BALLS do
      moveBall(balls[i]);

  until port[$60] = 1; (* wait on esc = key code 0 *)

  for i := 0 to 3 do freeSprite(sprites[i]);
  int10mode(3); (* return to text-mode *)
end.