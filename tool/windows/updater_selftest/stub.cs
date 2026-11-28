using System;
using System.IO;
using System.Threading;
class P {
  static int Main(string[] a) {
    string dir = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);
    string root = Path.GetFullPath(Path.Combine(dir, ".."));
    string ver = File.ReadAllText(Path.Combine(dir, "version.txt")).Trim();
    bool crash = File.Exists(Path.Combine(dir, "crash.txt"));
    File.AppendAllText(Path.Combine(root, "launches.log"), DateTime.Now.ToString("HH:mm:ss") + " " + ver + (crash ? " crash" : " start") + "\r\n");
    if (crash) return 3;
    string work = Path.Combine(root, "work");
    string inst = Path.Combine(work, "installing.json");
    if (File.Exists(inst) && File.ReadAllText(inst).Contains("\"to\":\"" + ver + "\"")) {
      File.WriteAllText(Path.Combine(work, "started-ok.txt"), ver);
    }
    int secs = ver == "0.20.24" ? 3 : 25;
    Thread.Sleep(secs * 1000);
    return 0;
  }
}
