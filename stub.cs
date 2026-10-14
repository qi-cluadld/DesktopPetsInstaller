using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;

class PetsInstaller
{
    [STAThread]
    static void Main()
    {
        try
        {
            string dir = Path.Combine(Path.GetTempPath(), "pets_" + Guid.NewGuid().ToString("N").Substring(0, 8));
            Directory.CreateDirectory(dir);
            string[] names = { "install.ps1", "run.vbs", "AllPets.zip" };
            var asm = Assembly.GetExecutingAssembly();
            foreach (string n in names)
            {
                using (Stream s = asm.GetManifestResourceStream("payload." + n))
                {
                    if (s == null) continue;
                    using (var fs = new FileStream(Path.Combine(dir, n), FileMode.Create, FileAccess.Write))
                    {
                        byte[] buf = new byte[81920];
                        int r;
                        while ((r = s.Read(buf, 0, buf.Length)) > 0) fs.Write(buf, 0, r);
                    }
                }
            }
            var psi = new ProcessStartInfo("wscript.exe", "\"" + Path.Combine(dir, "run.vbs") + "\"");
            psi.UseShellExecute = false;
            psi.WorkingDirectory = dir;
            Process.Start(psi);
        }
        catch (Exception ex)
        {
            try { System.Windows.Forms.MessageBox.Show(ex.Message, "AI Desktop Pets"); } catch { }
        }
    }
}