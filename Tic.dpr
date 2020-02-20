program Tic;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Windows,
  Messages;

type
  PBoard = ^TBoard;

  TBoard = record

    Boxes: Array [0 .. 2, 0 .. 2] of Integer;
    Children: Array of PBoard;
    State: Integer;
  end;

const
  humanSymbol = -1;
  meSymbol = 1;

procedure ClearScreen;
var
  StdOut: THandle;
  CSBI: TConsoleScreenBufferInfo;
  consoleSize: DWORD;
  numWritten: DWORD;
  origin: TCoord;
begin

  // standard windows procedure that i picked up from some file in some project in some hard drive
  StdOut := GetStdHandle(STD_OUTPUT_HANDLE);
  Win32Check(StdOut <> INVALID_HANDLE_VALUE);
  Win32Check(GetConsoleScreenBufferInfo(StdOut, CSBI));
  consoleSize := CSBI.dwSize.X * CSBI.dwSize.Y;
  origin.X := 0;
  origin.Y := 0;
  Win32Check(FillConsoleOutputCharacter(StdOut, ' ', consoleSize, origin,
    numWritten));
  Win32Check(FillConsoleOutputAttribute(StdOut, CSBI.wAttributes, consoleSize,
    origin, numWritten));
  Win32Check(SetConsoleCursorPosition(StdOut, origin));
end;

function getPlayerCount(PB: TBoard; Player: Integer): Integer;
var
  I, J, R: Integer;

begin
  { this function returns the player count for any player - (meSymbol, humanSymbol, 0)
    when called with any TBoard getPlayerCount(PB, 0) will return the number
    of empty spaces on the board. although pretty simple, this function comes handy later.

  }

  R := 0;
  for J := 0 to 2 do
    for I := 0 to 2 do
    begin
      if (PB.Boxes[I, J] = Player) then
        Inc(R, 1);

    end;
  Result := R;
end;

function getWinner(PB: TBoard): Integer;
var
  I, R: Integer;
begin
  {
    returns the symbol value of the current winner of the board;
    default winner is a 0;
    this method can be optimized, but i think we won't loose a lot in terms of cpu usage
  }

  R := 0;
  with PB do
  begin
    if ((Boxes[0, 0] = Boxes[1, 1]) AND (Boxes[0, 0] = Boxes[2, 2])) then
      R := Boxes[0, 0];
    if R = 0 then

      if ((Boxes[0, 2] = Boxes[1, 1]) AND (Boxes[0, 2] = Boxes[2, 0])) then
        R := Boxes[1, 1];
    if R = 0 then
      for I := 0 to 2 do
      begin
        if R = 0 then
          if ((Boxes[0, I] = Boxes[1, I]) AND (Boxes[0, I] = Boxes[2, I])) then
            R := Boxes[0, I];
        if R = 0 then
          if ((Boxes[I, 0] = Boxes[I, 1]) AND (Boxes[I, 0] = Boxes[I, 2])) then
            R := Boxes[I, 0];

      end;
  end;

  Result := R;

end;

function IntToSymbol(IX: Integer): String;
begin
  // used to map the symbol values to their symbols

  case IX of
    0:
      Result := '_';
    humanSymbol:
      Result := 'X';
    meSymbol:
      Result := 'O';
  end;
end;

procedure printBoard(PB: TBoard);
var
  J, I: Integer;
begin

  // procedure to print the board; clears screen first. nothing fancy here :P
  // the O of IO
  ClearScreen;
  WriteLn(' 1    2    3 ');
  WriteLn('-------------');
  for J := 0 to 2 do
  begin
    for I := 0 to 2 do
    begin
      Write('| ' + IntToSymbol(PB.Boxes[I, J]) + ' ');
    end;
    WriteLn('| ' + IntToStr(J + 1));
    WriteLn('-------------');

  end;

  WriteLn;
  WriteLn;
  WriteLn('Numbered 1 to 3 -- Top to Bottom -- Left to right');
  WriteLn;

end;

function isValidNumber(inString: String): Boolean;
var
  J: Integer;
  R: Boolean;
begin
  // check if input is a valid number;

  R := True;
  for J := 1 to Length(inString) do
    if NOT(inString[J] in ['0' .. '9']) then
      R := False;
  Result := R;

end;

function getHuman(currBoard: TBoard): TBoard;
var
  I, J: Integer;
  tempStr: String;
  f1: Boolean;
begin

  // gets the humans move - basically the I of IO

  repeat
    Write('Column : ');
    Readln(tempStr);
    if isValidNumber(tempStr) then
      I := StrToInt(tempStr)
    else
      I := -1;

    Write('Row : ');
    Readln(tempStr);
    if isValidNumber(tempStr) then
      J := StrToInt(tempStr)
    else
      J := -1;
    J := J - 1;
    I := I - 1;
    f1 := ((I > 2) OR (I < 0));
    f1 := (f1 OR ((J > 2) OR (J < 0)));
    f1 := (f1 OR (currBoard.Boxes[I, J] <> 0));

    if f1 then
      WriteLn('Illegal move; Retry -');

  until f1 = False;

  currBoard.Boxes[I, J] := humanSymbol;
  Result := currBoard;
