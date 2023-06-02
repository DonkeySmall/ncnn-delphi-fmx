unit Unit1;

interface

uses
  WinApi.Windows, System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, ncnn,
  FMX.Controls.Presentation, FMX.StdCtrls, System.ImageList, FMX.ImgList, FMX.Utils,
  FMX.Objects, FMX.Memo.Types, FMX.ScrollBox, FMX.Memo;

type
  TForm1 = class(TForm)
    Button1: TButton;
    ImageMain: TImage;
    OpenDialog: TOpenDialog;
    ImageList: TImageList;
    Button2: TButton;
    Memo1: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
  public
    procedure LoadImage;
  end;

var
  Form1: TForm1;

var
  InferenceEngine: TInferenceEngine;

  FClassList: TStringList;

type
  PInputData = ^TInputData;
  TInputData = array [0 .. 227 - 1] of array [0 .. 227 - 1] of array [0 .. 3 - 1] of Byte;

  POutputData = ^TOutputData;
  TOutputData = array [0 .. 1000 - 1] of Float32;

implementation

{$R *.fmx}


procedure TForm1.LoadImage;
begin
{$IFDEF MSWINDOWS}
  if not FileExists(OpenDialog.FileName) then
    Exit;

  if ImageMain.MultiResBitmap.Count > 0 then
    ImageMain.MultiResBitmap[0].Free;

  ImageMain.MultiResBitmap.Add;

  if FileExists(OpenDialog.FileName) then
  begin
    if ImageList.Source[0].MultiResBitmap.Count > 0 then
      ImageList.Source[0].MultiResBitmap[0].Free;

    ImageList.Source[0].MultiResBitmap.Add;
    ImageList.Source[0].MultiResBitmap[0].Bitmap.LoadFromFile(OpenDialog.FileName);
  end;

  ImageMain.Bitmap.Assign(ImageList.Source[0].MultiResBitmap[0].Bitmap);

{$ENDIF MSWINDOWS}
end;

procedure TForm1.Button1Click(Sender: TObject);
var
  FNet, FOption, FExtractor: Pointer;
  FInput, FOutput: Pointer;
  FResult: Int32;
  FScore: Float32;
  i, L, X, Y: DWORD;
  FColorArray: PAlphaColorArray;
  FBitmapData: TBitmapData;
  FInputData: PInputData;
  FOutputData: Pointer;

  FData: TOutputData;
  FMean: mean_rgb;
