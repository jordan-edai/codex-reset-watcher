using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Web.Script.Serialization;

namespace CodexResetWatcher.Windows
{
    internal static class JsonUtil
    {
        public static Dictionary<string, object> ParseObject(string json)
        {
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            serializer.MaxJsonLength = Int32.MaxValue;
            return AsDictionary(serializer.DeserializeObject(json));
        }

        public static string Serialize(object value)
        {
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            serializer.MaxJsonLength = Int32.MaxValue;
            return serializer.Serialize(value);
        }

        public static Dictionary<string, object> AsDictionary(object value)
        {
            Dictionary<string, object> dict = value as Dictionary<string, object>;
            if (dict != null)
            {
                return dict;
            }
            return null;
        }

        public static IList AsList(object value)
        {
            IList list = value as IList;
            return list;
        }

        public static object Get(Dictionary<string, object> dict, string key)
        {
            if (dict == null)
            {
                return null;
            }
            object value;
            if (dict.TryGetValue(key, out value))
            {
                return value;
            }
            return null;
        }

        public static Dictionary<string, object> GetDictionary(Dictionary<string, object> dict, string key)
        {
            return AsDictionary(Get(dict, key));
        }

        public static IList GetList(Dictionary<string, object> dict, string key)
        {
            return AsList(Get(dict, key));
        }

        public static string GetString(Dictionary<string, object> dict, string key)
        {
            object value = Get(dict, key);
            if (value == null)
            {
                return null;
            }
            string text = value as string;
            if (text != null)
            {
                return text;
            }
            if (value is int || value is long || value is double || value is decimal || value is bool)
            {
                return Convert.ToString(value, CultureInfo.InvariantCulture);
            }
            return null;
        }

        public static int? GetInt(Dictionary<string, object> dict, string key)
        {
            object value = Get(dict, key);
            if (value == null)
            {
                return null;
            }
            if (value is int)
            {
                return (int)value;
            }
            if (value is long)
            {
                long longValue = (long)value;
                if (longValue >= Int32.MinValue && longValue <= Int32.MaxValue)
                {
                    return (int)longValue;
                }
            }
            if (value is decimal || value is double)
            {
                return Convert.ToInt32(value, CultureInfo.InvariantCulture);
            }
            string text = value as string;
            int parsed;
            if (text != null && Int32.TryParse(text, NumberStyles.Integer, CultureInfo.InvariantCulture, out parsed))
            {
                return parsed;
            }
            return null;
        }

        public static double? GetDouble(Dictionary<string, object> dict, string key)
        {
            object value = Get(dict, key);
            if (value == null)
            {
                return null;
            }
            if (value is double || value is decimal || value is int || value is long)
            {
                return Convert.ToDouble(value, CultureInfo.InvariantCulture);
            }
            string text = value as string;
            double parsed;
            if (text != null && Double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out parsed))
            {
                return parsed;
            }
            return null;
        }

        public static bool? GetBool(Dictionary<string, object> dict, string key)
        {
            object value = Get(dict, key);
            if (value == null)
            {
                return null;
            }
            if (value is bool)
            {
                return (bool)value;
            }
            string text = value as string;
            bool parsed;
            if (text != null && Boolean.TryParse(text, out parsed))
            {
                return parsed;
            }
            return null;
        }
    }
}
