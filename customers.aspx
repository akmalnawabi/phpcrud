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
            // خواندن داده‌های POST
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
            catch (Exception ex)
            {
                Response.Write("{\"status\":\"error\",\"message\":\"خطا در خواندن JSON: " + ex.Message.Replace("\"", "'") + "\"}");
                return;
            }
            
            // استخراج داده‌های فرم
            string nameM = "";
            string mobailM = "";
            string email = "";
            string city = "";
            string postM = "";
            
            if (data != null)
            {
                // اگر داده به صورت مستقیم باشد (از فرم ساده)
                if (data.ContainsKey("name"))
                    nameM = data["name"] != null ? data["name"].ToString() : "";
                if (data.ContainsKey("mobile"))
                    mobailM = data["mobile"] != null ? data["mobile"].ToString() : "";
                if (data.ContainsKey("email"))
                    email = data["email"] != null ? data["email"].ToString() : "";
                if (data.ContainsKey("city"))
                    city = data["city"] != null ? data["city"].ToString() : "";
                if (data.ContainsKey("postal_code"))
                    postM = data["postal_code"] != null ? data["postal_code"].ToString() : "";
                
                // اگر داده از WooCommerce باشد
                if (data.ContainsKey("customer"))
                {
                    nameM = data["customer"] != null ? data["customer"].ToString() : "";
                }
                if (data.ContainsKey("postcode"))
                {
                    postM = data["postcode"] != null ? data["postcode"].ToString() : "";
                }
            }
            
            // اعتبارسنجی - نام و موبایل الزامی است
            if (string.IsNullOrEmpty(nameM) || string.IsNullOrEmpty(mobailM))
            {
                Response.Write("{\"status\":\"error\",\"message\":\"نام و موبایل الزامی است\"}");
                return;
            }
            
            // تولید codeM به صورت bigint (عدد یونیک)
            // استفاده از timestamp + عدد تصادفی برای یونیک بودن
            long codeM = DateTime.Now.Ticks % 10000000000; // 10 رقم آخر از Ticks
            Random rnd = new Random();
            codeM = codeM * 1000 + rnd.Next(0, 999); // اضافه کردن 3 رقم تصادفی
            
            // اگر codeM منفی شد، مثبت می‌کنیم
            if (codeM < 0) codeM = Math.Abs(codeM);
            
            // فرمت تاریخ برای datet (nvarchar(10)) - فرمت: YYYY/MM/DD
            string datet = DateTime.Now.ToString("yyyy/MM/dd");
            
            // اتصال به دیتابیس
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
                
                try
                {
                    // درج داده در جدول Eshterak
                    string query = @"INSERT INTO dbo.Eshterak 
                                    ([codeM], [nameM], [Tel1M], [mobailM], [postM], [tedadkol], 
                                     [adresM], [MemM], [codemeli], [datet], [namefather], [codehesabdari])
                                    VALUES 
                                    (@codeM, @nameM, @Tel1M, @mobailM, @postM, @tedadkol, 
                                     @adresM, @MemM, @codemeli, @datet, @namefather, @codehesabdari)";
                    
                    using (SqlCommand cmd = new SqlCommand(query, conn))
                    {
                        // codeM باید bigint باشد
                        cmd.Parameters.AddWithValue("@codeM", codeM);
                        
                        // nameM - nvarchar(35)
                        cmd.Parameters.AddWithValue("@nameM", string.IsNullOrEmpty(nameM) ? (object)DBNull.Value : (nameM.Length > 35 ? nameM.Substring(0, 35) : nameM));
                        
                        // Tel1M - varchar(15)
                        cmd.Parameters.AddWithValue("@Tel1M", DBNull.Value);
                        
                        // mobailM - varchar(50)
                        cmd.Parameters.AddWithValue("@mobailM", string.IsNullOrEmpty(mobailM) ? (object)DBNull.Value : (mobailM.Length > 50 ? mobailM.Substring(0, 50) : mobailM));
                        
                        // postM - varchar(20)
                        cmd.Parameters.AddWithValue("@postM", string.IsNullOrEmpty(postM) ? (object)DBNull.Value : (postM.Length > 20 ? postM.Substring(0, 20) : postM));
                        
                        // tedadkol - int
                        cmd.Parameters.AddWithValue("@tedadkol", DBNull.Value);
                        
                        // adresM - varchar(150)
                        cmd.Parameters.AddWithValue("@adresM", string.IsNullOrEmpty(city) ? (object)DBNull.Value : (city.Length > 150 ? city.Substring(0, 150) : city));
                        
                        // MemM - nvarchar(200)
                        cmd.Parameters.AddWithValue("@MemM", string.IsNullOrEmpty(email) ? (object)DBNull.Value : (email.Length > 200 ? email.Substring(0, 200) : email));
                        
                        // codemeli - nvarchar(12)
                        cmd.Parameters.AddWithValue("@codemeli", DBNull.Value);
                        
                        // datet - nvarchar(10) - فرمت: YYYY/MM/DD
                        cmd.Parameters.AddWithValue("@datet", datet);
                        
                        // namefather - nvarchar(20)
                        cmd.Parameters.AddWithValue("@namefather", DBNull.Value);
                        
                        // codehesabdari - nvarchar(15) - NOT NULL - باید مقدار داشته باشد
                        cmd.Parameters.AddWithValue("@codehesabdari", ""); // رشته خالی به جای null
                        
                        cmd.ExecuteNonQuery();
                    }
                    
                    // پاسخ موفقیت
                    Response.Write("{\"status\":\"ok\",\"message\":\"اطلاعات با موفقیت ذخیره شد\",\"codeM\":\"" + codeM.ToString() + "\"}");
                }
                catch (SqlException sqlEx)
                {
                    Response.Write("{\"status\":\"error\",\"message\":\"خطا در ذخیره‌سازی: " + sqlEx.Message.Replace("\"", "'") + "\"}");
                }
                catch (Exception ex)
                {
                    Response.Write("{\"status\":\"error\",\"message\":\"خطا: " + ex.Message.Replace("\"", "'") + "\"}");
                }
            }
        }
        catch (Exception ex)
        {
            Response.Write("{\"status\":\"error\",\"message\":\"خطای عمومی: " + ex.Message.Replace("\"", "'") + "\"}");
        }
    }
</script>
