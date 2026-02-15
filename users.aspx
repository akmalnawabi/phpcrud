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
        Response.ContentType = "application/json";
        Response.Charset = "utf-8";

        try
        {
            // خواندن بدنه درخواست (JSON)
            string body = new StreamReader(Request.InputStream, Encoding.UTF8).ReadToEnd();

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

            // فیلدهای مورد نیاز از JSON
            string username     = "";
            string password     = "";
            string firstName    = "";
            string lastName     = "";
            byte   statusId     = 1; // FK_Status_ID پیش‌فرض = 1
            int    userLevelId  = 5; // نقش پیش‌فرض = مشترک

            if (data != null)
            {
                if (data.ContainsKey("username"))
                    username = data["username"] != null ? data["username"].ToString() : "";

                if (data.ContainsKey("password"))
                    password = data["password"] != null ? data["password"].ToString() : "";

                if (data.ContainsKey("first_name"))
                    firstName = data["first_name"] != null ? data["first_name"].ToString() : "";

                if (data.ContainsKey("last_name"))
                    lastName = data["last_name"] != null ? data["last_name"].ToString() : "";

                if (data.ContainsKey("status_id"))
                {
                    byte tmpStatus;
                    if (byte.TryParse(data["status_id"].ToString(), out tmpStatus))
                        statusId = tmpStatus;
                }

                if (data.ContainsKey("role_id"))
                {
                    int tmpRole;
                    if (int.TryParse(data["role_id"].ToString(), out tmpRole))
                        userLevelId = tmpRole;
                }
            }

            // اعتبارسنجی فیلدهای الزامی
            if (string.IsNullOrEmpty(username))
            {
                Response.Write("{\"status\":\"error\",\"message\":\"نام کاربری الزامی است\"}");
                return;
            }

            if (string.IsNullOrEmpty(password))
            {
                Response.Write("{\"status\":\"error\",\"message\":\"رمز عبور الزامی است\"}");
                return;
            }

            // پر کردن مقادیر خالی
            if (string.IsNullOrEmpty(firstName))
                firstName = username;

            if (string.IsNullOrEmpty(lastName))
                lastName = username;

            // محدود کردن طول رشته‌ها به 50 کاراکتر
            username = username.Length > 50 ? username.Substring(0, 50) : username;
            password = password.Length > 50 ? password.Substring(0, 50) : password;
            firstName = firstName.Length > 50 ? firstName.Substring(0, 50) : firstName;
            lastName = lastName.Length > 50 ? lastName.Substring(0, 50) : lastName;

            // ==========================================
            // خواندن Connection String از web.config
            // ==========================================
            string connectionString = string.Format(
                "Server={0};Database={1};User Id={2};Password={3};",
                ConfigurationManager.AppSettings["DbServer"],
                ConfigurationManager.AppSettings["DbName"],
                ConfigurationManager.AppSettings["DbUser"],
                ConfigurationManager.AppSettings["DbPassword"]
            );

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
                    // محاسبه User_ID جدید (بزرگترین + 1)
                    int nextUserId = 1;
                    string maxIdQuery = "SELECT ISNULL(MAX(User_ID), 0) + 1 FROM dbo.Users";
                    using (SqlCommand maxCmd = new SqlCommand(maxIdQuery, conn))
                    {
                        object result = maxCmd.ExecuteScalar();
                        if (result != null && result != DBNull.Value)
                        {
                            nextUserId = Convert.ToInt32(result);
                        }
                    }

                    // INSERT با User_ID محاسبه شده
                    string query = @"
                        INSERT INTO dbo.Users
                            (User_ID, User_Name, User_Password, User_FirstName, User_LastName, FK_Status_ID, FK_UserLevel_ID)
                        VALUES
                            (@User_ID, @User_Name, @User_Password, @User_FirstName, @User_LastName, @FK_Status_ID, @FK_UserLevel_ID);
                    ";

                    using (SqlCommand cmd = new SqlCommand(query, conn))
                    {
                        cmd.Parameters.AddWithValue("@User_ID", nextUserId);
                        cmd.Parameters.AddWithValue("@User_Name", username);
                        cmd.Parameters.AddWithValue("@User_Password", password);
                        cmd.Parameters.AddWithValue("@User_FirstName", firstName);
                        cmd.Parameters.AddWithValue("@User_LastName", lastName);
                        cmd.Parameters.AddWithValue("@FK_Status_ID", statusId);
                        cmd.Parameters.AddWithValue("@FK_UserLevel_ID", userLevelId);

                        cmd.ExecuteNonQuery();
                    }

                    Response.Write("{\"status\":\"ok\",\"message\":\"کاربر با موفقیت ذخیره شد\"}");
                }
                catch (SqlException sqlEx)
                {
                    // بررسی خطای تکراری بودن نام کاربری
                    string errorMessage = sqlEx.Message;
                    if (sqlEx.Number == 2627 || sqlEx.Number == 2601 || errorMessage.Contains("UNIQUE") || errorMessage.Contains("duplicate"))
                    {
                        Response.Write("{\"status\":\"error\",\"message\":\"نام کاربری تکراری است\"}");
                    }
                    else
                    {
                        Response.Write("{\"status\":\"error\",\"message\":\"خطا در ذخیره‌سازی: " + sqlEx.Message.Replace("\"", "'") + "\"}");
                    }
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
