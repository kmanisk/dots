using System;
using System.Runtime.InteropServices;
public static class XLiteGpuProbe {
 [DllImport("d3d11.dll")] static extern int D3D11CreateDevice(IntPtr adapter,int type,IntPtr software,uint flags,IntPtr levels,uint count,uint sdk,out IntPtr device,out uint level,out IntPtr context);
 [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int GetAdapter(IntPtr self,out IntPtr adapter);
 [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int GetDesc(IntPtr self,IntPtr desc);
 public static string Run(){
  IntPtr dev,ctx;uint level;int hr=D3D11CreateDevice(IntPtr.Zero,1,IntPtr.Zero,0,IntPtr.Zero,0,7,out dev,out level,out ctx);
  string result="D3D11 hardware HRESULT=0x"+hr.ToString("X8")+" featureLevel=0x"+level.ToString("X");
  if(hr<0)return result;
  Guid iid=new Guid("54ec77fa-1377-44e6-8c32-88fd5f44c84c");IntPtr dxgi;
  if(Marshal.QueryInterface(dev,ref iid,out dxgi)==0){
   IntPtr vtbl=Marshal.ReadIntPtr(dxgi);IntPtr adapter;
   var get=(GetAdapter)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(vtbl,7*IntPtr.Size),typeof(GetAdapter));
   if(get(dxgi,out adapter)==0){
    IntPtr desc=Marshal.AllocHGlobal(512);var gd=(GetDesc)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(Marshal.ReadIntPtr(adapter),8*IntPtr.Size),typeof(GetDesc));
    if(gd(adapter,desc)==0)result+="\nadapter="+Marshal.PtrToStringUni(desc)+" vendor=0x"+Marshal.ReadInt32(desc,256).ToString("X4")+" device=0x"+Marshal.ReadInt32(desc,260).ToString("X4");
    Marshal.FreeHGlobal(desc);Marshal.Release(adapter);
   }Marshal.Release(dxgi);
  }Marshal.Release(ctx);Marshal.Release(dev);return result;
 }
}
