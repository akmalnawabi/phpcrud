<%@ Page Language="C#" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "application/json";
    Response.Charset = "utf-8";
    
    string orderIdStr = "";
    
    try
    {
        string body = new StreamReader(Request.InputStream).ReadToEnd();
        
        if (string.IsNullOrEmpty(body))
        {
            Response.Write("{\"status\":\"error\",\"message\":\"بدون داده\"}");
            return;
        }

        var js = new JavaScriptSerializer();
        dynamic data = null;
        
        try
        {
            data = js.DeserializeObject(body);
        }
        catch (Exception jsonEx)
        {
            Response.Write("{\"status\":\"error\",\"message\":\"خطا در پارس JSON: " + jsonEx.Message.Replace("\"", "'") + "\"}");
            return;
        }

        if (data == null || !data.ContainsKey("order_id") || !data.ContainsKey("items"))
        {
            Response.Write("{\"status\":\"error\",\"message\":\"داده‌های ناقص\"}");
            return;
        }

        // بررسی انواع مختلف آرایه
        object itemsObj = data["items"];
        System.Collections.IList items = null;
        
        if (itemsObj is System.Collections.ArrayList)
        {
            items = (System.Collections.ArrayList)itemsObj;
        }
        else if (itemsObj is object[])
        {
            var arr = (object[])itemsObj;
            items = new System.Collections.ArrayList(arr);
        }
        else if (itemsObj is System.Collections.Generic.List<object>)
        {
            var list = (System.Collections.Generic.List<object>)itemsObj;
            items = new System.Collections.ArrayList(list);
        }
        else
        {
            Response.Write("{\"status\":\"error\",\"message\":\"آیتم‌ها نامعتبر است\"}");
            return;
        }

        if (items == null || items.Count == 0)
        {
            Response.Write("{\"status\":\"error\",\"message\":\"هیچ آیتمی وجود ندارد\"}");
            return;
        }

        string connectionString = "Server=194.5.195.93;Database=millionaire;User Id=sa;Password=2901;";

        using (SqlConnection conn = new SqlConnection(connectionString))
        {
            conn.Open();

            // دریافت آخرین NoFact از دیتابیس
            SqlCommand cmdMaxNoFact = new SqlCommand("SELECT ISNULL(MAX(NoFact), 0) FROM dbo.sale_title", conn);
            long lastNoFact = Convert.ToInt64(cmdMaxNoFact.ExecuteScalar());
            long newNoFact = lastNoFact + 1;

            // بررسی اینکه آیا order_id از WordPress تکراری است
            long wordpressOrderId = 0;
            if (long.TryParse(data["order_id"].ToString(), out wordpressOrderId))
            {
                // بررسی وجود order_id در دیتابیس
                SqlCommand cmdCheck = new SqlCommand("SELECT COUNT(*) FROM dbo.sale_title WHERE NoFact = @NoFact", conn);
                cmdCheck.Parameters.AddWithValue("@NoFact", wordpressOrderId);
                int exists = Convert.ToInt32(cmdCheck.ExecuteScalar());
                
                if (exists == 0)
                {
                    // اگر تکراری نیست، از order_id WordPress استفاده می‌کنیم
                    newNoFact = wordpressOrderId;
                }
                // اگر تکراری است، از newNoFact استفاده می‌کنیم (که از MAX + 1 محاسبه شده)
            }

            orderIdStr = newNoFact.ToString();

            // ترکیب نام و نام خانوادگی برای appEmza
            string firstName = data.ContainsKey("first_name") ? data["first_name"].ToString().Trim() : "";
            string lastName = data.ContainsKey("last_name") ? data["last_name"].ToString().Trim() : "";
            string customerName = data.ContainsKey("customer") ? data["customer"].ToString().Trim() : "";
            
            if (string.IsNullOrEmpty(customerName) && (!string.IsNullOrEmpty(firstName) || !string.IsNullOrEmpty(lastName)))
            {
                customerName = (firstName + " " + lastName).Trim();
            }
            
            if (string.IsNullOrEmpty(customerName))
            {
                customerName = "سفارش #" + orderIdStr;
            }

            // دریافت سایر فیلدها
            string sharhFact = data.ContainsKey("order_notes") ? data["order_notes"].ToString().Trim() : "";
            string codeMF = data.ContainsKey("mobile") ? data["mobile"].ToString().Trim() : 
                           (data.ContainsKey("phone") ? data["phone"].ToString().Trim() : "");
            string codep = data.ContainsKey("email") ? data["email"].ToString().Trim() : "";
            decimal subF = 0;
            if (data.ContainsKey("total"))
            {
                decimal.TryParse(data["total"].ToString(), out subF);
            }

            // ===== INSERT INTO sale_title =====
            SqlCommand cmd = new SqlCommand(@"
INSERT INTO dbo.sale_title
(NoFact,DateFact,SharhFact,CodeMF,SubF,Flag,codep,appEmza)
VALUES
(@NoFact,@DateFact,@SharhFact,@CodeMF,@SubF,@Flag,@codep,@appEmza)", conn);

            cmd.Parameters.AddWithValue("@NoFact", newNoFact);
            cmd.Parameters.AddWithValue("@DateFact", DateTime.Now.ToString("yyyy/MM/dd"));
            cmd.Parameters.AddWithValue("@SharhFact", sharhFact);
            cmd.Parameters.AddWithValue("@CodeMF", codeMF);
            cmd.Parameters.AddWithValue("@SubF", subF);
            cmd.Parameters.AddWithValue("@Flag", "WC");
            cmd.Parameters.AddWithValue("@codep", codep);
            cmd.Parameters.AddWithValue("@appEmza", customerName);
            
            cmd.ExecuteNonQuery();

            // ===== دریافت آخرین id از sale_detaile =====
            SqlCommand cmdMaxId = new SqlCommand("SELECT ISNULL(MAX(id), 0) FROM dbo.sale_detaile", conn);
            int nextId = Convert.ToInt32(cmdMaxId.ExecuteScalar()) + 1;

            // ===== INSERT INTO sale_detaile =====
            int radif = 1;
            int insertedCount = 0;
            
            foreach (Dictionary<string, object> item in items)
            {
                string codeK = item.ContainsKey("sku") ? item["sku"].ToString().Trim() : "";
                string sharh = item.ContainsKey("name") ? item["name"].ToString().Trim() : "";
                decimal tedad = 0;
                decimal pool = 0;
                
                decimal.TryParse(item.ContainsKey("qty") ? item["qty"].ToString() : "0", out tedad);
                decimal.TryParse(item.ContainsKey("total") ? item["total"].ToString() : "0", out pool);

                SqlCommand cmdDetail = new SqlCommand(@"
INSERT INTO dbo.sale_detaile
(id,NoFact,codeK,NoAnbar,Radif,Sharh,Tedad,Pool,SabtOkInt)
VALUES
(@id,@NoFact,@codeK,1,@Radif,@Sharh,@Tedad,@Pool,1)", conn);

                cmdDetail.Parameters.AddWithValue("@id", nextId++);
                cmdDetail.Parameters.AddWithValue("@NoFact", newNoFact);
                cmdDetail.Parameters.AddWithValue("@codeK", codeK);
                cmdDetail.Parameters.AddWithValue("@Radif", radif++);
                cmdDetail.Parameters.AddWithValue("@Sharh", sharh);
                cmdDetail.Parameters.AddWithValue("@Tedad", tedad);
                cmdDetail.Parameters.AddWithValue("@Pool", pool);
                
                cmdDetail.ExecuteNonQuery();
                insertedCount++;
            }

            if (insertedCount == 0)
            {
                Response.Write("{\"status\":\"error\",\"message\":\"هیچ آیتمی در sale_detaile ذخیره نشد\"}");
                return;
            }
        }

        var result = new { 
            status = "ok", 
            message = "سفارش با موفقیت ذخیره شد", 
            order_id = orderIdStr,
            wordpress_order_id = data["order_id"].ToString()
        };
        var serializer = new JavaScriptSerializer();
        Response.Write(serializer.Serialize(result));
    }
    catch (SqlException sqlEx)
    {
        Response.StatusCode = 500;
        Response.Write("{\"status\":\"error\",\"message\":\"خطای SQL: " + sqlEx.Message.Replace("\"", "'").Replace("\r\n", " ") + "\"}");
    }
    catch (Exception ex)
    {
        Response.StatusCode = 500;
        Response.Write("{\"status\":\"error\",\"message\":\"خطا: " + ex.Message.Replace("\"", "'").Replace("\r\n", " ") + "\"}");
    }
}
</script>
