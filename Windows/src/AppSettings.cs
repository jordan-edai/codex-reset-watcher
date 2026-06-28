using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace CodexResetWatcher.Windows
{
    internal sealed class AppSettings
    {
        private readonly string path;
        public MenuBarMetric Metric = MenuBarMetric.Weekly;

        public AppSettings()
        {
            string directory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Codex Reset Watcher");
            Directory.CreateDirectory(directory);
            path = Path.Combine(directory, "settings.json");
            Load();
        }

        public void Save()
        {
            Dictionary<string, object> root = new Dictionary<string, object>
            {
                { "menuBarMetric", Metric == MenuBarMetric.FiveHour ? "fiveHour" : "weekly" }
            };
            File.WriteAllText(path, JsonUtil.Serialize(root), Encoding.UTF8);
        }

        private void Load()
        {
            if (!File.Exists(path))
            {
                return;
            }
            try
            {
                Dictionary<string, object> root = JsonUtil.ParseObject(File.ReadAllText(path, Encoding.UTF8));
                string metric = JsonUtil.GetString(root, "menuBarMetric");
                Metric = String.Equals(metric, "fiveHour", StringComparison.OrdinalIgnoreCase) ? MenuBarMetric.FiveHour : MenuBarMetric.Weekly;
            }
            catch
            {
                Metric = MenuBarMetric.Weekly;
            }
        }
    }
}
