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
    
    string orderIdStr = ""; // تعریف در scope بالاتر
    
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

        if (data == null)
        {
            Response.Write("{\"status\":\"error\",\"message\":\"داده null است\"}");
            return;
        }

        if (!data.ContainsKey("order_id"))
        {
            Response.Write("{\"status\":\"error\",\"message\":\"order_id وجود ندارد\"}");
            return;
        }

        if (!data.ContainsKey("items"))
        {
            Response.Write("{\"status\":\"error\",\"message\":\"items وجود ندارد\"}");
            return;
        }

        // بررسی انواع مختلف آرایه
        object itemsObj = data["items"];
        System.Collections.IList items = null;
        
        if (itemsObj == null)
        {
            Response.Write("{\"status\":\"error\",\"message\":\"items null است\"}");
            return;
        }
        
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
            Response.Write("{\"status\":\"error\",\"message\":\"آیتم‌ها نامعتبر است - نوع: " + itemsObj.GetType().Name + "\"}");
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
            try
            {
                conn.Open();
            }
            catch (SqlException connEx)
            {
                Response.Write("{\"status\":\"error\",\"message\":\"خطا در اتصال به دیتابیس: " + connEx.Message.Replace("\"", "'") + "\"}");
                return;
            }

            // ترکیب نام و نام خانوادگی برای appEmza
            string firstName = "";
            string lastName = "";
            string customerName = "";
            
            try
            {
                firstName = data.ContainsKey("first_name") ? data["first_name"].ToString().Trim() : "";
                lastName = data.ContainsKey("last_name") ? data["last_name"].ToString().Trim() : "";
                customerName = data.ContainsKey("customer") ? data["customer"].ToString().Trim() : "";
            }
            catch
            {
                customerName = "";
            }
            
            if (string.IsNullOrEmpty(customerName) && (!string.IsNullOrEmpty(firstName) || !string.IsNullOrEmpty(lastName)))
            {
                customerName = (firstName + " " + lastName).Trim();
            }
            
            if (string.IsNullOrEmpty(customerName))
            {
                orderIdStr = data["order_id"].ToString().Trim();
                customerName = "سفارش #" + orderIdStr;
            }
            else
            {
                orderIdStr = data["order_id"].ToString().Trim();
            }

            // تبدیل order_id
            long orderIdLong = 0;
            if (!long.TryParse(orderIdStr, out orderIdLong))
            {
                Response.Write("{\"status\":\"error\",\"message\":\"order_id نامعتبر است: " + orderIdStr + "\"}");
                return;
            }

            // دریافت سایر فیلدها
            string sharhFact = "";
            string codeMF = "";
            string codep = "";
            decimal subF = 0;
            
            try
            {
                sharhFact = data.ContainsKey("order_notes") ? data["order_notes"].ToString().Trim() : "";
                codeMF = data.ContainsKey("mobile") ? data["mobile"].ToString().Trim() : 
                         (data.ContainsKey("phone") ? data["phone"].ToString().Trim() : "");
                codep = data.ContainsKey("email") ? data["email"].ToString().Trim() : "";
                
                if (data.ContainsKey("total"))
                {
                    decimal.TryParse(data["total"].ToString(), out subF);
                }
            }
            catch (Exception fieldEx)
            {
                Response.Write("{\"status\":\"error\",\"message\":\"خطا در خواندن فیلدها: " + fieldEx.Message.Replace("\"", "'") + "\"}");
                return;
            }

            // ===== INSERT INTO sale_title =====
            try
            {
                SqlCommand cmd = new SqlCommand(@"
INSERT INTO dbo.sale_title
(NoFact,DateFact,SharhFact,CodeMF,SubF,Flag,codep,appEmza)
VALUES
(@NoFact,@DateFact,@SharhFact,@CodeMF,@SubF,@Flag,@codep,@appEmza)", conn);

                cmd.Parameters.AddWithValue("@NoFact", orderIdLong);
                cmd.Parameters.AddWithValue("@DateFact", DateTime.Now.ToString("yyyy/MM/dd"));
                cmd.Parameters.AddWithValue("@SharhFact", sharhFact);
                cmd.Parameters.AddWithValue("@CodeMF", codeMF);
                cmd.Parameters.AddWithValue("@SubF", subF);
                cmd.Parameters.AddWithValue("@Flag", "WC");
                cmd.Parameters.AddWithValue("@codep", codep);
                cmd.Parameters.AddWithValue("@appEmza", customerName);
                
                cmd.ExecuteNonQuery();
            }
            catch (SqlException insertEx)
            {
                Response.Write("{\"status\":\"error\",\"message\":\"خطا در INSERT sale_title: " + insertEx.Message.Replace("\"", "'").Replace("\r\n", " ") + "\"}");
                return;
            }

            // ===== دریافت آخرین id از sale_detaile =====
            int nextId = 1;
            try
            {
                SqlCommand cmdMaxId = new SqlCommand("SELECT ISNULL(MAX(id), 0) FROM dbo.sale_detaile", conn);
                object maxIdObj = cmdMaxId.ExecuteScalar();
                if (maxIdObj != null && maxIdObj != DBNull.Value)
                {
                    nextId = Convert.ToInt32(maxIdObj) + 1;
                }
            }
            catch (Exception maxIdEx)
            {
                Response.Write("{\"status\":\"error\",\"message\":\"خطا در دریافت MAX(id): " + maxIdEx.Message.Replace("\"", "'") + "\"}");
                return;
            }

            // ===== INSERT INTO sale_detaile =====
            int radif = 1;
            int insertedCount = 0;
            
            foreach (Dictionary<string, object> item in items)
            {
                try
                {
                    string codeK = "";
                    string sharh = "";
                    decimal tedad = 0;
                    decimal pool = 0;
                    
                    if (item.ContainsKey("sku"))
                    {
                        codeK = item["sku"].ToString().Trim();
                    }
                    
                    if (item.ContainsKey("name"))
                    {
                        sharh = item["name"].ToString().Trim();
                    }
                    
                    if (item.ContainsKey("qty"))
                    {
                        decimal.TryParse(item["qty"].ToString(), out tedad);
                    }
                    
                    if (item.ContainsKey("total"))
                    {
                        decimal.TryParse(item["total"].ToString(), out pool);
                    }

                    SqlCommand cmdDetail = new SqlCommand(@"
INSERT INTO dbo.sale_detaile
(id,NoFact,codeK,NoAnbar,Radif,Sharh,Tedad,Pool,SabtOkInt)
VALUES
(@id,@NoFact,@codeK,1,@Radif,@Sharh,@Tedad,@Pool,1)", conn);

                    cmdDetail.Parameters.AddWithValue("@id", nextId++);
                    cmdDetail.Parameters.AddWithValue("@NoFact", orderIdLong);
                    cmdDetail.Parameters.AddWithValue("@codeK", codeK);
                    cmdDetail.Parameters.AddWithValue("@Radif", radif++);
                    cmdDetail.Parameters.AddWithValue("@Sharh", sharh);
                    cmdDetail.Parameters.AddWithValue("@Tedad", tedad);
                    cmdDetail.Parameters.AddWithValue("@Pool", pool);
                    
                    cmdDetail.ExecuteNonQuery();
                    insertedCount++;
                }
                catch (Exception itemEx)
                {
                    Response.Write("{\"status\":\"error\",\"message\":\"خطا در ذخیره آیتم ردیف " + radif + ": " + itemEx.Message.Replace("\"", "'").Replace("\r\n", " ") + "\"}");
                    return;
                }
            }

            if (insertedCount == 0)
            {
                Response.Write("{\"status\":\"error\",\"message\":\"هیچ آیتمی در sale_detaile ذخیره نشد\"}");
                return;
            }
        }

        var result = new { status = "ok", message = "سفارش با موفقیت ذخیره شد", order_id = orderIdStr };
        var serializer = new JavaScriptSerializer();
        Response.Write(serializer.Serialize(result));
    }
    catch (Exception ex)
    {
        Response.StatusCode = 500;
        Response.Write("{\"status\":\"error\",\"message\":\"خطای عمومی: " + ex.Message.Replace("\"", "'").Replace("\r\n", " ") + "\"}");
    }
}
</script>
