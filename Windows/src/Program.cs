using System;
using System.Net;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace CodexResetWatcher.Windows
{
    internal static class Program
    {
        [STAThread]
        private static int Main(string[] args)
        {
            ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;

            string selfTestOutput = ArgumentValue(args, "--self-test-output");
            if (!String.IsNullOrEmpty(selfTestOutput))
            {
                return Diagnostics.RunSelfTest(selfTestOutput);
            }

            string liveCheckOutput = ArgumentValue(args, "--live-check-output");
            if (!String.IsNullOrEmpty(liveCheckOutput))
            {
                return RunLiveCheck(liveCheckOutput);
            }

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new WatcherApplicationContext());
            return 0;
        }

        private static int RunLiveCheck(string outputPath)
        {
            try
            {
                Task<int> task = Diagnostics.RunLiveCheckAsync(outputPath);
                task.Wait();
                return task.Result;
            }
            catch (AggregateException ex)
            {
                Exception inner = ex.InnerException ?? ex;
                Diagnostics.WriteFailure(outputPath, inner.Message);
                return 1;
            }
            catch (Exception ex)
            {
                Diagnostics.WriteFailure(outputPath, ex.Message);
                return 1;
            }
        }

        private static string ArgumentValue(string[] args, string name)
        {
            for (int i = 0; i < args.Length - 1; i++)
            {
                if (String.Equals(args[i], name, StringComparison.OrdinalIgnoreCase))
                {
                    return args[i + 1];
                }
            }
            return null;
        }
    }
}