end;

function getRanking(PB: TBoard): Integer;
var
  I, J: Integer;
begin
  {
    this function calculates the ranking a move/board.
    the State of each terminal (winning/draw) board is multiplied by
    the total number of moves left
    that is  9 - emptySpaces. (as in 9 minus emptySpaces) ;
    State is calculated using getWinner;
    the winner state is basically what getWinner(PB) returns.
    this allows us to get a ranking for each branch of all the possible children boards;
    The ranking is stored in TBoard.State, but that is just to reduce object size.
    since the state is being used after calculating ranks, it's simpler to store the rankings here.

    The weighting allows us to choose the board which would allow a possible victory in fewer moves.

  }

  if getWinner(PB) <> 0 then
  begin
    Result := (9 - getPlayerCount(PB, 0)) * getWinner(PB);
  end
  else
  begin
    J := 0;
    for I := 0 to Length(PB.Children) - 1 do
      J := J + getRanking(PB.Children[I]^);
    Result := J;
  end;

end;

function placeNew(PB: TBoard; Col, Row: Integer): TBoard;
var

  tempBoard: TBoard;

begin

  {
    placeNew places the next legal symbol for a given board;
    the method used avoids having to store a count of the number of moves (total/individual)
  }
  tempBoard := PB;
  if getPlayerCount(PB, humanSymbol) > getPlayerCount(PB, meSymbol) then
    tempBoard.Boxes[Col, Row] := meSymbol
  else
    tempBoard.Boxes[Col, Row] := humanSymbol;

  Result := tempBoard;
end;

function createChildren(PB: TBoard): TBoard;
var
  copyBoard: TBoard;
  J: Integer;
  I, K: Integer;
begin
  {
    this function recusively populates all the children boards for a given board;
    in the end it calculated their individual rank;
  }

  copyBoard := PB;
  SetLength(copyBoard.Children, 0);
  for J := 0 to 2 do
    for I := 0 to 2 do
      if copyBoard.Boxes[I, J] = 0 then
      begin
        copyBoard := placeNew(copyBoard, I, J);
        // copyBoard.State := getWinner(copyBoard);
        K := Length(copyBoard.Children);
        SetLength(copyBoard.Children, K + 1);
        New(copyBoard.Children[K]);
        copyBoard.Children[K]^ := copyBoard;
        if getWinner(copyBoard) = 0 then
          copyBoard.Children[K]^ := createChildren(copyBoard.Children[K]^);

        copyBoard.Boxes[I, J] := 0;

      end;

  copyBoard.State := getRanking(copyBoard);
  Result := copyBoard;

end;

function newBoard: TBoard;
var
  tempB: TBoard;
  I, J: Integer;

begin

  // returns a clean board -- empty board;

  for J := 0 to 2 do
    for I := 0 to 2 do
      tempB.Boxes[I, J] := 0;

  tempB.State := 0;
  Result := tempB;

end;

function getNextMove(PB: TBoard): TBoard;
var
  I, K: Integer;
  copyBoard: TBoard;

begin
  {
    calls a function thatcreates all the children boards needed to get the next move;
    returns the highest ranking board. the ranking of the board is what is returned by
    the getFullState function.
  }
  copyBoard := PB;
  copyBoard := createChildren(copyBoard);
  //
  if Length(copyBoard.Children) = 0 then
    Result := copyBoard
  else
  begin
    K := 0;
    for I := 0 to Length(copyBoard.Children) - 1 do
    begin
      if copyBoard.Children[I]^.State > copyBoard.Children[K]^.State then
        K := I;

    end;

    Result := copyBoard.Children[K]^;
  end;

end;

procedure playGame;
var
  gameBoard, copyBoard: TBoard;
  s: String;
begin
  // this is the driver procedure
  // pretty simple to understand once you understand the real juju happening
  repeat
    gameBoard := newBoard;
    printBoard(gameBoard);
    repeat
      gameBoard := getHuman(gameBoard);
      printBoard(gameBoard);
      // Sleep(1);
      gameBoard := getNextMove(gameBoard);

      printBoard(gameBoard);

    until ((getWinner(gameBoard) <> 0) OR (getPlayerCount(gameBoard, 0) = 0));
    begin
      printBoard(gameBoard);
      if getPlayerCount(gameBoard, 0) = 0 then
        WriteLn('Game drawn. :P')
      else
        WriteLn(IntToSymbol(getWinner(gameBoard)) + ' wins.');
      WriteLn('Press Y to play again, N to end game');

      repeat
        WriteLn('Y/N: ');
        Readln(s);
      until ((UpperCase(s) = 'Y') OR (UpperCase(s) = 'N'));

      if UpperCase(s) = 'N' then
        exit;

    end;

  until (0 = 1);

end;

begin
  playGame;
  WriteLn('Press Enter to Exit. Haha.. get it? enter to ex.. never mind.');
  Readln;

end.
