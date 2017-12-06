function Send-CatFact {
    <#
    .SYNOPSIS
        Send a cat fact to users on a computer.
    .DESCRIPTION
        Send a random cat fact to any number of computers and play it through the speakers. Supports credential passing.
        Acknowledgment to https://github.com/nickrod518/PowerShell-Scripts/blob/master/Fun/Send-CatFactMessage.ps1

    .EXAMPLE
        Send-CatFact
        Sends cat fact message to localhost and outputs fact through speakers.

    .EXAMPLE
        Get-ADComputer -Filter * | Send-CatFact -Credential (Get-Credential)
        Send cat fact to all AD computers. Prompt user for credentials to run command with.

    .EXAMPLE
        Send-CatFact -ComputerName pc1, pc2, pc3
        Send cat fact to provided computer names.

    .PARAMETER ComputerName
        The computer name to execute against. Default is local computer.

    .PARAMETER Credential
        The credential object to execute the command with.
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]$ComputerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $CatFact = Invoke-RestMethod -Uri 'https://catfact.ninja/fact' -Method Get |
        Select-Object -ExpandProperty fact

    if ($pscmdlet.ShouldProcess("Computer: $ComputerName", "Send cat fact, $CatFact")) {
        $ScriptBlock = {
            param (
                [Parameter(Mandatory = $true)]
                [string]$CatFact
            )

            # Add .NET lib for controlling audio
            Add-Type -TypeDefinition @'
            using System.Runtime.InteropServices;

            [Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
            interface IAudioEndpointVolume {
              // f(), g(), ... are unused COM method slots. Define these if you care
              int f(); int g(); int h(); int i();
              int SetMasterVolumeLevelScalar(float fLevel, System.Guid pguidEventContext);
              int j();
              int GetMasterVolumeLevelScalar(out float pfLevel);
              int k(); int l(); int m(); int n();
              int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, System.Guid pguidEventContext);
              int GetMute(out bool pbMute);
            }
            [Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
            interface IMMDevice {
              int Activate(ref System.Guid id, int clsCtx, int activationParams, out IAudioEndpointVolume aev);
            }
            [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
            interface IMMDeviceEnumerator {
              int f(); // Unused
              int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);
            }
            [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumeratorComObject { }

            public class Audio {
              static IAudioEndpointVolume Vol() {
                var enumerator = new MMDeviceEnumeratorComObject() as IMMDeviceEnumerator;
                IMMDevice dev = null;
                Marshal.ThrowExceptionForHR(enumerator.GetDefaultAudioEndpoint(/*eRender*/ 0, /*eMultimedia*/ 1, out dev));
                IAudioEndpointVolume epv = null;
                var epvid = typeof(IAudioEndpointVolume).GUID;
                Marshal.ThrowExceptionForHR(dev.Activate(ref epvid, /*CLSCTX_ALL*/ 23, 0, out epv));
                return epv;
              }
              public static float Volume {
                get {float v = -1; Marshal.ThrowExceptionForHR(Vol().GetMasterVolumeLevelScalar(out v)); return v;}
                set {Marshal.ThrowExceptionForHR(Vol().SetMasterVolumeLevelScalar(value, System.Guid.Empty));}
              }
              public static bool Mute {
                get { bool mute; Marshal.ThrowExceptionForHR(Vol().GetMute(out mute)); return mute; }
                set { Marshal.ThrowExceptionForHR(Vol().SetMute(value, System.Guid.Empty)); }
              }
            }
'@

            # Set audio to unmuted and volume to MAX
            ([audio]::Mute) = 0; ([Audio]::Volume) = 1

            Add-Type -AssemblyName System.Speech
            $SpeechSynth = New-Object System.Speech.Synthesis.SpeechSynthesizer
            $SpeechSynth.Speak($CatFact)
        }

        $Params = @{
            'ComputerName' = $ComputerName
            'ScriptBlock'  = $ScriptBlock
            'ArgumentList' = @($CatFact)
            'AsJob'        = $true
        }
        if ($Credential) { $Params.Add('Credential', $Credential) }

        Invoke-Command @Params

        Get-Job | Wait-Job | Receive-Job
        Get-Job | Remove-Job
    }
}
