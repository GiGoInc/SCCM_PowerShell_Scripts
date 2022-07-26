﻿#Start PInvoke Code 
$sigFormatMessage = @' 
[DllImport("kernel32.dll")] 
public static extern uint FormatMessage(uint flags, IntPtr source, uint messageId, uint langId, StringBuilder buffer, uint size, string[] arguments); 
'@ 
 
$sigGetModuleHandle = @' 
[DllImport("kernel32.dll")] 
public static extern IntPtr GetModuleHandle(string lpModuleName); 
'@ 
 
$sigLoadLibrary = @' 
[DllImport("kernel32.dll")] 
public static extern IntPtr LoadLibrary(string lpFileName); 
'@ 
 
$Win32FormatMessage = Add-Type -MemberDefinition $sigFormatMessage -name "Win32FormatMessage" -namespace Win32Functions -PassThru -Using System.Text 
$Win32GetModuleHandle = Add-Type -MemberDefinition $sigGetModuleHandle -name "Win32GetModuleHandle" -namespace Win32Functions -PassThru -Using System.Text 
$Win32LoadLibrary = Add-Type -MemberDefinition $sigLoadLibrary -name "Win32LoadLibrary" -namespace Win32Functions -PassThru -Using System.Text 
#End PInvoke Code
 
$sizeOfBuffer = [int]16384 
$stringArrayInput = {"%1","%2","%3","%4","%5", "%6", "%7", "%8", "%9"} 
$flags = 0x00000800 -bor 0x00000200  
$stringOutput = New-Object System.Text.StringBuilder $sizeOfBuffer 
$colMessages = @() 
$strOutputCSV = "E:\StatusMessages\StatusMessages.csv" 
$stringPathToDLL = "D:\Program Files\Microsoft Configuration Manager\bin\X64\system32\smsmsgs\srvmsgs.dll"

 
#Load Status Message Lookup DLL into memory and get pointer to memory 
$ptrFoo = $Win32LoadLibrary::LoadLibrary($stringPathToDLL.ToString()) 
$ptrModule = $Win32GetModuleHandle::GetModuleHandle($stringPathToDLL.ToString())


 
#Find Informational Status Messages 
for ($iMessageID = 1; $iMessageID -ile 99999; $iMessageID++) 
{ 
    $result = $Win32FormatMessage::FormatMessage($flags, $ptrModule, 1073741824 -bor $iMessageID, 0, $stringOutput, $sizeOfBuffer, $stringArrayInput) 
     
    if( $result -gt 0) 
    { 
        $objMessage = New-Object System.Object 
        $objMessage | Add-Member -type NoteProperty -name MessageID -value $iMessageID 
        $objMessage | Add-Member -type NoteProperty -name MessageString -value $stringOutput.ToString().Replace("%11","").Replace("%12","").Replace("%3%4%5%6%7%8%9%10","") 
        $objMessage | Add-Member -type NoteProperty -name Severity -value "Informational" 
        $colMessages += $objMessage 
        #$iMessageID 
        #$stringOutput.ToString() 
    } 
     
    #$previousString = $stringOutput.ToString() 
} 

$colMessages | Export-CSV -path $stringOutputCSV 