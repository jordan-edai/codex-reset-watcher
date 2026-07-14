using System;
using System.Drawing;
using System.IO;
using System.Windows.Forms;

namespace CodexResetWatcher.Windows
{
    internal static class UiUtil
    {
        public static readonly Color Background = Color.FromArgb(250, 250, 247);
        public static readonly Color Panel = Color.White;
        public static readonly Color Border = Color.FromArgb(225, 225, 218);
        public static readonly Color Text = Color.FromArgb(28, 31, 35);
        public static readonly Color Secondary = Color.FromArgb(96, 101, 108);
        public static readonly Color Accent = Color.FromArgb(32, 123, 91);
        public static readonly Color Warning = Color.FromArgb(184, 95, 0);
        public static readonly Color Urgent = Color.FromArgb(180, 40, 45);

        public static Font TitleFont()
        {
            return new Font("Segoe UI", 16f, FontStyle.Bold);
        }

        public static Font SectionFont()
        {
            return new Font("Segoe UI", 10f, FontStyle.Bold);
        }

        public static Font BodyFont()
        {
            return new Font("Segoe UI", 9f, FontStyle.Regular);
        }

        public static Font SmallFont()
        {
            return new Font("Segoe UI", 8.25f, FontStyle.Regular);
        }

        public static Icon LoadAppIcon()
        {
            string path = AssetPath("AppIcon.png");
            if (File.Exists(path))
            {
                try
                {
                    Bitmap bitmap = new Bitmap(path);
                    return Icon.FromHandle(bitmap.GetHicon());
                }
                catch
                {
                }
            }
            return SystemIcons.Application;
        }

        public static Image LoadHeaderImage()
        {
            string path = AssetPath("UsageHeader.png");
            if (!File.Exists(path))
            {
                return null;
            }
            try
            {
                return Image.FromFile(path);
            }
            catch
            {
                return null;
            }
        }

        public static string AssetPath(string filename)
        {
            string baseDirectory = AppDomain.CurrentDomain.BaseDirectory;
            string local = Path.Combine(baseDirectory, "Assets", filename);
            if (File.Exists(local))
            {
                return local;
            }
            return Path.GetFullPath(Path.Combine(baseDirectory, "..", "..", "Assets", filename));
        }

        public static Label Label(string text, Font font, Color color)
        {
            return new Label
            {
                AutoSize = false,
                Text = text,
                Font = font,
                ForeColor = color,
                UseMnemonic = false
            };
        }

        public static ListView DetailsList()
        {
            return new ListView
            {
                View = View.Details,
                FullRowSelect = true,
                HeaderStyle = ColumnHeaderStyle.Nonclickable,
                BorderStyle = BorderStyle.FixedSingle,
                Font = BodyFont(),
                BackColor = Panel,
                ForeColor = Text,
                HideSelection = false
            };
        }

        public static string RemainingText(int? value)
        {
            return value.HasValue ? value.Value + "% left" : "Unknown";
        }

        public static string ResetText(UsageLimitDisplay window)
        {
            if (window == null || window.Window == null)
            {
                return "-";
            }
            if (window.Window.ResetDate.HasValue)
            {
                return DateFormatting.WeekdayDate(window.Window.ResetDate) + " at " + DateFormatting.TimeOnly(window.Window.ResetDate);
            }
            return "in " + DateFormatting.Duration(window.Window.ResetAfterSeconds);
        }

        public static Color NudgeColor(UsageNudge nudge)
        {
            if (nudge == null)
            {
                return Secondary;
            }
            switch (nudge.Tier)
            {
                case "spend":
                    return Accent;
                case "expiringReset":
                    return Urgent;
                case "deadline":
                case "useIfBlocked":
                    return Warning;
                default:
                    return Secondary;
            }
        }
    }
}
