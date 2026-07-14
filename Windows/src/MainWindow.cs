using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;

namespace CodexResetWatcher.Windows
{
    internal sealed class MainWindow : Form
    {
        private readonly ResetWatcherStore store;
        private readonly AppSettings settings;
        private readonly ListBox sidebar;
        private readonly Label titleLabel;
        private readonly Label metaLabel;
        private readonly Label nudgeLabel;
        private readonly Label nudgeDetailLabel;
        private readonly Label errorsLabel;
        private readonly ListView usageList;
        private readonly ListView creditsList;
        private readonly Button refreshButton;
        private readonly Button forgetButton;
        private readonly Button clearStaleButton;
        private readonly Button clearCachedButton;
        private bool updating;

        public MainWindow(ResetWatcherStore store, AppSettings settings)
        {
            this.store = store;
            this.settings = settings;

            Text = "Codex Reset Watcher";
            Icon = UiUtil.LoadAppIcon();
            MinimumSize = new Size(800, 560);
            Size = new Size(860, 620);
            BackColor = UiUtil.Background;
            Font = UiUtil.BodyFont();

            SplitContainer split = new SplitContainer();
            split.Dock = DockStyle.Fill;
            split.FixedPanel = FixedPanel.Panel1;
            split.SplitterDistance = 250;
            split.BackColor = UiUtil.Background;
            Controls.Add(split);

            sidebar = new ListBox();
            sidebar.Dock = DockStyle.Fill;
            sidebar.DrawMode = DrawMode.OwnerDrawFixed;
            sidebar.ItemHeight = 54;
            sidebar.BorderStyle = BorderStyle.None;
            sidebar.BackColor = UiUtil.Background;
            sidebar.ForeColor = UiUtil.Text;
            sidebar.DrawItem += DrawSidebarItem;
            sidebar.SelectedIndexChanged += SidebarSelectedIndexChanged;
            split.Panel1.Padding = new Padding(12);
            split.Panel1.Controls.Add(sidebar);

            TableLayoutPanel detail = new TableLayoutPanel();
            detail.Dock = DockStyle.Fill;
            detail.ColumnCount = 1;
            detail.RowCount = 7;
            detail.Padding = new Padding(18);
            detail.BackColor = UiUtil.Background;
            detail.RowStyles.Add(new RowStyle(SizeType.Absolute, 86));
            detail.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            detail.RowStyles.Add(new RowStyle(SizeType.Absolute, 70));
            detail.RowStyles.Add(new RowStyle(SizeType.Percent, 48));
            detail.RowStyles.Add(new RowStyle(SizeType.Percent, 52));
            detail.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            detail.RowStyles.Add(new RowStyle(SizeType.Absolute, 42));
            split.Panel2.Controls.Add(detail);

            Panel header = new Panel { Dock = DockStyle.Fill };
            titleLabel = UiUtil.Label("", UiUtil.TitleFont(), UiUtil.Text);
            titleLabel.Dock = DockStyle.Top;
            titleLabel.Height = 32;
            metaLabel = UiUtil.Label("", UiUtil.BodyFont(), UiUtil.Secondary);
            metaLabel.Dock = DockStyle.Top;
            metaLabel.Height = 42;
            header.Controls.Add(metaLabel);
            header.Controls.Add(titleLabel);
            detail.Controls.Add(header, 0, 0);

            errorsLabel = UiUtil.Label("", UiUtil.BodyFont(), UiUtil.Warning);
            errorsLabel.AutoSize = true;
            errorsLabel.MaximumSize = new Size(560, 0);
            detail.Controls.Add(errorsLabel, 0, 1);

            Panel nudgePanel = new Panel { Dock = DockStyle.Fill, BackColor = UiUtil.Panel, Padding = new Padding(12) };
            nudgeLabel = UiUtil.Label("", UiUtil.SectionFont(), UiUtil.Text);
            nudgeLabel.Dock = DockStyle.Top;
            nudgeLabel.Height = 22;
            nudgeDetailLabel = UiUtil.Label("", UiUtil.BodyFont(), UiUtil.Secondary);
            nudgeDetailLabel.Dock = DockStyle.Fill;
            nudgePanel.Controls.Add(nudgeDetailLabel);
            nudgePanel.Controls.Add(nudgeLabel);
            detail.Controls.Add(nudgePanel, 0, 2);

            usageList = UiUtil.DetailsList();
            usageList.Columns.Add("Window", 130);
            usageList.Columns.Add("Remaining", 110);
            usageList.Columns.Add("Resets", 260);
            detail.Controls.Add(usageList, 0, 3);

            creditsList = UiUtil.DetailsList();
            creditsList.Columns.Add("Reset", 130);
            creditsList.Columns.Add("Expires", 220);
            creditsList.Columns.Add("Status", 150);
            detail.Controls.Add(creditsList, 0, 4);

            FlowLayoutPanel cleanup = new FlowLayoutPanel();
            cleanup.Dock = DockStyle.Fill;
            cleanup.FlowDirection = FlowDirection.LeftToRight;
            cleanup.AutoSize = true;
            cleanup.WrapContents = false;
            clearStaleButton = new Button { Text = "Clear stale", AutoSize = true };
            clearStaleButton.Click += delegate { store.ClearStaleSnapshots(); };
            clearCachedButton = new Button { Text = "Clear cached", AutoSize = true };
            clearCachedButton.Click += delegate { store.ClearCachedSnapshots(); };
            cleanup.Controls.Add(clearStaleButton);
            cleanup.Controls.Add(clearCachedButton);
            detail.Controls.Add(cleanup, 0, 5);

            FlowLayoutPanel actions = new FlowLayoutPanel();
            actions.Dock = DockStyle.Fill;
            actions.FlowDirection = FlowDirection.RightToLeft;
            actions.WrapContents = false;
            refreshButton = new Button { Text = "Refresh", Width = 90 };
            refreshButton.Click += delegate { store.BeginRefresh(); };
            forgetButton = new Button { Text = "Forget cached", Width = 110 };
            forgetButton.Click += delegate
            {
                AccountDetailState state = store.Detail();
                if (state.CanForget)
                {
                    store.ForgetSnapshot(state.SnapshotId);
                }
            };
            actions.Controls.Add(refreshButton);
            actions.Controls.Add(forgetButton);
            detail.Controls.Add(actions, 0, 6);

            RefreshContent();
        }

