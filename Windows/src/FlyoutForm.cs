using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;

namespace CodexResetWatcher.Windows
{
    internal sealed class FlyoutForm : Form
    {
        private readonly ResetWatcherStore store;
        private readonly AppSettings settings;
        private readonly Action showMainWindow;
        private readonly Action quit;
        private readonly FlowLayoutPanel content;

        public FlyoutForm(ResetWatcherStore store, AppSettings settings, Action showMainWindow, Action quit)
        {
            this.store = store;
            this.settings = settings;
            this.showMainWindow = showMainWindow;
            this.quit = quit;

            Text = "Codex Reset Watcher";
            ShowInTaskbar = false;
            FormBorderStyle = FormBorderStyle.FixedSingle;
            Size = new Size(430, 620);
            BackColor = UiUtil.Background;
            Font = UiUtil.BodyFont();
            Deactivate += delegate { Hide(); };

            content = new FlowLayoutPanel();
            content.Dock = DockStyle.Fill;
            content.FlowDirection = FlowDirection.TopDown;
            content.WrapContents = false;
            content.AutoScroll = true;
            content.Padding = new Padding(14);
            content.BackColor = UiUtil.Background;
            Controls.Add(content);
        }

        public void RefreshContent()
        {
            content.SuspendLayout();
            content.Controls.Clear();

            AddHeader();
            AddMetricSelector();
            AddErrors(store.ErrorMessages);
            AddUsageRows(store.UsageWindows);
            AddNudge(store.Nudge);
            AddResetRows(store.AvailableCreditDisplays);
            AddCachedSnapshots();
            AddFooter();

            content.ResumeLayout();
        }

        private void AddHeader()
        {
            Panel panel = RowPanel(86);
            Image image = UiUtil.LoadHeaderImage();
            if (image != null)
            {
                PictureBox picture = new PictureBox { Image = image, SizeMode = PictureBoxSizeMode.Zoom, Size = new Size(72, 52), Location = new Point(0, 8) };
                panel.Controls.Add(picture);
            }
            Label title = UiUtil.Label("Codex limits", UiUtil.TitleFont(), UiUtil.Text);
            title.Location = new Point(86, 8);
            title.Size = new Size(280, 28);
            Label meta = UiUtil.Label(DateFormatting.Checked(store.LastChecked), UiUtil.SmallFont(), UiUtil.Secondary);
            meta.Location = new Point(86, 36);
            meta.Size = new Size(280, 18);
            Label account = UiUtil.Label("Active: " + store.AccountDisplayLabel, UiUtil.BodyFont(), UiUtil.Secondary);
            account.Location = new Point(86, 56);
            account.Size = new Size(290, 20);
            panel.Controls.Add(title);
            panel.Controls.Add(meta);
            panel.Controls.Add(account);
            content.Controls.Add(panel);
        }

        private void AddMetricSelector()
        {
            Panel panel = RowPanel(44);
            Label label = UiUtil.Label("Tray display", UiUtil.BodyFont(), UiUtil.Text);
            label.Location = new Point(10, 12);
            label.Size = new Size(150, 20);
            RadioButton week = new RadioButton { Text = "Week", Location = new Point(235, 10), Width = 70, Checked = settings.Metric == MenuBarMetric.Weekly };
            RadioButton five = new RadioButton { Text = "5h", Location = new Point(310, 10), Width = 52, Checked = settings.Metric == MenuBarMetric.FiveHour };
            week.CheckedChanged += delegate
            {
                if (week.Checked)
                {
                    settings.Metric = MenuBarMetric.Weekly;
                    settings.Save();
                }
            };
            five.CheckedChanged += delegate
            {
                if (five.Checked)
                {
                    settings.Metric = MenuBarMetric.FiveHour;
                    settings.Save();
                }
            };
            panel.Controls.Add(label);
            panel.Controls.Add(week);
            panel.Controls.Add(five);
            content.Controls.Add(panel);
        }

        private void AddErrors(List<string> errors)
        {
            foreach (string error in errors)
            {
                Panel panel = RowPanel(58);
                Label label = UiUtil.Label(error, UiUtil.SmallFont(), UiUtil.Warning);
                label.Location = new Point(10, 8);
                label.Size = new Size(370, 42);
                panel.Controls.Add(label);
                content.Controls.Add(panel);
            }
        }

        private void AddUsageRows(List<UsageLimitDisplay> windows)
        {
            foreach (UsageLimitDisplay window in windows)
            {
                Panel panel = RowPanel(54);
                Label title = UiUtil.Label(window.Title, UiUtil.BodyFont(), UiUtil.Text);
                title.Location = new Point(10, 8);
                title.Size = new Size(150, 20);
                Label reset = UiUtil.Label("Resets " + UiUtil.ResetText(window), UiUtil.SmallFont(), UiUtil.Secondary);
                reset.Location = new Point(10, 28);
                reset.Size = new Size(230, 18);
                Label metric = UiUtil.Label(UiUtil.RemainingText(window.RemainingPercent), UiUtil.SectionFont(), UiUtil.Text);
                metric.Location = new Point(270, 16);
                metric.Size = new Size(105, 22);
                metric.TextAlign = ContentAlignment.MiddleRight;
                panel.Controls.Add(title);
                panel.Controls.Add(reset);
                panel.Controls.Add(metric);
                content.Controls.Add(panel);
            }
        }

