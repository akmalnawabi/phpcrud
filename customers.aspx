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
            
            // تولید codeM یونیک (10 کاراکتر)
            string codeM = Guid.NewGuid().ToString().Replace("-", "").Substring(0, 10).ToUpper();
            
            // تبدیل موبایل و کد پستی به عدد (اگر فیلد bigint باشد)
            long? mobailM_long = null;
            long? postM_long = null;
            
            // حذف کاراکترهای غیر عددی از موبایل (مثل فاصله، خط تیره و ...)
            string mobailM_clean = mobailM.Replace(" ", "").Replace("-", "").Replace("(", "").Replace(")", "").Replace("+", "");
            if (!string.IsNullOrEmpty(mobailM_clean))
            {
                long tempMobail;
                if (long.TryParse(mobailM_clean, out tempMobail))
                {
                    mobailM_long = tempMobail;
                }
            }
            
            // حذف کاراکترهای غیر عددی از کد پستی
            string postM_clean = postM.Replace(" ", "").Replace("-", "");
            if (!string.IsNullOrEmpty(postM_clean))
            {
                long tempPost;
                if (long.TryParse(postM_clean, out tempPost))
                {
                    postM_long = tempPost;
                }
            }
            
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
                        cmd.Parameters.AddWithValue("@codeM", codeM);
                        cmd.Parameters.AddWithValue("@nameM", string.IsNullOrEmpty(nameM) ? (object)DBNull.Value : nameM);
                        cmd.Parameters.AddWithValue("@Tel1M", DBNull.Value);
                        
                        // اگر mobailM از نوع bigint است، عدد ارسال می‌کنیم
                        if (mobailM_long.HasValue)
                        {
                            cmd.Parameters.AddWithValue("@mobailM", mobailM_long.Value);
                        }
                        else
                        {
                            cmd.Parameters.AddWithValue("@mobailM", DBNull.Value);
                        }
                        
                        // اگر postM از نوع bigint است، عدد ارسال می‌کنیم
                        if (postM_long.HasValue)
                        {
                            cmd.Parameters.AddWithValue("@postM", postM_long.Value);
                        }
                        else
                        {
                            cmd.Parameters.AddWithValue("@postM", DBNull.Value);
                        }
                        
                        cmd.Parameters.AddWithValue("@tedadkol", DBNull.Value);
                        cmd.Parameters.AddWithValue("@adresM", string.IsNullOrEmpty(city) ? (object)DBNull.Value : city);
                        cmd.Parameters.AddWithValue("@MemM", string.IsNullOrEmpty(email) ? (object)DBNull.Value : email);
                        cmd.Parameters.AddWithValue("@codemeli", DBNull.Value);
                        cmd.Parameters.AddWithValue("@datet", DateTime.Now);
                        cmd.Parameters.AddWithValue("@namefather", DBNull.Value);
                        cmd.Parameters.AddWithValue("@codehesabdari", DBNull.Value);
                        
                        cmd.ExecuteNonQuery();
                    }
                    
                    // پاسخ موفقیت
                    Response.Write("{\"status\":\"ok\",\"message\":\"اطلاعات با موفقیت ذخیره شد\",\"codeM\":\"" + codeM + "\"}");
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
