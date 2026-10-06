$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives,System.Private.Windows.GdiPlus,System.Private.Windows.Core -TypeDefinition @'
using System;
using System.Drawing;
public static class PropScan {
 public static int Cut(int[] counts, double fraction) {
  int ideal=(int)(counts.Length*fraction), best=ideal, score=int.MaxValue;
  for(int k=Math.Max(1,ideal-counts.Length/12);k<Math.Min(counts.Length-1,ideal+counts.Length/12);k++) {
   int s=counts[k]*10000+Math.Abs(k-ideal);
   if(s<score){score=s;best=k;}
  }
  if(counts[best]>0) throw new Exception("No transparent separation found");
  return best;
 }
 public static int[][] Scan(string path) {
  using(var b=new Bitmap(path)) {
   int[] xs=new int[b.Width],ys=new int[b.Height];
   for(int y=0;y<b.Height;y++) for(int x=0;x<b.Width;x++) if(b.GetPixel(x,y).A>16){xs[x]++;ys[y]++;}
   int[] cx={0,Cut(xs,1.0/3),Cut(xs,2.0/3),b.Width},cy={0,Cut(ys,1.0/3),Cut(ys,2.0/3),b.Height};
   int[][] result=new int[9][];
   for(int r=0;r<3;r++) for(int c=0;c<3;c++) {
    int x0=cx[c+1],y0=cy[r+1],x1=-1,y1=-1;
    for(int y=cy[r];y<cy[r+1];y++) for(int x=cx[c];x<cx[c+1];x++) if(b.GetPixel(x,y).A>16){x0=Math.Min(x0,x);y0=Math.Min(y0,y);x1=Math.Max(x1,x);y1=Math.Max(y1,y);}
    if(x1<0) throw new Exception("Empty prop region");
    x0=Math.Max(cx[c],x0-2);y0=Math.Max(cy[r],y0-2);x1=Math.Min(cx[c+1]-1,x1+2);y1=Math.Min(cy[r+1]-1,y1+2);
    result[r*3+c]=new int[]{x0,y0,x1-x0+1,y1-y0+1};
   }
   return result;
  }
 }
}
'@
$catalog = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') | ConvertFrom-Json
New-Item -ItemType Directory -Force -Path (Join-Path $PSScriptRoot 'props') | Out-Null
$records = @()
foreach($theme in $catalog.themes) {
 $source = Join-Path $PSScriptRoot $theme.prop_sheet
 $regions = [PropScan]::Scan($source)
 $im = [System.Drawing.Bitmap]::FromFile($source)
 $dimensions = @($im.Width,$im.Height)
 $alpha = $im.GetPixel(0,0).A
 $im.Dispose()
 if($alpha -gt 1){ throw "Opaque background: $source" }
 for($i=0;$i -lt 9;$i++) {
  $rect=$regions[$i]
  $id='{0}-{1:d2}' -f $theme.id,($i+1)
  $resource=@"
[gd_resource type="AtlasTexture" load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://assets/art/biofactory-v1/$($theme.prop_sheet)" id="1"]

[resource]
atlas = ExtResource("1")
region = Rect2($($rect -join ', '))
filter_clip = true
"@
  [IO.File]::WriteAllText((Join-Path $PSScriptRoot "props/$id.tres"),$resource)
  $records += [ordered]@{id=$id; theme=$theme.id; description=$theme.props[$i]; sheet=$theme.prop_sheet; dimensions=$dimensions; region=$rect; transparent_background=$true; region_alpha_threshold=16; resource="props/$id.tres"}
 }
 Write-Output "$($theme.id): $($dimensions -join 'x'), transparent alpha and 9 separated props verified"
}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'regions.json'),(ConvertTo-Json -Depth 6 -InputObject $records))
