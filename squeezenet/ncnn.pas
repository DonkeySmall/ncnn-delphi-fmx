unit ncnn;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, FMX.Types,

{$IFDEF ANDROID}

{$ENDIF ANDROID}
{$IFDEF MSWINDOWS}
  WinApi.Windows
{$ENDIF MSWINDOWS}
    ;

{$IFDEF ANDROID}

{$ENDIF ANDROID}
{$IFDEF MSWINDOWS}
const
  ncnn_module_name = 'ncnn.dll';
{$ENDIF MSWINDOWS}


const
  NCNN_MAT_PIXEL_RGB = 1;
  NCNN_MAT_PIXEL_BGR = 2;
  NCNN_MAT_PIXEL_GRAY = 3;
  NCNN_MAT_PIXEL_RGBA = 4;
  NCNN_MAT_PIXEL_BGRA = 5;

type
  mean_rgb = array [0 .. 3 - 1] of Float32;

type
  ncnn_net_custom_layer_factory_t = ^_ncnn_net_custom_layer_factory_t;

  _ncnn_net_custom_layer_factory_t = record
    creator: Pointer;
    destroyer: Pointer;
    userdata: Pointer;
    next: ncnn_net_custom_layer_factory_t;
  end;

type
  ncnn_net_t = Pointer; // ^_ncnn_net_t;

  _ncnn_net_t = record
    pthis: Pointer;
    custom_layer_factory: ncnn_net_custom_layer_factory_t;
  end;

var
  ncnn_module: HMODULE = 0;

type
  TInferenceEngine = class(TComponent)
  private

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Version(): PAnsiChar;
    function NetCreate: Pointer;
    procedure MatDestroy(mat: Pointer);
    procedure ExtractorDestroy(ex: Pointer);
    procedure OptionDestroy(opt: Pointer);
    procedure NetDestroy(net: ncnn_net_t);
    function MatCreate: Pointer;
    function MatGetW(mat: Pointer): Int64;
    procedure MatGetData(mat: Pointer; out data: Pointer);
    function NetLoadParam(net: ncnn_net_t; const path: PAnsiChar): Int64;
    function NetLoadModel(net: ncnn_net_t; const path: PAnsiChar): Int64;
    function OptionCreate: Pointer;
    procedure NetSetOption(net: ncnn_net_t; opt: Pointer);
    function ExtractorCreate(net: ncnn_net_t): Pointer;
    function ExtractorInput(ex: Pointer; const name: PAnsiChar; mat: Pointer): Int64;
    function ExtractorExtract(ex: Pointer; const name: PAnsiChar; out mat: Pointer): Int64;
    function MatFromPixelsResize(pixels: Pointer; pixel_type: Int64; w: Int64; h: Int64; stride: Int64; target_width: Int64; target_height: Int64; allocator: Pointer = nil): Pointer;
    function MatFromPixels(pixels: Pointer; pixel_type: Int64; w: Int64; h: Int64; stride: Int64; allocator: Pointer = nil): Pointer;
    procedure OptionSetUseVulkanCompute(opt: Pointer; use_vulkan_compute: Int64);
    procedure MatSubstractMeanNormalize(mat: Pointer; mean_vals: Pointer; norm_vals: Pointer);
  end;

implementation


type
  _ncnn_version = function: PAnsiChar; stdcall;
  _ncnn_net_create = function: Pointer; stdcall;
  _ncnn_option_create = function: Pointer; stdcall;
  _ncnn_net_load_param = function(net: ncnn_net_t; const path: PAnsiChar): Int64; stdcall;
  _ncnn_net_load_model = function(net: ncnn_net_t; const path: PAnsiChar): Int64; stdcall;
  _ncnn_net_set_option = procedure(net: ncnn_net_t; opt: Pointer); stdcall;
  _ncnn_extractor_create = function(net: ncnn_net_t): Pointer; stdcall;
  _ncnn_extractor_input = function(ex: Pointer; const name: PAnsiChar; const mat: Pointer): Int64; stdcall;
  _ncnn_extractor_extract = function(ex: Pointer; const name: PAnsiChar; out mat: Pointer): Int64; stdcall;
  _ncnn_mat_create = function: Pointer; stdcall;
  _ncnn_mat_get_w = function(const mat: Pointer): Int64; stdcall;
  _ncnn_mat_from_pixels_resize = function(pixels: Pointer; pixel_type: Int64; w: Int64; h: Int64; stride: Int64; target_width: Int64; target_height: Int64; allocator: Pointer): Pointer; stdcall;
  _ncnn_mat_from_pixels = function(pixels: Pointer; pixel_type: Int64; w: Int64; h: Int64; stride: Int64; allocator: Pointer): Pointer; stdcall;
  _ncnn_option_set_use_vulkan_compute = procedure(opt: Pointer; use_vulkan_compute: Int64); stdcall;
  _ncnn_mat_destroy = procedure(mat: Pointer); stdcall;
  _ncnn_extractor_destroy = procedure(ex: Pointer); stdcall;
  _ncnn_option_destroy = procedure(opt: Pointer); stdcall;
  _ncnn_net_destroy = procedure(net: ncnn_net_t); stdcall;
  _ncnn_mat_get_data = function(const mat: Pointer): Pointer; stdcall;
  _ncnn_mat_substract_mean_normalize = procedure(mat: Pointer; mean_vals: Pointer; norm_vals: Pointer);