        private void AddNudge(UsageNudge nudge)
        {
            Panel panel = RowPanel(48);
            Label title = UiUtil.Label(nudge.Title, UiUtil.SectionFont(), UiUtil.NudgeColor(nudge));
            title.Location = new Point(10, 6);
            title.Size = new Size(220, 20);
            Label detail = UiUtil.Label(nudge.Detail, UiUtil.SmallFont(), UiUtil.Secondary);
            detail.Location = new Point(240, 7);
            detail.Size = new Size(135, 20);
            detail.TextAlign = ContentAlignment.MiddleRight;
            Label message = UiUtil.Label(nudge.Message, UiUtil.SmallFont(), UiUtil.Secondary);
            message.Location = new Point(10, 27);
            message.Size = new Size(365, 17);
            panel.Controls.Add(title);
            panel.Controls.Add(detail);
            panel.Controls.Add(message);
            content.Controls.Add(panel);
        }

        private void AddResetRows(List<ResetCreditDisplay> credits)
        {
            int count = 0;
            for (int i = 0; i < credits.Count && count < 4; i++)
            {
                ResetCreditDisplay credit = credits[i];
                if (!credit.IsAvailable)
                {
                    continue;
                }
                count++;
                Panel panel = RowPanel(54);
                Label title = UiUtil.Label("Reset " + count + " expires:", UiUtil.BodyFont(), UiUtil.Text);
                title.Location = new Point(10, 17);
                title.Size = new Size(180, 20);
                Label date = UiUtil.Label(DateFormatting.WeekdayDate(credit.ExpiresAt), UiUtil.SmallFont(), UiUtil.Secondary);
                date.Location = new Point(240, 9);
                date.Size = new Size(135, 18);
                date.TextAlign = ContentAlignment.MiddleRight;
                Label time = UiUtil.Label(DateFormatting.TimeOnly(credit.ExpiresAt), UiUtil.SmallFont(), UiUtil.Secondary);
                time.Location = new Point(240, 27);
                time.Size = new Size(135, 18);
                time.TextAlign = ContentAlignment.MiddleRight;
                panel.Controls.Add(title);
                panel.Controls.Add(date);
                panel.Controls.Add(time);
                content.Controls.Add(panel);
            }
            if (count == 0 && String.IsNullOrWhiteSpace(store.CreditsErrorMessage))
            {
                Panel panel = RowPanel(42);
                Label label = UiUtil.Label("No available resets", UiUtil.BodyFont(), UiUtil.Secondary);
                label.Location = new Point(10, 11);
                label.Size = new Size(250, 20);
                panel.Controls.Add(label);
                content.Controls.Add(panel);
            }
        }

        private void AddCachedSnapshots()
        {
            List<CodexAccountSnapshot> snapshots = store.CachedSnapshots;
            if (snapshots.Count == 0)
            {
                return;
            }
            Label header = UiUtil.Label("Cached snapshots", UiUtil.SectionFont(), UiUtil.Secondary);
            header.Size = new Size(390, 22);
            content.Controls.Add(header);

            int max = Math.Min(3, snapshots.Count);
            for (int i = 0; i < max; i++)
            {
                CodexAccountSnapshot snapshot = snapshots[i];
                bool stale = snapshot.IsStale(DateTimeOffset.Now);
                Button button = new Button();
                button.FlatStyle = FlatStyle.System;
                button.TextAlign = ContentAlignment.MiddleLeft;
                button.Width = 386;
                button.Height = 44;
                button.Text = snapshot.EffectiveLabel + "  -  " + (stale ? "Stale snapshot" : "Cached snapshot");
                string id = snapshot.Id;
                button.Click += delegate
                {
                    store.SelectCachedAccount(id);
                    showMainWindow();
                    Hide();
                };
                content.Controls.Add(button);
            }

            if (store.StaleCachedSnapshotCount > 0)
            {
                Button clear = new Button { Text = "Clear stale snapshots", Width = 386, Height = 34 };
                clear.Click += delegate { store.ClearStaleSnapshots(); RefreshContent(); };
                content.Controls.Add(clear);
            }
        }

        private void AddFooter()
        {
            FlowLayoutPanel footer = new FlowLayoutPanel();
            footer.FlowDirection = FlowDirection.LeftToRight;
            footer.WrapContents = false;
            footer.Width = 390;
            footer.Height = 42;

            Button refresh = new Button { Text = "Refresh", Width = 90, Enabled = !store.IsRefreshing };
            refresh.Click += delegate { store.BeginRefresh(); };
            Button open = new Button { Text = "Open", Width = 80 };
            open.Click += delegate { showMainWindow(); Hide(); };
            Button quitButton = new Button { Text = "Quit", Width = 80 };
            quitButton.Click += delegate { quit(); };
            footer.Controls.Add(refresh);
            footer.Controls.Add(open);
            footer.Controls.Add(quitButton);
            content.Controls.Add(footer);
        }

        private Panel RowPanel(int height)
        {
            return new Panel
            {
                Width = 390,
                Height = height,
                BackColor = UiUtil.Panel,
                Margin = new Padding(0, 0, 0, 8)
            };
        }
    }
}