begin
  Memo1.Lines.Clear;

  if ImageList.Source[0].MultiResBitmap.Count = 0 then
    Exit;

  if FClassList.Count <= 0 then
    Exit;

  GetMem(FInputData, SizeOf(TInputData));
  try
    ImageList.Source[0].MultiResBitmap[0].Bitmap.Map(TMapAccess.Read, FBitmapData);

    for Y := 0 to ImageList.Source[0].MultiResBitmap[0].Bitmap.Height - 1 do
    begin
      FColorArray := PAlphaColorArray(FBitmapData.GetScanline(Y));

      for X := 0 to ImageList.Source[0].MultiResBitmap[0].Bitmap.Width - 1 do
      begin
        FInputData[Y][X][0] := TAlphaColorRec(FColorArray[X]).B;
        FInputData[Y][X][1] := TAlphaColorRec(FColorArray[X]).G;
        FInputData[Y][X][2] := TAlphaColorRec(FColorArray[X]).R;
      end;
    end;

    ImageList.Source[0].MultiResBitmap[0].Bitmap.Unmap(FBitmapData);

    try
      FInput := InferenceEngine.MatFromPixelsResize(FInputData, NCNN_MAT_PIXEL_BGR,
        ImageList.Source[0].MultiResBitmap[0].Bitmap.Width, ImageList.Source[0].MultiResBitmap[0].Height, ImageList.Source[0].MultiResBitmap[0].Bitmap.Height * 3, 227, 227);

      // FInput := InferenceEngine.MatFromPixels(FInputData, NCNN_MAT_PIXEL_BGR,
      // ImageList.Source[0].MultiResBitmap[0].Bitmap.Width, ImageList.Source[0].MultiResBitmap[0].Height, ImageList.Source[0].MultiResBitmap[0].Bitmap.Height * 3);

      FMean[0] := 104;
      FMean[1] := 117;
      FMean[2] := 123;

      InferenceEngine.MatSubstractMeanNormalize(FInput, @FMean, nil);

      if FInput = nil then
      begin
        // raise EncnnError.Create('MatFromPixelsResize');
        Exit;
      end;

      FNet := InferenceEngine.NetCreate;

      if FNet = nil then
      begin
        // raise EncnnError.Create('NetCreate');
        Exit;
      end;

      FOption := InferenceEngine.OptionCreate;

      if FOption = nil then
      begin
        // raise EncnnError.Create('NetCreateOption');
        Exit;
      end;

      // InferenceEngine.OptionSetUseVulkanCompute(FOption, 1); //Use Vulkan GPU
      InferenceEngine.OptionSetUseVulkanCompute(FOption, 0); // Don't use Vulkan GPU

      InferenceEngine.NetSetOption(FNet, FOption);

      FResult := InferenceEngine.NetLoadParam(FNet, PAnsiChar(AnsiString('squeezenet_v1.1.param')));

      if FResult <> 0 then
      begin
        // raise EncnnError.Create('NetLoadParam');
        Exit;
      end;

      FResult := InferenceEngine.NetLoadModel(FNet, PAnsiChar(AnsiString('squeezenet_v1.1.bin')));

      if FResult <> 0 then
      begin
        // raise EncnnError.Create('NetLoadModel');
        Exit;
      end;

      FExtractor := InferenceEngine.ExtractorCreate(FNet);

      if FExtractor = nil then
      begin
        // raise EncnnError.Create('NetExtractorCreate');
        Exit;
      end;

      InferenceEngine.ExtractorInput(FExtractor, PAnsiChar(AnsiString('data')), FInput);

      InferenceEngine.ExtractorExtract(FExtractor, PAnsiChar(AnsiString('prob')), FOutput);

      if FOutput = nil then
      begin
        // raise EncnnError.Create('NetExtractorExtract');
        Exit;
      end;

      InferenceEngine.MatGetData(FOutput, FOutputData);

      if FOutputData = nil then
      begin
        // raise EncnnError.Create('MatGetData');
        Exit;
      end;

      for i := 0 to 1000 - 1 do
      begin
        if (StrToFloat(Copy(FloatToStr(TOutputData(FOutputData^)[i]), 1, 4)) > 0) and
          (StrToFloat(Copy(FloatToStr(TOutputData(FOutputData^)[i]), 1, 4)) < 1) then
        begin
          Memo1.Lines.Add('(' + FClassList[i] + ') score: ' + FloatToStr(TOutputData(FOutputData^)[i]));
        end;
      end;


    finally
      if FInput <> nil then
        InferenceEngine.MatDestroy(FInput);
      if FOutput <> nil then
        InferenceEngine.MatDestroy(FOutput);
      if FExtractor <> nil then
        InferenceEngine.ExtractorDestroy(FExtractor);
      if FOption <> nil then
        InferenceEngine.OptionDestroy(FOption);
      if FNet <> nil then
        InferenceEngine.NetDestroy(FNet);
    end;

  finally
    FreeMem(FInputData);
  end;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  if OpenDialog.Execute then
    LoadImage;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  InferenceEngine := TInferenceEngine.Create(Self);

  FClassList := TStringList.Create;

  FClassList.LoadFromFile('class.txt');

  if ImageList.Source[0].MultiResBitmap.Count > 0 then
    ImageList.Source[0].MultiResBitmap[0].Free;

  ImageList.Source[0].MultiResBitmap.Add;
  ImageList.Source[0].MultiResBitmap[0].Bitmap.LoadFromFile('cat.jpg');

  ImageMain.Bitmap.Assign(ImageList.Source[0].MultiResBitmap[0].Bitmap);
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  InferenceEngine.Destroy;
end;

end.