        public void RefreshContent()
        {
            updating = true;
            object selectedId = null;
            if (sidebar.SelectedItem is SidebarRow)
            {
                selectedId = ((SidebarRow)sidebar.SelectedItem).Id;
            }

            sidebar.Items.Clear();
            sidebar.Items.Add(new SidebarRow { Id = null, Label = store.AccountDisplayLabel, Detail = ActiveDetailText(), IsStale = false });
            foreach (CodexAccountSnapshot snapshot in store.CachedSnapshots)
            {
                bool stale = snapshot.IsStale(DateTimeOffset.Now);
                sidebar.Items.Add(new SidebarRow
                {
                    Id = snapshot.Id,
                    Label = snapshot.EffectiveLabel,
                    Detail = stale ? "Stale snapshot" : "Cached " + DateFormatting.TimeOnly(snapshot.LastChecked),
                    IsStale = stale
                });
            }

            int selectIndex = 0;
            for (int i = 0; i < sidebar.Items.Count; i++)
            {
                SidebarRow row = (SidebarRow)sidebar.Items[i];
                if ((selectedId == null && row.Id == null) || (selectedId != null && String.Equals((string)selectedId, row.Id, StringComparison.OrdinalIgnoreCase)))
                {
                    selectIndex = i;
                    break;
                }
            }
            sidebar.SelectedIndex = selectIndex;
            updating = false;

            AccountDetailState state = store.Detail();
            titleLabel.Text = state.AccountLabel;
            metaLabel.Text = state.PlanLabel + "  -  " + state.StatusTitle + "  -  " + DateFormatting.Checked(state.LastChecked) + "  -  " + state.AvailableCount + " reset" + (state.AvailableCount == 1 ? "" : "s");

            nudgeLabel.Text = state.Nudge == null ? "" : state.Nudge.Title;
            nudgeLabel.ForeColor = UiUtil.NudgeColor(state.Nudge);
            nudgeDetailLabel.Text = state.Nudge == null ? "" : state.Nudge.Message + " " + state.Nudge.Detail;

            errorsLabel.Text = state.ErrorMessages.Count == 0 ? "" : String.Join(Environment.NewLine, state.ErrorMessages.ToArray());

            PopulateUsage(state.UsageWindows);
            PopulateCredits(state.Credits);

            refreshButton.Enabled = state.CanRefresh && !state.IsRefreshing;
            forgetButton.Visible = state.CanForget;
            forgetButton.Text = state.IsStale ? "Forget stale" : "Forget cached";
            clearStaleButton.Enabled = state.StaleSnapshotCount > 0;
            clearCachedButton.Enabled = store.CachedSnapshots.Count > 0;
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (e.CloseReason == CloseReason.UserClosing)
            {
                e.Cancel = true;
                Hide();
                return;
            }
            base.OnFormClosing(e);
        }

