<%@ Page Language="C#" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>
<%@ Import Namespace="System.Text" %>
<%@ Import Namespace="System.Configuration" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "application/json; charset=utf-8";
    Response.Charset = "utf-8";
    
    string orderIdStr = "";
    StringBuilder log = new StringBuilder();
    
    try
    {
        log.AppendLine("=== save_order.aspx Started ===");
        log.AppendLine("Time: " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
        
        // خواندن داده‌های POST با UTF-8
        string body = "";
        using (StreamReader reader = new StreamReader(Request.InputStream, Encoding.UTF8))
        {
            body = reader.ReadToEnd();
        }
        
        log.AppendLine("Body Length: " + (body != null ? body.Length : 0));
        
        if (string.IsNullOrEmpty(body))
        {
            log.AppendLine("ERROR: Body is empty");
            Response.Write("{\"status\":\"error\",\"message\":\"بدون داده\",\"log\":\"" + EscapeJson(log.ToString()) + "\"}");
            return;
        }

        var js = new JavaScriptSerializer();
        js.MaxJsonLength = int.MaxValue; // برای JSON های بزرگ
        dynamic data = null;
        
        try
        {
            data = js.DeserializeObject(body);
            log.AppendLine("JSON Deserialized Successfully");
        }
        catch (Exception jsonEx)
        {
            log.AppendLine("ERROR in JSON Deserialization: " + jsonEx.Message);
            Response.Write("{\"status\":\"error\",\"message\":\"خطا در پارس JSON: " + jsonEx.Message.Replace("\"", "'") + "\",\"log\":\"" + EscapeJson(log.ToString()) + "\"}");
            return;
        }

        if (data == null)
        {
            log.AppendLine("ERROR: data is null");
            Response.Write("{\"status\":\"error\",\"message\":\"داده null است\",\"log\":\"" + EscapeJson(log.ToString()) + "\"}");
            return;
        }

        if (!(data is Dictionary<string, object>))
        {
            log.AppendLine("ERROR: data is not Dictionary");
            Response.Write("{\"status\":\"error\",\"message\":\"فرمت داده نامعتبر\",\"log\":\"" + EscapeJson(log.ToString()) + "\"}");
            return;
        }

        var dict = (Dictionary<string, object>)data;

        if (!dict.ContainsKey("order_id"))
        {
            log.AppendLine("ERROR: order_id not found");
            Response.Write("{\"status\":\"error\",\"message\":\"order_id یافت نشد\",\"log\":\"" + EscapeJson(log.ToString()) + "\"}");
            return;
        }

        if (!dict.ContainsKey("items"))
        {
            log.AppendLine("ERROR: items not found");
            Response.Write("{\"status\":\"error\",\"message\":\"items یافت نشد\",\"log\":\"" + EscapeJson(log.ToString()) + "\"}");
            return;
        }

        // بررسی items
        object itemsObj = dict["items"];
        System.Collections.IList items = null;
        
        if (itemsObj is System.Collections.ArrayList)
        {
            items = (System.Collections.ArrayList)itemsObj;
            log.AppendLine("Items is ArrayList, Count: " + items.Count);
        }
        else if (itemsObj is object[])
        {
            var arr = (object[])itemsObj;
            items = new System.Collections.ArrayList(arr);
            log.AppendLine("Items is Array, Count: " + items.Count);
        }
        else if (itemsObj is System.Collections.Generic.List<object>)
        {
            var list = (System.Collections.Generic.List<object>)itemsObj;
            items = new System.Collections.ArrayList(list);
            log.AppendLine("Items is List, Count: " + items.Count);
        }
        else
        {
            log.AppendLine("ERROR: Items type not supported: " + (itemsObj != null ? itemsObj.GetType().ToString() : "null"));
            Response.Write("{\"status\":\"error\",\"message\":\"آیتم‌ها نامعتبر است\",\"log\":\"" + EscapeJson(log.ToString()) + "\"}");
            return;
        }

        if (items == null || items.Count == 0)
        {
            log.AppendLine("ERROR: No items found");
            Response.Write("{\"status\":\"error\",\"message\":\"هیچ آیتمی وجود ندارد\",\"log\":\"" + EscapeJson(log.ToString()) + "\"}");
            return;
        }

        string connectionString = "Server=194.5.195.93;Database=millionaire;User Id=sa;Password=2901;";

        using (SqlConnection conn = new SqlConnection(connectionString))
        {
            log.AppendLine("Connecting to database...");
            conn.Open();
            log.AppendLine("Database connection opened");

            // دریافت آخرین NoFact
            SqlCommand cmdMaxNoFact = new SqlCommand("SELECT ISNULL(MAX(NoFact), 0) FROM dbo.sale_title", conn);
            long lastNoFact = Convert.ToInt64(cmdMaxNoFact.ExecuteScalar());
            long newNoFact = lastNoFact + 1;
            log.AppendLine("Last NoFact: " + lastNoFact + ", New NoFact: " + newNoFact);

            // بررسی order_id
            long wordpressOrderId = 0;
            if (long.TryParse(dict["order_id"].ToString(), out wordpressOrderId))
            {
                log.AppendLine("WordPress Order ID: " + wordpressOrderId);
                SqlCommand cmdCheck = new SqlCommand("SELECT COUNT(*) FROM dbo.sale_title WHERE NoFact = @NoFact", conn);
                cmdCheck.Parameters.AddWithValue("@NoFact", wordpressOrderId);
                int exists = Convert.ToInt32(cmdCheck.ExecuteScalar());
                log.AppendLine("Order ID exists check: " + exists);
                
                if (exists == 0)
                {
                    newNoFact = wordpressOrderId;
                    log.AppendLine("Using WordPress Order ID as NoFact: " + newNoFact);
                }
            }

            orderIdStr = newNoFact.ToString();

            // آماده‌سازی داده‌ها با محدودیت طول
            string firstName = dict.ContainsKey("first_name") ? (dict["first_name"] != null ? dict["first_name"].ToString().Trim() : "") : "";
            string lastName = dict.ContainsKey("last_name") ? (dict["last_name"] != null ? dict["last_name"].ToString().Trim() : "") : "";
            string customerName = dict.ContainsKey("customer") ? (dict["customer"] != null ? dict["customer"].ToString().Trim() : "") : "";
            
            if (string.IsNullOrEmpty(customerName) && (!string.IsNullOrEmpty(firstName) || !string.IsNullOrEmpty(lastName)))
            {
                customerName = (firstName + " " + lastName).Trim();
            }
            
            if (string.IsNullOrEmpty(customerName))
            {
                customerName = "سفارش #" + orderIdStr;
            }

            if (customerName.Length > 500) customerName = customerName.Substring(0, 500);

            string sharhFact = dict.ContainsKey("order_notes") ? (dict["order_notes"] != null ? dict["order_notes"].ToString().Trim() : "") : "";
            if (sharhFact.Length > 150) sharhFact = sharhFact.Substring(0, 150);

            string codeMF = dict.ContainsKey("mobile") ? (dict["mobile"] != null ? dict["mobile"].ToString().Trim() : "") : 
                           (dict.ContainsKey("phone") ? (dict["phone"] != null ? dict["phone"].ToString().Trim() : "") : "");
            if (codeMF.Length > 15) codeMF = codeMF.Substring(0, 15);

            string codep = dict.ContainsKey("email") ? (dict["email"] != null ? dict["email"].ToString().Trim() : "") : "";
            if (codep.Length > 20) codep = codep.Substring(0, 20);

            decimal subF = 0;
            if (dict.ContainsKey("total"))
            {
                if (!decimal.TryParse(dict["total"].ToString(), out subF))
                {
                    log.AppendLine("WARNING: Could not parse total");
                }
            }

            log.AppendLine("Prepared data - NoFact: " + newNoFact + ", Customer: " + customerName + ", Total: " + subF);

            // INSERT INTO sale_title
            SqlCommand cmd = new SqlCommand(@"
INSERT INTO dbo.sale_title
(NoFact,DateFact,SharhFact,CodeMF,SubF,Flag,codep,appEmza)
VALUES
(@NoFact,@DateFact,@SharhFact,@CodeMF,@SubF,@Flag,@codep,@appEmza)", conn);

            cmd.Parameters.AddWithValue("@NoFact", newNoFact);
            cmd.Parameters.AddWithValue("@DateFact", DateTime.Now.ToString("yyyy/MM/dd"));
            cmd.Parameters.AddWithValue("@SharhFact", (object)sharhFact ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@CodeMF", (object)codeMF ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@SubF", subF);
            cmd.Parameters.AddWithValue("@Flag", "WC");
            cmd.Parameters.AddWithValue("@codep", (object)codep ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@appEmza", (object)customerName ?? DBNull.Value);
            
            cmd.ExecuteNonQuery();
            log.AppendLine("sale_title inserted successfully");

            // دریافت آخرین id از sale_detaile
            SqlCommand cmdMaxId = new SqlCommand("SELECT ISNULL(MAX(id), 0) FROM dbo.sale_detaile", conn);
            int nextId = Convert.ToInt32(cmdMaxId.ExecuteScalar()) + 1;
            log.AppendLine("Next id for sale_detaile: " + nextId);

            // INSERT INTO sale_detaile
            int radif = 1;
            int insertedCount = 0;
            
            foreach (object itemObj in items)
            {
                Dictionary<string, object> item = null;
                
                if (itemObj is Dictionary<string, object>)
                {
                    item = (Dictionary<string, object>)itemObj;
                }
                else
                {
                    log.AppendLine("WARNING: Item is not Dictionary");
                    continue;
                }

                string codeK = item.ContainsKey("sku") ? (item["sku"] != null ? item["sku"].ToString().Trim() : "") : "";
                if (codeK.Length > 15) codeK = codeK.Substring(0, 15);

                string sharh = item.ContainsKey("name") ? (item["name"] != null ? item["name"].ToString().Trim() : "") : "";
                if (sharh.Length > 150) sharh = sharh.Substring(0, 150);

                decimal tedad = 0;
                decimal pool = 0;
                
                if (!decimal.TryParse(item.ContainsKey("qty") ? (item["qty"] != null ? item["qty"].ToString() : "0") : "0", out tedad))
                {
                    log.AppendLine("WARNING: Could not parse qty");
                }
                
                if (!decimal.TryParse(item.ContainsKey("total") ? (item["total"] != null ? item["total"].ToString() : "0") : "0", out pool))
                {
                    log.AppendLine("WARNING: Could not parse total");
                }

                log.AppendLine("Item " + radif + ": codeK=" + codeK + ", tedad=" + tedad + ", pool=" + pool);

                SqlCommand cmdDetail = new SqlCommand(@"
INSERT INTO dbo.sale_detaile
(id,NoFact,codeK,NoAnbar,Radif,Sharh,Tedad,Pool,SabtOkInt)
VALUES
(@id,@NoFact,@codeK,1,@Radif,@Sharh,@Tedad,@Pool,1)", conn);

                cmdDetail.Parameters.AddWithValue("@id", nextId++);
                cmdDetail.Parameters.AddWithValue("@NoFact", newNoFact);
                cmdDetail.Parameters.AddWithValue("@codeK", (object)codeK ?? DBNull.Value);
                cmdDetail.Parameters.AddWithValue("@Radif", radif++);
                cmdDetail.Parameters.AddWithValue("@Sharh", (object)sharh ?? DBNull.Value);
                cmdDetail.Parameters.AddWithValue("@Tedad", tedad);
                cmdDetail.Parameters.AddWithValue("@Pool", pool);
                
                cmdDetail.ExecuteNonQuery();
                insertedCount++;
            }

            log.AppendLine("Inserted " + insertedCount + " items into sale_detaile");

            if (insertedCount == 0)
            {
                log.AppendLine("ERROR: No items inserted");
                Response.Write("{\"status\":\"error\",\"message\":\"هیچ آیتمی در sale_detaile ذخیره نشد\",\"log\":\"" + EscapeJson(log.ToString()) + "\"}");
                return;
            }
        }

        log.AppendLine("=== Completed Successfully ===");
        var result = new { 
            status = "ok", 
            message = "سفارش با موفقیت ذخیره شد", 
            order_id = orderIdStr,
            wordpress_order_id = dict["order_id"].ToString(),
            log = log.ToString()
        };
        var serializer = new JavaScriptSerializer();
        serializer.MaxJsonLength = int.MaxValue;
        Response.Write(serializer.Serialize(result));
    }
    catch (SqlException sqlEx)
    {
        log.AppendLine("SQL ERROR: " + sqlEx.Message);
        log.AppendLine("Stack Trace: " + sqlEx.StackTrace);
        Response.StatusCode = 500;
        Response.Write("{\"status\":\"error\",\"message\":\"خطای SQL: " + sqlEx.Message.Replace("\"", "'").Replace("\r\n", " ") + "\",\"log\":\"" + EscapeJson(log.ToString()) + "\"}");
    }
    catch (Exception ex)
    {
        log.AppendLine("GENERAL ERROR: " + ex.Message);
        log.AppendLine("Stack Trace: " + ex.StackTrace);
        Response.StatusCode = 500;
        Response.Write("{\"status\":\"error\",\"message\":\"خطا: " + ex.Message.Replace("\"", "'").Replace("\r\n", " ") + "\",\"log\":\"" + EscapeJson(log.ToString()) + "\"}");
    }
}

string EscapeJson(string text)
{
    if (string.IsNullOrEmpty(text)) return "";
    return text.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r\n", "\\n").Replace("\n", "\\n").Replace("\r", "\\n");
}
</script>
