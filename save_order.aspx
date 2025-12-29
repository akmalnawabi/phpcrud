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
    
    try
    {
        string body = new StreamReader(Request.InputStream).ReadToEnd();
        
        if (string.IsNullOrEmpty(body))
        {
            Response.Write("{\"status\":\"error\",\"message\":\"بدون داده\"}");
            return;
        }

        var js = new JavaScriptSerializer();
        dynamic data = js.DeserializeObject(body);

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
                customerName = "سفارش #" + data["order_id"].ToString();
            }

            // تبدیل order_id به string
            string orderIdStr = data["order_id"].ToString().Trim();

            // ===== INSERT INTO sale_title =====
            SqlCommand cmd = new SqlCommand(@"
INSERT INTO dbo.sale_title
(NoFact,DateFact,SharhFact,CodeMF,SubF,Flag,codep,appEmza)
VALUES
(@NoFact,@DateFact,@SharhFact,@CodeMF,@SubF,@Flag,@codep,@appEmza)", conn);

            cmd.Parameters.AddWithValue("@NoFact", Convert.ToInt64(orderIdStr));
            cmd.Parameters.AddWithValue("@DateFact", DateTime.Now.ToString("yyyy/MM/dd"));
            cmd.Parameters.AddWithValue("@SharhFact", data.ContainsKey("order_notes") ? data["order_notes"].ToString().Trim() : "");
            cmd.Parameters.AddWithValue("@CodeMF", data.ContainsKey("mobile") ? data["mobile"].ToString().Trim() : 
                                                      (data.ContainsKey("phone") ? data["phone"].ToString().Trim() : ""));
            cmd.Parameters.AddWithValue("@SubF", Convert.ToDecimal(data.ContainsKey("total") ? data["total"] : "0"));
            cmd.Parameters.AddWithValue("@Flag", "WC");
            cmd.Parameters.AddWithValue("@codep", data.ContainsKey("email") ? data["email"].ToString().Trim() : "");
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
                try
                {
                    SqlCommand cmdDetail = new SqlCommand(@"
INSERT INTO dbo.sale_detaile
(id,NoFact,codeK,NoAnbar,Radif,Sharh,Tedad,Pool,SabtOkInt)
VALUES
(@id,@NoFact,@codeK,1,@Radif,@Sharh,@Tedad,@Pool,1)", conn);

                    cmdDetail.Parameters.AddWithValue("@id", nextId++);
                    cmdDetail.Parameters.AddWithValue("@NoFact", Convert.ToInt64(orderIdStr));
                    cmdDetail.Parameters.AddWithValue("@codeK", item.ContainsKey("sku") ? item["sku"].ToString().Trim() : "");
                    cmdDetail.Parameters.AddWithValue("@Radif", radif++);
                    cmdDetail.Parameters.AddWithValue("@Sharh", item.ContainsKey("name") ? item["name"].ToString().Trim() : "");
                    cmdDetail.Parameters.AddWithValue("@Tedad", item.ContainsKey("qty") ? Convert.ToDecimal(item["qty"]) : 0);
                    cmdDetail.Parameters.AddWithValue("@Pool", item.ContainsKey("total") ? Convert.ToDecimal(item["total"]) : 0);
                    
                    cmdDetail.ExecuteNonQuery();
                    insertedCount++;
                }
                catch (Exception itemEx)
                {
                    Response.Write("{\"status\":\"error\",\"message\":\"خطا در ذخیره آیتم: " + itemEx.Message.Replace("\"", "'").Replace("\r\n", " ") + "\"}");
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