        private void PopulateUsage(List<UsageLimitDisplay> windows)
        {
            usageList.BeginUpdate();
            usageList.Items.Clear();
            foreach (UsageLimitDisplay window in windows)
            {
                ListViewItem item = new ListViewItem(window.Title);
                item.SubItems.Add(UiUtil.RemainingText(window.RemainingPercent));
                item.SubItems.Add(UiUtil.ResetText(window));
                usageList.Items.Add(item);
            }
            if (usageList.Items.Count == 0)
            {
                ListViewItem item = new ListViewItem("Usage meters");
                item.SubItems.Add("Unknown");
                item.SubItems.Add("-");
                usageList.Items.Add(item);
            }
            usageList.EndUpdate();
        }

        private void PopulateCredits(List<ResetCreditDisplay> credits)
        {
            creditsList.BeginUpdate();
            creditsList.Items.Clear();
            int index = 1;
            foreach (ResetCreditDisplay credit in credits)
            {
                if (!credit.IsAvailable)
                {
                    continue;
                }
                ResetExpiryUrgency urgency = ResetExpiryUrgency.Make(credit.ExpiresAt, DateTimeOffset.Now, credit.IsAvailable);
                ListViewItem item = new ListViewItem("Reset " + index);
                item.SubItems.Add(DateFormatting.ResetTime(credit.ExpiresAt));
                item.SubItems.Add(urgency.Badge);
                creditsList.Items.Add(item);
                index++;
            }
            if (creditsList.Items.Count == 0)
            {
                ListViewItem item = new ListViewItem("Reset credits");
                item.SubItems.Add("-");
                item.SubItems.Add("No available resets");
                creditsList.Items.Add(item);
            }
            creditsList.EndUpdate();
        }

        private void SidebarSelectedIndexChanged(object sender, EventArgs e)
        {
            if (updating || sidebar.SelectedItem == null)
            {
                return;
            }
            SidebarRow row = (SidebarRow)sidebar.SelectedItem;
            if (row.Id == null)
            {
                store.SelectActive();
            }
            else
            {
                store.SelectCachedAccount(row.Id);
            }
        }

        private void DrawSidebarItem(object sender, DrawItemEventArgs e)
        {
            if (e.Index < 0)
            {
                return;
            }
            SidebarRow row = (SidebarRow)sidebar.Items[e.Index];
            e.DrawBackground();
            Color labelColor = row.IsStale ? UiUtil.Warning : UiUtil.Text;
            using (Brush labelBrush = new SolidBrush(labelColor))
            using (Brush detailBrush = new SolidBrush(UiUtil.Secondary))
            {
                Rectangle labelRect = new Rectangle(e.Bounds.Left + 8, e.Bounds.Top + 7, e.Bounds.Width - 16, 20);
                Rectangle detailRect = new Rectangle(e.Bounds.Left + 8, e.Bounds.Top + 29, e.Bounds.Width - 16, 18);
                e.Graphics.DrawString(row.Label, UiUtil.BodyFont(), labelBrush, labelRect);
                e.Graphics.DrawString(row.Detail, UiUtil.SmallFont(), detailBrush, detailRect);
            }
            e.DrawFocusRectangle();
        }

        private string ActiveDetailText()
        {
            if (store.IsRefreshing)
            {
                return "Refreshing active account...";
            }
            if (store.Usage == null && store.Credits.Count == 0 && store.ErrorMessages.Count > 0)
            {
                return "No active Codex login";
            }
            return "Active now";
        }

        private sealed class SidebarRow
        {
            public string Id;
            public string Label;
            public string Detail;
            public bool IsStale;

            public override string ToString()
            {
                return Label;
            }
        }
    }
}
