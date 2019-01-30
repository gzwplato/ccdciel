unit cu_ascomrest;

{$mode objfpc}{$H+}

{
Copyright (C) 2019 Patrick Chevalley

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
{
  Implement a client for the ASCOM REST API
  https://ascom-standards.org
}

interface

uses httpsend, synautil, fpjson, jsonparser,
  Classes, SysUtils;

type

  { TAscomRest }

  EAscomException = class(Exception);
  EApiException = class(Exception);
  ESocketException = class(Exception);

  ITrackingRates = array of integer;
  IRate = class(TObject)
      Minimum, Maximum: double;
  end;
  IAxisRates = array of IRate;
  TImageArray = class(Tobject)
    nplane: integer;
    height,width: integer;
    img: array of array of array of integer;  // nplane, height, width
  end;
  IStringArray = array of string;
  IIntArray = array of integer;

  TAscomResult= class(TObject)
     protected
       Fdata: TJSONData;
       function GetAsFloat: double;
       function GetAsInt: integer;
       function GetAsBool: boolean;
       function GetAsString: string;
       function GetAsStringArray: IStringArray;
       function GetIntArray: IIntArray;
     public
       constructor Create;
       destructor Destroy; override;
       property data: TJSONData read Fdata write Fdata;
       property AsFloat: double read GetAsFloat;
       property AsInt: Integer read GetAsInt;
       property AsBool: boolean read GetAsBool;
       property AsString: string read GetAsString;
       property AsStringArray: IStringArray read GetAsStringArray;
       property AsIntArray: IIntArray read GetIntArray;
  end;

  TAscomRest = class(TComponent)
  protected
    Fhost, Fport, Fprotocol, FDevice, FbaseUrl, FApiVersion: string;
    Fuser, Fpassword: string;
    FClientId: integer;
    FLastError: string;
    FLastErrorCode: integer;
    FDriverException: TJSONData;
    Fhttp: THTTPSend;
    function GetHeaders: TStringList;
    function GetDocument: TMemoryStream;
    procedure SetBaseUrl;
    procedure SetHost(host: string);
    procedure SetPort(port: string);
    procedure SetProtocol(protocol: string);
    procedure SetApiVersion(v: string);
    procedure SetUser(u: string);
    procedure SetPassword(p: string);
    procedure SetClientId(i: integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Get(method:string):TAscomResult;
    function GetTrackingRates: ITrackingRates;
    function GetAxisRates(axis:string): IAxisRates;
    function GetImageArray: TImageArray;
    procedure Put(method: string; params:array of string); overload;
    procedure Put(method:string); overload;
    procedure Put(method,value:string); overload;
    procedure Put(method:string;value:double); overload;
    procedure Put(method:string;value:Boolean); overload;
    property Host: string read Fhost write SetHost;
    property Port: string read Fport write SetPort;
    property Protocol: string read Fprotocol write SetProtocol;
    property Device: string read FDevice write FDevice;
    property ApiVersion: string read FApiVersion write SetApiVersion;
    property User: string read Fuser write SetUser;
    property Password: string read Fpassword write SetPassword;
    property ClientId: integer read FClientId write SetClientId;
    property LastError: string read FLastError;
    property LastErrorCode: integer read FLastErrorCode;
    property DriverException: TJSONData read FDriverException;
    property Headers: TStringList read GetHeaders;
    property Document: TMemoryStream read GetDocument;

  end;


implementation

{ TAscomResult }

constructor TAscomResult.Create;
begin
  inherited Create;
  data:=nil;
end;

destructor TAscomResult.Destroy;
begin
  if data<>nil then data.free;
  inherited Destroy;
end;

function TAscomResult.GetAsFloat: Double;
begin
 Result:=data.GetPath('Value').AsFloat;
 Free;
end;

function TAscomResult.GetAsInt: Integer;
begin
 Result:=data.GetPath('Value').AsInteger;
 Free;
end;

function TAscomResult.GetAsBool: Boolean;
begin
  Result:=data.GetPath('Value').AsBoolean;
  Free;
end;

function TAscomResult.GetAsString: string;
begin
   Result:=data.GetPath('Value').AsString;
   Free;
end;

function TAscomResult.GetAsStringArray: IStringArray;
var i: integer;
begin
  with TJSONArray(data.GetPath('Value')) do begin
    SetLength(Result,Count);
    for i:=0 to Count-1 do
      Result[i]:=Strings[i];
  end;
end;

function TAscomResult.GetIntArray: IIntArray;
var i: integer;
begin
  with TJSONArray(data.GetPath('Value')) do begin
    SetLength(Result,Count);
    for i:=0 to Count-1 do
      Result[i]:=Integers[i];
  end;
end;

{ TAscomRest }

constructor TAscomRest.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Fhttp:=THTTPSend.Create;
  Fhttp.Sock.ConnectionTimeout:=2000;  // not too long if service is not available
  Fhttp.Timeout:=120000;               // 2 minutes for long sync request
  Fhttp.UserAgent:='';
  Fprotocol:='http:';
  Fhost:='localhost';
  Fport:='11111';
  FDevice:='';
  Fuser:='';
  Fpassword:='';
  FClientId:=0;
  FApiVersion:='1';
  SetBaseUrl;
end;

destructor  TAscomRest.Destroy;
begin
  Fhttp.Free;
  inherited Destroy;
end;

function TAscomRest.GetHeaders: TStringList;
begin
  result:=Fhttp.Headers;
end;

function TAscomRest.GetDocument: TMemoryStream;
begin
  Fhttp.Document.Position:=0;
  result:=Fhttp.Document;
end;

procedure TAscomRest.SetBaseUrl;
begin
  if (Fuser='')or(Fpassword='') then
     FbaseUrl:=Fprotocol+'//'+Fhost+':'+Fport+'/API/V'+FApiVersion+'/'
  else
     FbaseUrl:=Fprotocol+'//'+Fuser+':'+Fpassword+'@'+Fhost+':'+Fport+'/API/V'+FApiVersion+'/'
end;

procedure TAscomRest.SetProtocol(protocol: string);
begin
  if (protocol='http:')or(protocol='https:') then Fprotocol:=protocol;
  SetBaseUrl;
end;

procedure TAscomRest.SetApiVersion(v: string);
begin
  FApiVersion:=v;
  SetBaseUrl;
end;

procedure TAscomRest.SetHost(host: string);
begin
   Fhost:=host;
   SetBaseUrl;
end;

procedure TAscomRest.SetPort(port: string);
begin
   Fport:=port;
   SetBaseUrl;
end;

procedure TAscomRest.SetUser(u: string);
begin
   Fuser:=u;
   SetBaseUrl;
end;

procedure TAscomRest.SetPassword(p: string);
begin
   Fpassword:=p;
   SetBaseUrl;
end;

procedure TAscomRest.SetClientId(i: integer);
begin
  FClientId:=i;
end;

function TAscomRest.Get(method:string):TAscomResult;
 var ok: boolean;
     url: string;
     i: integer;
 begin
   Fhttp.Document.Clear;
   Fhttp.Headers.Clear;
   url:=FbaseUrl+Fdevice+'/'+method;
   if ClientId>0 then url:=url+'?ClientID='+IntToStr(FClientId);
   ok := Fhttp.HTTPMethod('GET', url);
   if ok then begin
     if (Fhttp.ResultCode=200) then begin
       Fhttp.Document.Position:=0;
       Result:=TAscomResult.Create;
       Result.data:=GetJSON(Fhttp.Document);
       FLastErrorCode:=Result.data.GetPath('ErrorNumber').AsInteger;
       FLastError:=Result.data.GetPath('ErrorMessage').AsString;
       FDriverException:=Result.data.GetPath('DriverException');
       if FLastErrorCode<>0 then begin
          Result.Free;
          raise EAscomException.Create(FLastError);
       end;
     end
     else begin
       FLastErrorCode:=Fhttp.ResultCode;
       FLastError:=Fhttp.ResultString;
       i:=pos('<br>',FLastError);
       if i>0 then FLastError:=copy(FLastError,1,i-1);
       raise EApiException.Create(FLastError);
     end;
   end
   else begin
     FLastErrorCode:=Fhttp.Sock.LastError;
     FLastError:=Fhttp.Sock.LastErrorDesc;
     raise ESocketException.Create(Fhost+':'+Fport+' '+FLastError);
   end;
 end;

function TAscomRest.GetTrackingRates: ITrackingRates;
var J: TAscomResult;
    i: integer;
begin
  J:=Get('TrackingRates');
  try
  with TJSONArray(J.data.GetPath('Rates')) do begin
    SetLength(Result,Count);
    for i:=0 to Count-1 do
      Result[i]:=Integers[i];
  end;
  finally
    J.Free;
  end;
end;

function TAscomRest.GetAxisRates(axis:string): IAxisRates;
var J: TAscomResult;
    i,n: integer;
    r: IRate;
begin
  J:=Get('AxisRates?Axis='+axis);
  try
  with TJSONArray(J.data.GetPath('Value')) do begin
    n:=count;
    SetLength(Result,n);
    for i:=0 to n-1 do begin
      r:=IRate.Create;
      r.Maximum:=Objects[i].GetPath('Maximum').AsFloat;
      r.Minimum:=Objects[i].GetPath('Minimum').AsFloat;
      Result[i]:=r;
    end;
  end;
  finally
    J.Free;
  end;
end;

function TAscomRest.GetImageArray: TImageArray;
var J: TAscomResult;
    i,k,n: integer;
begin
   J:=Get('ImageArray');
   try
   Result:=TImageArray.Create;
   Result.nplane:=J.data.GetPath('Rank').AsInteger;
   if result.nplane=2 then begin
     with TJSONArray(J.data.GetPath('Value')) do begin
       Result.width:=Count;
       Result.height:=Arrays[0].Count;
       SetLength(Result.img,1,Result.height,Result.width);
       for i:=0 to Count-1 do begin
         with Arrays[i] do begin
           for k:=0 to Count-1 do begin
              Result.img[0,k,i]:=Integers[k];
           end;
         end;
       end;
     end;
   end
   else
   if result.nplane=3 then begin
     with TJSONArray(J.data.GetPath('Value')) do begin
       Result.width:=Count;
       Result.height:=Arrays[0].Count;
       SetLength(Result.img,3,Result.height,Result.width);
       for i:=0 to Count-1 do begin
         with Arrays[i] do begin
           for k:=0 to Count-1 do begin
             for n:=0 to 2 do begin
               with Arrays[n] do begin
                 Result.img[n,k,i]:=Integers[n];
               end;
             end; //n
           end; // k
         end;
       end; //i
     end;
   end;
   finally
     J.Free;
   end;
end;

procedure TAscomRest.Put(method: string; params:array of string); overload;
var J: TJSONData;
    url,data: string;
    ok: boolean;
    i,n: integer;
begin
  Fhttp.Document.Clear;
  Fhttp.Headers.Clear;
  n:=Length(params);
  if n=0 then begin
    if ClientId>0 then
       data:='ClientID='+IntToStr(FClientId)
    else
       data:=' ';
  end
  else if n=1 then begin
    data:=params[0];
    if ClientId>0 then
       data:=data+'&ClientID='+IntToStr(FClientId);
  end
  else begin
     i:=0;
     data:='';
     repeat
       data:=data+params[i]+'='+params[i+1]+'&';
       inc(i,2);
     until (i+1)>(n-1);
     if odd(n) then data:=data+params[n-1];
     if copy(data,length(data),1)='&' then data:=copy(data,1,length(data)-1);
     if ClientId>0 then
        data:=data+'&ClientID='+IntToStr(FClientId);
  end;
  WriteStrToStream(Fhttp.Document, data);
  Fhttp.MimeType := 'application/x-www-form-urlencoded';
  url := FbaseUrl+Fdevice+'/'+method;
  ok := Fhttp.HTTPMethod('PUT', url);
   if ok then begin
    if (Fhttp.ResultCode=200) then begin
      Fhttp.Document.Position:=0;
      J:=GetJSON(Fhttp.Document);
      FLastErrorCode:=J.GetPath('ErrorNumber').AsInteger;
      FLastError:=J.GetPath('ErrorMessage').AsString;
      FDriverException:=J.GetPath('DriverException');
      J.Free;
      if FLastErrorCode<>0 then begin
         raise EAscomException.Create(FLastError);
      end;
    end
    else begin
      FLastErrorCode:=Fhttp.ResultCode;
      FLastError:=Fhttp.ResultString;
      i:=pos('<br>',FLastError);
      if i>0 then FLastError:=copy(FLastError,1,i-1);
      raise EApiException.Create(FLastError);
    end;
  end
  else begin
    FLastErrorCode:=Fhttp.Sock.LastError;
    FLastError:=Fhttp.Sock.LastErrorDesc;
    raise ESocketException.Create(Fhost+':'+Fport+' '+FLastError);
  end;
end;

procedure TAscomRest.Put(method:string); overload;
begin
  Put(method,[]);
end;

procedure TAscomRest.Put(method,value:string); overload;
begin
  Put(method,[method,value]);
end;

procedure TAscomRest.Put(method:string;value:double);  overload;
begin
  Put(method,[method,FloatToStr(value)]);
end;

procedure TAscomRest.Put(method:string;value:Boolean); overload;
begin
  Put(method,[method,BoolToStr(value,true)]);
end;


end.