var
  ncnn_version: _ncnn_version = nil;
  ncnn_net_create: _ncnn_net_create = nil;
  ncnn_mat_create: _ncnn_mat_create = nil;
  ncnn_mat_get_w: _ncnn_mat_get_w = nil;
  ncnn_option_create: _ncnn_option_create = nil;
  ncnn_net_load_param: _ncnn_net_load_param = nil;
  ncnn_net_load_model: _ncnn_net_load_model = nil;
  ncnn_net_set_option: _ncnn_net_set_option = nil;
  ncnn_extractor_create: _ncnn_extractor_create = nil;
  ncnn_extractor_input: _ncnn_extractor_input = nil;
  ncnn_extractor_extract: _ncnn_extractor_extract = nil;
  ncnn_mat_from_pixels_resize: _ncnn_mat_from_pixels_resize = nil;
  ncnn_mat_from_pixels: _ncnn_mat_from_pixels = nil;
  ncnn_option_set_use_vulkan_compute: _ncnn_option_set_use_vulkan_compute = nil;
  ncnn_mat_destroy: _ncnn_mat_destroy = nil;
  ncnn_extractor_destroy: _ncnn_extractor_destroy = nil;
  ncnn_option_destroy: _ncnn_option_destroy = nil;
  ncnn_net_destroy: _ncnn_net_destroy = nil;
  ncnn_mat_get_data: _ncnn_mat_get_data = nil;
  ncnn_mat_substract_mean_normalize: _ncnn_mat_substract_mean_normalize = nil;

constructor TInferenceEngine.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
{$IFDEF MSWINDOWS}
  ncnn_module := WinApi.Windows.LoadLibrary(ncnn_module_name);
{$ENDIF MSWINDOWS}
{$IFDEF ANDROID}

{$ENDIF ANDROID}
  if (ncnn_module = 0) then
  begin
    // raise EncnnError.Create('LoadLibrary');
    Exit;
  end;

  ncnn_version := GetProcAddress(ncnn_module, 'ncnn_version');
  ncnn_net_create := GetProcAddress(ncnn_module, 'ncnn_net_create');
  ncnn_mat_get_w := GetProcAddress(ncnn_module, 'ncnn_mat_get_w');
  ncnn_mat_create := GetProcAddress(ncnn_module, 'ncnn_mat_create');
  ncnn_option_create := GetProcAddress(ncnn_module, 'ncnn_option_create');
  ncnn_net_load_param := GetProcAddress(ncnn_module, 'ncnn_net_load_param');
  ncnn_net_load_model := GetProcAddress(ncnn_module, 'ncnn_net_load_model');
  ncnn_net_set_option := GetProcAddress(ncnn_module, 'ncnn_net_set_option');
  ncnn_extractor_create := GetProcAddress(ncnn_module, 'ncnn_extractor_create');
  ncnn_extractor_input := GetProcAddress(ncnn_module, 'ncnn_extractor_input');
  ncnn_extractor_extract := GetProcAddress(ncnn_module, 'ncnn_extractor_extract');
  ncnn_mat_from_pixels_resize := GetProcAddress(ncnn_module, 'ncnn_mat_from_pixels_resize');
  ncnn_mat_from_pixels := GetProcAddress(ncnn_module, 'ncnn_mat_from_pixels');
  ncnn_option_set_use_vulkan_compute := GetProcAddress(ncnn_module, 'ncnn_option_set_use_vulkan_compute');
  ncnn_mat_destroy := GetProcAddress(ncnn_module, 'ncnn_mat_destroy');
  ncnn_extractor_destroy := GetProcAddress(ncnn_module, 'ncnn_extractor_destroy');
  ncnn_option_destroy := GetProcAddress(ncnn_module, 'ncnn_option_destroy');
  ncnn_net_destroy := GetProcAddress(ncnn_module, 'ncnn_net_destroy');
  ncnn_mat_get_data := GetProcAddress(ncnn_module, 'ncnn_mat_get_data');
  ncnn_mat_substract_mean_normalize := GetProcAddress(ncnn_module, 'ncnn_mat_substract_mean_normalize');

  if (@ncnn_version = nil) or (@ncnn_net_create = nil) or (@ncnn_net_load_param = nil) or (@ncnn_net_load_model = nil) or
    (@ncnn_option_create = nil) or (@ncnn_net_set_option = nil) or (@ncnn_extractor_create = nil) or (@ncnn_extractor_input = nil) or
    (@ncnn_mat_from_pixels_resize = nil) or (@ncnn_extractor_extract = nil) or (@ncnn_mat_create = nil) or (@ncnn_mat_get_w = nil) or
    (@ncnn_mat_destroy = nil) or (@ncnn_extractor_destroy = nil) or (@ncnn_option_destroy = nil) or (@ncnn_net_destroy = nil) or
    (@ncnn_option_set_use_vulkan_compute = nil) or (@ncnn_mat_get_data = nil) or (@ncnn_mat_substract_mean_normalize = nil) or (@ncnn_mat_from_pixels = nil)
  then
  begin
    // raise EncnnError.Create('GetProcAddress');
    Exit;
  end;
