unit fu_rotator;

{$mode objfpc}{$H+}

{
Copyright (C) 2017 Patrick Chevalley

http://www.ap-i.net
pch@ap-i.net

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>. 

}

interface

uses  UScaleDPI, u_global,
  Classes, SysUtils, FileUtil, Forms, Controls, StdCtrls, ExtCtrls;

type

  { Tf_rotator }

  Tf_rotator = class(TFrame)
    BtnRotate: TButton;
    Angle: TEdit;
    Label6: TLabel;
    Panel1: TPanel;
    StaticText1: TStaticText;
    procedure BtnRotateClick(Sender: TObject);
  private
    { private declarations }
    FonRotate: TNotifyEvent;
  public
    { public declarations }
    constructor Create(aOwner: TComponent); override;
    destructor  Destroy; override;
    property onRotate: TNotifyEvent read FonRotate write FonRotate;
  end;

implementation

{$R *.lfm}

{ Tf_rotator }

constructor Tf_rotator.Create(aOwner: TComponent);
begin
 inherited Create(aOwner);
 ScaleDPI(Self);
end;

destructor  Tf_rotator.Destroy;
begin
 inherited Destroy;
end;

procedure Tf_rotator.BtnRotateClick(Sender: TObject);
begin
   if Assigned(FonRotate) then FonRotate(self);
end;

end.

