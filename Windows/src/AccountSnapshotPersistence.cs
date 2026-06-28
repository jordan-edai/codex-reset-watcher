using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Security.AccessControl;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;

namespace CodexResetWatcher.Windows
{
    internal sealed class AccountSnapshotPersistence
    {
        private const int SchemaVersion = 1;
        private const string AppFolderName = "Codex Reset Watcher";
        private const string SnapshotFilename = "account-snapshots.json";
        private const string SaltFilename = "install-salt.txt";

        public readonly string DirectoryPath;
        public readonly string FilePath;
        private readonly string saltPath;

        public AccountSnapshotPersistence() : this(null)
        {
        }

        public AccountSnapshotPersistence(string directoryPath)
        {
            DirectoryPath = directoryPath ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), AppFolderName);
            FilePath = Path.Combine(DirectoryPath, SnapshotFilename);
            saltPath = Path.Combine(DirectoryPath, SaltFilename);
        }

        public List<CodexAccountSnapshot> Load()
        {
            if (!File.Exists(FilePath))
            {
                return new List<CodexAccountSnapshot>();
            }

            try
            {
                Dictionary<string, object> root = JsonUtil.ParseObject(File.ReadAllText(FilePath, Encoding.UTF8));
                if ((JsonUtil.GetInt(root, "schemaVersion") ?? 0) != SchemaVersion)
                {
                    return new List<CodexAccountSnapshot>();
                }

                List<CodexAccountSnapshot> snapshots = new List<CodexAccountSnapshot>();
                IList list = JsonUtil.GetList(root, "snapshots");
                if (list != null)
                {
                    foreach (object item in list)
                    {
                        CodexAccountSnapshot snapshot = CodexAccountSnapshot.FromJsonObject(JsonUtil.AsDictionary(item));
                        if (snapshot != null)
                        {
                            snapshots.Add(snapshot);
                        }
                    }
                }
                snapshots.Sort((a, b) => b.LastChecked.CompareTo(a.LastChecked));
                return snapshots;
            }
            catch
            {
                return new List<CodexAccountSnapshot>();
            }
        }

        public void Save(List<CodexAccountSnapshot> snapshots)
        {
            EnsureDirectory();
            List<CodexAccountSnapshot> sorted = new List<CodexAccountSnapshot>(snapshots);
            sorted.Sort((a, b) => b.LastChecked.CompareTo(a.LastChecked));

            List<object> snapshotObjects = new List<object>();
            foreach (CodexAccountSnapshot snapshot in sorted)
            {
                snapshotObjects.Add(snapshot.ToJsonObject());
            }

            Dictionary<string, object> root = new Dictionary<string, object>
            {
                { "schemaVersion", SchemaVersion },
                { "snapshots", snapshotObjects }
            };

            string temp = FilePath + ".tmp";
            File.WriteAllText(temp, JsonUtil.Serialize(root), Encoding.UTF8);
            if (File.Exists(FilePath))
            {
                File.Delete(FilePath);
            }
            File.Move(temp, FilePath);
            TrySetCurrentUserOnly(FilePath);
        }

        public List<CodexAccountSnapshot> Upsert(CodexAccountSnapshot snapshot, List<CodexAccountSnapshot> snapshots)
        {
            List<CodexAccountSnapshot> next = new List<CodexAccountSnapshot>();
            foreach (CodexAccountSnapshot existing in snapshots)
            {
                if (!String.Equals(existing.Id, snapshot.Id, StringComparison.OrdinalIgnoreCase))
                {
                    next.Add(existing);
                }
            }
            next.Add(snapshot);
            Save(next);
            next.Sort((a, b) => b.LastChecked.CompareTo(a.LastChecked));
            return next;
        }

        public string SnapshotIdFor(string accountId)
        {
            string clean = (accountId ?? "").Trim();
            string input = LoadSalt() + ":" + clean;
            using (SHA256 sha = SHA256.Create())
            {
                byte[] digest = sha.ComputeHash(Encoding.UTF8.GetBytes(input));
                StringBuilder builder = new StringBuilder();
                for (int i = 0; i < digest.Length; i++)
                {
                    builder.Append(digest[i].ToString("x2"));
                }
                return builder.ToString().Substring(0, 32);
            }
        }

        private string LoadSalt()
        {
            EnsureDirectory();
            if (File.Exists(saltPath))
            {
                string existing = File.ReadAllText(saltPath, Encoding.UTF8).Trim();
                if (!String.IsNullOrWhiteSpace(existing))
                {
                    return existing;
                }
            }

            byte[] bytes = new byte[32];
            using (RandomNumberGenerator rng = RandomNumberGenerator.Create())
            {
                rng.GetBytes(bytes);
            }
            string salt = Convert.ToBase64String(bytes);
            File.WriteAllText(saltPath, salt, Encoding.UTF8);
            TrySetCurrentUserOnly(saltPath);
            return salt;
        }

        private void EnsureDirectory()
        {
            Directory.CreateDirectory(DirectoryPath);
            TrySetCurrentUserOnly(DirectoryPath);
        }

        private static void TrySetCurrentUserOnly(string path)
        {
            try
            {
                SecurityIdentifier user = WindowsIdentity.GetCurrent().User;
                FileSystemSecurity security;
                bool isDirectory = Directory.Exists(path);
                if (isDirectory)
                {
                    security = Directory.GetAccessControl(path);
                }
                else
                {
                    security = File.GetAccessControl(path);
                }

                security.SetAccessRuleProtection(true, false);
                security.AddAccessRule(new FileSystemAccessRule(
                    user,
                    FileSystemRights.FullControl,
                    isDirectory ? InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit : InheritanceFlags.None,
                    PropagationFlags.None,
                    AccessControlType.Allow));

                if (isDirectory)
                {
                    Directory.SetAccessControl(path, (DirectorySecurity)security);
                }
                else
                {
                    File.SetAccessControl(path, (FileSecurity)security);
                }
            }
            catch
            {
                // Best effort only. The file still remains under the user's profile.
            }
        }
    }
}
