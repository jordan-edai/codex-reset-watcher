using System;
using System.Drawing;
using System.Windows.Forms;

namespace CodexResetWatcher.Windows
{
    internal sealed class WatcherApplicationContext : ApplicationContext
    {
        private readonly ResetWatcherStore store;
        private readonly AppSettings settings;
        private readonly NotifyIcon notifyIcon;
        private readonly Control invoker;
        private MainWindow mainWindow;
        private FlyoutForm flyout;
        private Icon appIcon;

        public WatcherApplicationContext()
        {
            settings = new AppSettings();
            store = new ResetWatcherStore();
            appIcon = UiUtil.LoadAppIcon();

            invoker = new Control();
            invoker.CreateControl();

            notifyIcon = new NotifyIcon();
            notifyIcon.Icon = appIcon;
            notifyIcon.Visible = true;
            notifyIcon.Text = "Codex Reset Watcher";
            notifyIcon.ContextMenuStrip = BuildContextMenu();
            notifyIcon.MouseClick += NotifyIconMouseClick;
            notifyIcon.DoubleClick += delegate { ShowMainWindow(); };

            store.Changed += StoreChanged;
            store.Start();
            UpdateTray();
        }

        public void ShowMainWindow()
        {
            if (mainWindow == null || mainWindow.IsDisposed)
            {
                mainWindow = new MainWindow(store, settings);
                mainWindow.FormClosed += delegate { mainWindow = null; };
            }
            mainWindow.Show();
            if (mainWindow.WindowState == FormWindowState.Minimized)
            {
                mainWindow.WindowState = FormWindowState.Normal;
            }
            mainWindow.Activate();
            mainWindow.BringToFront();
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                store.Dispose();
                notifyIcon.Visible = false;
                notifyIcon.Dispose();
                if (mainWindow != null)
                {
                    mainWindow.Dispose();
                }
                if (flyout != null)
                {
                    flyout.Dispose();
                }
                if (appIcon != null)
                {
                    appIcon.Dispose();
                }
                invoker.Dispose();
            }
            base.Dispose(disposing);
        }

        private ContextMenuStrip BuildContextMenu()
        {
            ContextMenuStrip menu = new ContextMenuStrip();
            menu.Items.Add("Refresh", null, delegate { store.BeginRefresh(); });
            menu.Items.Add("Open", null, delegate { ShowMainWindow(); });
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add("Quit", null, delegate { ExitThread(); });
            return menu;
        }

        private void NotifyIconMouseClick(object sender, MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Left)
            {
                ShowFlyout();
            }
        }

        private void ShowFlyout()
        {
            if (flyout == null || flyout.IsDisposed)
            {
                flyout = new FlyoutForm(store, settings, ShowMainWindow, ExitThread);
            }
            flyout.RefreshContent();

            Rectangle workArea = Screen.FromPoint(Cursor.Position).WorkingArea;
            int x = Math.Min(Cursor.Position.X, workArea.Right - flyout.Width - 8);
            int y = Math.Min(Cursor.Position.Y, workArea.Bottom - flyout.Height - 8);
            flyout.StartPosition = FormStartPosition.Manual;
            flyout.Location = new Point(Math.Max(workArea.Left + 8, x), Math.Max(workArea.Top + 8, y));
            flyout.Show();
            flyout.Activate();
        }

        private void StoreChanged(object sender, EventArgs e)
        {
            if (invoker.InvokeRequired)
            {
                invoker.BeginInvoke(new MethodInvoker(UpdateAll));
            }
            else
            {
                UpdateAll();
            }
        }

        private void UpdateAll()
        {
            UpdateTray();
            if (mainWindow != null && !mainWindow.IsDisposed)
            {
                mainWindow.RefreshContent();
            }
            if (flyout != null && !flyout.IsDisposed && flyout.Visible)
            {
                flyout.RefreshContent();
            }
        }

        private void UpdateTray()
        {
            string title = store.MenuBarTitle(settings.Metric);
            notifyIcon.Text = Truncate("Codex Reset Watcher - " + title, 63);
        }

        private static string Truncate(string value, int max)
        {
            if (value.Length <= max)
            {
                return value;
            }
            return value.Substring(0, max - 1) + "...";
        }
    }
}