end;

function TInferenceEngine.Version: PAnsiChar;
begin
  Result := ncnn_version;
end;

function TInferenceEngine.NetCreate: Pointer;
begin
  Result := ncnn_net_create;
end;

function TInferenceEngine.MatCreate: Pointer;
begin
  Result := ncnn_mat_create;
end;

procedure TInferenceEngine.MatGetData(mat: Pointer; out data: Pointer);
begin
  data := ncnn_mat_get_data(mat);
end;

procedure TInferenceEngine.MatDestroy(mat: Pointer);
begin
  ncnn_mat_destroy(mat);
end;

procedure TInferenceEngine.ExtractorDestroy(ex: Pointer);
begin
  ncnn_extractor_destroy(ex);
end;

procedure TInferenceEngine.OptionDestroy(opt: Pointer);
begin
  ncnn_option_destroy(opt);
end;

procedure TInferenceEngine.NetDestroy(net: ncnn_net_t);
begin
  ncnn_net_destroy(net);
end;

function TInferenceEngine.MatGetW(mat: Pointer): Int64;
begin
  Result := ncnn_mat_get_w(mat);
end;

function TInferenceEngine.NetLoadModel(net: ncnn_net_t; const path: PAnsiChar): Int64;
begin
  Result := ncnn_net_load_model(net, path);
end;

function TInferenceEngine.NetLoadParam(net: ncnn_net_t; const path: PAnsiChar): Int64;
begin
  Result := ncnn_net_load_param(net, path);
end;

procedure TInferenceEngine.NetSetOption(net: ncnn_net_t; opt: Pointer);
begin
  ncnn_net_set_option(net, opt);
end;

function TInferenceEngine.OptionCreate: Pointer;
begin
  Result := ncnn_option_create();
end;

function TInferenceEngine.ExtractorCreate(net: ncnn_net_t): Pointer;
begin
  Result := ncnn_extractor_create(net);
end;

function TInferenceEngine.ExtractorInput(ex: Pointer; const name: PAnsiChar; mat: Pointer): Int64;
begin
  Result := ncnn_extractor_input(ex, name, mat);
end;

function TInferenceEngine.ExtractorExtract(ex: Pointer; const name: PAnsiChar; out mat: Pointer): Int64;
begin
  Result := ncnn_extractor_extract(ex, name, mat);
end;

function TInferenceEngine.MatFromPixelsResize(pixels: Pointer; pixel_type: Int64; w: Int64; h: Int64; stride: Int64; target_width: Int64; target_height: Int64; allocator: Pointer = nil): Pointer;
begin
  Result := ncnn_mat_from_pixels_resize(pixels, pixel_type, w, h, stride, target_width, target_height, allocator);
end;

function TInferenceEngine.MatFromPixels(pixels: Pointer; pixel_type: Int64; w: Int64; h: Int64; stride: Int64; allocator: Pointer = nil): Pointer;
begin
  Result := ncnn_mat_from_pixels(pixels, pixel_type, w, h, stride, allocator);
end;

procedure TInferenceEngine.MatSubstractMeanNormalize(mat: Pointer; mean_vals: Pointer; norm_vals: Pointer);
begin
  ncnn_mat_substract_mean_normalize(mat, mean_vals, norm_vals);
end;

procedure TInferenceEngine.OptionSetUseVulkanCompute(opt: Pointer; use_vulkan_compute: Int64);
begin
  ncnn_option_set_use_vulkan_compute(opt, use_vulkan_compute);
end;

destructor TInferenceEngine.Destroy;
begin
  if ncnn_module <> 0 then
    FreeLibrary(ncnn_module);
  ncnn_module := 0;

  inherited Destroy;
end;

end.
